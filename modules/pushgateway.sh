#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция установки Pushgateway
install_pushgateway() {
    print_header "📤 УСТАНОВКА PUSHGATEWAY"
    log_message "INFO" "Начинаем установку Pushgateway"

    # Проверяем доступность GitHub
    if ! check_internet "https://github.com"; then
        log_message "WARNING" "Проблема с доступом к GitHub, пропускаем установку Pushgateway"
        log_message "INFO" "Pushgateway можно установить позже вручную"
        check_error "Установка Pushgateway (пропущена)"
        return 0
    fi
    
    {
        log_message "INFO" "Загрузка Pushgateway..."
        if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/prometheus/pushgateway/releases/download/v1.6.1/pushgateway-1.6.1.linux-amd64.tar.gz -O /tmp/pushgateway.tar.gz; then
            log_message "WARNING" "Не удалось загрузить Pushgateway, пропускаем установку"
            return 0
        fi
        
        log_message "INFO" "Распаковка Pushgateway..."
        tar xvf /tmp/pushgateway.tar.gz -C /tmp/
        mv /tmp/pushgateway-1.6.1.linux-amd64/pushgateway /usr/local/bin/
        useradd --no-create-home --shell /bin/false pushgateway 2>/dev/null || true
        chown pushgateway:pushgateway /usr/local/bin/pushgateway

        # Создаем директорию для Pushgateway
        mkdir -p /etc/pushgateway

        create_pushgateway_service

        systemctl daemon-reload
        systemctl enable pushgateway
        systemctl start pushgateway
    } > /dev/null 2>&1
    
    check_error "Установка Pushgateway"
}

# Функция создания systemd сервиса Pushgateway
create_pushgateway_service() {
    cat > /etc/systemd/system/pushgateway.service <<EOF
[Unit]
Description=Prometheus Pushgateway
After=network.target

[Service]
User=pushgateway
Group=pushgateway
ExecStart=/usr/local/bin/pushgateway \\
    --web.listen-address=0.0.0.0:9091

[Install]
WantedBy=multi-user.target
EOF
}
