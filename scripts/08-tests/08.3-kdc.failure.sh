#!/bin/bash
# 09.4-fault-kdc-failure.sh
# Experimento: fallo del KDC primario (detener krb5-kdc). Mide tiempo
# de recuperacion del servicio y registra el resultado.
# Ejecutar en VM1.
set -e

RESULTS_DIR="$HOME/Desktop/Computacion_distribuida/minilDM/tests"
RESULTS_FILE="$RESULTS_DIR/fault-kdc-failure.csv"

[ -f "$RESULTS_FILE" ] || echo "timestamp,servicio,downtime_segundos" > "$RESULTS_FILE"

echo "[*] Deteniendo krb5-kdc ..."
sudo systemctl stop krb5-kdc

echo "[*] Verificando que el KDC primario esta caido:"
systemctl is-active krb5-kdc || echo "    (inactivo)"

echo "[*] Reiniciando y midiendo tiempo de recuperacion..."
START=$(date +%s.%N)
sudo systemctl start krb5-kdc
END=$(date +%s.%N)

DOWNTIME=$(echo "$END - $START" | bc)
echo "[OK] Tiempo de recuperacion: ${DOWNTIME}s"

echo "$(date -Iseconds),krb5-kdc,${DOWNTIME}" >> "$RESULTS_FILE"

echo "[*] Verificando servicio activo:"
systemctl status krb5-kdc --no-pager | head -3
echo ""
