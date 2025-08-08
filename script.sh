#!/bin/bash

# Проверка root
if [ "$(id -u)" != "0" ]; then
    echo "Этот скрипт должен быть запущен от имени root" 1>&2
    exit 1
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функция проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ОШИБКА] $1${NC}"
        exit 1
    else
        echo -e "${GREEN}[OK] $1${NC}"
    fi
}

# 1. Очистка системы
echo -e "${YELLOW}=== Очистка системы ===${NC}"
{
    systemctl stop grafana-server 2>/dev/null || true
    apt purge -y grafana* 2>/dev/null || true
    rm -rf /etc/apt/sources.list.d/grafana* /usr/share/keyrings/grafana.gpg
    apt autoremove -y
    apt update
} > /dev/null 2>&1

# Установка временной зоны
timedatectl set-timezone Europe/Moscow

# 2. Обновление системы и установка базовых пакетов
echo -e "${YELLOW}=== Установка базовых пакетов ===${NC}"
apt update && apt upgrade -y
apt install -y fail2ban iptables-persistent netfilter-persistent nftables curl wget \
               software-properties-common apt-transport-https python3 \
               python3-pip python3-venv git gnupg2 ca-certificates \
               adduser libfontconfig1 unzip htop ncdu
check_error "Установка базовых пакетов"

