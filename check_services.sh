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
STAR="*"

echo -e "${BLUE}${BOLD}🔍 ПРОВЕРКА ВСЕХ КОМПОНЕНТОВ СИСТЕМЫ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Функция проверки статуса сервиса
check_service() {
    local service_name="$1"
    local display_name="$2"
    local port="$3"
    
    echo -e "${CYAN}${ARROW}${NC} Проверка $display_name..."
    
    # Проверяем статус systemd сервиса
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Сервис $service_name: ${GREEN}АКТИВЕН${NC}"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Сервис $service_name: ${RED}НЕ АКТИВЕН${NC}"
    fi
    
    # Проверяем порт если указан
    if [ -n "$port" ]; then
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port: ${GREEN}ОТКРЫТ${NC}"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Порт $port: ${RED}ЗАКРЫТ${NC}"
        fi
    fi
    
    echo ""
}

# Функция проверки процесса
check_process() {
    local process_name="$1"
    local display_name="$2"
    local port="$3"
    
    echo -e "${CYAN}${ARROW}${NC} Проверка $display_name..."
    
    if pgrep -f "$process_name" >/dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Процесс $process_name: ${GREEN}РАБОТАЕТ${NC}"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Процесс $process_name: ${RED}НЕ РАБОТАЕТ${NC}"
    fi
    
    # Проверяем порт если указан
    if [ -n "$port" ]; then
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port: ${GREEN}ОТКРЫТ${NC}"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Порт $port: ${RED}ЗАКРЫТ${NC}"
        fi
    fi
    
    echo ""
}

# Функция проверки файла
check_file() {
    local file_path="$1"
    local display_name="$2"
    
    if [ -f "$file_path" ]; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $display_name: ${GREEN}НАЙДЕН${NC}"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} $display_name: ${RED}НЕ НАЙДЕН${NC}"
    fi
}

# Функция проверки директории
check_directory() {
    local dir_path="$1"
    local display_name="$2"
    
    if [ -d "$dir_path" ]; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $display_name: ${GREEN}НАЙДЕНА${NC}"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} $display_name: ${RED}НЕ НАЙДЕНА${NC}"
    fi
}

echo -e "${PURPLE}${BOLD}📊 СИСТЕМА МОНИТОРИНГА${NC}"
echo -e "${PURPLE}========================${NC}"

# Проверяем Grafana
check_service "grafana-server" "Grafana" "3000"

# Проверяем Prometheus
check_process "prometheus" "Prometheus" "9090"

# Проверяем Node Exporter
check_process "node_exporter" "Node Exporter" "9100"

# Проверяем Pushgateway
check_process "pushgateway" "Pushgateway" "9091"

# Проверяем Loki
check_process "loki" "Loki" "3100"

# Проверяем Promtail
check_process "promtail" "Promtail" "9080"

# Проверяем fail2ban exporter
check_process "fail2ban_exporter" "Fail2ban Exporter" "9191"

echo -e "${PURPLE}${BOLD}🌐 ВЕБ-СЕРВЕРЫ${NC}"
echo -e "${PURPLE}================${NC}"

# Проверяем Hestia CP
check_service "hestia" "Hestia CP" "8083"
check_service "hestia-web" "Hestia Web" "8083"
check_service "hestia-api" "Hestia API" "8083"

# Проверяем NGINX
check_service "nginx" "NGINX" "80"

# Проверяем Apache (если установлен)
check_service "apache2" "Apache" "80"

echo -e "${PURPLE}${BOLD}🗄️ БАЗЫ ДАННЫХ${NC}"
echo -e "${PURPLE}================${NC}"

# Проверяем MariaDB/MySQL
check_service "mariadb" "MariaDB" "3306"
check_service "mysql" "MySQL" "3306"

echo -e "${PURPLE}${BOLD}🛡️ БЕЗОПАСНОСТЬ${NC}"
echo -e "${PURPLE}================${NC}"

# Проверяем fail2ban
check_service "fail2ban" "Fail2ban"

# Проверяем firewall
echo -e "${CYAN}${ARROW}${NC} Проверка файрвола..."
if command -v nft >/dev/null 2>&1; then
    if nft list ruleset >/dev/null 2>&1; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} nftables: ${GREEN}АКТИВЕН${NC}"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} nftables: ${RED}НЕ АКТИВЕН${NC}"
    fi
