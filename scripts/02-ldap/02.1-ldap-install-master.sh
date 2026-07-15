#!/bin/bash
# 01.1-ldap-install-master.sh
# Instala OpenLDAP master (cn=config, via dpkg-reconfigure) y habilita TLS.
# Ejecutar SOLO en VM1 (core1).
set -e

CA_CERT="/etc/ssl/fis-ca/certs/ca.cert.pem"
SERVER_CERT="/etc/ssl/fis-ca/issued/core1.cert.pem"
SERVER_KEY="/etc/ssl/fis-hosts/core1/core1.key.pem"

# --- Instalar y configurar (interactivo, igual que en la practica) ---
sudo apt-get update
sudo apt install -y slapd ldap-utils

echo ">> En el asistente usa: dominio=fis.epn.ec, org=FIS, backend=MDB"
sudo dpkg-reconfigure slapd

# --- Asegurar que el servicio quede habilitado y corriendo ---
sudo systemctl enable slapd
sudo systemctl start slapd

# --- Copiar certificados a ubicacion legible por openldap ---
sudo mkdir -p /etc/ldap/tls
sudo cp "$CA_CERT" "$SERVER_CERT" "$SERVER_KEY" /etc/ldap/tls/
sudo chown -R openldap:openldap /etc/ldap/tls
sudo chmod 640 /etc/ldap/tls/core1.key.pem

# --- Habilitar TLS via ldapmodify (cn=config) ---
cat <<EOF | sudo ldapmodify -Y EXTERNAL -H ldapi:///
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/tls/ca.cert.pem
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/tls/core1.cert.pem
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/tls/core1.key.pem
EOF

# --- Habilitar puerto ldaps (636) ---
sudo sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap:/// ldaps:/// ldapi:///"|' /etc/default/slapd
sudo systemctl restart slapd

echo "[OK] LDAP master listo con TLS."
echo "Verificar con: openssl s_client -connect core1.fis.epn.ec:636 -CAfile /etc/ldap/tls/ca.cert.pem"