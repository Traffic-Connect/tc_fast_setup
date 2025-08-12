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

echo -e "${BLUE}${BOLD}🔥 ИСПРАВЛЕНИЕ ФАЙРВОЛА И ОТКРЫТИЕ ПОРТОВ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Функция добавления правила в nftables
add_nft_rule() {
    local port="$1"
    local description="$2"
    
    echo -e "${CYAN}${ARROW}${NC} Открытие порта $port ($description)..."
    
    if nft add rule inet filter input tcp dport "$port" accept 2>/dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port открыт"
    else
        echo -e "  ${YELLOW}⚠️ Порт $port уже открыт или ошибка${NC}"
    fi
}

# Функция добавления правила в iptables
add_ipt_rule() {
    local port="$1"
    local description="$2"
    
    echo -e "${CYAN}${ARROW}${NC} Открытие порта $port ($description)..."
    
    if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️ Порт $port уже открыт${NC}"
    else
        if iptables -A INPUT -p tcp --dport "$port" -j ACCEPT; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port открыт"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Ошибка открытия порта $port"
        fi
    fi
}

# Проверяем, какой файрвол используется
echo -e "${CYAN}${ARROW}${NC} Определение типа файрвола..."

if command -v nft >/dev/null 2>&1 && nft list ruleset >/dev/null 2>&1; then
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Используется nftables"
    USE_NFTABLES=true
elif command -v iptables >/dev/null 2>&1; then
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Используется iptables"
    USE_NFTABLES=false
else
    echo -e "  ${RED}${CROSS_MARK}${NC} Файрвол не найден"
    exit 1
fi

echo ""

# Список портов для открытия
PORTS=(
    "80:HTTP"
    "443:HTTPS"
    "8083:Hestia CP"
    "3000:Grafana"
    "9090:Prometheus"
    "9100:Node Exporter"
    "3100:Loki"
    "9080:Promtail"
    "9091:Pushgateway"
    "9191:Fail2ban Exporter"
    "3306:MariaDB/MySQL"
    "22:SSH"
)

echo -e "${PURPLE}${BOLD}🔓 ОТКРЫТИЕ ПОРТОВ${NC}"
echo -e "${PURPLE}==================${NC}"

# Открываем порты
for port_info in "${PORTS[@]}"; do
    port=$(echo "$port_info" | cut -d: -f1)
    description=$(echo "$port_info" | cut -d: -f2)
    
    if [ "$USE_NFTABLES" = true ]; then
        add_nft_rule "$port" "$description"
    else
        add_ipt_rule "$port" "$description"
    fi
done

echo ""

# Сохраняем правила
echo -e "${CYAN}${ARROW}${NC} Сохранение правил файрвола..."

if [ "$USE_NFTABLES" = true ]; then
    if nft list ruleset > /etc/nftables.conf; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Правила nftables сохранены"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Ошибка сохранения правил nftables"
    fi
else
    if command -v netfilter-persistent >/dev/null 2>&1; then
        if netfilter-persistent save; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Правила iptables сохранены"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Ошибка сохранения правил iptables"
        fi
    else
        echo -e "  ${YELLOW}⚠️ netfilter-persistent не найден, правила не сохранены${NC}"
    fi
fi

echo ""

# Перезапускаем сервисы для применения новых правил
echo -e "${CYAN}${ARROW}${NC} Перезапуск сервисов..."

SERVICES=("grafana-server" "prometheus" "pushgateway" "loki" "promtail" "fail2ban_exporter" "nginx" "mariadb" "mysql")

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "  ${CYAN}${ARROW}${NC} Перезапуск $service..."
        if systemctl restart "$service" 2>/dev/null; then
            echo -e "    ${GREEN}${CHECK_MARK}${NC} $service перезапущен"
        else
            echo -e "    ${YELLOW}⚠️ Ошибка перезапуска $service${NC}"
        fi
    fi
done

echo ""

# Проверяем открытые порты
echo -e "${PURPLE}${BOLD}🌐 ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ${NC}"
echo -e "${PURPLE}========================${NC}"

echo -e "${CYAN}${ARROW}${NC} Открытые порты:"
netstat -tlnp 2>/dev/null | grep -E ":(80|443|3000|8083|9090|9100|3100|9080|9091|9191|3306|22)" | while read line; do
    echo -e "  ${GREEN}${CHECK_MARK}${NC} $line"
done

echo ""

echo -e "${GREEN}${BOLD}✅ ФАЙРВОЛ ИСПРАВЛЕН${NC}"
echo -e "${GREEN}========================${NC}"
echo ""
echo -e "${YELLOW}💡 Теперь запустите проверку снова:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} ./check_services.sh"
echo ""
echo -e "${BLUE}🌐 Доступные веб-интерфейсы:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Hestia CP: https://$(hostname -I | awk '{print $1}'):8083"
echo -e "  ${CYAN}${ARROW}${NC} Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo -e "  ${CYAN}${ARROW}${NC} Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo -e "  ${CYAN}${ARROW}${NC} Loki: http://$(hostname -I | awk '{print $1}'):3100"
