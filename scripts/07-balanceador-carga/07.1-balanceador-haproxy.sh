#!/bin/bash 
# 07.1-balanceador-haproxy.sh
# Instalacion y configuracion de HAproxy como balanceador de carga para LDAP
# Distribuye el trafico entre ldap1 y ldap2
# Ejecutar en VM3 que funciona como balanceador
# Frontend:  ldap.fis.epn.edu.ec:636
# Backends:  core1.fis.epn.ec:636 (ldap1)
#            core2.fis.epn.ec:636 (ldap2) 
set -e
 
echo "[*] Instalando HAProxy..."
sudo apt-get update
sudo apt install -y haproxy
 
echo "[*] Respaldando configuracion original..."
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak.$(date +%s)
 
echo "[*] Escribiendo configuracion de balanceo LDAPS..."
sudo tee -a /etc/haproxy/haproxy.cfg > /dev/null <<'EOF'
 

# Configuracion del Balanceador de carga 

frontend ldaps_front
    bind *:636
    mode tcp
    option tcplog
    default_backend ldaps_back
 
backend ldaps_back
    mode tcp
    balance roundrobin
    option tcp-check
    server ldap1 core1.fis.epn.ec:636 check
    server ldap2 core2.fis.epn.ec:636 check

# Panel de estadisticas 

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
EOF
 
echo "[*] Validando configuracion..."
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
 
sudo systemctl restart haproxy
sudo systemctl enable haproxy
 
echo ""
echo "[*] Estado del servicio:"
sudo systemctl status haproxy --no-pager | head -8
 
echo ""
echo "[OK] Balanceador HAProxy activo en VM3."
echo ""
echo "Prueba de verificacion sugerida:"
echo "  openssl s_client -connect ldap.fis.epn.edu.ec:636 -CAfile /etc/ssl/fis-ca/certs/ca.cert.pem"
echo "  Panel de estadisticas: http://<ip-vm3>:8404/stats"