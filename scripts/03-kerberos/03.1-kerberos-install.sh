#!/bin/bash
# 03.1-kerberos-install-kdc.sh
# Instala el KDC y servidor de administracion de Kerberos (MIT) para la FIS.
# Ejecutar en(core1) - KDC primario.
set -e

echo ">> Responder con lo siguiente en el menu interactivo"
echo "   Default Kerberos version 5 realm:      FIS.EPN.EC"
echo "   Kerberos servers for your realm:       core1.fis.epn.ec"
echo "   Administrative server for your realm:  core1.fis.epn.ec"
echo ""

sudo apt-get update
sudo apt install -y krb5-kdc krb5-admin-server krb5-config

sudo krb5_newrealm

sudo systemctl enable krb5-kdc krb5-admin-server
sudo systemctl start krb5-kdc krb5-admin-server

echo ""
echo "[*] Estado de los servicios:"
sudo systemctl status krb5-kdc --no-pager | head -5
sudo systemctl status krb5-admin-server --no-pager | head -5

echo ""
echo "[OK] KDC de Kerberos instalado para el realm FIS.EPN.EC"
echo "Siguiente paso: añadir los principals con los mismos nombres que los usuarios agregados en ldap" 
echo "ejm: sudo kadmin.local -q "addprinc <usuario>" "