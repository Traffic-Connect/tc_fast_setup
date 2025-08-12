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

echo -e "${BLUE}${BOLD}🔍 ДИАГНОСТИКА И ИСПРАВЛЕНИЕ СЕРВИСОВ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Функция проверки и исправления сервиса
fix_service() {
    local service_name="$1"
    local display_name="$2"
    local config_file="$3"
    local listen_address="$4"
    
    echo -e "${CYAN}${ARROW}${NC} Диагностика $display_name..."
    
    # Проверяем статус сервиса
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Сервис $service_name: АКТИВЕН"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} Сервис $service_name: НЕ АКТИВЕН"
        echo -e "  ${CYAN}${ARROW}${NC} Запуск сервиса..."
        if systemctl start "$service_name" 2>/dev/null; then
            echo -e "    ${GREEN}${CHECK_MARK}${NC} Сервис запущен"
        else
            echo -e "    ${RED}${CROSS_MARK}${NC} Ошибка запуска"
            return 1
        fi
    fi
    
    # Проверяем конфигурацию если указан файл
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурация найдена"
        
        # Исправляем listen address если указан
        if [ -n "$listen_address" ]; then
            echo -e "  ${CYAN}${ARROW}${NC} Проверка listen address..."
            if grep -q "listen.*127.0.0.1\|listen.*localhost" "$config_file" 2>/dev/null; then
                echo -e "  ${YELLOW}⚠️ Сервис слушает только localhost${NC}"
                echo -e "  ${CYAN}${ARROW}${NC} Изменение на $listen_address..."
                
                # Создаем резервную копию
                cp "$config_file" "$config_file.backup"
                
                # Заменяем localhost на 0.0.0.0
                sed -i 's/listen.*127\.0\.0\.1/listen 0.0.0.0/g' "$config_file" 2>/dev/null
                sed -i 's/listen.*localhost/listen 0.0.0.0/g' "$config_file" 2>/dev/null
                
                echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурация обновлена"
                
                # Перезапускаем сервис
                echo -e "  ${CYAN}${ARROW}${NC} Перезапуск сервиса..."
                systemctl restart "$service_name" 2>/dev/null
            else
                echo -e "  ${GREEN}${CHECK_MARK}${NC} Listen address корректный"
            fi
        fi
    fi
    
    echo ""
}

# Проверяем и исправляем Grafana
echo -e "${PURPLE}${BOLD}📊 ИСПРАВЛЕНИЕ GRAFANA${NC}"
echo -e "${PURPLE}====================${NC}"
fix_service "grafana-server" "Grafana" "/etc/grafana/grafana.ini" "0.0.0.0:3000"

# Проверяем и исправляем Prometheus
echo -e "${PURPLE}${BOLD}📈 ИСПРАВЛЕНИЕ PROMETHEUS${NC}"
echo -e "${PURPLE}======================${NC}"
fix_service "prometheus" "Prometheus" "/etc/prometheus/prometheus.yml" "0.0.0.0:9090"

# Проверяем и исправляем Node Exporter
echo -e "${PURPLE}${BOLD}🖥️ ИСПРАВЛЕНИЕ NODE EXPORTER${NC}"
echo -e "${PURPLE}========================${NC}"
fix_service "node_exporter" "Node Exporter"

# Проверяем и исправляем Pushgateway
echo -e "${PURPLE}${BOLD}📤 ИСПРАВЛЕНИЕ PUSHGATEWAY${NC}"
echo -e "${PURPLE}======================${NC}"
fix_service "pushgateway" "Pushgateway"

# Проверяем и исправляем Loki
echo -e "${PURPLE}${BOLD}📝 ИСПРАВЛЕНИЕ LOKI${NC}"
echo -e "${PURPLE}==================${NC}"
fix_service "loki" "Loki" "/etc/loki/loki-config.yaml" "0.0.0.0:3100"

# Проверяем и исправляем Promtail
echo -e "${PURPLE}${BOLD}📤 ИСПРАВЛЕНИЕ PROMTAIL${NC}"
echo -e "${PURPLE}======================${NC}"
fix_service "promtail" "Promtail" "/etc/promtail/promtail-config.yaml" "0.0.0.0:9080"

