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

echo -e "${BLUE}${BOLD}🔧 ИСПРАВЛЕНИЕ ОСТАВШИХСЯ ПРОБЛЕМ${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Функция проверки и исправления Prometheus
fix_prometheus() {
    echo -e "${PURPLE}${BOLD}🔧 ДЕТАЛЬНАЯ ДИАГНОСТИКА PROMETHEUS${NC}"
    echo -e "${PURPLE}====================================${NC}"
    
    # Проверяем статус
    echo -e "${CYAN}${ARROW}${NC} Статус сервиса:"
    systemctl status prometheus --no-pager -l
    
    echo ""
    
    # Проверяем логи
    echo -e "${CYAN}${ARROW}${NC} Последние логи:"
    journalctl -u prometheus --no-pager -l -n 10
    
    echo ""
    
    # Проверяем конфигурацию
    echo -e "${CYAN}${ARROW}${NC} Проверка конфигурации:"
    echo -e "  ${CYAN}${ARROW}${NC} /etc/prometheus/web.yml:"
    cat /etc/prometheus/web.yml
    
    echo ""
    echo -e "  ${CYAN}${ARROW}${NC} /etc/prometheus/prometheus.yml:"
    cat /etc/prometheus/prometheus.yml
    
    echo ""
    
    # Проверяем права доступа
    echo -e "${CYAN}${ARROW}${NC} Права доступа:"
    ls -la /etc/prometheus/
    ls -la /var/lib/prometheus/
    
    echo ""
    
    # Пробуем запустить вручную
    echo -e "${CYAN}${ARROW}${NC} Попытка запуска вручную:"
    sudo -u prometheus /usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus --web.listen-address=0.0.0.0:9090 --web.enable-lifecycle --web.config.file=/etc/prometheus/web.yml &
    sleep 3
    
    if pgrep prometheus > /dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Prometheus запущен вручную"
        pkill prometheus
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Ошибка запуска Prometheus"
    fi
    
    echo ""
}

# Функция проверки и исправления Pushgateway
fix_pushgateway() {
    echo -e "${PURPLE}${BOLD}🔧 ДЕТАЛЬНАЯ ДИАГНОСТИКА PUSHGATEWAY${NC}"
    echo -e "${PURPLE}====================================${NC}"
    
    # Проверяем статус
    echo -e "${CYAN}${ARROW}${NC} Статус сервиса:"
    systemctl status pushgateway --no-pager -l
    
    echo ""
    
    # Проверяем логи
    echo -e "${CYAN}${ARROW}${NC} Последние логи:"
    journalctl -u pushgateway --no-pager -l -n 10
    
    echo ""
    
    # Проверяем конфигурацию
    echo -e "${CYAN}${ARROW}${NC} Проверка конфигурации:"
    echo -e "  ${CYAN}${ARROW}${NC} /etc/pushgateway/web.yml:"
    cat /etc/pushgateway/web.yml
    
    echo ""
    
    # Проверяем права доступа
    echo -e "${CYAN}${ARROW}${NC} Права доступа:"
    ls -la /etc/pushgateway/
    
    echo ""
    
    # Пробуем запустить вручную
    echo -e "${CYAN}${ARROW}${NC} Попытка запуска вручную:"
    sudo -u pushgateway /usr/local/bin/pushgateway --web.listen-address=0.0.0.0:9091 --web.config.file=/etc/pushgateway/web.yml &
    sleep 3
    
    if pgrep pushgateway > /dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Pushgateway запущен вручную"
        pkill pushgateway
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Ошибка запуска Pushgateway"
    fi
    
    echo ""
}

# Функция исправления конфигураций без аутентификации
fix_configs_no_auth() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ КОНФИГУРАЦИЙ БЕЗ АУТЕНТИФИКАЦИИ${NC}"
    echo -e "${PURPLE}==============================================${NC}"
    
    # Убираем web.config.file из Prometheus
    echo -e "${CYAN}${ARROW}${NC} Исправление Prometheus service..."
    sed -i 's/--web.config.file=\/etc\/prometheus\/web.yml//' /etc/systemd/system/prometheus.service
    systemctl daemon-reload
    
    # Убираем web.config.file из Pushgateway
    echo -e "${CYAN}${ARROW}${NC} Исправление Pushgateway service..."
    sed -i 's/--web.config.file=\/etc\/pushgateway\/web.yml//' /etc/systemd/system/pushgateway.service
    systemctl daemon-reload
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурации исправлены"
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
echo -e "${CYAN}${ARROW}${NC} Начинаем детальную диагностику..."

# Диагностируем проблемные сервисы
fix_prometheus
fix_pushgateway

# Исправляем конфигурации без аутентификации
fix_configs_no_auth

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
echo -e "  ${CYAN}${ARROW}${NC} Prometheus: без аутентификации"
echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: без аутентификации"
echo -e "  ${CYAN}${ARROW}${NC} Loki: без аутентификации"
