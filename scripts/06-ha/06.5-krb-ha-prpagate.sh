#!/bin/bash
# 07.2-kerberos-ha-propagate.sh
# Genera el keytab de host/core2y propaga la base de datos de Kerberos de VM1 -> VM2.
# Ejecutar SOLO en VM1. Requiere que 07.3 ya se haya corrido en VM2.
set -e

REALM="FIS.EPN.EC"
VM2_IP="192.168.100.9"
VM2_USER="kali"

# --- 1. Generar keytab de host/core2 para que kpropd en VM2 se autentique ---
echo "[*] Generando keytab de host/core2.fis.epn.ec..."
sudo mkdir -p /tmp/keytabs
sudo kadmin.local -q "ktadd -k /tmp/keytabs/host-core2.keytab host/core2.fis.epn.ec"

echo "[*] Transfiriendo keytab a VM2..."
sudo chmod 644 /tmp/keytabs/host-core2.keytab
scp /tmp/keytabs/host-core2.keytab ${VM2_USER}@${VM2_IP}:/tmp/host-core2.keytab

echo ""
echo ">> En VM2 "
echo "   a /etc/krb5.keytab:"
echo ""
echo "   sudo ktutil <<EOF2"
echo "   rkt /tmp/host-core2.keytab"
echo "   wkt /etc/krb5.keytab"
echo "   quit"
echo "   EOF2"
echo ""
read -r -p "Presiona ENTER cuando hayas hecho esto en VM2 y kpropd este corriendo..."

# --- 2. Volcar (dump) la base de datos actual ---
echo ""
echo "[*] Generando dump de la base de datos de Kerberos..."
sudo kdb5_util dump /var/lib/krb5kdc/replica_datatrans

# --- 3. Propagar a VM2 via kprop ---
echo "[*] Propagando base de datos a core2.fis.epn.ec ..."
START_TIME=$(date +%s.%N)
sudo kprop -f /var/lib/krb5kdc/replica_datatrans core2.fis.epn.ec
END_TIME=$(date +%s.%N)

ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
echo ""
echo "[OK] Propagacion completada."
echo "     Tiempo de propagacion: ${ELAPSED} segundos"
echo ""
echo "Verificar en VM2 con:"
echo "  sudo kdb5_util list_mkeys"
echo "  sudo kadmin.local -q 'list_principals'"