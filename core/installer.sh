#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/utils.sh"
source "$(dirname "$0")/system.sh"

# Глобальные переменные
declare -g HESTIA_USERNAME="admin"
declare -g HESTIA_PASSWORD=""
declare -g HESTIA_EMAIL=""
declare -g SERVER_IP=""
declare -g GRAFANA_PASSWORD=""

# Функция инициализации установки
initialize_installation() {
    print_header "🚀 ИНИЦИАЛИЗАЦИЯ УСТАНОВКИ"
    
    # Проверяем root права
    check_root
    
    # Генерируем данные для входа
    HESTIA_PASSWORD=$(generate_password)
    HESTIA_EMAIL="admin@$(hostname)"
    SERVER_IP=$(get_server_ip)
    
    # Отладочная информация
    log_message "INFO" "Скрипт запущен"
    log_message "INFO" "Время: $(date)"
    log_message "INFO" "PID: $$"
    log_message "INFO" "Пользователь: $(whoami)"
    log_message "INFO" "Директория: $(pwd)"
    
    # Показываем информацию о системе
    display_system_info
}

# Функция отображения информации о системе
display_system_info() {
    print_header "🔧 ПОДГОТОВКА К УСТАНОВКЕ"
    
    log_message "INFO" "Проверка системы..."
    log_message "INFO" "ОС: $(lsb_release -d | cut -f2 2>/dev/null || echo 'Ubuntu')"
    log_message "INFO" "Ядро: $(uname -r)"
    log_message "INFO" "IP адрес: ${SERVER_IP}"
}

# Функция отображения данных для входа
display_login_info() {
    print_header "🔐 ДАННЫЕ ДЛЯ ВХОДА"
    
    echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУП К HESTIA CP${NC} ${LIGHT_PURPLE}${STAR}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🌐 ВЕБ-ИНТЕРФЕЙС${NC}${LIGHT_PURPLE}${LINE_V:0:40}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}URL:${NC}         ${LIGHT_YELLOW}https://${SERVER_IP}:8083${NC}${LIGHT_PURPLE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Альтернативный:${NC} ${LIGHT_YELLOW}https://$(hostname):8083${NC}${LIGHT_PURPLE}${LINE_V:0:2}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

    echo -e "\n${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДАННЫЕ ДЛЯ ВХОДА${NC} ${LIGHT_BLUE}${STAR}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🔐 УЧЕТНЫЕ ДАННЫЕ${NC}${LIGHT_BLUE}${LINE_V:0:40}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Логин:${NC}       ${LIGHT_YELLOW}${HESTIA_USERNAME}${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Пароль:${NC}      ${LIGHT_RED}${HESTIA_PASSWORD}${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Email:${NC}       ${LIGHT_YELLOW}${HESTIA_EMAIL}${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция отображения компонентов
display_components() {
    echo -e "\n${LIGHT_GREEN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ЧТО БУДЕТ УСТАНОВЛЕНО${NC} ${LIGHT_GREEN}${STAR}${NC}"
    echo -e "${LIGHT_GREEN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🚀 КОМПОНЕНТЫ${NC}${LIGHT_GREEN}${LINE_V:0:45}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ NGINX Web/Proxy Server${NC}${LIGHT_GREEN}${LINE_V:0:25}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ PHP-FPM 8.3${NC}${LIGHT_GREEN}${LINE_V:0:35}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ MariaDB 11.4${NC}${LIGHT_GREEN}${LINE_V:0:35}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ Vsftpd FTP Server${NC}${LIGHT_GREEN}${LINE_V:0:30}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ Firewall (iptables) + Fail2Ban${NC}${LIGHT_GREEN}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ phpMyAdmin v5.2.2${NC}${LIGHT_GREEN}${LINE_V:0:25}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ File Manager${NC}${LIGHT_GREEN}${LINE_V:0:35}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ Rclone & Restic${NC}${LIGHT_GREEN}${LINE_V:0:30}${LINE_V}${NC}"
    echo -e "${LIGHT_GREEN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция отображения важной информации
display_important_info() {
    echo -e "\n${LIGHT_YELLOW}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ВАЖНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_YELLOW}${STAR}${NC}"
    echo -e "${LIGHT_YELLOW}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}⚠️ ВНИМАНИЕ${NC}${LIGHT_YELLOW}${LINE_V:0:45}${LINE_V}${NC}"
    echo -e "${LIGHT_YELLOW}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
    echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}•${NC} Установка займет 5-10 минут${LIGHT_YELLOW}${LINE_V:0:25}${LINE_V}${NC}"
    echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}•${NC} После установки сервер перезагрузится${LIGHT_YELLOW}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}•${NC} Сохраните пароль: ${LIGHT_RED}${HESTIA_PASSWORD}${NC}${LIGHT_YELLOW}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_YELLOW}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

    echo -e "\n${LIGHT_RED}${STAR}${NC} ${BOLD}${LIGHT_GREEN}СОХРАНИТЕ ПАРОЛЬ: ${LIGHT_RED}${HESTIA_PASSWORD}${NC} ${LIGHT_RED}${STAR}${NC}"
}

# Функция ожидания подтверждения
wait_for_confirmation() {
    echo -e "\n${LIGHT_CYAN}${ARROW}${NC} Нажмите любую клавишу для начала установки..."
    read -n 1 -s
}

