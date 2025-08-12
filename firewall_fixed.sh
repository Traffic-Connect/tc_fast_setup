#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Символы
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="->"

echo -e "${BLUE}${BOLD}🔥 ИСПРАВЛЕННАЯ НАСТРОЙКА ФАЙРВОЛА${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Функция проверки root прав
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${CROSS_MARK}${NC} Этот скрипт должен быть запущен от root"
        exit 1
    fi
}

# Функция проверки валидности IP адреса
is_valid_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Функция определения типа файрвола
detect_firewall() {
    echo -e "${CYAN}${ARROW}${NC} Определение типа файрвола..."
    
    if command -v nft >/dev/null 2>&1 && nft list ruleset >/dev/null 2>&1; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Используется nftables (современный файрвол)"
        echo "nftables"
        return 0
    elif command -v iptables >/dev/null 2>&1; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Используется iptables (классический файрвол)"
        echo "iptables"
        return 0
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Файрвол не найден"
        return 1
    fi
}

# Функция настройки nftables
setup_nftables() {
    echo -e "${PURPLE}${BOLD}🔧 НАСТРОЙКА NFTABLES${NC}"
    echo -e "${PURPLE}====================${NC}"
    
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
        
        
        
        # Сервисы мониторинга
        tcp dport { 9090, 9100, 3100, 9080, 9191, 9091, 3000 } accept
        
        # DNS
        udp dport 53 accept
        tcp dport 53 accept
        
        # Логирование подозрительной активности
        log prefix "nftables-dropped: " group 0
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# Защита от DDoS
table inet ddos {
    chain input {
        type filter hook input priority 10; policy accept;
        
        # Защита от SYN flood
        tcp flags syn ct state new limit rate 10/second burst 25 packets accept
        tcp flags syn ct state new drop
        
        # Защита от сканирования портов
        tcp flags & (fin|syn|rst|ack) == rst ct state new limit rate 1/second accept
        tcp flags & (fin|syn|rst|ack) == rst ct state new drop
    }
}
EOF
    
    # Применяем правила nftables
    echo -e "${CYAN}${ARROW}${NC} Применение правил nftables..."
    if nft -f /etc/nftables.conf; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Правила nftables применены"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Ошибка применения правил nftables"
        return 1
    fi
    
    # Включаем и запускаем nftables
    systemctl enable nftables 2>/dev/null || true
    systemctl start nftables 2>/dev/null || true
    
    # Добавляем правила Cloudflare
    add_cloudflare_rules "nftables"
    
    # Сохраняем правила
    nft list ruleset > /etc/nftables.conf 2>/dev/null || true
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} nftables настроен успешно"
}

# Функция настройки iptables
setup_iptables() {
    echo -e "${PURPLE}${BOLD}🔧 НАСТРОЙКА IPTABLES${NC}"
    echo -e "${PURPLE}====================${NC}"
    
    # Очищаем все правила
    echo -e "${CYAN}${ARROW}${NC} Очистка существующих правил..."
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    
    # Устанавливаем политики по умолчанию
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Базовые правила
    echo -e "${CYAN}${ARROW}${NC} Добавление базовых правил..."
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # SSH с защитой от брутфорса
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 5/minute --limit-burst 10 -j ACCEPT
    
    # HTTP/HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    
    
    # Сервисы мониторинга
    echo -e "${CYAN}${ARROW}${NC} Открытие портов мониторинга..."
    for port in 9090 9100 3100 9080 9191 9091 3000; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port открыт"
    done
    
    # DNS
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    
    # Добавляем правила Cloudflare
    add_cloudflare_rules "iptables"
    
    # Защита от атак
    echo -e "${CYAN}${ARROW}${NC} Настройка защиты от атак..."
    
    # SYN flood protection
    iptables -N SYN_FLOOD 2>/dev/null || true
    iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    iptables -A SYN_FLOOD -m limit --limit 10/s --limit-burst 25 -j RETURN
    iptables -A SYN_FLOOD -j DROP
    
    # ICMP с ограничениями
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    
    # Защита от сканирования портов
    iptables -N PORT_SCAN 2>/dev/null || true
    iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST -j PORT_SCAN
    iptables -A PORT_SCAN -m limit --limit 1/s -j RETURN
    iptables -A PORT_SCAN -j DROP
    
    # Логирование подозрительной активности
    iptables -A INPUT -j LOG --log-prefix "iptables-dropped: " --log-level 4
    
    # Сохраняем правила
    echo -e "${CYAN}${ARROW}${NC} Сохранение правил..."
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save 2>/dev/null || true
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Правила сохранены"
    else
        echo -e "  ${YELLOW}⚠️ netfilter-persistent не найден, правила не сохранены${NC}"
    fi
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} iptables настроен успешно"
}

