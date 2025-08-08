#!/bin/bash
# ============================================================================
# Traffic Connect Server - Менеджер конфигураций
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/main.conf"
source "$PROJECT_ROOT/core/utils/common.sh"

# ============================================================================
# КОНСТАНТЫ
# ============================================================================

CONFIG_BACKUP_DIR="/var/backup/configs"
CONFIG_RESTORE_DIR="/tmp/config_restore"

# ============================================================================
# ФУНКЦИИ РАБОТЫ С КОНФИГУРАЦИЯМИ
# ============================================================================

backup_config() {
    local config_path="$1"
    local backup_name="${2:-$(basename "$config_path")}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ ! -f "$config_path" ] && [ ! -d "$config_path" ]; then
        log_err "Конфигурация не найдена: $config_path"
        return 1
    fi
    
    # Создание директории для бэкапов
    mkdir -p "$CONFIG_BACKUP_DIR"
    
    local backup_file="$CONFIG_BACKUP_DIR/${backup_name}_${timestamp}.tar.gz"
    
    if tar -czf "$backup_file" -C "$(dirname "$config_path")" "$(basename "$config_path")" 2>/dev/null; then
        log_ok "✅ Конфигурация сохранена: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_err "❌ Ошибка создания бэкапа: $config_path"
        return 1
    fi
}

restore_config() {
    local backup_file="$1"
    local target_path="$2"
    
    if [ ! -f "$backup_file" ]; then
        log_err "Файл бэкапа не найден: $backup_file"
        return 1
    fi
    
    # Создание временной директории для восстановления
    mkdir -p "$CONFIG_RESTORE_DIR"
    
    # Распаковка бэкапа
    if tar -xzf "$backup_file" -C "$CONFIG_RESTORE_DIR" 2>/dev/null; then
        # Создание бэкапа текущей конфигурации
        if [ -e "$target_path" ]; then
            backup_config "$target_path" "$(basename "$target_path")_before_restore"
        fi
        
        # Восстановление конфигурации
        local extracted_file="$CONFIG_RESTORE_DIR/$(basename "$target_path")"
        if [ -e "$extracted_file" ]; then
            if cp -r "$extracted_file" "$(dirname "$target_path")/" 2>/dev/null; then
                log_ok "✅ Конфигурация восстановлена: $target_path"
                rm -rf "$CONFIG_RESTORE_DIR"
                return 0
            else
                log_err "❌ Ошибка восстановления: $target_path"
                rm -rf "$CONFIG_RESTORE_DIR"
                return 1
            fi
        else
            log_err "❌ Файл не найден в бэкапе: $(basename "$target_path")"
            rm -rf "$CONFIG_RESTORE_DIR"
            return 1
        fi
    else
        log_err "❌ Ошибка распаковки бэкапа: $backup_file"
        rm -rf "$CONFIG_RESTORE_DIR"
        return 1
    fi
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ КОНФИГУРАЦИЯМИ СЕРВИСОВ
# ============================================================================

backup_all_configs() {
    log_info "=== СОЗДАНИЕ БЭКАПА ВСЕХ КОНФИГУРАЦИЙ ==="
    
    local configs=(
        "/etc/nginx:nginx"
        "/etc/apache2:apache2"
        "/etc/ssh:ssh"
        "/etc/fail2ban:fail2ban"
        "/etc/grafana:grafana"
        "/etc/prometheus:prometheus"
        "/etc/loki:loki"
        "/usr/local/admin:hestia"
        "/usr/local/hestia:hestia_core"
        "/home/*/conf:user_configs"
        "/var/log:logs"
    )
    
    local backup_files=()
    local failed_backups=()
    
    for config_info in "${configs[@]}"; do
        IFS=':' read -r path name <<< "$config_info"
        
        if [ -e "$path" ]; then
            if backup_file=$(backup_config "$path" "$name"); then
                backup_files+=("$backup_file")
            else
                failed_backups+=("$name")
            fi
        else
            log_warn "Конфигурация не найдена: $path"
        fi
    done
    
    # Создание общего бэкапа
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local full_backup="$CONFIG_BACKUP_DIR/full_backup_${timestamp}.tar.gz"
    
    if tar -czf "$full_backup" -C "$CONFIG_BACKUP_DIR" . 2>/dev/null; then
        log_ok "✅ Полный бэкап создан: $full_backup"
        backup_files+=("$full_backup")
    fi
    
    # Отчет
    log_info "Результаты создания бэкапов:"
    log_info "  Успешно: ${#backup_files[@]} бэкапов"
    if [ ${#failed_backups[@]} -gt 0 ]; then
        log_warn "  Ошибки: ${failed_backups[*]}"
    fi
    
    echo "${backup_files[@]}"
}

list_backups() {
    log_info "=== СПИСОК ДОСТУПНЫХ БЭКАПОВ ==="
    
    if [ ! -d "$CONFIG_BACKUP_DIR" ]; then
        log_warn "Директория бэкапов не найдена: $CONFIG_BACKUP_DIR"
        return 1
    fi
    
    local backups=($(find "$CONFIG_BACKUP_DIR" -name "*.tar.gz" -type f | sort))
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_warn "Бэкапы не найдены"
        return 1
    fi
    
    echo "Доступные бэкапы:"
    echo ""
    
    for i in "${!backups[@]}"; do
        local backup="${backups[$i]}"
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1)
        local time=$(stat -c %y "$backup" | cut -d' ' -f2 | cut -d'.' -f1)
        
        printf "%2d) %-40s | %8s | %s %s\n" $((i+1)) "$filename" "$size" "$date" "$time"
    done
    
    echo ""
    log_info "Всего бэкапов: ${#backups[@]}"
}

# ============================================================================
# ФУНКЦИИ ВАЛИДАЦИИ КОНФИГУРАЦИЙ
# ============================================================================

validate_nginx_config() {
    log_info "Проверка конфигурации Nginx..."
    
    if command -v nginx >/dev/null 2>&1; then
        if nginx -t 2>/dev/null; then
            log_ok "✅ Конфигурация Nginx корректна"
            return 0
        else
            log_err "❌ Ошибки в конфигурации Nginx"
            nginx -t
            return 1
        fi
    else
        log_warn "Nginx не установлен"
        return 1
    fi
}

validate_apache_config() {
    log_info "Проверка конфигурации Apache..."
    
    if command -v apache2 >/dev/null 2>&1; then
        if apache2ctl configtest 2>/dev/null; then
            log_ok "✅ Конфигурация Apache корректна"
            return 0
        else
            log_err "❌ Ошибки в конфигурации Apache"
            apache2ctl configtest
            return 1
        fi
    else
        log_warn "Apache не установлен"
        return 1
    fi
}

validate_ssh_config() {
    log_info "Проверка конфигурации SSH..."
    
    if [ -f "/etc/ssh/sshd_config" ]; then
        if sshd -t 2>/dev/null; then
            log_ok "✅ Конфигурация SSH корректна"
            return 0
        else
            log_err "❌ Ошибки в конфигурации SSH"
            sshd -t
            return 1
        fi
    else
        log_warn "Конфигурация SSH не найдена"
        return 1
    fi
}

validate_all_configs() {
    log_info "=== ВАЛИДАЦИЯ ВСЕХ КОНФИГУРАЦИЙ ==="
    
    local validation_results=()
    
    # Проверка веб-серверов
    if validate_nginx_config; then
        validation_results+=("nginx:OK")
    else
        validation_results+=("nginx:ERROR")
    fi
    
    if validate_apache_config; then
        validation_results+=("apache:OK")
    else
        validation_results+=("apache:ERROR")
    fi
    
    # Проверка SSH
    if validate_ssh_config; then
        validation_results+=("ssh:OK")
    else
        validation_results+=("ssh:ERROR")
    fi
    
    # Проверка fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        if fail2ban-client ping 2>/dev/null; then
            log_ok "✅ Fail2ban работает корректно"
            validation_results+=("fail2ban:OK")
        else
            log_err "❌ Ошибки в Fail2ban"
            validation_results+=("fail2ban:ERROR")
        fi
    else
        log_warn "Fail2ban не установлен"
        validation_results+=("fail2ban:NOT_INSTALLED")
    fi
    
    # Отчет
    echo ""
    log_info "Результаты валидации:"
    for result in "${validation_results[@]}"; do
        IFS=':' read -r service status <<< "$result"
        case "$status" in
            "OK")
                echo "✅ $service - корректно"
                ;;
            "ERROR")
                echo "❌ $service - ошибки"
                ;;
            "NOT_INSTALLED")
                echo "⚠️ $service - не установлен"
                ;;
        esac
    done
}

