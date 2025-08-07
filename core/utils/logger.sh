#!/bin/bash
# ============================================================================
# Traffic Connect Server - Система логирования
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/configuration.sh"

# ============================================================================
# КОНСТАНТЫ ЛОГИРОВАНИЯ
# ============================================================================

# LOG_DIR определен в core/configs/configuration.sh
LOG_FILE="$LOG_DIR/traffic_connect.log"
ERROR_LOG_FILE="$LOG_DIR/error.log"
DEBUG_LOG_FILE="$LOG_DIR/debug.log"
JSON_LOG_FILE="$LOG_DIR/traffic_connect.json"

# Цвета для вывода (импортируются из configuration.sh)
# RED, GREEN, YELLOW, BLUE, NC определены в core/configs/configuration.sh
# PURPLE и CYAN используются только в этом файле
PURPLE='\033[0;35m'
CYAN='\033[0;36m'

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[Инфо]${NC} $message" | tee -a "$LOG_FILE"
    
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        log_json "INFO" "$message"
    fi
}

log_ok() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[OK]${NC} $message" | tee -a "$LOG_FILE"
    
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        log_json "SUCCESS" "$message"
    fi
}

log_warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $message" | tee -a "$LOG_FILE"
    
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        log_json "WARNING" "$message"
    fi
}

log_err() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ОШИБКА]${NC} $message" | tee -a "$LOG_FILE" "$ERROR_LOG_FILE"
    
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        log_json "ERROR" "$message"
    fi
}

log_step() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${PURPLE}[ЭТАП]${NC} $message" | tee -a "$LOG_FILE"
    
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        log_json "STEP" "$message"
    fi
}

log_debug() {
    local message="$1"
    
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${CYAN}[DEBUG]${NC} $message" | tee -a "$DEBUG_LOG_FILE"
        
        if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
            log_json "DEBUG" "$message"
        fi
    fi
}

# ============================================================================
# JSON ЛОГИРОВАНИЕ
# ============================================================================

log_json() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    local script_name="${BASH_SOURCE[1]:-unknown}"
    local line_number="${BASH_LINENO[0]:-0}"
    
    # Создание JSON записи
    local json_record=$(cat << EOF
{
  "timestamp": "$timestamp",
  "level": "$level",
  "message": "$message",
  "script": "$(basename "$script_name")",
  "line": $line_number,
  "pid": $$
}
EOF
)
    
    echo "$json_record" >> "$JSON_LOG_FILE"
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ ЛОГАМИ
# ============================================================================

setup_logging() {
    # Создание директории для логов
    mkdir -p "$LOG_DIR"
    
    # Создание файлов логов если не существуют
    touch "$LOG_FILE" "$ERROR_LOG_FILE" "$DEBUG_LOG_FILE"
    
    # Установка прав доступа
    chmod 644 "$LOG_FILE" "$ERROR_LOG_FILE" "$DEBUG_LOG_FILE"
    chown root:root "$LOG_FILE" "$ERROR_LOG_FILE" "$DEBUG_LOG_FILE"
    
    # Создание JSON лога если включен
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        touch "$JSON_LOG_FILE"
        chmod 644 "$JSON_LOG_FILE"
        chown root:root "$JSON_LOG_FILE"
    fi
    
    # Очистка старых логов
    cleanup_old_logs
    
    log_info "Система логирования инициализирована"
}

cleanup_old_logs() {
    local retention_days="${LOG_RETENTION_DAYS:-7}"
    
    log_info "Очистка старых логов (старше $retention_days дней)..."
    
    # Очистка основных логов
    find "$LOG_DIR" -name "*.log" -mtime +$retention_days -delete 2>/dev/null || true
    
    # Очистка JSON логов
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        find "$LOG_DIR" -name "*.json" -mtime +$retention_days -delete 2>/dev/null || true
    fi
    
    log_info "Очистка логов завершена"
}

# ============================================================================
# ФУНКЦИИ ПРОСМОТРА ЛОГОВ
# ============================================================================

show_logs() {
    local log_type="${1:-main}"
    local lines="${2:-50}"
    
    case "$log_type" in
        "main"|"")
            if [ -f "$LOG_FILE" ]; then
                log_info "Последние $lines строк основного лога:"
                tail -n "$lines" "$LOG_FILE"
            else
                log_warn "Основной лог не найден"
            fi
            ;;
        "error")
            if [ -f "$ERROR_LOG_FILE" ]; then
                log_info "Последние $lines строк лога ошибок:"
                tail -n "$lines" "$ERROR_LOG_FILE"
            else
                log_warn "Лог ошибок не найден"
            fi
            ;;
        "debug")
            if [ -f "$DEBUG_LOG_FILE" ]; then
                log_info "Последние $lines строк отладочного лога:"
                tail -n "$lines" "$DEBUG_LOG_FILE"
            else
                log_warn "Отладочный лог не найден"
            fi
            ;;
        "json")
            if [ -f "$JSON_LOG_FILE" ]; then
                log_info "Последние $lines строк JSON лога:"
                tail -n "$lines" "$JSON_LOG_FILE"
            else
                log_warn "JSON лог не найден"
            fi
            ;;
        *)
            log_err "Неизвестный тип лога: $log_type"
            return 1
            ;;
    esac
}

