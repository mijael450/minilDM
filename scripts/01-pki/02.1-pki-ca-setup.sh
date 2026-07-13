#!/bin/bash
#02.1-pki-setup-sh
#Se crea la Autoridad certificadora con el algoritmo del logaritmo discreto para curvas elipticas (ECDSA) para la infraestructura de pkis 
#Se ejecuta en el servido CA (raiz) 

set -euo pipefail 
CA_DIR="/etc/ssl/fis-ca"
CA_KEY="$CA_DIR/private/ca.key.pem"
CA_CERT="$CA_DIR/certs/ca.cert.pem"
CURVE="prime256v1"   # ECDSA P-256
DAYS_VALID=365

echo "Creando estructura de directorios de la Autoridad certificadora (CA) en $CA_DIR" 

sudo mkdir -p "$CA_DIR"/{certs,crl,newcerts,private,csr} 
sudo chmod 700 "$CA_DIR/private"
sudo touch "$CA_DIR/index.txt"

if [ ! -f "$CA_DIR/serial" ]; then
    sudo bash -c "echo 1000 > $CA_DIR/serial"
fi
 
if [ -f "$CA_KEY" ]; then
    echo "[!] Ya existe una llave de CA en $CA_KEY. Abortando para no sobrescribir."
    exit 1
fi
 
echo "[*] Generando llave privada ECDSA ($CURVE) para la CA..."
sudo openssl ecparam -name "$CURVE" -genkey -noout -out "$CA_KEY"
sudo chmod 400 "$CA_KEY"
 
echo "[*] Generando certificado de la CA raiz (valido $DAYS_VALID dias)..."
sudo openssl req -x509 -new -key "$CA_KEY" \
  -sha256 -days "$DAYS_VALID" \
  -out "$CA_CERT" \
  -subj "/C=EC/ST=Pichincha/L=Quito/O=EPN/OU=IdM/CN=FIS Root CA"
 
echo "[*] Verificando certificado generado..."
openssl x509 -in "$CA_CERT" -noout -text | grep -E "Signature Algorithm|Public Key Algorithm|Subject:|Not After"
 
echo "[OK] CA raiz creada correctamente en $CA_DIR"
echo "     Certificado publico: $CA_CERT"
