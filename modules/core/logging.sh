#!/bin/bash
# ============================================================================
# Traffic Connect Server - Модуль системы логирования
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# ============================================================================
# КОНСТАНТЫ ЛОГИРОВАНИЯ
# ============================================================================

LOG_DIR="/var/log/install"
LOG_FILE="$LOG_DIR/traffic_connect.log"
ERROR_LOG="$LOG_DIR/error.log"
JSON_LOG="$LOG_DIR/traffic_connect.json"

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

# Инициализация системы логирования
setup_logging() {
    # Создание директории логов
    mkdir -p "$LOG_DIR"
    
    # Создание файлов логов
    touch "$LOG_FILE" "$ERROR_LOG" "$JSON_LOG"
    
    # Установка прав доступа
    chmod 644 "$LOG_FILE" "$ERROR_LOG" "$JSON_LOG"
    
    # Очистка старых логов (старше 7 дней)
    find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    log_info "Система логирования инициализирована"
}

# Функция логирования с уровнем INFO
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[Инфо] $message" | tee -a "$LOG_FILE"
    log_to_json "INFO" "$message"
}

# Функция логирования с уровнем OK
log_ok() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[OK] $message" | tee -a "$LOG_FILE"
    log_to_json "OK" "$message"
}

# Функция логирования с уровнем WARNING
log_warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[ВНИМАНИЕ] $message" | tee -a "$LOG_FILE"
    log_to_json "WARNING" "$message"
}

# Функция логирования с уровнем ERROR
log_err() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[ОШИБКА] $message" | tee -a "$LOG_FILE" "$ERROR_LOG"
    log_to_json "ERROR" "$message"
}

# Функция логирования этапов
log_step() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[ЭТАП] $message" | tee -a "$LOG_FILE"
    log_to_json "STEP" "$message"
}

# Логирование в JSON формат
log_to_json() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    # Создание JSON записи
    local json_record=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level",
  "message": "$message",
  "script": "${BASH_SOURCE[1]:-unknown}",
  "line": "${BASH_LINENO[0]:-0}"
}
EOF
)
    
    # Добавление в JSON лог
    echo "$json_record" >> "$JSON_LOG"
}

# Функция для показа логов
show_logs() {
    local log_type="${1:-main}"
    local lines="${2:-50}"
    
    case "$log_type" in
        "main")
            tail -n "$lines" "$LOG_FILE"
            ;;
        "error")
            tail -n "$lines" "$ERROR_LOG"
            ;;
        "json")
            tail -n "$lines" "$JSON_LOG"
            ;;
        "all")
            echo "=== ОСНОВНОЙ ЛОГ ==="
            tail -n "$lines" "$LOG_FILE"
            echo ""
            echo "=== ЛОГ ОШИБОК ==="
            tail -n "$lines" "$ERROR_LOG"
            ;;
        *)
            echo "Неизвестный тип лога: $log_type"
            echo "Доступные типы: main, error, json, all"
            ;;
    esac
}

# Функция поиска в логах
search_logs() {
    local pattern="$1"
    local log_type="${2:-main}"
    local lines="${3:-100}"
    
    if [ -z "$pattern" ]; then
        echo "Укажите паттерн для поиска"
        return 1
    fi
    
    case "$log_type" in
        "main")
            grep -i "$pattern" "$LOG_FILE" | tail -n "$lines"
            ;;
        "error")
            grep -i "$pattern" "$ERROR_LOG" | tail -n "$lines"
            ;;
        "all")
            grep -i "$pattern" "$LOG_FILE" "$ERROR_LOG" | tail -n "$lines"
            ;;
        *)
            echo "Неизвестный тип лога: $log_type"
            ;;
    esac
}

# Функция статистики логов
log_statistics() {
    echo "📊 СТАТИСТИКА ЛОГОВ"
    echo "================================================"
    
    if [ -f "$LOG_FILE" ]; then
        local total_lines=$(wc -l < "$LOG_FILE")
        local info_count=$(grep -c "\[Инфо\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local ok_count=$(grep -c "\[OK\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local warn_count=$(grep -c "\[ВНИМАНИЕ\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local error_count=$(grep -c "\[ОШИБКА\]" "$LOG_FILE" 2>/dev/null || echo "0")
        
        echo "Основной лог: $total_lines строк"
        echo "  INFO: $info_count"
        echo "  OK: $ok_count"
        echo "  WARNING: $warn_count"
        echo "  ERROR: $error_count"
    fi
    
    if [ -f "$ERROR_LOG" ]; then
        local error_lines=$(wc -l < "$ERROR_LOG")
        echo "Лог ошибок: $error_lines строк"
    fi
    
    if [ -f "$JSON_LOG" ]; then
        local json_lines=$(wc -l < "$JSON_LOG")
        echo "JSON лог: $json_lines записей"
    fi
}

# Функция очистки логов
cleanup_logs() {
    local days="${1:-7}"
    
    log_info "Очистка логов старше $days дней..."
    
    find "$LOG_DIR" -name "*.log" -mtime +"$days" -delete 2>/dev/null || true
    
    log_ok "Очистка логов завершена"
}

# ============================================================================
# ЭКСПОРТ ФУНКЦИЙ
# ============================================================================

export -f setup_logging
export -f log_info
export -f log_ok
export -f log_warn
export -f log_err
export -f log_step
export -f log_to_json
export -f show_logs
export -f search_logs
export -f log_statistics
export -f cleanup_logs