search_logs() {
    local pattern="$1"
    local log_type="${2:-main}"
    local lines="${3:-100}"
    
    if [ -z "$pattern" ]; then
        log_err "Укажите паттерн для поиска"
        return 1
    fi
    
    local target_file=""
    case "$log_type" in
        "main"|"")
            target_file="$LOG_FILE"
            ;;
        "error")
            target_file="$ERROR_LOG_FILE"
            ;;
        "debug")
            target_file="$DEBUG_LOG_FILE"
            ;;
        "json")
            target_file="$JSON_LOG_FILE"
            ;;
        *)
            log_err "Неизвестный тип лога: $log_type"
            return 1
            ;;
    esac
    
    if [ -f "$target_file" ]; then
        log_info "Поиск '$pattern' в логе $log_type:"
        grep -i "$pattern" "$target_file" | tail -n "$lines"
    else
        log_warn "Лог $log_type не найден"
    fi
}

# ============================================================================
# ФУНКЦИИ СТАТИСТИКИ ЛОГОВ
# ============================================================================

get_log_stats() {
    log_info "=== СТАТИСТИКА ЛОГОВ ==="
    
    if [ -f "$LOG_FILE" ]; then
        local total_lines=$(wc -l < "$LOG_FILE")
        local error_count=$(grep -c "\[ОШИБКА\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local warning_count=$(grep -c "\[ВНИМАНИЕ\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local success_count=$(grep -c "\[OK\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local info_count=$(grep -c "\[Инфо\]" "$LOG_FILE" 2>/dev/null || echo "0")
        
        echo "Основной лог ($LOG_FILE):"
        echo "  Всего записей: $total_lines"
        echo "  Ошибок: $error_count"
        echo "  Предупреждений: $warning_count"
        echo "  Успешных операций: $success_count"
        echo "  Информационных: $info_count"
    else
        echo "Основной лог не найден"
    fi
    
    if [ -f "$ERROR_LOG_FILE" ]; then
        local error_lines=$(wc -l < "$ERROR_LOG_FILE")
        echo "Лог ошибок ($ERROR_LOG_FILE):"
        echo "  Записей: $error_lines"
    fi
    
    if [ -f "$DEBUG_LOG_FILE" ]; then
        local debug_lines=$(wc -l < "$DEBUG_LOG_FILE")
        echo "Отладочный лог ($DEBUG_LOG_FILE):"
        echo "  Записей: $debug_lines"
    fi
    
    if [ -f "$JSON_LOG_FILE" ]; then
        local json_lines=$(wc -l < "$JSON_LOG_FILE")
        echo "JSON лог ($JSON_LOG_FILE):"
        echo "  Записей: $json_lines"
    fi
}

# ============================================================================
# ФУНКЦИИ ЭКСПОРТА ЛОГОВ
# ============================================================================

export_logs() {
    local output_file="$1"
    local log_type="${2:-all}"
    local days="${3:-7}"
    
    if [ -z "$output_file" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        output_file="/tmp/traffic_connect_logs_${timestamp}.tar.gz"
    fi
    
    # Создание временной директории
    local temp_dir="/tmp/log_export_$$"
    mkdir -p "$temp_dir"
    
    case "$log_type" in
        "all")
            # Экспорт всех логов
            if [ -f "$LOG_FILE" ]; then
                cp "$LOG_FILE" "$temp_dir/"
            fi
            if [ -f "$ERROR_LOG_FILE" ]; then
                cp "$ERROR_LOG_FILE" "$temp_dir/"
            fi
            if [ -f "$DEBUG_LOG_FILE" ]; then
                cp "$DEBUG_LOG_FILE" "$temp_dir/"
            fi
            if [ -f "$JSON_LOG_FILE" ]; then
                cp "$JSON_LOG_FILE" "$temp_dir/"
            fi
            ;;
        "main")
            if [ -f "$LOG_FILE" ]; then
                cp "$LOG_FILE" "$temp_dir/"
            fi
            ;;
        "error")
            if [ -f "$ERROR_LOG_FILE" ]; then
                cp "$ERROR_LOG_FILE" "$temp_dir/"
            fi
            ;;
        "debug")
            if [ -f "$DEBUG_LOG_FILE" ]; then
                cp "$DEBUG_LOG_FILE" "$temp_dir/"
            fi
            ;;
        "json")
            if [ -f "$JSON_LOG_FILE" ]; then
                cp "$JSON_LOG_FILE" "$temp_dir/"
            fi
            ;;
        *)
            log_err "Неизвестный тип лога: $log_type"
            rm -rf "$temp_dir"
            return 1
            ;;
    esac
    
    # Создание архива
    if tar -czf "$output_file" -C "$temp_dir" . 2>/dev/null; then
        log_ok "Логи экспортированы в: $output_file"
        rm -rf "$temp_dir"
        return 0
    else
        log_err "Ошибка создания архива логов"
        rm -rf "$temp_dir"
        return 1
    fi
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
    case "${1:-}" in
        "setup")
            setup_logging
            ;;
        "show")
            show_logs "${2:-main}" "${3:-50}"
            ;;
        "search")
            search_logs "${2:-}" "${3:-main}" "${4:-100}"
            ;;
        "stats")
            get_log_stats
            ;;
        "export")
            export_logs "${2:-}" "${3:-all}" "${4:-7}"
            ;;
        "cleanup")
            cleanup_old_logs
            ;;
        "help"|"")
            echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
            echo ""
            echo "Команды:"
            echo "  setup                    - Инициализация системы логирования"
            echo "  show [ТИП] [СТРОКИ]     - Показать логи (main/error/debug/json)"
            echo "  search ПАТТЕРН [ТИП] [СТРОКИ] - Поиск в логах"
            echo "  stats                    - Статистика логов"
            echo "  export [ФАЙЛ] [ТИП] [ДНИ] - Экспорт логов"
            echo "  cleanup                  - Очистка старых логов"
            echo "  help                     - Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0 setup"
            echo "  $0 show error 100"
            echo "  $0 search 'ошибка' main 50"
            echo "  $0 export /tmp/logs.tar.gz all 7"
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
