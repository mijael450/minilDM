#!/bin/bash
# 09.2-monitoring-prometheus-server.sh
# Instala el servidor Prometheus, configurado para recolectar metricas
# de las 3 VMs (via Node Exporter en el puerto 9100 de cada una).
# Ejecutar SOLO en VM3.
set -e

PROM_VERSION="2.54.1"
ARCH="amd64"

echo "[*] Descargando Prometheus v${PROM_VERSION}..."
cd /tmp
curl -LO "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz"

echo "[*] Extrayendo..."
tar xzf "prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz"

echo "[*] Instalando binarios y archivos..."
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo mv "prometheus-${PROM_VERSION}.linux-${ARCH}/prometheus" /usr/local/bin/
sudo mv "prometheus-${PROM_VERSION}.linux-${ARCH}/promtool" /usr/local/bin/
sudo mv "prometheus-${PROM_VERSION}.linux-${ARCH}/consoles" /etc/prometheus/
sudo mv "prometheus-${PROM_VERSION}.linux-${ARCH}/console_libraries" /etc/prometheus/
rm -rf "prometheus-${PROM_VERSION}.linux-${ARCH}"*

# --- Configuracion: recolectar de los 3 nodos + de si mismo ---
echo "[*] Escribiendo configuracion (prometheus.yml)..."
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets:
          - 'core1.fis.epn.ec:9100'
          - 'core2.fis.epn.ec:9100'
          - 'client.fis.epn.ec:9100'
        labels:
          proyecto: 'fis-miniidm'

  - job_name: 'haproxy'
    static_configs:
      - targets: ['localhost:8404']
EOF

# --- Servicio systemd ---
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus Monitoring Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

echo ""
echo "[*] Estado del servicio:"
sudo systemctl status prometheus --no-pager | head -5

echo ""
echo "[OK] Prometheus activo en el puerto 9090."
echo "Accede desde el navegador a: http://<ip-vm3>:9090"
echo "Verifica los targets en:      http://<ip-vm3>:9090/targets"