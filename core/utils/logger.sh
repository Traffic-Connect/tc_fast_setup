#!/bin/bash
# ============================================================================
# Traffic Connect Server - Система логирования
# ============================================================================

# Загрузка конфигурации
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    source "$PROJECT_ROOT/core/configs/main.conf"
fi

# ============================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ЛОГИРОВАНИЯ
# ============================================================================

# Инициализация системы логирования
LOGGER_INITIALIZED=false
LOGGER_MODULE=""
LOGGER_START_TIME=$(date +%s)

# Счетчики логов
LOG_COUNTERS=(
    ["DEBUG"]=0
    ["INFO"]=0
    ["WARN"]=0
    ["ERROR"]=0
    ["FATAL"]=0
)

# ============================================================================
# ФУНКЦИИ ИНИЦИАЛИЗАЦИИ
# ============================================================================

# Инициализация системы логирования
setup_logging() {
    if [ "$LOGGER_INITIALIZED" = true ]; then
        return 0
    fi
    
    log_debug "Инициализация системы логирования..."
    
    # Создание директорий для логов
    mkdir -p "$LOG_DIR" "$TEMP_DIR" 2>/dev/null || {
        echo "❌ Не удалось создать директории для логов"
        return 1
    }
    
    # Установка прав доступа
    chmod 755 "$LOG_DIR" 2>/dev/null || true
    chmod 755 "$TEMP_DIR" 2>/dev/null || true
    
    # Очистка старых логов если они слишком большие
    cleanup_old_logs
    
    # Создание файлов логов если они не существуют
    touch "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG" "$JSON_LOG" 2>/dev/null || true
    
    # Установка прав доступа для файлов логов
    chmod 644 "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG" "$JSON_LOG" 2>/dev/null || true
    
    LOGGER_INITIALIZED=true
    log_info "Система логирования инициализирована"
}

# Очистка старых логов
cleanup_old_logs() {
    local max_size_mb=100  # Максимальный размер лога в MB
    local max_size_bytes=$((max_size_mb * 1024 * 1024))
    
    for log_file in "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG" "$JSON_LOG"; do
        if [ -f "$log_file" ] && [ $(stat -c%s "$log_file" 2>/dev/null || echo 0) -gt $max_size_bytes ]; then
            log_info "Ротация лога: $log_file"
            mv "$log_file" "${log_file}.old" 2>/dev/null || true
            touch "$log_file" 2>/dev/null || true
        fi
    done
}

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

# Основная функция логирования
_log_message() {
    local level="$1"
    local message="$2"
    local module="${3:-$LOGGER_MODULE}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local timestamp_iso=$(date -Iseconds)
    
    # Проверка уровня логирования
    local level_num
    case "$level" in
        "DEBUG") level_num=$LOG_LEVEL_DEBUG ;;
        "INFO")  level_num=$LOG_LEVEL_INFO ;;
        "WARN")  level_num=$LOG_LEVEL_WARN ;;
        "ERROR") level_num=$LOG_LEVEL_ERROR ;;
        "FATAL") level_num=$LOG_LEVEL_FATAL ;;
        *)       level_num=$LOG_LEVEL_INFO ;;
    esac
    
    # Проверка, нужно ли логировать
    if [ $level_num -lt $CURRENT_LOG_LEVEL ]; then
        return 0
    fi
    
    # Увеличение счетчика
    ((LOG_COUNTERS[$level]++))
    
    # Форматирование сообщения для текстового лога
    local text_message="$timestamp [$level]"
    if [ -n "$module" ]; then
        text_message="$text_message [$module]"
    fi
    text_message="$text_message $message"
    
    # Форматирование сообщения для JSON лога
    local json_message=$(printf '{"timestamp":"%s","level":"%s","message":"%s","module":"%s"}' \
        "$timestamp_iso" "$level" "$(echo "$message" | sed 's/"/\\"/g')" "$module")
    
    # Запись в соответствующие файлы
    case "$level" in
        "DEBUG")
            if [ "$ENABLE_DEBUG_LOGGING" = true ]; then
                echo "$text_message" >> "$DEBUG_LOG"
                echo "$json_message" >> "$JSON_LOG"
            fi
            ;;
        "ERROR"|"FATAL")
            echo "$text_message" >> "$ERROR_LOG"
            echo "$text_message" >> "$LOG_FILE"
            echo "$json_message" >> "$JSON_LOG"
            ;;
        *)
            echo "$text_message" >> "$LOG_FILE"
            if [ "$ENABLE_JSON_LOGGING" = true ]; then
                echo "$json_message" >> "$JSON_LOG"
            fi
            ;;
    esac
    
    # Вывод в консоль с цветами
    _print_colored_message "$level" "$message" "$module"
}