# 3. Установка Hestia CP
echo -e "${YELLOW}=== Установка Hestia CP ===${NC}"
{
    # Расширенная проверка наличия Hestia CP
    HESTIA_INSTALLED=false
    
    # Проверяем различные признаки установки Hestia CP
    if [ -f "/usr/local/hestia/bin/v-list" ] || [ -f "/usr/local/hestia/bin/v-add-user" ]; then
        HESTIA_INSTALLED=true
        echo -e "${BLUE}[Инфо] Найдены бинарные файлы Hestia CP${NC}"
    fi
    
    if [ -d "/usr/local/hestia" ]; then
        HESTIA_INSTALLED=true
        echo -e "${BLUE}[Инфо] Найдена директория Hestia CP${NC}"
    fi
    
    if systemctl list-unit-files | grep -q hestia; then
        HESTIA_INSTALLED=true
        echo -e "${BLUE}[Инфо] Найдена служба Hestia CP${NC}"
    fi
    
    if [ "$HESTIA_INSTALLED" = true ]; then
        echo -e "${BLUE}[Инфо] Hestia CP уже установлен. Пропускаем установку.${NC}"
        
        # Проверяем и запускаем службу если нужно
        # Проверяем различные варианты имен служб Hestia
        HESTIA_SERVICE=""
        for service_name in hestia hestia-web hestia-api hestia-cp; do
            if systemctl list-unit-files | grep -q "$service_name"; then
                HESTIA_SERVICE="$service_name"
                echo -e "${BLUE}[Инфо] Найдена служба: $HESTIA_SERVICE${NC}"
                break
            fi
        done
        
        if [ -n "$HESTIA_SERVICE" ]; then
            if systemctl is-active --quiet "$HESTIA_SERVICE"; then
                echo -e "${GREEN}Служба $HESTIA_SERVICE уже работает${NC}"
            else
                echo -e "${BLUE}[Инфо] Запуск службы $HESTIA_SERVICE...${NC}"
                systemctl start "$HESTIA_SERVICE"
                sleep 5
                if systemctl is-active --quiet "$HESTIA_SERVICE"; then
                    echo -e "${GREEN}Служба $HESTIA_SERVICE запущена успешно${NC}"
                else
                    echo -e "${YELLOW}Предупреждение: Не удалось запустить службу $HESTIA_SERVICE${NC}"
                    echo -e "${BLUE}[Инфо] Попытка перезапуска...${NC}"
                    systemctl restart "$HESTIA_SERVICE"
                    sleep 5
                    if systemctl is-active --quiet "$HESTIA_SERVICE"; then
                        echo -e "${GREEN}Служба $HESTIA_SERVICE перезапущена успешно${NC}"
                    else
                        echo -e "${YELLOW}Предупреждение: Служба $HESTIA_SERVICE не запущена${NC}"
                        echo -e "${BLUE}[Инфо] Проверяем статус службы...${NC}"
                        systemctl status "$HESTIA_SERVICE" --no-pager || true
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}Предупреждение: Служба Hestia не найдена${NC}"
            echo -e "${BLUE}[Инфо] Доступные службы:${NC}"
            systemctl list-unit-files | grep -i hestia || echo "Службы Hestia не найдены"
        fi
    else
        echo -e "${BLUE}[Инфо] Hestia CP не найден. Начинаем установку...${NC}"
        echo -e "${BLUE}[Инфо] Загрузка установочного скрипта...${NC}"
        wget https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh
        
        echo -e "${BLUE}[Инфо] Запуск установки (это может занять несколько минут)...${NC}"
        # Получаем реальный hostname системы
        SYSTEM_HOSTNAME=$(hostname -f 2>/dev/null || hostname)
        echo -e "${BLUE}[Инфо] Используем hostname: $SYSTEM_HOSTNAME${NC}"
        
        # Запускаем установку с автоматическими ответами на вопросы
        echo -e "${BLUE}[Инфо] Запуск установки с автоматическими ответами...${NC}"
        if yes | bash hst-install.sh --lang 'ru' --hostname "$SYSTEM_HOSTNAME" --username 'TrafficAdmin' --email 'info@traffic.com' --password 'AdMiNiStRaToR' --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force 2>&1 | tee /tmp/hestia_install.log; then
            # Проверяем успешность установки
            if grep -q "Hestia install detected" /tmp/hestia_install.log; then
                echo -e "${BLUE}[Инфо] Hestia CP уже установлен (обнаружено установочным скриптом)${NC}"
            elif grep -q "Goodbye" /tmp/hestia_install.log; then
                echo -e "${YELLOW}Предупреждение: Установка завершена досрочно${NC}"
                echo -e "${BLUE}[Инфо] Проверяем наличие установленных файлов...${NC}"
                if [ -f "/usr/local/hestia/bin/v-list" ] || [ -d "/usr/local/hestia" ]; then
                    echo -e "${GREEN}Hestia CP установлен успешно${NC}"
                else
                    echo -e "${RED}Ошибка: Hestia CP не установлен${NC}"
                    cat /tmp/hestia_install.log
                    exit 1
                fi
            else
                echo -e "${GREEN}Установка Hestia CP завершена успешно${NC}"
            fi
        else
            # Проверяем, была ли ошибка из-за уже установленного Hestia
            if grep -q "Hestia install detected" /tmp/hestia_install.log; then
                echo -e "${BLUE}[Инфо] Hestia CP уже установлен (обнаружено установочным скриптом)${NC}"
            else
                echo -e "${RED}Ошибка установки Hestia CP${NC}"
                cat /tmp/hestia_install.log
                exit 1
            fi
        fi
        
        echo -e "${BLUE}[Инфо] Проверка работы службы...${NC}"
        
        # Проверяем различные варианты имен служб Hestia
        HESTIA_SERVICE=""
        for service_name in hestia hestia-web hestia-api hestia-cp; do
            if systemctl list-unit-files | grep -q "$service_name"; then
                HESTIA_SERVICE="$service_name"
                echo -e "${BLUE}[Инфо] Найдена служба: $HESTIA_SERVICE${NC}"
                break
            fi
        done
        
        if [ -n "$HESTIA_SERVICE" ]; then
            if systemctl is-active --quiet "$HESTIA_SERVICE"; then
                echo -e "${GREEN}Служба $HESTIA_SERVICE уже работает${NC}"
            else
                echo -e "${BLUE}[Инфо] Запуск службы $HESTIA_SERVICE...${NC}"
                systemctl start "$HESTIA_SERVICE"
                sleep 5
                if systemctl is-active --quiet "$HESTIA_SERVICE"; then
                    echo -e "${GREEN}Служба $HESTIA_SERVICE запущена успешно${NC}"
                else
                    echo -e "${YELLOW}Предупреждение: Не удалось запустить службу $HESTIA_SERVICE${NC}"
                    echo -e "${BLUE}[Инфо] Проверяем статус службы...${NC}"
                    systemctl status "$HESTIA_SERVICE" --no-pager || true
                fi
            fi
        else
            echo -e "${YELLOW}Предупреждение: Служба Hestia не найдена${NC}"
            echo -e "${BLUE}[Инфо] Доступные службы:${NC}"
            systemctl list-unit-files | grep -i hestia || echo "Службы Hestia не найдены"
        fi
        
        rm -f hst-install.sh /tmp/hestia_install.log
    fi
}
check_error "Установка Hestia CP"

# 4. Firewall configuration (improved version)
echo -e "${YELLOW}=== Firewall configuration ===${NC}"