# Функция основного процесса установки
main_installation_process() {
    # 0. Восстановление состояния системы
    print_header "🔧 ВОССТАНОВЛЕНИЕ СОСТОЯНИЯ СИСТЕМЫ"
    restore_system_state

    # Проверка зависимостей
    check_dependencies

    # 1. Очистка системы
    cleanup_system

    # 2. Обновление системы и установка базовых пакетов
    update_system

    # 3. Установка и настройка файрвола
    install_firewall

    # 4. Установка и настройка fail2ban
    install_fail2ban

    # 5. Установка мониторинга
    install_monitoring_stack

    # 6. Установка Hestia CP
    install_hestia_cp

    # 7. Финальная настройка
    final_setup
}

# Функция установки файрвола
install_firewall() {
    print_header "🔥 НАСТРОЙКА ФАЙРВОЛА"
    
    log_message "INFO" "Загрузка firewall_fixed.sh..."
    if wget -q https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/firewall_fixed.sh -O /tmp/firewall_fixed.sh; then
        chmod +x /tmp/firewall_fixed.sh
        log_message "INFO" "Запуск firewall_fixed.sh..."
        bash /tmp/firewall_fixed.sh
        rm -f /tmp/firewall_fixed.sh
    else
        log_message "WARNING" "Не удалось загрузить firewall_fixed.sh, настраиваем базовый файрвол"
        setup_basic_firewall
    fi
    
    # Проверяем и перезапускаем сервисы
    check_and_restart_services
}

# Функция базовой настройки файрвола
setup_basic_firewall() {
    log_message "INFO" "Базовая настройка файрвола..."
    
    # Определяем тип файрвола
    if command -v nft >/dev/null 2>&1; then
        log_message "INFO" "Using nftables (modern firewall)"
        setup_nftables
    else
        log_message "INFO" "Using iptables"
        setup_iptables
    fi
    
    log_message "SUCCESS" "Базовая настройка файрвола завершена"
}

# Функция настройки nftables
setup_nftables() {
    cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        tcp dport { 22, 80, 443, 3000, 9090, 9100, 3100, 9080, 9191, 9091 } accept
        udp dport 53 accept
        tcp dport 53 accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output { type filter hook output priority 0; policy accept; }
}
EOF
    nft -f /etc/nftables.conf
    systemctl enable nftables
    systemctl start nftables
}

# Функция настройки iptables
setup_iptables() {
    iptables -F
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    for port in 22 80 443 3000 9090 9100 3100 9080 9191 9091; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    done
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    netfilter-persistent save 2>/dev/null || true
}

# Функция установки fail2ban
install_fail2ban() {
    print_header "🛡️ НАСТРОЙКА FAIL2BAN"
    
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
EOL

    # Создаем фильтры для fail2ban
    cat > /etc/fail2ban/filter.d/nginx-dos.conf <<EOL
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (404|503|400|499) .*$
ignoreregex =
EOL

    systemctl enable --now fail2ban
    check_error "Настройка fail2ban"
}

# Функция установки стека мониторинга
install_monitoring_stack() {
    # Загружаем и выполняем модули мониторинга
    source "$(dirname "$0")/../modules/grafana.sh"
    source "$(dirname "$0")/../modules/prometheus.sh"
    source "$(dirname "$0")/../modules/node_exporter.sh"
    source "$(dirname "$0")/../modules/pushgateway.sh"
    source "$(dirname "$0")/../modules/loki.sh"
    source "$(dirname "$0")/../modules/fail2ban_exporter.sh"
    
    # Устанавливаем компоненты
    install_grafana
    install_prometheus
    install_node_exporter
    install_pushgateway
    install_loki
    install_fail2ban_exporter
    
    # Настраиваем Grafana
    configure_grafana
}

# Функция установки Hestia CP
install_hestia_cp() {
    print_header "📦 УСТАНОВКА HESTIA CP"
    
    log_message "INFO" "Загрузка установщика Hestia CP..."
    if wget -q https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh -O /tmp/hst-install.sh; then
        log_message "SUCCESS" "Установщик загружен"
        chmod +x /tmp/hst-install.sh
    else
        log_message "ERROR" "Ошибка загрузки установщика"
        exit 1
    fi

    log_message "INFO" "Запуск установки Hestia CP..."
    log_message "WARNING" "Установка может занять 5-10 минут"

    # Запускаем установку Hestia CP
    /tmp/hst-install.sh \
        --lang 'ru' \
        --hostname "$(hostname)" \
        --username "$HESTIA_USERNAME" \
        --email "$HESTIA_EMAIL" \
        --password "$HESTIA_PASSWORD" \
        --apache no \
        --named no \
        --exim no \
        --dovecot no \
        --clamav no \
        --spamassassin no \
        --force

    check_error "Установка Hestia CP"

    # Очищаем временные файлы
    rm -f /tmp/hst-install.sh
}

# Функция финальной настройки
final_setup() {
    print_header "🎉 УСТАНОВКА ЗАВЕРШЕНА"
    
    log_message "SUCCESS" "Hestia CP успешно установлен!"
    log_message "INFO" "Для входа используйте: https://${SERVER_IP}:8083"
    log_message "INFO" "Логин: ${HESTIA_USERNAME} | Пароль: ${HESTIA_PASSWORD}"
    
    # Загружаем диагностический скрипт
    download_diagnostic_script
}

# Функция загрузки диагностического скрипта
download_diagnostic_script() {
    log_message "INFO" "Загрузка диагностического скрипта..."
    if wget -q https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh -O /usr/local/bin/diagnostic.sh; then
        chmod +x /usr/local/bin/diagnostic.sh
        log_message "SUCCESS" "Диагностический скрипт загружен"
        log_message "INFO" "Для диагностики запустите: diagnostic.sh"
    else
        log_message "WARNING" "Не удалось загрузить диагностический скрипт"
    fi
}
