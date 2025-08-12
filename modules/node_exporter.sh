#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция установки Node Exporter
install_node_exporter() {
    print_header "🖥️ УСТАНОВКА NODE EXPORTER"
    log_message "INFO" "Начинаем установку Node Exporter"

    # Проверяем доступность GitHub
    if ! check_internet "https://github.com"; then
        log_message "WARNING" "Проблема с доступом к GitHub, пропускаем установку Node Exporter"
        log_message "INFO" "Node Exporter можно установить позже вручную"
        check_error "Установка Node Exporter (пропущена)"
        return 0
    fi
    
    {
        log_message "INFO" "Загрузка Node Exporter..."
        if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz; then
            log_message "WARNING" "Не удалось загрузить Node Exporter, пропускаем установку"
            return 0
        fi
        
        log_message "INFO" "Распаковка Node Exporter..."
        tar xvf /tmp/node_exporter.tar.gz -C /tmp/
        mv /tmp/node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
        useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
        chown node_exporter:node_exporter /usr/local/bin/node_exporter

        create_node_exporter_service

        systemctl daemon-reload
        systemctl enable node_exporter
        systemctl start node_exporter
    } > /dev/null 2>&1
    
    check_error "Установка Node Exporter"
}

# Функция создания systemd сервиса Node Exporter
create_node_exporter_service() {
    cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100

[Install]
WantedBy=multi-user.target
EOF
}
