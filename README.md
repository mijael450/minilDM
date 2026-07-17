# MiniIdM



## Objetivo

Diseñar, implementar y evaluar una infraestructura segura de autenticación y
servicios de directorio para la FIS, integrando:

1. Autenticación Kerberos (MIT Kerberos)
2. Infraestructura de Llave Pública (PKI) con OpenSSL
3. Servicios de Directorio LDAP (OpenLDAP)
4. Alta Disponibilidad (replicación LDAP, KDC secundario, balanceo de carga)

## Arquitectura y roles de las VMs

Con solo 3 máquinas disponibles, los roles del diagrama original se
consolidaron así:

| VM  | Hostname (alias)     | IP              | Roles                                                             |
|-----|-----------------------|-----------------|--------------------------------------------------------------------|
| VM1 | core1.fis.epn.ec      | 192.168.100.6   | CA Raíz, LDAP Master, KDC Primario                                 |
| VM2 | core2.fis.epn.ec      | 192.168.100.9   | LDAP Réplica, KDC Secundario, Servicio Web (Apache+TLS+Kerberos)   |
| VM3 | client.fis.epn.ec     | 192.168.100.3   | Cliente de pruebas, Balanceador HAProxy, Servidor Prometheus       |

La resolución de nombres se maneja completamente vía `/etc/hosts` en las
3 máquinas (sin DNS dedicado ni cambio del hostname real del sistema
operativo, salvo en pruebas puntuales documentadas más abajo).

Realm Kerberos: `FIS.EPN.EC`
Base DN LDAP: `dc=fis,dc=epn,dc=ec`

## Estructura del repositorio

```
.
├── config/
│   └── dit.ldif                        Estructura del DIT LDAP
├── scripts/
│   ├── 00-base/            00.1-setup-hosts.sh
│   ├── 01-pki/             01.1-pki-setup.sh, 01.2-pki-gen-csr.sh, 01.3-pki-sign-cert.sh
│   ├── 02-ldap/            02.1-ldap-install-master.sh
│   ├── 03-kerberos/        03.1-kerberos-install.sh, 03.2-kerberos-addPrincipals.sh
│   ├── 04-integracion/     04.1-syn-ldap-kerberos.sh
│   ├── 05-webapp-tls/      05.1-webapp-krb-tls.sh
│   ├── 06-ha/              06.1-ldap-replication.sh, 06.2-ldap-replication-consumer.sh,
│   │                       06.3-krb-ha-primary.sh, 06.4-krb-ha-secondary.sh,
│   │                       06.5-krb-ha-prpagate.sh
│   ├── 07-balanceador-carga/  07.1-balanceador-haproxy.sh
│   ├── 08-tests/           08.1-crash-kill9.sh, 08.2-network-partition.sh,
│   │                       08.3-kdc.failure.sh
│   └── 09-monitoreo/       09.1-monitoring-node-exporter.sh,
│                           09.2-monitoring-prometheus-server.sh
├── tests/                  Resultados CSV de los experimentos de fallos
├── webapp/                 Servicio web de prueba (Apache + mod_auth_gssapi)
├── Guia-MiniIdM.md
├── Lab2-miniIdM.pdf        Enunciado original del proyecto
├── makefile
└── README.md
```

## Prerrequisitos

- 3 VMs Debian/Ubuntu o cualquier otra distribucion basada en debian, conectadas en la misma red.
- Acceso `sudo` en las 3 máquinas.


## Guía de despliegue

### 1. Servicio de Directorio LDAP (VM1)
Instalar OpenLDAP con Base DN `dc=fis,dc=epn,dc=ec`, TLS habilitado, y
carga el DIT (`ou=people` con sub-OUs `profesores`/`estudiantes`/`empleados`,
más `ou=groups`).

```bash
bash scripts/02-ldap/02.1-ldap-install-master.sh
ldapadd -x -D cn=admin,dc=fis,dc=epn,dc=ec -W -f config/dit.ldif
```

Verificación:
```bash
openssl s_client -connect core1.fis.epn.ec:636 -CAfile /etc/ssl/fis-ca/certs/ca.cert.pem
```

### 2. Infraestructura de Llave Pública 
CA raíz con ECDSA (curva prime256v1), certificados emitidos para
cada servidor.

