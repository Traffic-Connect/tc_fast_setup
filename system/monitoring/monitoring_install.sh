#!/bin/bash

# ============================================================================
# ЭТАП 4: УСТАНОВКА СИСТЕМЫ МОНИТОРИНГА
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/main.conf"
source "$PROJECT_ROOT/core/utils/common.sh"

# Экспорт переменных паролей для использования в скрипте
export GRAFANA_ADMIN_PASSWORD
export PROMETHEUS_PASSWORD
export LOKI_PASSWORD
export NODE_EXPORTER_PASSWORD
export PUSHGATEWAY_PASSWORD
export FAIL2BAN_EXPORTER_PASSWORD

install_monitoring() {
    log_info "=== ЭТАП 4: Установка системы мониторинга ==="
    
    # Проверка, не установлены ли уже компоненты мониторинга
    if is_service_active "grafana-server" || is_service_active "prometheus"; then
        log_warn "Компоненты мониторинга уже установлены, пропускаем установку"
        log_info "Статус компонентов мониторинга:"
        if is_service_active "grafana-server"; then
            log_info "  Grafana: ✅ Работает"
        fi
        if is_service_active "prometheus"; then
            log_info "  Prometheus: ✅ Работает"
        fi
        if is_service_active "node_exporter"; then
            log_info "  Node Exporter: ✅ Работает"
        fi
        log_ok "✅ Этап 4 завершен успешно (пропущен)"
        return 0
    fi
    
    log_info "Установка системы мониторинга..."
    
    # Установка Grafana
    log_info "Установка Grafana..."
    
    # Установка зависимостей
    log_info "Установка зависимостей Grafana..."
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y musl
    
    # Загрузка и установка Grafana
    wget "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb" -O /tmp/grafana.deb
    dpkg -i /tmp/grafana.deb || DEBIAN_FRONTEND=noninteractive apt-get install -fy
    rm -f /tmp/grafana.deb
    
    # Настройка пароля администратора Grafana
    log_info "Настройка пароля администратора Grafana..."
    cat > /etc/grafana/grafana.ini <<EOF
[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD:-admin123}

[server]
http_port = ${GRAFANA_PORT:-3000}
EOF
    
    # Запуск Grafana
    systemctl enable grafana-server
    systemctl start grafana-server
    
    # Проверка запуска
    sleep 5
    if is_service_active "grafana-server"; then
        log_ok "✅ Grafana запущен успешно"
    else
        log_err "❌ Ошибка запуска Grafana"
        return 1
    fi
    
    # Установка Prometheus
    log_info "Установка Prometheus..."
    useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
    mkdir -p /etc/prometheus /var/lib/prometheus
    chown prometheus:prometheus /var/lib/prometheus
    
    wget "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" -O /tmp/prometheus.tar.gz
    tar xvf /tmp/prometheus.tar.gz -C /tmp/
    mv "/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus" /usr/local/bin/
    chown prometheus:prometheus /usr/local/bin/prometheus
    
    cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:'"$PROMETHEUS_PORT"']
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:'"$NODE_EXPORTER_PORT"']
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
    --web.listen-address=0.0.0.0:"$PROMETHEUS_PORT"

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
    
    # Установка Node Exporter
    log_info "Установка Node Exporter..."
    useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
    wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" -O /tmp/node_exporter.tar.gz
    tar xvf /tmp/node_exporter.tar.gz -C /tmp/
    mv "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
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
    
    # Установка Loki
    log_info "Установка Loki..."
    useradd --no-create-home --shell /bin/false loki 2>/dev/null || true
    mkdir -p /etc/loki /var/lib/loki
    chown loki:loki /var/lib/loki
    
    wget "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip" -O /tmp/loki.zip
    unzip /tmp/loki.zip -d /tmp/
    mv /tmp/loki-linux-amd64 /usr/local/bin/loki
    chmod +x /usr/local/bin/loki
    
    cat > /etc/loki/loki-config.yaml <<EOF
auth_enabled: false

server:
  http_listen_port: "$LOKI_PORT"

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

    systemctl daemon-reload
    systemctl enable loki
    systemctl start loki
    
    # Настройка Grafana
    log_info "Настройка Grafana..."
    while ! systemctl is-active --quiet grafana-server; do
        sleep 1
    done
    
    # Проверка пароля Grafana
    if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
        log_err "Пароль Grafana не установлен"
        return 1
    fi
    grafana-cli admin reset-admin-password "$GRAFANA_ADMIN_PASSWORD"
    
    until curl -u admin:admin -X POST -H "Content-Type: application/json" \
      -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:'"$PROMETHEUS_PORT"'","access":"proxy"}' \
      "http://localhost:$GRAFANA_PORT/api/datasources"; do
        sleep 2
    done
    
    # Проверка установки
    local monitoring_services=("grafana-server" "prometheus" "loki" "node_exporter")
    local failed_services=()
    
    for service in "${monitoring_services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_ok "✅ $service - активен"
        else
            log_warn "⚠️  $service - неактивен"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_ok "✅ Все службы мониторинга работают"
        echo "Grafana пароль: $GRAFANA_ADMIN_PASSWORD"
    else
        log_warn "⚠️  Проблемы со службами: ${failed_services[*]}"
    fi
    
    log_ok "✅ Этап 4 завершен"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_monitoring
fi 