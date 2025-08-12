#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция установки Grafana
install_grafana() {
    print_header "📊 УСТАНОВКА GRAFANA"
    log_message "INFO" "Начинаем установку Grafana"
    
    {
        wget https://dl.grafana.com/oss/release/grafana_10.4.3_amd64.deb -O /tmp/grafana.deb
        dpkg -i /tmp/grafana.deb || apt-get install -fy
        rm -f /tmp/grafana.deb
        
        # Настраиваем Grafana для доступа извне
        create_grafana_config
        
        systemctl daemon-reload
        systemctl enable grafana-server
        systemctl start grafana-server
    } > /dev/null 2>&1
    
    check_error "Установка Grafana"
}

# Функция создания конфигурации Grafana
create_grafana_config() {
    cat > /etc/grafana/grafana.ini <<EOF
[server]
http_addr = 0.0.0.0
http_port = 3000
protocol = http
domain = localhost
root_url = %(protocol)s://%(domain)s:%(http_port)s/
serve_from_sub_path = false

[security]
admin_user = admin
admin_password = admin
allow_embedding = true

[auth.anonymous]
enabled = false

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer
EOF
}

# Функция настройки Grafana
configure_grafana() {
    print_header "⚙️ НАСТРОЙКА GRAFANA"
    log_message "INFO" "Начинаем настройку Grafana"
    
    # Проверяем, запущен ли Grafana
    log_message "INFO" "Ожидание запуска Grafana..."
    timeout 60 bash -c 'while ! systemctl is-active --quiet grafana-server; do sleep 1; done' || {
        log_message "WARNING" "Grafana не запустился в течение 60 секунд, пропускаем настройку"
        check_error "Настройка Grafana (пропущена)"
        return 0
    }
    
    log_message "SUCCESS" "Grafana запущен, начинаем настройку..."
    
    # Генерируем пароль для Grafana
    local grafana_password=$(generate_password)
    log_message "INFO" "Установка пароля администратора..."
    grafana-cli admin reset-admin-password "$grafana_password" 2>/dev/null || {
        log_message "WARNING" "Не удалось установить пароль Grafana"
    }
    
    # Проверяем доступность Grafana API
    log_message "INFO" "Проверка доступности Grafana API..."
    timeout 30 bash -c 'until curl -s http://localhost:3000/api/health; do sleep 2; done' || {
        log_message "WARNING" "Grafana API недоступен, пропускаем настройку дашбордов"
        check_error "Настройка Grafana (базовая)"
        return 0
    }
    
    # Добавляем источники данных
    add_datasources "$grafana_password"
    
    # Пропускаем импорт дашбордов для ускорения
    log_message "WARNING" "Пропускаем импорт дашбордов для ускорения"
    log_message "INFO" "Дашборды можно импортировать позже вручную"
    
    check_error "Настройка Grafana"
}

# Функция добавления источников данных
add_datasources() {
    local password="$1"
    
    log_message "INFO" "Добавление источника данных Prometheus..."
    timeout 30 curl -u admin:"$password" -X POST -H "Content-Type: application/json" \
      -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy"}' \
      http://localhost:3000/api/datasources 2>/dev/null || {
        log_message "WARNING" "Не удалось добавить Prometheus как источник данных"
    }
    
    log_message "INFO" "Добавление источника данных Loki..."
    timeout 30 curl -u admin:"$password" -X POST -H "Content-Type: application/json" \
      -d '{"name":"Loki","type":"loki","url":"http://localhost:3100","access":"proxy"}' \
      http://localhost:3000/api/datasources 2>/dev/null || {
        log_message "WARNING" "Не удалось добавить Loki как источник данных"
    }
}
