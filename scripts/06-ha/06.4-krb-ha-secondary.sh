#!/bin/bash
# 06.4-krb-ha-secondary.sh
# Configura VM2 (core2) como KDC SECUNDARIO
# Ejecutar SOLO en VM2.
set -e

REALM="FIS.EPN.EC"

echo ">> Durante la instalacion responder lo siguiente"
echo "   Default Kerberos version 5 realm:      FIS.EPN.EC"
echo "   Kerberos servers for your realm:       core1.fis.epn.ec"
echo "   Administrative server for your realm:  core1.fis.epn.ec"
echo ""

sudo apt-get update
sudo apt install -y krb5-kdc

# --- Crear una base de datos local vacia (temporal)
echo ""
echo "[*] Creando base de datos local temporal"
echo " Define una master key temporal."
sudo kdb5_util create -s

sudo systemctl enable krb5-kdc
sudo systemctl start krb5-kdc
  

# --- ACL de propagacion: solo VM1 puede enviar actualizaciones ---
echo "[*] Configurando kpropd.acl ..."
echo "host/core1.fis.epn.ec@${REALM}" | sudo tee /etc/krb5kdc/kpropd.acl > /dev/null

# --- Servicio para kpropd  ---
echo "[*] Creando servicio para kpropd..."
sudo tee /etc/systemd/system/kpropd.service > /dev/null <<'EOF'
[Unit]
Description=Kerberos kpropd 
After=network.target krb5-kdc.service

[Service]
Type=simple
ExecStart=/usr/sbin/kpropd -S
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable kpropd
sudo systemctl start kpropd

echo ""
echo "[*] Estado de servicios:"
sudo systemctl status krb5-kdc --no-pager | head -5
sudo systemctl status kpropd --no-pager | head -5

echo ""
echo "[OK] VM2 (secundario) listo para recibir propagacion."
echo "Siguiente paso: en VM1, generar el keytab de host/core2 y ejecutar"
echo "06.5-kerberos-ha-propagate.sh para enviar la base de datos."