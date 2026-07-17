# Makefile - FIS MiniIdM
# Envoltorio de conveniencia sobre los scripts de scripts/.
# IMPORTANTE: cada target debe correrse en la VM que le corresponde
# (indicado entre parentesis). Este Makefile no ejecuta nada remoto;
# solo simplifica el comando local en la maquina donde lo invoques.

SHELL := /bin/bash

.PHONY: help base pki-setup pki-csr ldap kerberos integracion \
        webapp ldap-replication kerberos-ha loadbalancer tests monitoring

help:
	@echo "Targets disponibles (indican en que VM correrlos):"
	@echo "  make base           - Config. base: hosts, timesyncd (VM1, VM2, VM3)"
	@echo "  make pki-setup      - Crear CA raiz (VM1)"
	@echo "  make pki-csr        - Instrucciones para generar/firmar CSR (VM1 y VM2)"
	@echo "  make ldap           - Instalar LDAP master + cargar DIT (VM1)"
	@echo "  make kerberos       - Instalar KDC + crear principals (VM1)"
	@echo "  make integracion    - Sincronizar LDAP <-> Kerberos (VM1)"
	@echo "  make webapp         - Apache + TLS + Kerberos (VM2)"
	@echo "  make ldap-replication - Replicacion LDAP (VM1=provider, VM2=consumer)"
	@echo "  make kerberos-ha    - KDC secundario + propagacion (VM1 y VM2)"
	@echo "  make loadbalancer   - HAProxy (VM3)"
	@echo "  make tests          - Experimentos de inyeccion de fallos (VM segun experimento)"
	@echo "  make monitoring     - Node Exporter (VM1/VM2/VM3) + Prometheus (VM3)"

base:
	bash scripts/00-base/00.1-setup-hosts.sh

pki-setup:
	bash scripts/01-pki/01.1-pki-setup.sh

pki-csr:
	@echo "Uso manual (requiere nombre_corto e IP):"
	@echo "  bash scripts/01-pki/01.2-pki-gen-csr.sh core1 192.168.100.6   (en VM1)"
	@echo "  bash scripts/01-pki/01.2-pki-gen-csr.sh core2 192.168.100.9   (en VM2)"
	@echo "Luego firmar en VM1:"
	@echo "  bash scripts/01-pki/01.3-pki-sign-cert.sh <ruta_csr> <nombre_corto>"

ldap:
	bash scripts/02-ldap/02.1-ldap-install-master.sh
	@echo ">> Cargar el DIT: ldapadd -x -D cn=admin,dc=fis,dc=epn,dc=ec -W -f config/dit.ldif"

kerberos:
	bash scripts/03-kerberos/03.1-kerberos-install.sh
	bash scripts/03-kerberos/03.2-kerberos-addPrincipals.sh

integracion:
	bash scripts/04-integracion/04.1-syn-ldap-kerberos.sh

webapp:
	bash scripts/05-webapp-tls/05.1-webapp-krb-tls.sh

ldap-replication:
	@echo ">> En VM1 (provider): bash scripts/06-ha/06.1-ldap-replication.sh"
	@echo ">> En VM2 (consumer): bash scripts/06-ha/06.2-ldap-replication-consumer.sh"

kerberos-ha:
	@echo ">> En VM1: bash scripts/06-ha/06.3-krb-ha-primary.sh"
	@echo ">> En VM2: bash scripts/06-ha/06.4-krb-ha-secondary.sh"
	@echo ">> En VM1: bash scripts/06-ha/06.5-krb-ha-prpagate.sh"

loadbalancer:
	bash scripts/07-balanceador-carga/07.1-balanceador-haproxy.sh

tests:
	@echo ">> Corriendo experimentos disponibles localmente en esta VM..."
	@for f in scripts/08-tests/*.sh; do \
		echo "--- $$f ---"; \
		bash "$$f" || true; \
	done

monitoring:
	bash scripts/09-monitoreo/09.1-monitoring-node-exporter.sh
	@echo ">> Si esta VM es VM3, corre ademas:"
	@echo "   bash scripts/09-monitoreo/09.2-monitoring-prometheus-server.sh"