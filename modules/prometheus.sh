#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция установки Prometheus
install_prometheus() {
    print_header "📈 УСТАНОВКА PROMETHEUS"
    log_message "INFO" "Начинаем установку Prometheus"
    
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

        # Создаем конфигурацию
        create_prometheus_config
        
        # Создаем systemd сервис
        create_prometheus_service

        systemctl daemon-reload
        systemctl enable prometheus
        systemctl start prometheus
    } > /dev/null 2>&1
    
    check_error "Установка Prometheus"
}

# Функция создания конфигурации Prometheus
create_prometheus_config() {
    cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['0.0.0.0:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['0.0.0.0:9100']
  - job_name: 'loki'
    static_configs:
      - targets: ['0.0.0.0:9080']
  - job_name: 'fail2ban'
    static_configs:
      - targets: ['0.0.0.0:9191']
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['0.0.0.0:9091']
EOF

    # Создаем пустой файл конфигурации (без аутентификации)
    touch /etc/prometheus/web.yml
    chown prometheus:prometheus /etc/prometheus/web.yml
    chmod 600 /etc/prometheus/web.yml
}

# Функция создания systemd сервиса Prometheus
create_prometheus_service() {
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
}