# Вывод цветного сообщения в консоль
_print_colored_message() {
    local level="$1"
    local message="$2"
    local module="$3"
    
    local color=""
    local prefix=""
    
    case "$level" in
        "DEBUG")
            color="$CYAN"
            prefix="🔍"
            ;;
        "INFO")
            color="$GREEN"
            prefix="ℹ️"
            ;;
        "WARN")
            color="$YELLOW"
            prefix="⚠️"
            ;;
        "ERROR")
            color="$RED"
            prefix="❌"
            ;;
        "FATAL")
            color="$RED$BOLD"
            prefix="💥"
            ;;
        *)
            color="$WHITE"
            prefix="📝"
            ;;
    esac
    
    local output="$prefix $message"
    if [ -n "$module" ]; then
        output="[$module] $output"
    fi
    
    echo -e "${color}${output}${NC}"
}

# ============================================================================
# ПУБЛИЧНЫЕ ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

# Логирование отладочной информации
log_debug() {
    _log_message "DEBUG" "$1" "$2"
}

# Логирование общей информации
log_info() {
    _log_message "INFO" "$1" "$2"
}

# Логирование предупреждений
log_warn() {
    _log_message "WARN" "$1" "$2"
}

# Логирование ошибок
log_err() {
    _log_message "ERROR" "$1" "$2"
}

# Логирование критических ошибок
log_fatal() {
    _log_message "FATAL" "$1" "$2"
}

# Логирование успешных операций
log_ok() {
    _log_message "INFO" "✅ $1" "$2"
}

# Логирование шагов установки
log_step() {
    echo ""
    echo "================================================"
    echo "🚀 $1"
    echo "================================================"
    _log_message "INFO" "НАЧАЛО ЭТАПА: $1" "$2"
}

# Логирование завершения этапа
log_step_complete() {
    local step="$1"
    local module="$2"
    echo "✅ ЭТАП ЗАВЕРШЕН: $step"
    echo "================================================"
    _log_message "INFO" "ЭТАП ЗАВЕРШЕН: $step" "$module"
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ МОДУЛЯМИ
# ============================================================================

# Установка текущего модуля
set_logger_module() {
    LOGGER_MODULE="$1"
    log_debug "Установлен модуль логирования: $1"
}

# Получение текущего модуля
get_logger_module() {
    echo "$LOGGER_MODULE"
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ УРОВНЯМИ ЛОГИРОВАНИЯ
# ============================================================================

# Установка уровня логирования
set_log_level() {
    local level="$1"
    case "$level" in
        "DEBUG") CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        "INFO")  CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        "WARN")  CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        "ERROR") CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        "FATAL") CURRENT_LOG_LEVEL=$LOG_LEVEL_FATAL ;;
        *)       log_warn "Неизвестный уровень логирования: $level" ;;
    esac
    log_info "Уровень логирования установлен: $level"
}

# Получение текущего уровня логирования
get_log_level() {
    case "$CURRENT_LOG_LEVEL" in
        $LOG_LEVEL_DEBUG) echo "DEBUG" ;;
        $LOG_LEVEL_INFO)  echo "INFO" ;;
        $LOG_LEVEL_WARN)  echo "WARN" ;;
        $LOG_LEVEL_ERROR) echo "ERROR" ;;
        $LOG_LEVEL_FATAL) echo "FATAL" ;;
        *)               echo "UNKNOWN" ;;
    esac
}

# ============================================================================
# ФУНКЦИИ СТАТИСТИКИ И АНАЛИЗА
# ============================================================================

# Получение статистики логов
get_log_stats() {
    echo ""
    echo "📊 СТАТИСТИКА ЛОГОВ:"
    echo "================================================"
    
    if [ -f "$LOG_FILE" ]; then
        local total_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
        echo "Общее количество записей: $total_lines"
        
        for level in "DEBUG" "INFO" "WARN" "ERROR" "FATAL"; do
            local count=${LOG_COUNTERS[$level]}
            echo "$level: $count"
        done
        
        echo ""
        echo "Размеры файлов логов:"
        for log_file in "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG" "$JSON_LOG"; do
            if [ -f "$log_file" ]; then
                local size=$(du -h "$log_file" | cut -f1)
                echo "  $(basename "$log_file"): $size"
            fi
        done
    else
        echo "Файлы логов не найдены"
    fi
    
    echo "================================================"
}

# Поиск в логах
search_logs() {
    local pattern="$1"
    local log_type="${2:-main}"
    local lines="${3:-50}"
    
    local search_file=""
    case "$log_type" in
        "main")   search_file="$LOG_FILE" ;;
        "error")  search_file="$ERROR_LOG" ;;
        "debug")  search_file="$DEBUG_LOG" ;;
        "json")   search_file="$JSON_LOG" ;;
        *)        search_file="$LOG_FILE" ;;
    esac
    
    if [ ! -f "$search_file" ]; then
        log_err "Файл лога не найден: $search_file"
        return 1
    fi
    
    echo ""
    echo "🔍 ПОИСК В ЛОГАХ ($log_type):"
    echo "================================================"
    echo "Паттерн: $pattern"
    echo "Файл: $search_file"
    echo "================================================"
    
    if [ -n "$pattern" ]; then
        grep -i "$pattern" "$search_file" | tail -n "$lines" || {
            echo "Совпадения не найдены"
        }
    else
        tail -n "$lines" "$search_file"
    fi
    
    echo "================================================"
}

