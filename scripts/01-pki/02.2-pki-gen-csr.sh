#!/bin/bash
# 03-pki-gen-csr.sh
# Genera llave privada ECDSA y un CSR  para este servidor.
# La llave privada generada aqui NUNCA sale de esta maquina.
#
# Uso: bash 03-pki-gen-csr.sh <nombre> <ip>
# Ejemplo en VM1: bash 03-pki-gen-csr.sh core1 192.168.100.6

set -euo pipefail
 
if [ $# -ne 2 ]; then
    echo "Uso: $0 <nombre_corto> <ip>"
    echo "Ejemplo: $0 core1 192.168.100.6"
    exit 1
fi
 
SHORT_NAME="$1"
IP_ADDR="$2"
FQDN="${SHORT_NAME}.fis.epn.ec"
CURVE="prime256v1"
 
CERT_DIR="/etc/ssl/fis-hosts/${SHORT_NAME}"
KEY_FILE="${CERT_DIR}/${SHORT_NAME}.key.pem"
CSR_FILE="${CERT_DIR}/${SHORT_NAME}.csr.pem"
SAN_CONF="${CERT_DIR}/${SHORT_NAME}.san.cnf"
 
echo "[*] Creando directorio ${CERT_DIR} ..."
sudo mkdir -p "$CERT_DIR"
 
echo "[*] Generando llave privada ECDSA (${CURVE}) para ${SHORT_NAME} ..."
sudo openssl ecparam -name "$CURVE" -genkey -noout -out "$KEY_FILE"
sudo chmod 400 "$KEY_FILE"
 
echo "[*] Creando archivo de configuracion SAN ..."
sudo tee "$SAN_CONF" > /dev/null <<EOF
[req]
default_bits       = 256
prompt             = no
distinguished_name = dn
req_extensions     = req_ext
 
[dn]
C  = EC
ST = Pichincha
L  = Quito
O  = FIS-EPN
OU = IdM
CN = ${FQDN}
 
[req_ext]
subjectAltName = @alt_names
 
[alt_names]
DNS.1 = ${FQDN}
DNS.2 = ${SHORT_NAME}
DNS.3 = ldap.fis.epn.edu.ec
IP.1  = ${IP_ADDR}
EOF
 
echo "[*] Generando CSR (Certificate Signing Request) ..."
sudo openssl req -new -key "$KEY_FILE" \
  -out "$CSR_FILE" \
  -config "$SAN_CONF"

echo "[*] Copiando el "
 
echo "[OK] CSR generado en: $CSR_FILE"
echo "     Llave privada (NO transferir):   $KEY_FILE"
echo ""
echo "Siguiente paso: copiar el CSR a VM1 (CA) para firmarlo, ej:"
echo "  scp $CSR_FILE kali@192.168.100.6:/tmp/${SHORT_NAME}.csr.pem"
 