#!/bin/bash
# 01-setup-hosts.sh
# Configuracion de /etc/hosts y sincronizacion horaria.
# Se debe ejecutar en las 3 maquinas. 
set -euo pipefail

HOSTS_ENTRIES="
192.168.100.6   core1.fis.epn.ec   core1   ldap1   kdc1
192.168.100.9   core2.fis.epn.ec   core2   ldap2   kdc2
192.168.100.3   client.fis.epn.ec  client

#  balanceador 
192.168.100.6   ldap.fis.epn.edu.ec
"

MARKER_START="# --- FIS-MiniIdM BEGIN ---"
MARKER_END="# --- FIS-MiniIdM END ---"

if grep -q "$MARKER_START" /etc/hosts 2>/dev/null; then
    echo "[*] Entradas ya presentes en /etc/hosts, omitiendo..."
else
    echo "[*] Agregando entradas a /etc/hosts..."
    {
        echo "$MARKER_START"
        echo "$HOSTS_ENTRIES"
        echo "$MARKER_END"
    } | sudo tee -a /etc/hosts > /dev/null
fi

echo "[*] Habilitando systemd-timesyncd..."
sudo systemctl enable --now systemd-timesyncd
sudo timedatectl set-ntp true

echo "[*] Estado de sincronizacion:"
timedatectl status | grep -E "System clock synchronized|NTP service"

echo "[*] Hora actual: $(date)"
echo "[OK] Configuracion base completada."