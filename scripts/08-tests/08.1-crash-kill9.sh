#!/bin/bash
# 09.1-fault-crash-kill9.sh
# Experimento de inyeccion de fallos: CRASH abrupto de un servicio (kill -9).
# Mide el tiempo de recuperacion (downtime) y registra el resultado.
#
# Ejecutar en VM1, apuntando al servicio slapd (LDAP master).
set -e

SERVICE="slapd"
TARGET_PORT=636
TARGET_HOST="localhost"
RESULTS_DIR="$HOME/Desktop/Computacion_distribuida/minilDM/tests"
RESULTS_FILE="${RESULTS_DIR}/fault-crash-kill9.csv"

if [ ! -f "$RESULTS_FILE" ]; then
    echo "timestamp,servicio,pid_matado,downtime_segundos,recuperado" > "$RESULTS_FILE"
fi

PID=$(systemctl show -p MainPID --value slapd)
echo "[*] PID de slapd: $PID"
 
echo "[*] Matando proceso (kill -9)..."
sudo kill -9 "$PID"
 
echo "[*] Reiniciando y midiendo tiempo de recuperacion..."
START=$(date +%s.%N)
sudo systemctl start slapd
END=$(date +%s.%N)
 
DOWNTIME=$(echo "$END - $START" | bc)
echo "[OK] Tiempo de recuperacion: ${DOWNTIME}s"
 
echo "$(date -Iseconds),slapd,${PID},${DOWNTIME},si" >> "$RESULTS_FILE"
 
echo "[*] Verificando servicio..."
systemctl status slapd --no-pager | head -3
ldapsearch -x -LLL -b dc=fis,dc=epn,dc=ec -H ldap://localhost 'uid=jperez' cn