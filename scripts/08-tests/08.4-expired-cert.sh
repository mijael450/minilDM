#!/bin/bash
# 08.4-expired-cert.sh
# Experimento: reemplazar el certificado valido de core1 por uno ya expirado, y verificar el comportamiento de TLS (LDAP). Restaura el certificado original al finalizar.
# Ejecutar en VM1.
set -e

RESULTS_DIR="$HOME/Desktop/Computacion_distribuida/minilDM/tests"
RESULTS_FILE="$RESULTS_DIR/fault-expired-cert.csv"
mkdir -p "$RESULTS_DIR"
[ -f "$RESULTS_FILE" ] || echo "timestamp,host,verify_code_expirado,verify_code_restaurado" > "$RESULTS_FILE"

CA_CERT="/etc/ssl/fis-ca/certs/ca.cert.pem"
CA_KEY="/etc/ssl/fis-ca/private/ca.key.pem"
TLS_DIR="/etc/ldap/tls"
CERT_FILE="$TLS_DIR/core1.cert.pem"
KEY_FILE="$TLS_DIR/core1.key.pem"
BACKUP_CERT="$TLS_DIR/core1.cert.pem.bak"

echo "[*] Respaldando certificado valido actual..."
sudo cp "$CERT_FILE" "$BACKUP_CERT"

echo "[*] Generando certificado YA EXPIRADO (valido hace 2 dias, vencido ayer)..."
TMP_CSR=$(mktemp)
sudo openssl req -new -key "$KEY_FILE" -out "$TMP_CSR" \
    -subj "/C=EC/ST=Pichincha/L=Quito/O=FIS-EPN/OU=IdM/CN=core1.fis.epn.ec"

sudo openssl x509 -req -in "$TMP_CSR" \
    -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial \
    -not_before "$(date -d '2 days ago' '+%Y%m%d%H%M%SZ')" \
    -not_after "$(date -d 'yesterday' '+%Y%m%d%H%M%SZ')" \
    -sha256 -out "$CERT_FILE"
rm -f "$TMP_CSR"

echo "[*] Reiniciando slapd con el certificado expirado..."
sudo systemctl restart slapd

echo "[*] Probando conexion TLS ..."
OUT_EXPIRED=$(echo | openssl s_client -connect core1.fis.epn.ec:636 -CAfile "$CA_CERT" 2>&1 || true)
CODE_EXPIRED=$(echo "$OUT_EXPIRED" | grep "Verify return code" | grep -o '[0-9]\+' | head -1)
echo "    Verify return code obtenido: ${CODE_EXPIRED} (10 = certificate has expired)"

echo "[*] Restaurando el certificado original..."
sudo cp "$BACKUP_CERT" "$CERT_FILE"
sudo systemctl restart slapd

echo "[*] Confirmando que la conexion vuelve a validar correctamente..."
OUT_RESTORED=$(echo | openssl s_client -connect core1.fis.epn.ec:636 -CAfile "$CA_CERT" 2>&1 || true)
CODE_RESTORED=$(echo "$OUT_RESTORED" | grep "Verify return code" | grep -o '[0-9]\+' | head -1)
echo "    Verify return code obtenido: ${CODE_RESTORED} (0 = ok)"

echo "$(date -Iseconds),core1.fis.epn.ec,${CODE_EXPIRED},${CODE_RESTORED}" >> "$RESULTS_FILE"
echo "[OK] Experimento completado y registrado en ${RESULTS_FILE}"