elif command -v iptables >/dev/null 2>&1; then
    if iptables -L >/dev/null 2>&1; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} iptables: ${GREEN}АКТИВЕН${NC}"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} iptables: ${RED}НЕ АКТИВЕН${NC}"
    fi
else
    echo -e "  ${RED}${CROSS_MARK}${NC} Файрвол: ${RED}НЕ НАЙДЕН${NC}"
fi
echo ""

echo -e "${PURPLE}${BOLD}📁 ФАЙЛЫ И ДИРЕКТОРИИ${NC}"
echo -e "${PURPLE}========================${NC}"

# Проверяем Hestia CP
echo -e "${CYAN}${ARROW}${NC} Проверка файлов Hestia CP..."
check_file "/usr/local/hestia/bin/v-list" "Hestia CP binary"
check_directory "/usr/local/hestia" "Hestia CP directory"
check_file "/etc/hestia/hestia.conf" "Hestia CP config"

# Проверяем Grafana
echo -e "${CYAN}${ARROW}${NC} Проверка файлов Grafana..."
check_file "/usr/sbin/grafana-server" "Grafana binary"
check_directory "/etc/grafana" "Grafana config directory"
check_file "/etc/grafana/grafana.ini" "Grafana config"

# Проверяем Prometheus
echo -e "${CYAN}${ARROW}${NC} Проверка файлов Prometheus..."
check_file "/usr/local/bin/prometheus" "Prometheus binary"
check_directory "/etc/prometheus" "Prometheus config directory"
check_file "/etc/prometheus/prometheus.yml" "Prometheus config"

# Проверяем Loki
echo -e "${CYAN}${ARROW}${NC} Проверка файлов Loki..."
check_file "/usr/local/bin/loki" "Loki binary"
check_directory "/etc/loki" "Loki config directory"
check_file "/etc/loki/loki-config.yaml" "Loki config"

echo ""

echo -e "${PURPLE}${BOLD}🌐 СЕТЕВЫЕ ПОРТЫ${NC}"
echo -e "${PURPLE}================${NC}"

echo -e "${CYAN}${ARROW}${NC} Открытые порты:"
netstat -tlnp 2>/dev/null | grep -E ":(80|443|3000|8083|9090|9100|3100|9080|9091|9191|3306)" | while read line; do
    echo -e "  ${GREEN}${CHECK_MARK}${NC} $line"
done

echo ""

echo -e "${PURPLE}${BOLD}📋 ЛОГИ СИСТЕМЫ${NC}"
echo -e "${PURPLE}================${NC}"

# Проверяем логи
echo -e "${CYAN}${ARROW}${NC} Проверка логов..."
check_file "/var/log/grafana/grafana.log" "Grafana logs"
check_file "/var/log/fail2ban.log" "Fail2ban logs"
check_file "/var/log/nginx/error.log" "NGINX error logs"
check_file "/var/log/nginx/access.log" "NGINX access logs"

echo ""

echo -e "${PURPLE}${BOLD}🔧 ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ${NC}"
echo -e "${PURPLE}==============================${NC}"

# Системная информация
echo -e "${CYAN}${ARROW}${NC} Системная информация:"
echo -e "  ${BLUE}ОС:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || echo "Неизвестно")"
echo -e "  ${BLUE}Ядро:${NC} $(uname -r)"
echo -e "  ${BLUE}Архитектура:${NC} $(uname -m)"
echo -e "  ${BLUE}Время работы:${NC} $(uptime -p 2>/dev/null || echo "Неизвестно")"
echo -e "  ${BLUE}IP адрес:${NC} $(hostname -I | awk '{print $1}')"

echo ""

echo -e "${GREEN}${BOLD}✅ ПРОВЕРКА ЗАВЕРШЕНА${NC}"
echo -e "${GREEN}========================${NC}"
echo ""
echo -e "${YELLOW}💡 Подсказки:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Для запуска остановленных сервисов: systemctl start <service_name>"
echo -e "  ${CYAN}${ARROW}${NC} Для проверки статуса: systemctl status <service_name>"
echo -e "  ${CYAN}${ARROW}${NC} Для просмотра логов: journalctl -u <service_name>"
echo ""
echo -e "${BLUE}🌐 Доступные веб-интерфейсы:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Hestia CP: https://$(hostname -I | awk '{print $1}'):8083"
echo -e "  ${CYAN}${ARROW}${NC} Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo -e "  ${CYAN}${ARROW}${NC} Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo -e "  ${CYAN}${ARROW}${NC} Loki: http://$(hostname -I | awk '{print $1}'):3100"
