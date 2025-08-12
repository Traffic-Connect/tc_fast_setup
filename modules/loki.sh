#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция установки Loki и Promtail
install_loki_promtail() {
    print_header "📝 УСТАНОВКА LOKI И PROMTAIL"
    log_message "INFO" "Начинаем установку Loki и Promtail"

    # Проверяем доступность GitHub
    if ! check_internet "https://github.com"; then
        log_message "WARNING" "Проблема с доступом к GitHub, пропускаем установку Loki и Promtail"
        log_message "INFO" "Loki и Promtail можно установить позже вручную"
        check_error "Установка Loki и Promtail (пропущена)"
        return 0
    fi
    
    {
        LOKI_VERSION="2.9.1"
        
        # Установка Loki
        install_loki "$LOKI_VERSION"
        
        # Установка Promtail
        install_promtail "$LOKI_VERSION"

        systemctl daemon-reload
        systemctl enable --now loki
        systemctl enable --now promtail
    } > /dev/null 2>&1
    
    check_error "Установка Loki и Promtail"
}

# Функция установки Loki
install_loki() {
    local version="$1"
    
    log_message "INFO" "Загрузка Loki..."
    if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/grafana/loki/releases/download/v${version}/loki-linux-amd64.zip -O /tmp/loki.zip; then
        log_message "WARNING" "Не удалось загрузить Loki, пропускаем установку"
        return 0
    fi
    
    log_message "INFO" "Установка Loki..."
    unzip /tmp/loki.zip -d /tmp/
    mv /tmp/loki-linux-amd64 /usr/local/bin/loki
    chmod +x /usr/local/bin/loki

    useradd --no-create-home --shell /bin/false loki 2>/dev/null || true
    mkdir -p /etc/loki /var/lib/loki
    chown loki:loki /var/lib/loki

    create_loki_config
    create_loki_service
}

# Функция установки Promtail
install_promtail() {
    local version="$1"
    
    log_message "INFO" "Загрузка Promtail..."
    if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/grafana/loki/releases/download/v${version}/promtail-linux-amd64.zip -O /tmp/promtail.zip; then
        log_message "WARNING" "Не удалось загрузить Promtail, пропускаем установку"
        return 0
    fi
    
    log_message "INFO" "Установка Promtail..."
    unzip /tmp/promtail.zip -d /tmp/
    mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
    chmod +x /usr/local/bin/promtail

    useradd --no-create-home --shell /bin/false promtail 2>/dev/null || true
    mkdir -p /etc/promtail
    chown promtail:promtail /etc/promtail

    create_promtail_config
    create_promtail_service
}

# Функция создания конфигурации Loki
create_loki_config() {
    cat > /etc/loki/loki-config.yaml <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  http_listen_address: 0.0.0.0
  grpc_listen_port: 9096
  grpc_listen_address: 0.0.0.0

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
}

# Функция создания systemd сервиса Loki
create_loki_service() {
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
}

# Функция создания конфигурации Promtail
create_promtail_config() {
    cat > /etc/promtail/promtail-config.yaml <<EOF
server:
  http_listen_port: 9080
  http_listen_address: 0.0.0.0
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
}

# Функция создания systemd сервиса Promtail
create_promtail_service() {
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
}