# Проверяем и исправляем Fail2ban Exporter
echo -e "${PURPLE}${BOLD}🛡️ ИСПРАВЛЕНИЕ FAIL2BAN EXPORTER${NC}"
echo -e "${PURPLE}============================${NC}"
fix_service "fail2ban_exporter" "Fail2ban Exporter"

# Проверяем NGINX
echo -e "${PURPLE}${BOLD}🌐 ИСПРАВЛЕНИЕ NGINX${NC}"
echo -e "${PURPLE}==================${NC}"
fix_service "nginx" "NGINX" "/etc/nginx/sites-available/default" "0.0.0.0:80"

# Проверяем MariaDB/MySQL
echo -e "${PURPLE}${BOLD}🗄️ ИСПРАВЛЕНИЕ БАЗЫ ДАННЫХ${NC}"
echo -e "${PURPLE}========================${NC}"
fix_service "mariadb" "MariaDB" "/etc/mysql/mariadb.conf.d/50-server.cnf" "0.0.0.0:3306"

# Проверяем Hestia CP
echo -e "${PURPLE}${BOLD}🌐 ИСПРАВЛЕНИЕ HESTIA CP${NC}"
echo -e "${PURPLE}======================${NC}"
fix_service "hestia" "Hestia CP"

echo -e "${PURPLE}${BOLD}🌐 ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ${NC}"
echo -e "${PURPLE}========================${NC}"

# Ждем немного для запуска сервисов
echo -e "${CYAN}${ARROW}${NC} Ожидание запуска сервисов..."
sleep 5

# Проверяем открытые порты
echo -e "${CYAN}${ARROW}${NC} Открытые порты:"
netstat -tlnp 2>/dev/null | grep -E ":(80|443|3000|8083|9090|9100|3100|9080|9091|9191|3306|22)" | while read line; do
    echo -e "  ${GREEN}${CHECK_MARK}${NC} $line"
done

echo ""

# Проверяем процессы
echo -e "${PURPLE}${BOLD}🔍 ПРОВЕРКА ПРОЦЕССОВ${NC}"
echo -e "${PURPLE}====================${NC}"

PROCESSES=("grafana-server" "prometheus" "node_exporter" "pushgateway" "loki" "promtail" "fail2ban_exporter" "nginx" "mariadb" "mysql")

for process in "${PROCESSES[@]}"; do
    if pgrep -f "$process" >/dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $process: РАБОТАЕТ"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} $process: НЕ РАБОТАЕТ"
    fi
done

echo ""

# Проверяем systemd сервисы
echo -e "${PURPLE}${BOLD}🔧 ПРОВЕРКА SYSTEMD СЕРВИСОВ${NC}"
echo -e "${PURPLE}============================${NC}"

SERVICES=("grafana-server" "prometheus" "node_exporter" "pushgateway" "loki" "promtail" "fail2ban_exporter" "nginx" "mariadb" "mysql" "hestia")

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $service: АКТИВЕН"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} $service: НЕ АКТИВЕН"
    fi
done

echo ""

echo -e "${GREEN}${BOLD}✅ ДИАГНОСТИКА ЗАВЕРШЕНА${NC}"
echo -e "${GREEN}========================${NC}"
echo ""
echo -e "${YELLOW}💡 Если порты все еще закрыты, попробуйте:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} systemctl status <service_name> - для просмотра ошибок"
echo -e "  ${CYAN}${ARROW}${NC} journalctl -u <service_name> - для просмотра логов"
echo -e "  ${CYAN}${ARROW}${NC} netstat -tlnp | grep <port> - для проверки портов"
echo ""
echo -e "${BLUE}🌐 Доступные веб-интерфейсы:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Hestia CP: https://$(hostname -I | awk '{print $1}'):8083"
echo -e "  ${CYAN}${ARROW}${NC} Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo -e "  ${CYAN}${ARROW}${NC} Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo -e "  ${CYAN}${ARROW}${NC} Loki: http://$(hostname -I | awk '{print $1}'):3100"