# Очистка логов
cleanup_logs() {
    local days="${1:-7}"
    
    log_info "Очистка логов старше $days дней..."
    
    # Создание бэкапа перед очисткой
    local backup_file="$BACKUP_DIR/logs_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    
    if tar -czf "$backup_file" -C "$(dirname "$LOG_DIR")" "$(basename "$LOG_DIR")" 2>/dev/null; then
        log_info "Создан бэкап логов: $backup_file"
    fi
    
    # Очистка старых логов
    find "$LOG_DIR" -name "*.log" -mtime +$days -delete 2>/dev/null || true
    find "$LOG_DIR" -name "*.old" -mtime +$days -delete 2>/dev/null || true
    
    log_info "Очистка логов завершена"
}

# ============================================================================
# ФУНКЦИИ ЭКСПОРТА И ИМПОРТА
# ============================================================================

# Экспорт логов в JSON
export_logs_json() {
    local output_file="$1"
    if [ -z "$output_file" ]; then
        output_file="$LOG_DIR/logs_export_$(date +%Y%m%d_%H%M%S).json"
    fi
    
    log_info "Экспорт логов в JSON: $output_file"
    
    if [ -f "$JSON_LOG" ]; then
        cp "$JSON_LOG" "$output_file" 2>/dev/null || {
            log_err "Не удалось экспортировать логи"
            return 1
        }
        log_ok "Логи экспортированы: $output_file"
    else
        log_warn "JSON лог не найден"
    fi
}

# Экспорт логов в CSV
export_logs_csv() {
    local output_file="$1"
    if [ -z "$output_file" ]; then
        output_file="$LOG_DIR/logs_export_$(date +%Y%m%d_%H%M%S).csv"
    fi
    
    log_info "Экспорт логов в CSV: $output_file"
    
    # Заголовок CSV
    echo "timestamp,level,message,module" > "$output_file"
    
    # Конвертация JSON в CSV
    if [ -f "$JSON_LOG" ]; then
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Простой парсинг JSON (можно улучшить)
                local timestamp=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
                local level=$(echo "$line" | grep -o '"level":"[^"]*"' | cut -d'"' -f4)
                local message=$(echo "$line" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
                local module=$(echo "$line" | grep -o '"module":"[^"]*"' | cut -d'"' -f4)
                
                echo "$timestamp,$level,$message,$module" >> "$output_file"
            fi
        done < "$JSON_LOG"
        
        log_ok "Логи экспортированы в CSV: $output_file"
    else
        log_warn "JSON лог не найден"
    fi
}

# ============================================================================
# ФУНКЦИИ ДИАГНОСТИКИ
# ============================================================================

# Проверка состояния системы логирования
check_logger_health() {
    echo ""
    echo "🔍 ДИАГНОСТИКА СИСТЕМЫ ЛОГИРОВАНИЯ:"
    echo "================================================"
    
    # Проверка инициализации
    if [ "$LOGGER_INITIALIZED" = true ]; then
        echo "✅ Система логирования инициализирована"
    else
        echo "❌ Система логирования не инициализирована"
    fi
    
    # Проверка директорий
    if [ -d "$LOG_DIR" ]; then
        echo "✅ Директория логов существует: $LOG_DIR"
    else
        echo "❌ Директория логов не существует: $LOG_DIR"
    fi
    
    # Проверка файлов логов
    for log_file in "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG" "$JSON_LOG"; do
        if [ -f "$log_file" ]; then
            local size=$(du -h "$log_file" | cut -f1)
            local writable=""
            if [ -w "$log_file" ]; then
                writable="✅"
            else
                writable="❌"
            fi
            echo "$writable $(basename "$log_file"): $size"
        else
            echo "❌ $(basename "$log_file"): не найден"
        fi
    done
    
    # Проверка уровня логирования
    echo "📊 Текущий уровень логирования: $(get_log_level)"
    
    # Проверка счетчиков
    echo "📈 Счетчики логов:"
    for level in "DEBUG" "INFO" "WARN" "ERROR" "FATAL"; do
        local count=${LOG_COUNTERS[$level]}
        echo "  $level: $count"
    done
    
    echo "================================================"
}

# ============================================================================
# АВТОМАТИЧЕСКАЯ ИНИЦИАЛИЗАЦИЯ
# ============================================================================

# Автоматическая инициализация при загрузке модуля
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Если скрипт запущен напрямую
    setup_logging
    check_logger_health
else
    # Если скрипт загружен через source
    setup_logging
fi
