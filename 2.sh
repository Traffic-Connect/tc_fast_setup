#!/bin/bash
set -e

# --- Configuration ---
LOKI_VERSION="2.9.2"
GEOIP_DB_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb"
LOG_DIR="/var/log/apache2/domains"

# --- Root check ---
[ "$(id -u)" != "0" ] && { echo -e "\033[31mRoot required\033[0m" >&2; exit 1; }

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Error checking function
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] $1${NC}"
        exit 1
    else
        echo -e "${GREEN}[OK] $1${NC}"
    fi
}

# 1. System preparation
echo -e "${YELLOW}=== System preparation ===${NC}"
apt update && apt install -y wget unzip jq libmaxminddb-dev
check_error "System update and package installation"

systemctl stop promtail 2>/dev/null || true
rm -f /tmp/positions.yaml
mkdir -p /etc/promtail/geoip

# 2. Promtail installation
echo -e "${YELLOW}=== Installing Promtail ===${NC}"
wget -q "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/promtail-linux-amd64.zip" -O /tmp/promtail.zip
check_error "Downloading Promtail"

unzip -q /tmp/promtail.zip -d /tmp/
mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail
rm -f /tmp/promtail.zip

id -u promtail >/dev/null 2>&1 || useradd --no-create-home --shell /bin/false promtail
chown promtail:promtail /usr/local/bin/promtail
check_error "Promtail installation"

# 3. GeoIP configuration
echo -e "${YELLOW}=== GeoIP configuration ===${NC}"
wget -q "$GEOIP_DB_URL" -O /etc/promtail/geoip/GeoLite2-City.mmdb
check_error "Downloading GeoIP database"

chown -R promtail:promtail /etc/promtail

# 4. Configuration with fixed paths and improved parsing
echo -e "${YELLOW}=== Creating configuration ===${NC}"
cat > /etc/promtail/promtail-config.yaml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
- job_name: nginx
  static_configs:
  - targets: [localhost]
    labels:
      job: nginx
      __path__: "/var/log/apache2/domains/*.log"
  pipeline_stages:
    - regex:
        expression: '^(?P<remote_addr>\S+) \S+ \S+ \[(?P<timestamp>[^\]]+)\] "(?P<method>\S+) (?P<path>\S+) (?P<protocol>\S+)" (?P<status>\d+) (?P<bytes>\d+) "(?P<referer>[^"]*)" "(?P<user_agent>[^"]*)"'
    - labels:
        method:
        status:
        path:
        protocol:
        remote_addr:
        user_agent:
        referer:
    - timestamp:
        source: timestamp
        format: "02/Jan/2006:15:04:05 -0700"
    - geoip:
        db: "/etc/promtail/geoip/GeoLite2-City.mmdb"
        db_type: "city"
        source: "remote_addr"
        target: "geoip"
    - output:
        source: user_agent
    - output:
        source: remote_addr
EOF

check_error "Configuration creation"

# 5. Permission setup
echo -e "${YELLOW}=== Setting up permissions ===${NC}"
chown -R root:adm "$LOG_DIR"
chmod -R 750 "$LOG_DIR"
setfacl -Rm u:promtail:rx "$LOG_DIR"
setfacl -dm u:promtail:rx "$LOG_DIR"

# Access check
if ! sudo -u promtail head -n 1 "$LOG_DIR"/*.log >/dev/null 2>&1; then
  echo -e "${RED}ERROR: Promtail cannot read logs${NC}"
  echo "Problematic files:"
  sudo -u promtail ls -la "$LOG_DIR"/*.log
  exit 1
fi
check_error "Permission setup"

# 6. Systemd service
echo -e "${YELLOW}=== Service configuration ===${NC}"
cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
User=promtail
Group=promtail
ExecStart=/usr/local/bin/promtail \\
    -config.file=/etc/promtail/promtail-config.yaml \\
    -config.expand-env=true
Restart=always
RestartSec=5s
LimitNOFILE=65536
Environment="LOG_DIR=$LOG_DIR"

[Install]
WantedBy=multi-user.target
EOF

check_error "Service configuration"

# 7. Start and verification
echo -e "${YELLOW}=== Starting Promtail ===${NC}"
systemctl daemon-reload
systemctl enable promtail
systemctl restart promtail
sleep 5

if ! systemctl is-active --quiet promtail; then
  echo -e "${RED}ERROR: Promtail failed to start${NC}"
  journalctl -u promtail -n 20 --no-pager
  exit 1
fi
check_error "Promtail startup"

# 8. Log collection verification
echo -e "${YELLOW}=== Work verification ===${NC}"
echo "Waiting 20 seconds for log collection..."
sleep 20

# Field extraction check
LOG_CHECK=$(curl -s -G "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="nginx"} | logfmt | line_format "{{.remote_addr}} {{.user_agent}}"' | jq -r '.data.result[0].values[0][1]')

if [ -n "$LOG_CHECK" ]; then
  echo -e "${GREEN}✓ Logs are being collected successfully${NC}"
  echo "Example extracted data:"
  echo "$LOG_CHECK"
  
  # GeoIP check
  GEOIP_CHECK=$(curl -s -G "http://localhost:3100/loki/api/v1/query" \
    --data-urlencode 'query={job="nginx"} | logfmt | remote_addr!="" | geoip_country_name!=""' \
    | jq -r '.data.result[0].values[0][1]')
  
  if [ -n "$GEOIP_CHECK" ]; then
    echo -e "${GREEN}✓ GeoIP is working! Example data:${NC}"
    echo "$GEOIP_CHECK"
  else
    echo -e "${YELLOW}⚠ GeoIP is not returning data. Check IP addresses in logs${NC}"
  fi
else
  echo -e "${RED}ERROR: Logs are not reaching Loki or fields are not being extracted${NC}"
  echo "Additional diagnostics:"
  echo "1. Check position file: cat /tmp/positions.yaml"
  echo "2. Check Promtail logs: journalctl -u promtail -n 20 --no-pager"
  echo "3. Check Loki connection: curl -v http://localhost:3100/ready"
  exit 1
fi

check_error "Log collection verification"

echo -e "\n${GREEN}=== Configuration completed successfully! ===${NC}"
