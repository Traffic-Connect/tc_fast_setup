#!/bin/bash

# Подключаем модули
source "$(dirname "$0")/core/colors.sh"
source "$(dirname "$0")/core/utils.sh"

print_header "🔥 ИСПРАВЛЕННАЯ НАСТРОЙКА ФАЙРВОЛА"

# Проверяем root права
check_root



# Функция определения типа файрвола
detect_firewall() {
    log_message "INFO" "Определение типа файрвола..."
    
    if command -v nft >/dev/null 2>&1 && nft list ruleset >/dev/null 2>&1; then
        log_message "SUCCESS" "Используется nftables (современный файрвол)"
        echo "nftables"
        return 0
    elif command -v iptables >/dev/null 2>&1; then
        log_message "SUCCESS" "Используется iptables (классический файрвол)"
        echo "iptables"
        return 0
    else
        log_message "ERROR" "Файрвол не найден"
        return 1
    fi
}

# Функция настройки nftables
setup_nftables() {
    print_header "🔧 НАСТРОЙКА NFTABLES"
    
    # Создаем конфигурацию nftables
    cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f

# Очищаем все правила
flush ruleset

# Определяем таблицы
table inet filter {
    # Цепочки
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Локальный интерфейс
        iif lo accept
        
        # Установленные соединения
        ct state established,related accept
        
        # ICMP (ограниченно)
        icmp type echo-request limit rate 1/second accept
        icmp type echo-request drop
        
        # SSH (с защитой от брутфорса)
        tcp dport 22 ct state new limit rate 5/minute accept
        
        # HTTP/HTTPS
        tcp dport { 80, 443 } accept
        
        # Hestia CP
        tcp dport 8083 accept
        
        # Сервисы мониторинга
        tcp dport { 9090, 9100, 3100, 9080, 9191, 9091, 3000 } accept
        
        # DNS
        udp dport 53 accept
        tcp dport 53 accept
        
        # Drop все остальное
        drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

    # Применяем конфигурацию
    nft -f /etc/nftables.conf
    
    # Включаем и запускаем nftables
    systemctl enable nftables
    systemctl start nftables
    
    log_message "SUCCESS" "nftables настроен и запущен"
}

# Функция настройки iptables
setup_iptables() {
    print_header "🔧 НАСТРОЙКА IPTABLES"
    
    # Очищаем все правила
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    # Устанавливаем политики по умолчанию
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Локальный интерфейс
    iptables -A INPUT -i lo -j ACCEPT
    
    # Установленные соединения
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # ICMP (ограниченно)
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    
    # SSH (с защитой от брутфорса)
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 5/min -j ACCEPT
    
    # HTTP/HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Hestia CP
    iptables -A INPUT -p tcp --dport 8083 -j ACCEPT
    
    # Сервисы мониторинга
    for port in 9090 9100 3100 9080 9191 9091 3000; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    done
    
    # DNS
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    
    # Сохраняем правила
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    elif command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4
    fi
    
    log_message "SUCCESS" "iptables настроен"
}

# Функция проверки настроек файрвола
check_firewall() {
    print_header "🔍 ПРОВЕРКА НАСТРОЕК ФАЙРВОЛА"
    
    local firewall_type=$(detect_firewall)
    
    if [ "$firewall_type" = "nftables" ]; then
        log_message "INFO" "Проверка правил nftables..."
        nft list ruleset | head -20
    elif [ "$firewall_type" = "iptables" ]; then
        log_message "INFO" "Проверка правил iptables..."
        iptables -L -n | head -20
    fi
    
    # Проверяем статус сервиса
    if systemctl is-active --quiet nftables 2>/dev/null; then
        log_message "SUCCESS" "nftables сервис активен"
    elif systemctl is-active --quiet iptables 2>/dev/null; then
        log_message "SUCCESS" "iptables сервис активен"
    else
        log_message "WARNING" "Сервис файрвола не активен"
    fi
}

# Функция показа доступных портов
show_ports() {
    print_header "🌐 ДОСТУПНЫЕ ПОРТЫ"
    
    local ip=$(get_server_ip)
    
    echo -e "${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУПНЫЕ СЕРВИСЫ${NC} ${LIGHT_BLUE}${STAR}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🌐 ВЕБ-ИНТЕРФЕЙСЫ${NC}${LIGHT_BLUE}${LINE_V:0:42}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Hestia CP:${NC}      ${LIGHT_YELLOW}https://${ip}:8083${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Grafana:${NC}        ${LIGHT_YELLOW}http://${ip}:3000${NC}${LIGHT_BLUE}${LINE_V:0:10}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Prometheus:${NC}     ${LIGHT_YELLOW}http://${ip}:9090${NC}${LIGHT_BLUE}${LINE_V:0:6}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Loki:${NC}           ${LIGHT_YELLOW}http://${ip}:3100${NC}${LIGHT_BLUE}${LINE_V:0:12}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Pushgateway:${NC}    ${LIGHT_YELLOW}http://${ip}:9091${NC}${LIGHT_BLUE}${LINE_V:0:4}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Главная функция
main() {
    log_message "INFO" "Начало настройки файрвола..."
    
    # Определяем тип файрвола
    local firewall_type=$(detect_firewall)
    
    if [ "$firewall_type" = "nftables" ]; then
        setup_nftables
    elif [ "$firewall_type" = "iptables" ]; then
        setup_iptables
    else
        log_message "ERROR" "Не удалось определить тип файрвола"
        exit 1
    fi
    
    # Проверяем настройки
    check_firewall
    
    # Показываем доступные порты
    show_ports
    
    print_header "🎉 НАСТРОЙКА ФАЙРВОЛА ЗАВЕРШЕНА"
    log_message "SUCCESS" "Файрвол настроен успешно!"
    log_message "INFO" "Все необходимые порты открыты"
}

# Запуск главной функции
main "$@"
