#!/bin/bash
# ============================================================================
# Traffic Connect Server - Менеджер служб
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/main.conf"
source "$PROJECT_ROOT/core/utils/common.sh"

# ============================================================================
# ЦЕНТРАЛИЗОВАННЫЕ ФУНКЦИИ ПРОВЕРКИ СТАТУСА СЛУЖБ
# ============================================================================

# Универсальная функция проверки статуса службы
check_service_status_universal() {
    local service="$1"
    local service_name="${2:-$service}"
    local quiet="${3:-false}"
    
    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            if [ "$quiet" = "false" ]; then
                echo "✅ $service_name - активен"
            fi
            return 0
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            if [ "$quiet" = "false" ]; then
                echo "⚠️ $service_name - неактивен (включен)"
            fi
            return 1
        else
            if [ "$quiet" = "false" ]; then
                echo "❌ $service_name - неактивен (отключен)"
            fi
            return 1
        fi
    else
        if [ "$quiet" = "false" ]; then
            echo "❌ $service_name - не установлен"
        fi
        return 1
    fi
}

# Проверка статуса службы (тихая версия для скриптов)
is_service_active() {
    local service="$1"
    check_service_status_universal "$service" "" "true"
}

# Проверка статуса службы с выводом
is_service_active_verbose() {
    local service="$1"
    local service_name="${2:-$service}"
    check_service_status_universal "$service" "$service_name" "false"
}

