#!/bin/bash 
#05.1-webapp-krb-tls.sh 
#Instalacion de apache con tls y autenticacion de kerberos con el modulo "mod_auth_gssap"
#Requisitos previos 
# -Certificado TLS de core2 
# -Keytab http/core2.fis.epn.ec transferido desde la el servidor kerberos vm1 

CA_CERT="/etc/ssl/fis-ca/certs/ca.cert.pem"
SERVER_CERT="/etc/ssl/fis-hosts/core2/core2.cert.pem"
SERVER_KEY="/etc/ssl/fis-hosts/core2/core2.key.pem"
KEYTAB_SRC="/tmp/core2.keytab"
KEYTAB_DEST="/etc/apache2/http-core2.keytab"

#Verificacion de pre-requisitos 
for f in "$CA_CERT" "$SERVER_CERT" "$SERVER_KEY" "$KEYTAB_SRC"; do 
    if [ ! -f "$f" ]; then 
        echo "[!] No se encontro $f"
        exit 1
    fi 
done 

#Intalacion de apache, dependencias y cliente kerberos
sudo apt-get update 
sudo apt-get install -y apache2 libapache2-mod-auth-gssapi krb5-user 

sudo a2enmod ssl auth_gssapi 

#Ubicar el keytab para que apache lo pueda usar
echo "[*] Instalando keytab de servicio..."
sudo cp "$KEYTAB_SRC" "$KEYTAB_DEST"
sudo chown www-data:www-data "$KEYTAB_DEST"
sudo chmod 400 "$KEYTAB_DEST" 

# Creacion de una pagina de prueba
echo "[*] Creando pagina de prueba..."
sudo mkdir -p /var/www/fis-webapp
sudo tee /var/www/fis-webapp/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html><body>
<h1>FIS MiniIdM - Servicio Web Protegido</h1>
<p>Autenticado correctamente via Kerberos sobre TLS.</p>
</body></html>
EOF

# --- VirtualHost con TLS + autenticacion GSSAPI ---
echo "[*] Configurando VirtualHost..."
sudo tee /etc/apache2/sites-available/fis-webapp.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName core2.fis.epn.ec
    DocumentRoot /var/www/fis-webapp
 
    SSLEngine on
    SSLCertificateFile      ${SERVER_CERT}
    SSLCertificateKeyFile   ${SERVER_KEY}
    SSLCACertificateFile    ${CA_CERT}
    LogLevel auth_gssapi:trace8
    <Directory /var/www/fis-webapp>
        AuthType GSSAPI
        AuthName "FIS Kerberos Login"
        GssapiCredStore keytab:${KEYTAB_DEST}
        Require valid-user
    </Directory>
</VirtualHost>
EOF
 
sudo a2ensite fis-webapp.conf
sudo a2dissite 000-default.conf 2>/dev/null || true
 
sudo apache2ctl configtest
sudo systemctl restart apache2
sudo systemctl enable apache2
 
echo ""
echo "[OK] Servicio web con TLS + Kerberos listo en https://core2.fis.epn.ec/"
echo ""
echo "Prueba desde VM3 (cliente):"
echo "  kinit jperez"
echo "  curl --negotiate -u : -k https://core2.fis.epn.ec/"