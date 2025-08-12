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

echo -e "${BLUE}${BOLD}🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ С АУТЕНТИФИКАЦИЕЙ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Функция создания правильного bcrypt хеша
create_bcrypt_hash() {
    local password="$1"
    local username="$2"
    
    # Создаем правильный bcrypt хеш
    local hash=$(htpasswd -nbB "$username" "$password" | cut -d: -f2)
    echo "$hash"
}

# Функция исправления Prometheus аутентификации
fix_prometheus_auth() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ PROMETHEUS АУТЕНТИФИКАЦИИ${NC}"
    echo -e "${PURPLE}========================================${NC}"
    
    # Создаем правильный bcrypt хеш
    local hash=$(create_bcrypt_hash "EL8YcD649BB80rZM" "TrafficPrometheus")
    
    # Создаем правильный web.yml
    cat > /etc/prometheus/web.yml << EOF
basic_auth_users:
    TrafficPrometheus: $hash
EOF
    
    # Устанавливаем правильные права
    chown prometheus:prometheus /etc/prometheus/web.yml
    chmod 600 /etc/prometheus/web.yml
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Аутентификация Prometheus исправлена"
    echo ""
}

# Функция исправления Pushgateway аутентификации
fix_pushgateway_auth() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ PUSHGATEWAY АУТЕНТИФИКАЦИИ${NC}"
    echo -e "${PURPLE}==========================================${NC}"
    
    # Создаем правильный bcrypt хеш
    local hash=$(create_bcrypt_hash "9MBikpzCHrDeey3" "TrafficPushgateway")
    
    # Создаем правильный web.yml
    cat > /etc/pushgateway/web.yml << EOF
basic_auth_users:
    TrafficPushgateway: $hash
EOF
    
    # Устанавливаем правильные права
    chown pushgateway:pushgateway /etc/pushgateway/web.yml
    chmod 600 /etc/pushgateway/web.yml
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Аутентификация Pushgateway исправлена"
    echo ""
}

# Функция альтернативного исправления без аутентификации
fix_without_auth() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ БЕЗ АУТЕНТИФИКАЦИИ${NC}"
    echo -e "${PURPLE}================================${NC}"
    
    # Убираем web.config.file из Prometheus service
    echo -e "${CYAN}${ARROW}${NC} Исправление Prometheus service..."
    sed -i 's/--web.config.file=\/etc\/prometheus\/web.yml//' /etc/systemd/system/prometheus.service
    systemctl daemon-reload
    
    # Убираем web.config.file из Pushgateway service
    echo -e "${CYAN}${ARROW}${NC} Исправление Pushgateway service..."
    sed -i 's/--web.config.file=\/etc\/pushgateway\/web.yml//' /etc/systemd/system/pushgateway.service
    systemctl daemon-reload
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Сервисы настроены без аутентификации"
    echo ""
}

# Функция перезапуска сервисов
restart_services() {
    echo -e "${PURPLE}${BOLD}🔄 ПЕРЕЗАПУСК СЕРВИСОВ${NC}"
    echo -e "${PURPLE}======================${NC}"
    
    # Перезапускаем сервисы
    for service in prometheus pushgateway; do
        echo -e "${CYAN}${ARROW}${NC} Перезапуск $service..."
        systemctl restart $service
        sleep 5
        
        if systemctl is-active --quiet $service; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $service: АКТИВЕН"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $service: НЕ АКТИВЕН"
        fi
    done
    
    echo ""
}

# Функция проверки портов
check_ports() {
    echo -e "${PURPLE}${BOLD}🌐 ПРОВЕРКА ПОРТОВ${NC}"
    echo -e "${PURPLE}================${NC}"
    
    # Ждем немного для запуска сервисов
    echo -e "${CYAN}${ARROW}${NC} Ожидание запуска сервисов..."
    sleep 10
    
    # Проверяем порты
    for port in 9090 9091 3100; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port: ОТКРЫТ"
            netstat -tlnp 2>/dev/null | grep ":$port "
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Порт $port: ЗАКРЫТ"
        fi
    done
    
    echo ""
}

# Основная логика
echo -e "${CYAN}${ARROW}${NC} Начинаем исправление проблем с аутентификацией..."

# Проверяем наличие htpasswd
if ! command -v htpasswd &> /dev/null; then
    echo -e "${YELLOW}⚠️ htpasswd не найден, используем исправление без аутентификации${NC}"
    fix_without_auth
else
    echo -e "${CYAN}${ARROW}${NC} htpasswd найден, исправляем аутентификацию..."
    fix_prometheus_auth
    fix_pushgateway_auth
fi

# Перезапускаем сервисы
restart_services

# Проверяем порты
check_ports

echo -e "${GREEN}${BOLD}✅ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО${NC}"
echo -e "${GREEN}========================${NC}"
echo ""
echo -e "${YELLOW}💡 Результат:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: http://$(hostname -I | awk '{print $1}'):9091"
echo -e "  ${CYAN}${ARROW}${NC} Loki: http://$(hostname -I | awk '{print $1}'):3100"
echo ""
echo -e "${YELLOW}🔐 Данные для входа:${NC}"
if command -v htpasswd &> /dev/null; then
    echo -e "  ${CYAN}${ARROW}${NC} Prometheus: TrafficPrometheus / EL8YcD649BB80rZM"
    echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: TrafficPushgateway / 9MBikpzCHrDeey3"
else
    echo -e "  ${CYAN}${ARROW}${NC} Prometheus: без аутентификации"
    echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: без аутентификации"
fi
echo -e "  ${CYAN}${ARROW}${NC} Loki: без аутентификации"