# Check nftables availability, otherwise use iptables
if command -v nft >/dev/null 2>&1; then
    echo -e "${BLUE}Using nftables (modern firewall)${NC}"
    USE_NFTABLES=true
else
    echo -e "${BLUE}Using iptables${NC}"
    USE_NFTABLES=false
fi

if [ "$USE_NFTABLES" = true ]; then
    # nftables configuration
    cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f

# Clear all rules
flush ruleset

# Define tables
table inet filter {
    # Chains
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Local interface
        iif lo accept
        
        # Established connections
        ct state established,related accept
        
        # ICMP (limited)
        icmp type echo-request limit rate 1/second accept
        icmp type echo-request drop
        
        # SSH (with brute force protection)
        tcp dport 22 ct state new limit rate 5/minute accept
        
        # HTTP/HTTPS
        tcp dport { 80, 443 } accept
        
        # Hestia CP
        tcp dport 8083 accept
        
        # Monitoring (localhost only)
        tcp dport { 9090, 9100, 3100, 9080, 9191, 9091 } ip saddr 127.0.0.1 accept
        
        # DNS
        udp dport 53 accept
        tcp dport 53 accept
        
        # Log suspicious activity
        log prefix "nftables-dropped: " group 0
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# DDoS protection table
table inet ddos {
    chain input {
        type filter hook input priority 10; policy accept;
        
        # SYN flood protection
        tcp flags syn ct state new limit rate 10/second burst 25 packets accept
        tcp flags syn ct state new drop
        
        # Port scanner protection
        tcp flags & (fin|syn|rst|ack) == rst ct state new limit rate 1/second accept
        tcp flags & (fin|syn|rst|ack) == rst ct state new drop
    }
}
EOF

    # Apply nftables rules
    nft -f /etc/nftables.conf
    systemctl enable nftables
    systemctl start nftables
    
    # Add Cloudflare rules (only if used)
    echo -e "${BLUE}Adding Cloudflare rules...${NC}"
    CLOUDFLARE_IPS=$(curl -s --max-time 10 https://www.cloudflare.com/ips-v4 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$CLOUDFLARE_IPS" ]; then
        # Добавляем правила Cloudflare через команды nft
        CLOUDFLARE_COUNT=0
        for ip in $CLOUDFLARE_IPS; do
            if nft add rule inet filter input tcp saddr "$ip" dport { 80, 443 } accept 2>/dev/null; then
                CLOUDFLARE_COUNT=$((CLOUDFLARE_COUNT + 1))
            fi
        done
        echo -e "${GREEN}Added $CLOUDFLARE_COUNT Cloudflare IP addresses${NC}"
    else
        echo -e "${YELLOW}Failed to load Cloudflare IP addresses${NC}"
    fi
    
    # Save rules
    nft list ruleset > /etc/nftables.conf
    
else
    # iptables configuration (improved version)
    iptables -F && iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Basic rules
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # SSH with brute force protection
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 5/minute --limit-burst 10 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j DROP

    # HTTP/HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # Hestia CP
    iptables -A INPUT -p tcp --dport 8083 -j ACCEPT

    # Monitoring (localhost only)
    for port in 9090 9100 3100 9080 9191 9091; do
        iptables -A INPUT -p tcp --dport $port -s 127.0.0.1 -j ACCEPT
    done

    # DNS
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT

    # Cloudflare IPs (with error handling)
    echo -e "${BLUE}Adding Cloudflare rules...${NC}"
    CLOUDFLARE_IPS=$(curl -s --max-time 10 https://www.cloudflare.com/ips-v4 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$CLOUDFLARE_IPS" ]; then
        for ip in $CLOUDFLARE_IPS; do
            iptables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT
            iptables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT
        done
        echo -e "${GREEN}Added $(echo "$CLOUDFLARE_IPS" | wc -w) Cloudflare IP addresses${NC}"
    else
        echo -e "${YELLOW}Failed to load Cloudflare IP addresses${NC}"
    fi

    # Attack protection (improved)
    iptables -N SYN_FLOOD
    iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    iptables -A SYN_FLOOD -m limit --limit 10/s --limit-burst 25 -j RETURN
    iptables -A SYN_FLOOD -j DROP

    # ICMP with limits
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    # Port scanner protection
    iptables -N PORT_SCAN
    iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST -j PORT_SCAN
    iptables -A PORT_SCAN -m limit --limit 1/s -j RETURN
    iptables -A PORT_SCAN -j DROP

    # Log suspicious activity
    iptables -A INPUT -j LOG --log-prefix "iptables-dropped: " --log-level 4

    # Save rules
    netfilter-persistent save
fi

check_error "Firewall configuration"

# 5. Настройка fail2ban
echo -e "${YELLOW}=== Настройка fail2ban ===${NC}"
cat > /etc/fail2ban/jail.local <<EOL
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 1h
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-botsearch]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 10
findtime = 3600
bantime = 86400

[nginx-dos]
enabled = true
port = http,https
filter = nginx-dos
logpath = /var/log/nginx/access.log
maxretry = 100
findtime = 300
bantime = 3600

[hestia-auth]
enabled = true
port = 8083
filter = hestia-auth
logpath = /var/log/hestia/auth.log
maxretry = 5
findtime = 600
bantime = 86400
EOL

# Создаем фильтры для fail2ban
cat > /etc/fail2ban/filter.d/nginx-dos.conf <<EOL
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (404|503|400|499) .*$
ignoreregex =
EOL

cat > /etc/fail2ban/filter.d/hestia-auth.conf <<EOL
[Definition]
failregex = .*Authentication failed for .* from <HOST>
ignoreregex =
EOL

systemctl enable --now fail2ban
check_error "Настройка fail2ban"

# 6. Установка Grafana
echo -e "${YELLOW}=== Установка Grafana ===${NC}"
{
    wget https://dl.grafana.com/oss/release/grafana_10.4.3_amd64.deb -O /tmp/grafana.deb
    dpkg -i /tmp/grafana.deb || apt-get install -fy
    rm -f /tmp/grafana.deb
    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server
} > /dev/null 2>&1
check_error "Установка Grafana"

# 7. Установка Prometheus
echo -e "${YELLOW}=== Установка Prometheus ===${NC}"
{
    useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
    mkdir -p /etc/prometheus /var/lib/prometheus
    chown prometheus:prometheus /var/lib/prometheus

    PROM_VERSION="2.47.0"
    wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
    tar xvf /tmp/prometheus.tar.gz -C /tmp/
    mv /tmp/prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/local/bin/
    mv /tmp/prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin/
    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool

    cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'loki'
    static_configs:
      - targets: ['localhost:9080']
  - job_name: 'fail2ban'
    static_configs:
      - targets: ['localhost:9191']
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['localhost:9091']
EOF

    cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/var/lib/prometheus \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle

Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
} > /dev/null 2>&1
check_error "Установка Prometheus"

# 8. Установка Node Exporter
echo -e "${YELLOW}=== Установка Node Exporter ===${NC}"
{
    wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
    tar xvf /tmp/node_exporter.tar.gz -C /tmp/
    mv /tmp/node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
    useradd --no-create-home --shell /bin/false node_exporter
    chown node_exporter:node_exporter /usr/local/bin/node_exporter

    cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
} > /dev/null 2>&1
check_error "Установка Node Exporter"

# 9. Установка Pushgateway
echo -e "${YELLOW}=== Установка Pushgateway ===${NC}"
{
    wget https://github.com/prometheus/pushgateway/releases/download/v1.6.1/pushgateway-1.6.1.linux-amd64.tar.gz -O /tmp/pushgateway.tar.gz
    tar xvf /tmp/pushgateway.tar.gz -C /tmp/
    mv /tmp/pushgateway-1.6.1.linux-amd64/pushgateway /usr/local/bin/
    useradd --no-create-home --shell /bin/false pushgateway
    chown pushgateway:pushgateway /usr/local/bin/pushgateway

    cat > /etc/systemd/system/pushgateway.service <<EOF
[Unit]
Description=Prometheus Pushgateway
After=network.target

[Service]
User=pushgateway
Group=pushgateway
ExecStart=/usr/local/bin/pushgateway \\
    --web.listen-address=:9091

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable pushgateway
    systemctl start pushgateway
} > /dev/null 2>&1
check_error "Установка Pushgateway"

# 10. Установка Loki и Promtail
echo -e "${YELLOW}=== Установка Loki и Promtail ===${NC}"
{
    LOKI_VERSION="2.9.1"
    
    # Установка Loki
    wget https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip -O /tmp/loki.zip
    unzip /tmp/loki.zip -d /tmp/
    mv /tmp/loki-linux-amd64 /usr/local/bin/loki
    chmod +x /usr/local/bin/loki

    useradd --no-create-home --shell /bin/false loki
    mkdir -p /etc/loki /var/lib/loki
    chown loki:loki /var/lib/loki

    cat > /etc/loki/loki-config.yaml <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

ruler:
  alertmanager_url: http://localhost:9093
EOF

    cat > /etc/systemd/system/loki.service <<EOF
[Unit]
Description=Loki log aggregation system
After=network.target

[Service]
User=loki
Group=loki
Type=simple
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yaml

[Install]
WantedBy=multi-user.target
EOF

    # Установка Promtail
    wget https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/promtail-linux-amd64.zip -O /tmp/promtail.zip
    unzip /tmp/promtail.zip -d /tmp/
    mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
    chmod +x /usr/local/bin/promtail

    useradd --no-create-home --shell /bin/false promtail
    mkdir -p /etc/promtail
    chown promtail:promtail /etc/promtail

    cat > /etc/promtail/promtail-config.yaml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs
      __path__: /var/log/*log
EOF

    cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail log shipping agent
After=network.target

[Service]
User=promtail
Group=promtail
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now loki
    systemctl enable --now promtail
} > /dev/null 2>&1
check_error "Установка Loki и Promtail"

# 11. Настройка экспортера для fail2ban
echo -e "${YELLOW}=== Настройка мониторинга fail2ban ===${NC}"
{
    apt-get install -y python3-prometheus-client
    cat <<'EOF' | tee /usr/local/bin/fail2ban_exporter.py
from prometheus_client import start_http_server, Gauge
import subprocess
import time

banned_ips = Gauge('fail2ban_banned_ips', 'Number of banned IPs by fail2ban')

def collect():
    try:
        output = subprocess.check_output(["fail2ban-client", "status"])
        banned = 0
        for line in output.decode().splitlines():
            if "Total banned" in line:
                banned = int(line.split(":")[1].strip())
        banned_ips.set(banned)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    start_http_server(9191)
    while True:
        collect()
        time.sleep(15)
EOF

    chmod +x /usr/local/bin/fail2ban_exporter.py

    cat <<EOF | tee /etc/systemd/system/fail2ban_exporter.service
[Unit]
Description=Fail2Ban Metrics Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/fail2ban_exporter.py

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now fail2ban_exporter
} > /dev/null 2>&1
check_error "Настройка мониторинга fail2ban"

# 12. Настройка Grafana
echo -e "${YELLOW}=== Настройка Grafana ===${NC}"
{
    while ! systemctl is-active --quiet grafana-server; do
        sleep 1
    done

    grafana-cli admin reset-admin-password admin

    until curl -u admin:admin -X POST -H "Content-Type: application/json" \
      -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy"}' \
      http://localhost:3000/api/datasources; do
        sleep 2
    done

    until curl -u admin:admin -X POST -H "Content-Type: application/json" \
      -d '{"name":"Loki","type":"loki","url":"http://localhost:3100","access":"proxy"}' \
      http://localhost:3000/api/datasources; do
        sleep 2
    done

    DASHBOARD_IDS="1860 11074 13659 13639"
    for DASH in $DASHBOARD_IDS; do
        curl -u admin:admin -X POST -H "Content-Type: application/json" \
          -d "{\"dashboard\":$(curl -s https://grafana.com/api/dashboards/$DASH/revisions/latest/download),\"overwrite\":true}" \
          http://localhost:3000/api/dashboards/import
    done
} > /dev/null 2>&1
check_error "Настройка Grafana"

# 13. Завершение установки
echo -e "${YELLOW}=== Установка завершена ===${NC}"
echo -e "${GREEN}Доступные сервисы:${NC}"
echo -e "Hestia CP:    http://$(hostname -I | awk '{print $1}'):8083"
echo -e "Grafana:      http://$(hostname -I | awk '{print $1}'):3000"
echo -e "Prometheus:   http://$(hostname -I | awk '{print $1}'):9090"
echo -e "Loki:         http://$(hostname -I | awk '{print $1}'):3100"
echo -e "Pushgateway:  http://$(hostname -I | awk '{print $1}'):9091"
echo -e "\n${GREEN}Данные для входа:${NC}"
echo -e "Hestia CP:  admin / (пароль из файла /usr/local/hestia/data/users/admin/password.conf)"
echo -e "Grafana:    admin / admin"
echo -e "\n${RED}ВАЖНО: \Cмените пароли${NC}"
