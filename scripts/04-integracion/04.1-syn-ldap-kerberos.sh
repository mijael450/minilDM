#!/bin/bash 
#Este script garantiza la sincronizacion de ldap y kerberos 
set -e  
REALM="FIS.EPN.EC" 
BASE_DN="dc=fis,dc=epn,dc=ec"
PERSONAS_DN="ou=people,${BASE_DN}" 

echo "Sincronizacion kerberos y ldap (realm ${REALM})" 
echo ""
echo "[*] Consultando los usuarios existentes en LDAP ${PERSONAS_DN})" 

LDAP_UIDS=$(ldapsearch -x -LLL -b "$PERSONAS_DN" "(uid=*)" uid \
            | awk -F': ' '/^uid:/ {print $2}' | sort)

if [ -z "$LDAP_UIDS" ]; then 
echo "[!] No se encontraron usuarios en LDAP. Abortando."
    exit 1
fi 
echo "Usuarios encontrados en LDAP:" 
echo "$LDAP_UIDS" | sed 's/^/      - /'

echo ""
echo "[*] Consultando principals en kerberos.." 
KRB_PRINCIPALS=$(sudo kadmin.local -q "list_principals" 2>/dev/null \
                 | grep "@${REALM}" \
                 | grep -vE "^(K/M|kadmin/|krbtgt/|host/|ldap/|http/)" \
                 | grep -v "/admin@" \
                 | sed "s/@${REALM}//" | sort)

echo "    Principals de usuario encontrados en Kerberos:"
echo "$KRB_PRINCIPALS" | sed 's/^/      - /' 

echo "Verificando sincronizacion..." 

echo ""
echo "[*] Verificando faltantes: LDAP -> Kerberos ..."
MISSING_IN_KRB=$(comm -23 <(echo "$LDAP_UIDS") <(echo "$KRB_PRINCIPALS"))
 
if [ -z "$MISSING_IN_KRB" ]; then
    echo "    [OK] Todos los usuarios de LDAP ya tienen principal en Kerberos."
else
    echo "    Usuarios sin principal en Kerberos (se crearan ahora):"
    for uid in $MISSING_IN_KRB; do
        echo "      -> Creando principal para: $uid"
        sudo kadmin.local -q "addprinc -randkey ${uid}"
        echo "         [!] Creado con clave aleatoria. Definir password con:"
        echo "             sudo kadmin.local -q \"cpw ${uid}\""
    done
fi
 
# --- 4. Reportar principals huerfanos (existen en Kerberos, no en LDAP) ---
echo ""
echo "[*] Verificando huerfanos: Kerberos -> LDAP ..."
ORPHANS=$(comm -13 <(echo "$LDAP_UIDS") <(echo "$KRB_PRINCIPALS"))
 
if [ -z "$ORPHANS" ]; then
    echo "    [OK] No hay principals huerfanos."
else
    echo "    [!] ATENCION: los siguientes principals NO tienen cuenta en LDAP:"
    for uid in $ORPHANS; do
        echo "      - ${uid}@${REALM}"
    done
    echo "    Revisar si deben eliminarse o si falta crear la"
    echo "    cuenta correspondiente en LDAP."
fi
 
echo ""
echo "=========================================================="
echo " Sincronizacion completada."
echo "=========================================================="