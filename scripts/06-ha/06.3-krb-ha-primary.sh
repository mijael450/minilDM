#!/bin/bash
# 06.3-krb-ha-primary.sh
# Prepara VM1 (KDC primario) para HA: crea keytab del host y actualiza
# krb5.conf para que los clientes conozcan ambos KDCs (core1 y core2).
# Ejecutar SOLO en VM1.
set -e

REALM="FIS.EPN.EC"

echo "[*] Anadiendo host/core1.fis.epn.ec al keytab local /etc/krb5.keytab..."
sudo kadmin.local -q "ktadd host/core1.fis.epn.ec"

echo "[*] Verificando /etc/krb5.conf ..."
if ! grep -q "core2.fis.epn.ec" /etc/krb5.conf; then
    echo "[*] Agregando core2 como KDC secundario en krb5.conf..."
    sudo sed -i "/\[realms\]/,/}/ { /kdc = core1.fis.epn.ec/a\\
        kdc = core2.fis.epn.ec
}" /etc/krb5.conf
else
    echo "    core2 ya esta listado como KDC."
fi

echo ""
echo "[*] Seccion [realms] resultante:"
grep -A5 "\[realms\]" /etc/krb5.conf

echo ""
echo "[OK] VM1 (primario) listo para HA."
echo "Ejecutar 06.4-krb-ha-secondary.sh en VM2,"