```bash
bash scripts/01-pki/01.1-pki-setup.sh                          # VM1
bash scripts/01-pki/01.2-pki-gen-csr.sh core1 192.168.100.6    # VM1
bash scripts/01-pki/01.3-pki-sign-cert.sh <csr> core1           # VM1
bash scripts/01-pki/01.2-pki-gen-csr.sh core2 192.168.100.9    # VM2 (luego transferir CSR/cert por scp)
```

### 3. Autenticación Kerberos (VM1)
KDC + servidor de administración para el realm `FIS.EPN.EC`. Principals
de usuario (`jperez`, `malvan`, `dnoboa`) y de servicio (`ldap/core1`,
`HTTP/core2`, `host/core1`, `host/core2`).

```bash
bash scripts/03-kerberos/03.1-kerberos-install.sh
bash scripts/03-kerberos/03.2-kerberos-addPrincipals.sh
```

> 

### 4. Integración LDAP-Kerberos (VM1)
**sincronización activa**: un script
compara los `uid` de LDAP contra los principals de Kerberos, crea los
que falten y reporta huérfanos.

```bash
bash scripts/04-integracion/04.1-syn-ldap-kerberos.sh
```

### 5. Servicios Protegidos con TLS (VM2)
Apache + `mod_auth_gssapi`, usando el certificado de la CA y el keytab
de `HTTP/core2.fis.epn.ec`.

```bash
bash scripts/05-webapp-tls/05.1-webapp-krb-tls.sh
```

Prueba end-to-end (desde VM3):
```bash
kinit jperez
curl --negotiate -u : -k https://core2.fis.epn.ec/
```

### 6. Replicación de LDAP (VM1 → VM2)
`syncrepl` sobre TLS, modo `refreshAndPersist`.

```bash
bash scripts/06-ha/06.1-ldap-replication.sh            # VM1 (provider)
bash scripts/06-ha/06.2-ldap-replication-consumer.sh    # VM2 (consumer)
```

Prueba (la que exige el PDF): agregar usuario en el master, confirmar
réplica, detener el master, confirmar que las lecturas siguen
funcionando desde la réplica.

### 7. HA de Kerberos (VM1 ↔ VM2)
KDC secundario en VM2, propagación de base de datos vía `kprop`/`kpropd`.

```bash
bash scripts/06-ha/06.3-krb-ha-primary.sh      # VM1
bash scripts/06-ha/06.4-krb-ha-secondary.sh    # VM2
bash scripts/06-ha/06.5-krb-ha-prpagate.sh     # VM1
```


Prueba de failover: obtener ticket con el primario activo, detenerlo,
confirmar que el cliente obtiene ticket igualmente (vía el secundario).

### 8. Balanceo de Carga y Failover (VM3)
HAProxy en modo TCP (passthrough, no termina TLS), balanceando
`core1:636` y `core2:636` bajo el nombre virtual `ldap.fis.epn.edu.ec`.

```bash
bash scripts/07-balanceador-carga/07.1-balanceador-haproxy.sh
```



Prueba: `systemctl stop slapd` en VM1, confirmar que las conexiones al
balanceador siguen respondiendo (ahora solo vía VM2).

### 9. Experimentos de Inyección de Fallos
Scripts individuales en `scripts/08-tests/`, resultados en `tests/*.csv`:

- `08.1-crash-kill9.sh` — crash abrupto (`kill -9` sobre `slapd`)
- `08.2-network-partition.sh` — partición de red (`iptables DROP` temporal)
- `08.3-kdc.failure.sh` — fallo del KDC (`systemctl stop krb5-kdc`)

Cada script mide el tiempo de recuperación y lo registra en su CSV
correspondiente dentro de `tests/`.

### 10. Monitoreo (VM3)
Prometheus + Node Exporter (CPU/memoria) en las 3 VMs.

```bash
bash scripts/09-monitoreo/09.1-monitoring-node-exporter.sh     # VM1, VM2 y VM3
bash scripts/09-monitoreo/09.2-monitoring-prometheus-server.sh # solo VM3
```

Panel: `http://192.168.100.3:9090/targets`


## Créditos y herramientas

Proyecto individual.Los Scripts de automatización fuerondesarrollados con
asistencia de Claude (Anthropic) para la depuración de
scripts bash y configuración de servicios — todo el trabajo de
ejecución, verificación y toma de decisiones de arquitectura fue
realizado y validado directamente en las VMs.