# Проверка статуса службы с дополнительными проверками
check_service_status_extended() {
    local service="$1"
    local service_name="${2:-$service}"
    local port="${3:-0}"
    local max_attempts="${4:-5}"
    local attempt=1
    
    log_info "Проверка службы $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            # Если указан порт, проверяем веб-интерфейс
            if [ "$port" -gt 0 ]; then
                if curl -s "http://localhost:$port" >/dev/null 2>&1; then
                    log_ok "Служба $service_name работает (порт $port)"
                    return 0
                else
                    log_info "Попытка $attempt/$max_attempts: Веб-интерфейс недоступен, ожидание..."
                    sleep 2
                fi
            else
                log_ok "Служба $service_name работает"
                return 0
            fi
        else
            log_info "Попытка $attempt/$max_attempts: Служба $service_name не запущена, ожидание..."
            sleep 3
        fi
        attempt=$((attempt + 1))
    done
    
    log_err "Служба $service_name не запустилась после $max_attempts попыток"
    journalctl -u "$service" -n 20 --no-pager
    return 1
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ СЛУЖБАМИ
# ============================================================================

restart_all_services() {
    log_info "Перезапуск всех установленных служб..."
    
    # Список служб для перезапуска
    local services=(
        "ssh"
        "sshd"
        "fail2ban"
        "ufw"
        "nginx"
        "apache2"
        "admin"
        "hestia"
        "grafana-server"
        "prometheus"
        "loki"
        "node_exporter"
        "pushgateway"
        "fail2ban_exporter"
        "promtail"
    )
    
    local restarted_services=()
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service.service"; then
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                log_info "Перезапуск службы: $service"
                if systemctl restart "$service" 2>/dev/null; then
                    restarted_services+=("$service")
                    log_ok "✅ $service перезапущена"
                else
                    failed_services+=("$service")
                    log_warn "⚠️ Ошибка перезапуска $service"
                fi
            elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
                log_info "Запуск службы: $service"
                if systemctl start "$service" 2>/dev/null; then
                    restarted_services+=("$service")
                    log_ok "✅ $service запущена"
                else
                    failed_services+=("$service")
                    log_warn "⚠️ Ошибка запуска $service"
                fi
            fi
        fi
    done
    
    # Специальная обработка для HestiaCP
    if command -v hestia >/dev/null 2>&1; then
        log_info "Перезапуск HestiaCP..."
        if systemctl restart admin 2>/dev/null || systemctl restart hestia 2>/dev/null; then
            log_ok "✅ HestiaCP перезапущен"
        else
            log_warn "⚠️ Ошибка перезапуска HestiaCP"
        fi
    fi
    
    # Отчет о результатах
    log_info "Результаты перезапуска служб:"
    log_info "  Успешно: ${#restarted_services[@]} служб"
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warn "  Ошибки: ${failed_services[*]}"
    fi
}

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ СТАТУСА
# ============================================================================

check_service_status() {
    local service="$1"
    local service_name="${2:-$service}"
    check_service_status_universal "$service" "$service_name" "false"
}

check_all_services() {
    log_info "=== ПРОВЕРКА СТАТУСА СЛУЖБ ==="
    
    local services=(
        "ssh:SSH"
        "sshd:SSH Daemon"
        "fail2ban:Fail2ban"
        "ufw:UFW Firewall"
        "nginx:Nginx"
        "apache2:Apache2"
        "admin:HestiaCP Admin"
        "hestia:HestiaCP"
        "grafana-server:Grafana"
        "prometheus:Prometheus"
        "loki:Loki"
        "node_exporter:Node Exporter"
        "pushgateway:Pushgateway"
        "fail2ban_exporter:Fail2ban Exporter"
        "promtail:Promtail"
    )
    
    local active_count=0
    local total_count=0
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service name <<< "$service_info"
        if check_service_status "$service" "$name"; then
            ((active_count++))
        fi
        ((total_count++))
    done
    
    echo ""
    log_info "Статистика: $active_count/$total_count служб активны"
    
    if [ $active_count -eq $total_count ]; then
        log_ok "Все службы работают корректно"
    else
        log_warn "Некоторые службы требуют внимания"
    fi
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ ОТДЕЛЬНЫМИ СЛУЖБАМИ
# ============================================================================

start_service() {
    local service="$1"
    local service_name="${2:-$service}"
    
    log_info "Запуск службы: $service_name"
    
    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl start "$service" 2>/dev/null; then
            log_ok "✅ $service_name запущена"
            return 0
        else
            log_err "❌ Ошибка запуска $service_name"
            return 1
        fi
    else
        log_err "❌ Служба $service_name не найдена"
        return 1
    fi
}

stop_service() {
    local service="$1"
    local service_name="${2:-$service}"
    
    log_info "Остановка службы: $service_name"
    
    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl stop "$service" 2>/dev/null; then
            log_ok "✅ $service_name остановлена"
            return 0
        else
            log_err "❌ Ошибка остановки $service_name"
            return 1
        fi
    else
        log_err "❌ Служба $service_name не найдена"
        return 1
    fi
}

restart_service() {
    local service="$1"
    local service_name="${2:-$service}"
    
    log_info "Перезапуск службы: $service_name"
    
    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl restart "$service" 2>/dev/null; then
            log_ok "✅ $service_name перезапущена"
            return 0
        else
            log_err "❌ Ошибка перезапуска $service_name"
            return 1
        fi
    else
        log_err "❌ Служба $service_name не найдена"
        return 1
    fi
}

enable_service() {
    local service="$1"
    local service_name="${2:-$service}"
    
    log_info "Включение автозапуска службы: $service_name"
    
    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl enable "$service" 2>/dev/null; then
            log_ok "✅ $service_name включена для автозапуска"
            return 0
        else
            log_err "❌ Ошибка включения $service_name"
            return 1
        fi
    else
        log_err "❌ Служба $service_name не найдена"
        return 1
    fi
}

disable_service() {
    local service="$1"
    local service_name="${2:-$service}"
    
    log_info "Отключение автозапуска службы: $service_name"
    
    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl disable "$service" 2>/dev/null; then
            log_ok "✅ $service_name отключена от автозапуска"
            return 0
        else
            log_err "❌ Ошибка отключения $service_name"
            return 1
        fi
    else
        log_err "❌ Служба $service_name не найдена"
        return 1
    fi
}

# ============================================================================
# ФУНКЦИИ ДИАГНОСТИКИ
# ============================================================================

show_service_logs() {
    local service="$1"
    local lines="${2:-20}"
    local service_name="${3:-$service}"
    
    log_info "Логи службы: $service_name (последние $lines строк)"
    
    if systemctl list-unit-files | grep -q "^$service.service"; then
        journalctl -u "$service" -n "$lines" --no-pager
    else
        log_err "Служба $service_name не найдена"
    fi
}

check_service_ports() {
    log_info "=== ПРОВЕРКА ПОРТОВ СЛУЖБ ==="
    
    local service_ports=(
        "22:SSH"
        "80:HTTP"
        "443:HTTPS"
        "8083:HestiaCP"
        "3000:Grafana"
        "9090:Prometheus"
        "3100:Loki"
        "9100:Node Exporter"
        "9091:Pushgateway"
        "9191:Fail2ban Exporter"
        "9080:Promtail"
    )
    
    for port_info in "${service_ports[@]}"; do
        IFS=':' read -r port service_name <<< "$port_info"
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo "✅ $service_name (порт $port) - активен"
        else
            echo "❌ $service_name (порт $port) - неактивен"
        fi
    done
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
    case "${1:-}" in
        "restart-all")
            restart_all_services
            ;;
        "status")
            check_all_services
            ;;
        "start")
            if [ -z "$2" ]; then
                log_err "Укажите службу для запуска"
                exit 1
            fi
            start_service "$2"
            ;;
        "stop")
            if [ -z "$2" ]; then
                log_err "Укажите службу для остановки"
                exit 1
            fi
            stop_service "$2"
            ;;
        "restart")
            if [ -z "$2" ]; then
                log_err "Укажите службу для перезапуска"
                exit 1
            fi
            restart_service "$2"
            ;;
        "enable")
            if [ -z "$2" ]; then
                log_err "Укажите службу для включения"
                exit 1
            fi
            enable_service "$2"
            ;;
        "disable")
            if [ -z "$2" ]; then
                log_err "Укажите службу для отключения"
                exit 1
            fi
            disable_service "$2"
            ;;
        "logs")
            if [ -z "$2" ]; then
                log_err "Укажите службу для просмотра логов"
                exit 1
            fi
            show_service_logs "$2" "${3:-20}"
            ;;
        "ports")
            check_service_ports
            ;;
        "help"|"")
            echo "Использование: $0 [КОМАНДА] [СЛУЖБА] [ПАРАМЕТРЫ]"
            echo ""
            echo "Команды:"
            echo "  restart-all    - Перезапустить все службы"
            echo "  status         - Показать статус всех служб"
            echo "  start СЛУЖБА   - Запустить службу"
            echo "  stop СЛУЖБА    - Остановить службу"
            echo "  restart СЛУЖБА - Перезапустить службу"
            echo "  enable СЛУЖБА  - Включить автозапуск службы"
            echo "  disable СЛУЖБА - Отключить автозапуск службы"
            echo "  logs СЛУЖБА    - Показать логи службы"
            echo "  ports          - Проверить порты служб"
            echo "  help           - Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0 restart-all"
            echo "  $0 start grafana-server"
            echo "  $0 logs nginx 50"
            ;;
        *)
            log_err "Неизвестная команда: $1"
            echo "Используйте '$0 help' для справки"
            exit 1
            ;;
    esac
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