# Функция добавления правил Cloudflare
add_cloudflare_rules() {
    local firewall_type="$1"
    
    echo -e "${CYAN}${ARROW}${NC} Добавление правил Cloudflare..."
    
    # Получаем IP адреса Cloudflare
    CLOUDFLARE_IPS=$(curl -s --max-time 10 https://www.cloudflare.com/ips-v4 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$CLOUDFLARE_IPS" ]; then
        local count=0
        for ip in $CLOUDFLARE_IPS; do
            if is_valid_ip "$ip"; then
                if [ "$firewall_type" = "nftables" ]; then
                    nft add rule inet filter input tcp saddr "$ip" dport { 80, 443 } accept 2>/dev/null && count=$((count + 1))
                else
                    iptables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT 2>/dev/null && count=$((count + 1))
                    iptables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT 2>/dev/null && count=$((count + 1))
                fi
            fi
        done
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Добавлено $count IP адресов Cloudflare"
    else
        echo -e "  ${YELLOW}⚠️ Не удалось загрузить IP адреса Cloudflare${NC}"
    fi
}

# Функция перезапуска сервисов
restart_services() {
    echo -e "${PURPLE}${BOLD}🔄 ПЕРЕЗАПУСК СЕРВИСОВ${NC}"
    echo -e "${PURPLE}======================${NC}"
    
    local services=("grafana-server" "prometheus" "pushgateway" "loki" "promtail" "fail2ban_exporter" "nginx" "mariadb" "mysql")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${CYAN}${ARROW}${NC} Перезапуск $service..."
            if systemctl restart "$service" 2>/dev/null; then
                echo -e "  ${GREEN}${CHECK_MARK}${NC} $service перезапущен"
            else
                echo -e "  ${YELLOW}⚠️ Ошибка перезапуска $service${NC}"
            fi
        fi
    done
}

# Функция проверки портов
check_ports() {
    echo -e "${PURPLE}${BOLD}🌐 ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ${NC}"
    echo -e "${PURPLE}========================${NC}"
    
    echo -e "${CYAN}${ARROW}${NC} Ожидание запуска сервисов..."
    sleep 5
    
    local ports=(80 443 8083 3000 9090 9100 3100 9080 9091 9191 3306 22)
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port: ОТКРЫТ"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Порт $port: ЗАКРЫТ"
        fi
    done
}

# Основная логика
main() {
    # Проверяем root права
    check_root
    
    # Определяем тип файрвола
    FIREWALL_TYPE=$(detect_firewall)
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS_MARK}${NC} Не удалось определить тип файрвола"
        exit 1
    fi
    
    echo ""
    
    # Настраиваем файрвол
    if [ "$FIREWALL_TYPE" = "nftables" ]; then
        setup_nftables
    else
        setup_iptables
    fi
    
    echo ""
    
    # Перезапускаем сервисы
    restart_services
    
    echo ""
    
    # Проверяем порты
    check_ports
    
    echo ""
    
    echo -e "${GREEN}${BOLD}✅ ФАЙРВОЛ НАСТРОЕН УСПЕШНО${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo ""
    echo -e "${YELLOW}💡 Доступные веб-интерфейсы:${NC}"
    
    echo -e "  ${CYAN}${ARROW}${NC} Grafana: http://$(hostname -I | awk '{print $1}'):3000"
    echo -e "  ${CYAN}${ARROW}${NC} Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
    echo -e "  ${CYAN}${ARROW}${NC} Loki: http://$(hostname -I | awk '{print $1}'):3100"
    echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: http://$(hostname -I | awk '{print $1}'):9091"
}

# Запускаем основную функцию
main
