#!/bin/bash

# Подключаем модули
source "$(dirname "$0")/core/colors.sh"
source "$(dirname "$0")/core/utils.sh"

print_header "🔍 УНИВЕРСАЛЬНАЯ ДИАГНОСТИКА СИСТЕМЫ"

# Проверяем root права
check_root

# Функция диагностики системы
diagnose_system() {
    print_header "🔧 ДИАГНОСТИКА СИСТЕМЫ"
    
    # Проверка блокировки APT
    log_message "INFO" "Проверка блокировки APT..."
    if lsof /var/lib/dpkg/lock-frontend 2>/dev/null; then
        log_message "ERROR" "APT заблокирован"
        log_message "INFO" "Процессы APT:"
        ps aux | grep -E "(apt|dpkg)" | grep -v grep || log_message "WARNING" "Процессы не найдены"
    else
        log_message "SUCCESS" "APT не заблокирован"
    fi
    
    # Проверка места на диске
    log_message "INFO" "Проверка места на диске..."
    FREE_SPACE=$(df / | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
    if [ "$FREE_SPACE" -lt 1000000 ] 2>/dev/null; then
        log_message "ERROR" "Мало места (менее 1GB)"
    else
        log_message "SUCCESS" "Достаточно места"
    fi
    df -h / | tail -1
    
    # Проверка памяти
    log_message "INFO" "Проверка памяти..."
    free -h | grep -E "Mem|Swap"
}

# Функция диагностики сервисов
diagnose_services() {
    print_header "🔧 ДИАГНОСТИКА СЕРВИСОВ"
    
    local services=("grafana-server" "prometheus" "pushgateway" "loki" "promtail" "fail2ban_exporter" "nginx" "mariadb" "mysql")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "SUCCESS" "$service: АКТИВЕН"
        else
            log_message "ERROR" "$service: НЕ АКТИВЕН"
        fi
    done
}

# Функция диагностики портов
diagnose_ports() {
    print_header "🌐 ДИАГНОСТИКА ПОРТОВ"
    
    local ports=(80 443 8083 3000 9090 9100 3100 9080 9091 9191 3306 22)
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_message "SUCCESS" "Порт $port: ОТКРЫТ"
        else
            log_message "ERROR" "Порт $port: ЗАКРЫТ"
        fi
    done
}

# Функция диагностики процессов
diagnose_processes() {
    print_header "🔄 ДИАГНОСТИКА ПРОЦЕССОВ"
    
    local processes=("grafana" "prometheus" "node_exporter" "pushgateway" "loki" "promtail" "nginx" "mysql" "mariadb")
    
    for process in "${processes[@]}"; do
        if pgrep -x "$process" >/dev/null 2>&1; then
            log_message "SUCCESS" "$process: ЗАПУЩЕН"
        else
            log_message "ERROR" "$process: НЕ ЗАПУЩЕН"
        fi
    done
}

# Функция диагностики файлов
diagnose_files() {
    print_header "📁 ДИАГНОСТИКА ФАЙЛОВ"
    
    local files=(
        "/etc/grafana/grafana.ini"
        "/etc/prometheus/prometheus.yml"
        "/etc/loki/loki-config.yaml"
        "/etc/promtail/promtail-config.yaml"
        "/etc/fail2ban/jail.local"
        "/etc/nginx/nginx.conf"
        "/etc/mysql/my.cnf"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_message "SUCCESS" "$file: СУЩЕСТВУЕТ"
        else
            log_message "ERROR" "$file: НЕ СУЩЕСТВУЕТ"
        fi
    done
}

# Функция диагностики логов
diagnose_logs() {
    print_header "📋 ДИАГНОСТИКА ЛОГОВ"
    
    local log_files=(
        "/var/log/grafana/grafana.log"
        "/var/log/prometheus/"
        "/var/log/loki/"
        "/var/log/promtail/"
        "/var/log/fail2ban.log"
        "/var/log/nginx/error.log"
        "/var/log/mysql/error.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ] || [ -d "$log_file" ]; then
            log_message "SUCCESS" "$log_file: СУЩЕСТВУЕТ"
        else
            log_message "ERROR" "$log_file: НЕ СУЩЕСТВУЕТ"
        fi
    done
}

# Функция диагностики сети
diagnose_network() {
    print_header "🌐 ДИАГНОСТИКА СЕТИ"
    
    # Проверка интернет-соединения
    log_message "INFO" "Проверка интернет-соединения..."
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_message "SUCCESS" "Интернет-соединение: РАБОТАЕТ"
    else
        log_message "ERROR" "Интернет-соединение: НЕ РАБОТАЕТ"
    fi
    
    # Проверка DNS
    log_message "INFO" "Проверка DNS..."
    if nslookup google.com >/dev/null 2>&1; then
        log_message "SUCCESS" "DNS: РАБОТАЕТ"
    else
        log_message "ERROR" "DNS: НЕ РАБОТАЕТ"
    fi
    
    # IP адрес
    log_message "INFO" "IP адрес: $(get_server_ip)"
}

# Функция диагностики безопасности
diagnose_security() {
    print_header "🛡️ ДИАГНОСТИКА БЕЗОПАСНОСТИ"
    
    # Проверка Fail2Ban
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        log_message "SUCCESS" "Fail2Ban: АКТИВЕН"
        # Показываем заблокированные IP
        local banned_ips=$(fail2ban-client status sshd 2>/dev/null | grep "Total banned" | awk '{print $4}' || echo "0")
        log_message "INFO" "Заблокированных IP: $banned_ips"
    else
        log_message "ERROR" "Fail2Ban: НЕ АКТИВЕН"
    fi
    
    # Проверка файрвола
    if command -v nft >/dev/null 2>&1; then
        if systemctl is-active --quiet nftables 2>/dev/null; then
            log_message "SUCCESS" "nftables: АКТИВЕН"
        else
            log_message "ERROR" "nftables: НЕ АКТИВЕН"
        fi
    elif command -v iptables >/dev/null 2>&1; then
        if iptables -L >/dev/null 2>&1; then
            log_message "SUCCESS" "iptables: АКТИВЕН"
        else
            log_message "ERROR" "iptables: НЕ АКТИВЕН"
        fi
    else
        log_message "ERROR" "Файрвол не найден"
    fi
}

# Функция диагностики производительности
diagnose_performance() {
    print_header "⚡ ДИАГНОСТИКА ПРОИЗВОДИТЕЛЬНОСТИ"
    
    # CPU
    log_message "INFO" "CPU загрузка:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
    
    # Память
    log_message "INFO" "Использование памяти:"
    free -h | grep -E "Mem|Swap"
    
    # Диск
    log_message "INFO" "Использование диска:"
    df -h /
    
    # Температура (если доступно)
    if command -v sensors >/dev/null 2>&1; then
        log_message "INFO" "Температура CPU:"
        sensors | grep -E "Core|temp" | head -3
    fi
}

# Функция генерации отчета
generate_report() {
    print_header "📊 ГЕНЕРАЦИЯ ОТЧЕТА"
    
    local report_file="/tmp/tc_diagnostic_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== ОТЧЕТ ДИАГНОСТИКИ TC FAST SETUP ==="
        echo "Дата: $(date)"
        echo "Система: $(uname -a)"
        echo "IP адрес: $(get_server_ip)"
        echo ""
        
        echo "=== СИСТЕМА ==="
        df -h /
        free -h
        echo ""
        
        echo "=== СЕРВИСЫ ==="
        systemctl status grafana-server prometheus node_exporter pushgateway loki promtail fail2ban_exporter 2>/dev/null
        echo ""
        
        echo "=== ПОРТЫ ==="
        netstat -tlnp | grep -E ':(80|443|8083|3000|9090|9100|3100|9080|9091|9191)'
        echo ""
        
        echo "=== ЛОГИ ==="
        tail -20 /var/log/grafana/grafana.log 2>/dev/null || echo "Логи Grafana недоступны"
        echo ""
        tail -20 /var/log/prometheus/ 2>/dev/null || echo "Логи Prometheus недоступны"
        
    } > "$report_file"
    
    log_message "SUCCESS" "Отчет сохранен: $report_file"
    log_message "INFO" "Для просмотра: cat $report_file"
}

# Главная функция
main() {
    log_message "INFO" "Начало диагностики системы..."
    
    # Выполняем все проверки
    diagnose_system
    diagnose_services
    diagnose_ports
    diagnose_processes
    diagnose_files
    diagnose_logs
    diagnose_network
    diagnose_security
    diagnose_performance
    
    # Генерируем отчет
    generate_report
    
    print_header "🎉 ДИАГНОСТИКА ЗАВЕРШЕНА"
    log_message "SUCCESS" "Диагностика завершена успешно!"
    log_message "INFO" "Проверьте отчет выше для детальной информации"
}

# Запуск главной функции
main "$@"
