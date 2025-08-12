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

echo -e "${BLUE}${BOLD}🔍 УНИВЕРСАЛЬНАЯ ДИАГНОСТИКА СИСТЕМЫ${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Функция проверки root прав
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${CROSS_MARK}${NC} Этот скрипт должен быть запущен от root"
        exit 1
    fi
}

# Функция диагностики системы
diagnose_system() {
    echo -e "${PURPLE}${BOLD}🔧 ДИАГНОСТИКА СИСТЕМЫ${NC}"
    echo -e "${PURPLE}====================${NC}"
    
    # Проверка блокировки APT
    echo -e "${CYAN}${ARROW}${NC} Проверка блокировки APT..."
    if lsof /var/lib/dpkg/lock-frontend 2>/dev/null; then
        echo -e "  ${RED}${CROSS_MARK}${NC} APT заблокирован"
        echo -e "  ${CYAN}${ARROW}${NC} Процессы APT:"
        ps aux | grep -E "(apt|dpkg)" | grep -v grep || echo "    Процессы не найдены"
    else
        echo -e "  ${GREEN}${CHECK_MARK}${NC} APT не заблокирован"
    fi
    
    # Проверка места на диске
    echo -e "${CYAN}${ARROW}${NC} Проверка места на диске..."
    FREE_SPACE=$(df / | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
    if [ "$FREE_SPACE" -lt 1000000 ] 2>/dev/null; then
        echo -e "  ${RED}${CROSS_MARK}${NC} Мало места (менее 1GB)"
    else
        echo -e "  ${GREEN}${CHECK_MARK}${NC} Достаточно места"
    fi
    df -h / | tail -1
    
    # Проверка памяти
    echo -e "${CYAN}${ARROW}${NC} Проверка памяти..."
    free -h | grep -E "Mem|Swap"
    
    echo ""
}

# Функция диагностики сервисов
diagnose_services() {
    echo -e "${PURPLE}${BOLD}🔧 ДИАГНОСТИКА СЕРВИСОВ${NC}"
    echo -e "${PURPLE}======================${NC}"
    
    local services=("grafana-server" "prometheus" "pushgateway" "loki" "promtail" "fail2ban_exporter" "nginx" "mariadb" "mysql")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $service: АКТИВЕН"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $service: НЕ АКТИВЕН"
        fi
    done
    
    echo ""
}

# Функция диагностики портов
diagnose_ports() {
    echo -e "${PURPLE}${BOLD}🌐 ДИАГНОСТИКА ПОРТОВ${NC}"
    echo -e "${PURPLE}==================${NC}"
    
    local ports=(80 443 8083 3000 9090 9100 3100 9080 9091 9191 3306 22)
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port: ОТКРЫТ"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Порт $port: ЗАКРЫТ"
        fi
    done
    
    echo ""
}

# Функция диагностики процессов
diagnose_processes() {
    echo -e "${PURPLE}${BOLD}🔄 ДИАГНОСТИКА ПРОЦЕССОВ${NC}"
    echo -e "${PURPLE}======================${NC}"
    
    local processes=("grafana-server" "prometheus" "pushgateway" "loki" "promtail" "fail2ban_exporter" "nginx" "mariadb" "mysql")
    
    for process in "${processes[@]}"; do
        if pgrep -f "$process" >/dev/null; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $process: РАБОТАЕТ"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $process: НЕ РАБОТАЕТ"
        fi
    done
    
    echo ""
}

# Функция диагностики файлов
diagnose_files() {
    echo -e "${PURPLE}${BOLD}📁 ДИАГНОСТИКА ФАЙЛОВ${NC}"
    echo -e "${PURPLE}==================${NC}"
    
    local files=(
        "/etc/prometheus/prometheus.yml"
        "/etc/prometheus/web.yml"
        "/etc/pushgateway/web.yml"
        "/etc/loki/loki-config.yaml"
        "/etc/loki/users.yaml"
        "/etc/promtail/promtail-config.yaml"
        "/etc/grafana/grafana.ini"
        "/etc/nftables.conf"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $file: НАЙДЕН"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $file: НЕ НАЙДЕН"
        fi
    done
    
    echo ""
}

# Функция диагностики директорий
diagnose_directories() {
    echo -e "${PURPLE}${BOLD}📂 ДИАГНОСТИКА ДИРЕКТОРИЙ${NC}"
    echo -e "${PURPLE}========================${NC}"
    
    local dirs=(
        "/var/lib/prometheus"
        "/var/lib/loki"
        "/etc/pushgateway"
        "/etc/loki"
        "/etc/promtail"
        "/var/log/grafana"
        "/var/log/prometheus"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $dir: НАЙДЕНА"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $dir: НЕ НАЙДЕНА"
        fi
    done
    
    echo ""
}

# Функция диагностики логов
diagnose_logs() {
    echo -e "${PURPLE}${BOLD}📋 ДИАГНОСТИКА ЛОГОВ${NC}"
    echo -e "${PURPLE}==================${NC}"
    
    local logs=(
        "/var/log/grafana/grafana.log"
        "/var/log/fail2ban.log"
        "/var/log/nginx/error.log"
        "/var/log/nginx/access.log"
    )
    
    for log in "${logs[@]}"; do
        if [ -f "$log" ]; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $log: НАЙДЕН"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $log: НЕ НАЙДЕН"
        fi
    done
    
    echo ""
}

# Функция исправления проблем
fix_issues() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ${NC}"
    echo -e "${PURPLE}====================${NC}"
    
    # Очистка блокировок APT
    echo -e "${CYAN}${ARROW}${NC} Очистка блокировок APT..."
    pkill -f "apt" 2>/dev/null || true
    pkill -f "dpkg" 2>/dev/null || true
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/dpkg/lock* 2>/dev/null || true
    dpkg --configure -a 2>/dev/null || true
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Блокировки очищены"
    
    # Перезапуск проблемных сервисов
    echo -e "${CYAN}${ARROW}${NC} Перезапуск сервисов..."
    local services=("prometheus" "pushgateway" "loki")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl restart "$service" 2>/dev/null || true
            echo -e "  ${CYAN}${ARROW}${NC} $service перезапущен"
        fi
    done
    
    echo ""
}

# Функция показа информации о системе
show_system_info() {
    echo -e "${PURPLE}${BOLD}💻 ИНФОРМАЦИЯ О СИСТЕМЕ${NC}"
    echo -e "${PURPLE}======================${NC}"
    
    echo -e "${CYAN}${ARROW}${NC} ОС: $(lsb_release -d | cut -f2 2>/dev/null || echo 'Неизвестно')"
    echo -e "${CYAN}${ARROW}${NC} Ядро: $(uname -r)"
    echo -e "${CYAN}${ARROW}${NC} Архитектура: $(uname -m)"
    echo -e "${CYAN}${ARROW}${NC} Время работы: $(uptime -p 2>/dev/null || echo 'Неизвестно')"
    echo -e "${CYAN}${ARROW}${NC} IP адрес: $(hostname -I | awk '{print $1}' 2>/dev/null || echo 'Неизвестно')"
    
    echo ""
}

# Функция показа доступных интерфейсов
show_interfaces() {
    echo -e "${PURPLE}${BOLD}🌐 ДОСТУПНЫЕ ИНТЕРФЕЙСЫ${NC}"
    echo -e "${PURPLE}========================${NC}"
    
    local ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'localhost')
    
    
    echo -e "  ${CYAN}${ARROW}${NC} Grafana: http://$ip:3000"
    echo -e "  ${CYAN}${ARROW}${NC} Prometheus: http://$ip:9090"
    echo -e "  ${CYAN}${ARROW}${NC} Loki: http://$ip:3100"
    echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: http://$ip:9091"
    
    echo ""
}

# Основная логика
main() {
    # Проверяем root права
    check_root
    
    # Диагностика системы
    diagnose_system
    
    # Диагностика сервисов
    diagnose_services
    
    # Диагностика портов
    diagnose_ports
    
    # Диагностика процессов
    diagnose_processes
    
    # Диагностика файлов
    diagnose_files
    
    # Диагностика директорий
    diagnose_directories
    
    # Диагностика логов
    diagnose_logs
    
    # Исправление проблем
    fix_issues
    
    # Информация о системе
    show_system_info
    
    # Доступные интерфейсы
    show_interfaces
    
    echo -e "${GREEN}${BOLD}✅ ДИАГНОСТИКА ЗАВЕРШЕНА${NC}"
    echo -e "${GREEN}========================${NC}"
    echo ""
    echo -e "${YELLOW}💡 Рекомендации:${NC}"
    echo -e "  ${CYAN}${ARROW}${NC} Если сервисы не работают, проверьте логи: journalctl -u <service_name>"
    echo -e "  ${CYAN}${ARROW}${NC} Если порты закрыты, запустите: ./firewall_fixed.sh"
    echo -e "  ${CYAN}${ARROW}${NC} Для исправления аутентификации: ./fix_auth.sh"
}

# Запускаем основную функцию
main
