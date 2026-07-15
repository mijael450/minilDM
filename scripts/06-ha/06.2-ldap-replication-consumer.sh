#!/bin/bash
# 06.2-ldap-replication-consumer.sh
# Instala OpenLDAP en VM2 (core2) como REPLICA (consumer) del proveedor
# Ejecutar SOLO en VM2 (core2).
set -e

CA_CERT="/etc/ssl/fis-ca/certs/ca.cert.pem"
SERVER_CERT="/etc/ssl/fis-hosts/core2/core2.cert.pem"
SERVER_KEY="/etc/ssl/fis-hosts/core2/core2.key.pem"
BASE_DN="dc=fis,dc=epn,dc=ec"
PROVIDER_URI="ldaps://core1.fis.epn.ec:636"

for f in "$CA_CERT" "$SERVER_CERT" "$SERVER_KEY"; do
    if [ ! -f "$f" ]; then
        echo "[!] No se encontro $f"
        echo "    Ejecuta primero los scripts de 01-pki/ para VM2."
        exit 1
    fi
done

# --- Instalar y configurar ---
echo "[*] Instalando OpenLDAP..."
sudo apt-get update
sudo apt install -y slapd ldap-utils

echo ">> Usar: dominio=fis.epn.ec, org=FIS, backend=MDB"
sudo dpkg-reconfigure slapd
sudo systemctl enable slapd
sudo systemctl start slapd

# --- TLS  ---
echo "[*] Configurando TLS..."
sudo mkdir -p /etc/ldap/tls
sudo cp "$CA_CERT" "$SERVER_CERT" "$SERVER_KEY" /etc/ldap/tls/
sudo chown -R openldap:openldap /etc/ldap/tls
sudo chmod 640 /etc/ldap/tls/core2.key.pem

cat <<EOF | sudo ldapmodify -Y EXTERNAL -H ldapi:///
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/tls/ca.cert.pem
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/tls/core2.cert.pem
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/tls/core2.key.pem
EOF

sudo sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap:/// ldaps:/// ldapi:///"|' /etc/default/slapd
sudo systemctl restart slapd

# --- Password del admin del PROVEEDOR (VM1), necesaria para el bind de syncrepl ---
echo ""
echo "Ingresa la contrasena del admin de LDAP en VM1 (cn=admin,${BASE_DN}):"
read -r -s PROVIDER_ADMIN_PASS
echo ""

# --- Limpiar base de datos local para permitir una sincronizacion completa ---
echo "[*] Deteniendo slapd y limpiando base de datos local..."
sudo systemctl stop slapd
sudo rm -rf /var/lib/ldap/*
sudo systemctl start slapd

# --- Detectar DN de la base de datos MDB en el consumer ---
echo "[*] Detectando base de datos MDB local..."
DB_DN=$(sudo ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config \
        "(&(objectClass=olcMdbConfig))" dn 2>/dev/null | grep "^dn:" | awk '{print $2}')

if [ -z "$DB_DN" ]; then
    echo "[!] No se encontro la base de datos MDB local. Abortando."
    exit 1
fi
echo "    Base de datos local: $DB_DN"

# --- Configurar syncrepl (consumer) ---
echo "[*] Configurando syncrepl apuntando a ${PROVIDER_URI} ..."
SYNC_LDIF=$(mktemp)
cat > "$SYNC_LDIF" <<EOF
dn: ${DB_DN}
changetype: modify
add: olcSyncrepl
olcSyncrepl: rid=001 provider=${PROVIDER_URI} bindmethod=simple binddn="cn=admin,${BASE_DN}" credentials=${PROVIDER_ADMIN_PASS} searchbase="${BASE_DN}" type=refreshAndPersist retry="5 5 300 5" tls_cacert=/etc/ldap/tls/ca.cert.pem tls_reqcert=demand
-
add: olcUpdateRef
olcUpdateRef: ${PROVIDER_URI}
EOF

sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f "$SYNC_LDIF"
rm -f "$SYNC_LDIF"

echo ""
echo "[*] Esperando unos segundos a que la sincronizacion inicial ocurra..."
sleep 5

echo "[*] Verificando datos replicados localmente..."
sudo ldapsearch -Y EXTERNAL -H ldapi:/// -b "${BASE_DN}" "(uid=*)" uid 2>/dev/null | grep "^uid:" || \
    echo "    (Aun no hay datos replicados, puede tardar unos segundos mas)"

echo ""
echo "[OK] VM2 configurado como REPLICA (consumer) de VM1."
echo "     Verificar de nuevo con:"
echo "     ldapsearch -x -LLL -b ${BASE_DN} -H ldap://localhost 'uid=*' uid"