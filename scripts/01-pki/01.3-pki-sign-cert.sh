#!/bin/bash
# 01.3-pki-sign-cert.sh
# Firma un CSR con la CA raiz de la FIS.
# Ejecutar solo donde se tenga la llave privada de la Autoridad certificadora.
#
# Uso: bash 04-pki-sign-cert.sh <ruta_csr> <nombre_corto>
# Ejemplo: bash 04-pki-sign-cert.sh /tmp/core2.csr.pem core2
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Uso: $0 <ruta_csr> <nombre_corto>"
    echo "Ejemplo: $0 /tmp/core2.csr.pem core2"
    exit 1
fi

CSR_FILE="$1"
SHORT_NAME="$2"
DAYS_VALID=120   

CA_DIR="/etc/ssl/fis-ca"
CA_KEY="$CA_DIR/private/ca.key.pem"
CA_CERT="$CA_DIR/certs/ca.cert.pem"

OUT_DIR="/etc/ssl/fis-ca/issued"
OUT_CERT="${OUT_DIR}/${SHORT_NAME}.cert.pem"

if [ ! -f "$CSR_FILE" ]; then
    echo "[!] No se encontro el CSR en $CSR_FILE"
    exit 1
fi

sudo mkdir -p "$OUT_DIR"

echo "[*] Firmando CSR para ${SHORT_NAME} con la CA raiz (valido ${DAYS_VALID} dias)..."
sudo openssl x509 -req \
  -in "$CSR_FILE" \
  -CA "$CA_CERT" \
  -CAkey "$CA_KEY" \
  -CAcreateserial \
  -days "$DAYS_VALID" \
  -sha256 \
  -copy_extensions copy \
  -out "$OUT_CERT"

echo "[*] Certificado emitido. Verificando SAN incluido..."
openssl x509 -in "$OUT_CERT" -noout -text | grep -A2 "Subject Alternative Name"

echo ""
echo "[OK] Certificado firmado: $OUT_CERT"
