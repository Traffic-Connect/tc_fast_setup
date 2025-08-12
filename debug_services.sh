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

echo -e "${BLUE}${BOLD}🔍 ДЕТАЛЬНАЯ ДИАГНОСТИКА ПРОБЛЕМНЫХ СЕРВИСОВ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Функция диагностики сервиса
debug_service() {
    local service_name="$1"
    local display_name="$2"
    
    echo -e "${PURPLE}${BOLD}🔍 ДИАГНОСТИКА $display_name${NC}"
    echo -e "${PURPLE}========================${NC}"
    
    # Проверяем статус сервиса
    echo -e "${CYAN}${ARROW}${NC} Статус сервиса:"
    systemctl status "$service_name" --no-pager -l
    
    echo ""
    
    # Проверяем логи сервиса
    echo -e "${CYAN}${ARROW}${NC} Последние логи сервиса:"
    journalctl -u "$service_name" --no-pager -l -n 20
    
    echo ""
    
    # Проверяем конфигурационные файлы
    echo -e "${CYAN}${ARROW}${NC} Проверка конфигурации:"
    
    case "$service_name" in
        "prometheus")
            if [ -f "/etc/prometheus/prometheus.yml" ]; then
                echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурация найдена"
                echo -e "  ${CYAN}${ARROW}${NC} Содержимое /etc/prometheus/prometheus.yml:"
                cat /etc/prometheus/prometheus.yml
            else
                echo -e "  ${RED}${CROSS_MARK}${NC} Конфигурация не найдена"
            fi
            ;;
        "pushgateway")
            if [ -f "/etc/systemd/system/pushgateway.service" ]; then
                echo -e "  ${GREEN}${CHECK_MARK}${NC} Service файл найден"
                echo -e "  ${CYAN}${ARROW}${NC} Содержимое service файла:"
                cat /etc/systemd/system/pushgateway.service
            else
                echo -e "  ${RED}${CROSS_MARK}${NC} Service файл не найден"
            fi
            ;;
        "loki")
            if [ -f "/etc/loki/loki-config.yaml" ]; then
                echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурация найдена"
                echo -e "  ${CYAN}${ARROW}${NC} Содержимое /etc/loki/loki-config.yaml:"
                cat /etc/loki/loki-config.yaml
            else
                echo -e "  ${RED}${CROSS_MARK}${NC} Конфигурация не найдена"
            fi
            ;;
    esac
    
    echo ""
    
    # Пробуем запустить сервис вручную
    echo -e "${CYAN}${ARROW}${NC} Попытка запуска сервиса:"
    if systemctl start "$service_name" 2>&1; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Сервис запущен успешно"
        sleep 2
        if systemctl is-active --quiet "$service_name"; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Сервис активен"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Сервис не активен после запуска"
        fi
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Ошибка запуска сервиса"
    fi
    
    echo ""
    echo -e "${BLUE}${BOLD}==========================================${NC}"
    echo ""
}

# Диагностируем проблемные сервисы
debug_service "prometheus" "PROMETHEUS"
debug_service "pushgateway" "PUSHGATEWAY"
debug_service "loki" "LOKI"

# Проверяем общие проблемы
echo -e "${PURPLE}${BOLD}🔧 ОБЩИЕ ПРОВЕРКИ${NC}"
echo -e "${PURPLE}================${NC}"

# Проверяем права доступа
echo -e "${CYAN}${ARROW}${NC} Проверка прав доступа:"
echo -e "  ${CYAN}${ARROW}${NC} Пользователь prometheus:"
id prometheus 2>/dev/null || echo -e "    ${RED}${CROSS_MARK}${NC} Пользователь не найден"

echo -e "  ${CYAN}${ARROW}${NC} Пользователь pushgateway:"
id pushgateway 2>/dev/null || echo -e "    ${RED}${CROSS_MARK}${NC} Пользователь не найден"

echo -e "  ${CYAN}${ARROW}${NC} Пользователь loki:"
id loki 2>/dev/null || echo -e "    ${RED}${CROSS_MARK}${NC} Пользователь не найден"

echo ""

# Проверяем директории
echo -e "${CYAN}${ARROW}${NC} Проверка директорий:"
for dir in "/var/lib/prometheus" "/etc/pushgateway" "/var/lib/loki"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $dir: найдена"
        ls -la "$dir"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} $dir: не найдена"
    fi
done

echo ""

# Проверяем бинарные файлы
echo -e "${CYAN}${ARROW}${NC} Проверка бинарных файлов:"
for binary in "/usr/local/bin/prometheus" "/usr/local/bin/pushgateway" "/usr/local/bin/loki"; do
    if [ -f "$binary" ]; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $binary: найден"
        ls -la "$binary"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} $binary: не найден"
    fi
done

echo ""

# Проверяем открытые порты
echo -e "${CYAN}${ARROW}${NC} Проверка открытых портов:"
netstat -tlnp 2>/dev/null | grep -E ":(9090|9091|3100)" | while read line; do
    echo -e "  ${GREEN}${CHECK_MARK}${NC} $line"
done

echo ""

echo -e "${GREEN}${BOLD}✅ ДИАГНОСТИКА ЗАВЕРШЕНА${NC}"
echo -e "${GREEN}========================${NC}"
echo ""
echo -e "${YELLOW}💡 Рекомендации:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Если сервисы не запускаются, проверьте логи выше"
echo -e "  ${CYAN}${ARROW}${NC} Убедитесь, что все зависимости установлены"
echo -e "  ${CYAN}${ARROW}${NC} Проверьте права доступа к файлам и директориям"
echo -e "  ${CYAN}${ARROW}${NC} Убедитесь, что порты не заняты другими процессами"
