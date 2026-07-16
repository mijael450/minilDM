#!/bin/bash
# 08.2-network-partition.sh
# Experimento: particion de red via iptables. Bloquea trafico hacia un
# host especifico durante N segundos, sin detener ningun servicio.
# Ejecutar en VM1 (o el nodo desde donde se probara la particion).

TARGET_IP="$1"
DURATION="${2:-15}"
 
if [ -z "$TARGET_IP" ]; then
    echo "Uso: $0 <ip_a_bloquear> [duracion_segundos]"
    echo "Ejemplo: $0 192.168.100.9 15"
    exit 1
fi
 
RESULTS_DIR="$HOME/Desktop/Computacion_distribuida/minilDM/tests"
RESULTS_FILE="$RESULTS_DIR/fault-network-partition.csv"
mkdir -p "$RESULTS_DIR"
[ -f "$RESULTS_FILE" ] || echo "timestamp,ip_bloqueada,duracion_segundos" > "$RESULTS_FILE"
 
echo "[*] Bloqueando trafico hacia ${TARGET_IP} por ${DURATION}s..."
sudo iptables -A OUTPUT -d "$TARGET_IP" -j DROP
sudo iptables -A INPUT -s "$TARGET_IP" -j DROP
 
echo "[*] Verificando que el bloqueo este activo (deberia fallar):"
ping -c 2 -W 2 "$TARGET_IP" || echo " (sin respuesta)"
 
echo "[*] Esperando ${DURATION}s con la particion activa..."
sleep "$DURATION"
 
echo "[*] Removiendo el bloqueo..."
sudo iptables -D OUTPUT -d "$TARGET_IP" -j DROP
sudo iptables -D INPUT -s "$TARGET_IP" -j DROP
 
echo "$(date -Iseconds),${TARGET_IP},${DURATION}" >> "$RESULTS_FILE"
echo "[OK] Particion de red completada y registrada."
 
echo "[*] Verificando que la conectividad se restauro:"
ping -c 2 "$TARGET_IP" || echo "    (aviso: algun paquete se perdio justo al restaurar)"