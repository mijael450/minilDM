#!/bin/bash 
#06.1-ldap-replication.sh
#Configura core1 como proveedor de replicacion de LDAP con syncrepl. 
#Ejecutar solo en vm1 (core1) 

set -e 

echo "[*] Detectando el DN de la base de datos MDB en cn=config..."
DB_DN=$(sudo ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config \
        "(&(objectClass=olcMdbConfig))" dn 2>/dev/null | grep "^dn:" | awk '{print $2}')
 
if [ -z "$DB_DN" ]; then
    echo "[!] No se encontro la base de datos MDB. Abortando."
    exit 1
fi
echo "    Base de datos detectada: $DB_DN"
 
# --- Cargar el modulo syncprov si no esta cargado ---
echo "[*] Verificando modulo syncprov..."
MODULE_LOADED=$(sudo ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config \
                "(objectClass=olcModuleList)" olcModuleLoad 2>/dev/null | grep -i syncprov || true)
 
if [ -z "$MODULE_LOADED" ]; then
    echo "[*] Cargando modulo syncprov..."
    MOD_LDIF=$(mktemp)
    cat > "$MOD_LDIF" <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov
EOF
    sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f "$MOD_LDIF"
    rm -f "$MOD_LDIF"
else
    echo "    Ya estaba cargado."
fi
 
# --- Agregar el overlay syncprov a la base de datos ---
echo "[*] Configurando overlay syncprov en $DB_DN ..."
OVERLAY_LDIF=$(mktemp)
cat > "$OVERLAY_LDIF" <<EOF
dn: olcOverlay=syncprov,${DB_DN}
changetype: add
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpCheckpoint: 100 10
olcSpSessionlog: 100
EOF
 
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f "$OVERLAY_LDIF" || \
    echo "    (El overlay ya podria existir, continuando...)"
rm -f "$OVERLAY_LDIF"
 
# --- Habilitar limits para el usuario admin que usara la replica ---
echo "[*] Habilitando limites de busqueda ilimitados para el admin (replicacion)..."
LIMITS_LDIF=$(mktemp)
cat > "$LIMITS_LDIF" <<EOF
dn: ${DB_DN}
changetype: modify
add: olcLimits
olcLimits: dn.exact="cn=admin,dc=fis,dc=epn,dc=ec" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited
EOF
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f "$LIMITS_LDIF" || \
    echo "    (Los limites ya podrian existir, continuando...)"
rm -f "$LIMITS_LDIF"
 
echo ""
echo "[OK] VM1 configurado como PROVEEDOR de replicacion LDAP."
echo "     Verificar con: ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config olcOverlay"