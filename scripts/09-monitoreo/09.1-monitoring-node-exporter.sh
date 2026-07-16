#!/bin/bash
#  09.1-monitoring-node-exporter.sh
# Instala Node Exporter para exponer metricas de CPU/memoria/disco.
# Ejecutar en LAS 3 VMs (VM1, VM2, VM3).
set -e
 
NODE_EXPORTER_VERSION="1.8.2"
ARCH="amd64"
 
echo "[*] Descargando Node Exporter v${NODE_EXPORTER_VERSION}..."
cd /tmp
curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
 
echo "[*] Extrayendo..."
tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
 
echo "[*] Instalando binario..."
sudo mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/
rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}"*
 
# --- Directorio para metricas textfile (usado en Parte B) ---
sudo mkdir -p /var/lib/node_exporter/textfile_collector
 
# --- Servicio systemd (corre como root, sin usuario dedicado) ---
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target
 
[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
 
[Install]
WantedBy=multi-user.target
EOF
 
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
 
echo ""
echo "[*] Estado del servicio:"
sudo systemctl status node_exporter --no-pager | head -5
 
echo ""
echo "[OK] Node Exporter activo en el puerto 9100."
echo "Verificar con: curl http://localhost:9100/metrics | head -20"