#!/bin/bash
#03.2-kerberos.addPrincipals 
#Agrega los principals tanto de usuario como de servicios accediendo a la interfaz adinistrativa del KDC 

set -e
 
REALM="FIS.EPN.EC"
 
echo "=========================================================="
echo " Creando principals de USUARIOS (jperez, malvan, dnoboa)"
echo " Se te pedira definir una contrasena para cada uno."
echo "=========================================================="
 
for user in jperez malvan dnoboa; do
    echo ""
    echo ">> Usuario: ${user}@${REALM}"
    sudo kadmin.local -q "addprinc ${user}"
done
 
echo ""
echo "=========================================================="
echo " Creando principals de SERVICIOS "
echo "=========================================================="
 
# Servicios en core1 (LDAP + host)
sudo kadmin.local -q "addprinc -randkey ldap/core1.fis.epn.ec"
sudo kadmin.local -q "addprinc -randkey host/core1.fis.epn.ec"
 
# Servicios en core2 (HTTP web + host)
sudo kadmin.local -q "addprinc -randkey http/core2.fis.epn.ec"
sudo kadmin.local -q "addprinc -randkey host/core2.fis.epn.ec"
 
echo ""
echo "=========================================================="
echo " Exportando keytabs"
echo "=========================================================="
 
# Keytab para los servicios locales de core1 (LDAP)
sudo mkdir -p /etc/ldap/keytab
sudo kadmin.local -q "ktadd -k /etc/ldap/keytab/core1.keytab ldap/core1.fis.epn.ec host/core1.fis.epn.ec"
sudo chown openldap:openldap /etc/ldap/keytab/core1.keytab
sudo chmod 640 /etc/ldap/keytab/core1.keytab
 
# Keytab para los servicios de core2 (HTTP)
sudo mkdir -p /tmp/keytabs
sudo kadmin.local -q "ktadd -k /tmp/keytabs/core2.keytab HTTP/core2.fis.epn.ec host/core2.fis.epn.ec"
 
echo ""
echo "[OK] Principals y keytabs creados."
echo ""
echo "Verificar lista completa de los principals:"
sudo kadmin.local -q "list_principals"
echo ""
echo "Siguiente paso: transferir /tmp/keytabs/core2.keytab a VM2, ej:"
echo " sudo scp /tmp/keytabs/core2.keytab kali@192.168.100.9:/tmp/"
echo "recuerda mover el archivo core2.keytab si reinicias la maquina de core2"