# ============================================================================
# ФУНКЦИИ ОЧИСТКИ
# ============================================================================

cleanup_old_backups() {
    local days="${1:-30}"
    
    log_info "Очистка старых бэкапов (старше $days дней)..."
    
    if [ ! -d "$CONFIG_BACKUP_DIR" ]; then
        log_warn "Директория бэкапов не найдена"
        return 1
    fi
    
    local deleted_count=$(find "$CONFIG_BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$days | wc -l)
    
    if [ "$deleted_count" -gt 0 ]; then
        find "$CONFIG_BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$days -delete
        log_ok "✅ Удалено $deleted_count старых бэкапов"
    else
        log_info "Старые бэкапы не найдены"
    fi
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
    case "${1:-}" in
        "backup")
            case "${2:-}" in
                "all")
                    backup_all_configs
                    ;;
                *)
                    if [ -z "$2" ]; then
                        log_err "Укажите конфигурацию для бэкапа"
                        exit 1
                    fi
                    backup_config "$2" "${3:-}"
                    ;;
            esac
            ;;
        "restore")
            if [ -z "$2" ] || [ -z "$3" ]; then
                log_err "Использование: $0 restore БЭКАП_ФАЙЛ ЦЕЛЕВОЙ_ПУТЬ"
                exit 1
            fi
            restore_config "$2" "$3"
            ;;
        "list")
            list_backups
            ;;
        "validate")
            validate_all_configs
            ;;
        "cleanup")
            cleanup_old_backups "${2:-30}"
            ;;
        "help"|"")
            echo "Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]"
            echo ""
            echo "Команды:"
            echo "  backup all                    - Создать бэкап всех конфигураций"
            echo "  backup ПУТЬ [ИМЯ]            - Создать бэкап конкретной конфигурации"
            echo "  restore БЭКАП_ФАЙЛ ЦЕЛЕВОЙ_ПУТЬ - Восстановить конфигурацию"
            echo "  list                          - Показать список бэкапов"
            echo "  validate                      - Проверить все конфигурации"
            echo "  cleanup [ДНЕЙ]               - Очистить старые бэкапы"
            echo "  help                          - Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0 backup all"
            echo "  $0 backup /etc/nginx nginx_config"
            echo "  $0 restore backup_20231201_120000.tar.gz /etc/nginx"
            echo "  $0 cleanup 7"
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
