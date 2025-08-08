#!/bin/bash
# ============================================================================
# Traffic Connect Server - Главный установщик (Модульная версия 2.0)
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Загрузка конфигурации
source "$PROJECT_ROOT/core/configs/main.conf"

# Загрузка основных утилит
source "$PROJECT_ROOT/core/utils/logger.sh"
source "$PROJECT_ROOT/core/utils/system.sh"

# ============================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================================================

# Состояние установки
INSTALLATION_STARTED=false
INSTALLATION_COMPLETED=false
CURRENT_INSTALL_STAGE=""

# Счетчики установки
INSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()
SKIPPED_COMPONENTS=()

# ============================================================================
# ФУНКЦИЯ ИМПОРТА МОДУЛЕЙ
# ============================================================================

import_module() {
    local module="$1"
    local module_path=""
    
    set_logger_module "module_loader"
    log_debug "Попытка импорта модуля: $module"
    
    case "$module" in
        # Core модули
        "system_check")
            module_path="$PROJECT_ROOT/modules/core/system_check.sh"
            ;;
        "logging")
            module_path="$PROJECT_ROOT/modules/core/logging.sh"
            ;;
        "password_gen")
            module_path="$PROJECT_ROOT/modules/core/password_gen.sh"
            ;;
        "utils")
            module_path="$PROJECT_ROOT/modules/core/utils.sh"
            ;;
        
        # Установщики
        "hestia_install")
            module_path="$PROJECT_ROOT/modules/installers/hestia_install.sh"
            ;;
        "security_install")
            module_path="$PROJECT_ROOT/modules/installers/security_install.sh"
            ;;
        "monitoring_install")
            module_path="$PROJECT_ROOT/modules/installers/monitoring_install.sh"
            ;;
        "templates_install")
            module_path="$PROJECT_ROOT/modules/installers/templates_install.sh"
            ;;
        
        # Менеджеры
        "service_manager")
            module_path="$PROJECT_ROOT/modules/managers/service_manager.sh"
            ;;
        "config_manager")
            module_path="$PROJECT_ROOT/modules/managers/config_manager.sh"
            ;;
        "log_manager")
            module_path="$PROJECT_ROOT/modules/managers/log_manager.sh"
            ;;
        
        # Системные модули
        "security_policy")
            module_path="$PROJECT_ROOT/system/security/security_policy.sh"
            ;;
        "monitoring_policy")
            module_path="$PROJECT_ROOT/system/monitoring/monitoring_policy.sh"
            ;;
        
        # Инструменты
        "diagnostics")
            module_path="$PROJECT_ROOT/modules/tools/diagnostics.sh"
            ;;
        "maintenance")
            module_path="$PROJECT_ROOT/modules/tools/maintenance.sh"
            ;;
        "cleanup")
            module_path="$PROJECT_ROOT/modules/tools/cleanup.sh"
            ;;
        
        *)
            log_err "Неизвестный модуль: $module"
            return 1
            ;;
    esac
    
    if [ -f "$module_path" ]; then
        log_debug "Загрузка модуля: $module_path"
        source "$module_path"
        log_ok "Модуль $module загружен успешно"
        return 0
    else
        log_err "Модуль не найден: $module_path"
        return 1
    fi
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ УСТАНОВКОЙ
# ============================================================================

# Инициализация установки
initialize_installation() {
    set_logger_module "installer"
    log_step "ИНИЦИАЛИЗАЦИЯ УСТАНОВКИ TRAFFIC CONNECT SERVER"
    
    INSTALLATION_STARTED=true
    INSTALLATION_START_TIME=$(date +%s)
    
    # Создание необходимых директорий
    mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "$TEMP_DIR" 2>/dev/null || {
        log_err "Не удалось создать необходимые директории"
        return 1
    }
    
    # Инициализация системы логирования
    setup_logging
    
    # Импорт core модулей
    log_info "Загрузка основных модулей..."
    import_module "system_check"
    import_module "password_gen"
    import_module "utils"
    
    # Проверка системы
    log_info "Проверка совместимости системы..."
    if ! full_system_check; then
        log_err "Система не прошла проверку совместимости"
        return 1
    fi
    
    log_step_complete "Инициализация установки" "installer"
    return 0
}

# Проверка существующей установки
check_existing_installation() {
    set_logger_module "installer"
    log_info "Проверка существующей установки..."
    
    local existing_components=()
    
    # Проверка HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || is_service_active "admin"; then
        existing_components+=("hestia")
        log_info "✅ HestiaCP уже установлен"
    fi
    
    # Проверка мониторинга
    if is_service_active "grafana-server" || is_service_active "prometheus"; then
        existing_components+=("monitoring")
        log_info "✅ Мониторинг уже установлен"
    fi
    
    # Проверка безопасности
    if is_service_active "fail2ban" || is_service_active "ufw"; then
        existing_components+=("security")
        log_info "✅ Компоненты безопасности уже установлены"
    fi
    
    if [ ${#existing_components[@]} -gt 0 ]; then
        log_warn "Обнаружены существующие компоненты: ${existing_components[*]}"
        log_info "Будет выполнена частичная установка/обновление"
        return 0
    else
        log_info "Существующая установка не обнаружена, будет выполнена полная установка"
        return 0
    fi
}

# Установка компонентов
install_components() {
    set_logger_module "installer"
    log_step "УСТАНОВКА КОМПОНЕНТОВ"
    
    local install_order=(
        "hestia_install"
        "security_install"
        "monitoring_install"
        "templates_install"
    )
    
    for component in "${install_order[@]}"; do
        CURRENT_INSTALL_STAGE="$component"
        log_info "Установка компонента: $component"
        
        # Проверка, нужно ли устанавливать компонент
        if should_skip_component "$component"; then
            log_info "Компонент $component пропущен"
            SKIPPED_COMPONENTS+=("$component")
            continue
        fi
        
        # Импорт и установка компонента
        if import_module "$component"; then
            if install_component "$component"; then
                log_ok "Компонент $component установлен успешно"
                INSTALLED_COMPONENTS+=("$component")
            else
                log_err "Ошибка установки компонента $component"
                FAILED_COMPONENTS+=("$component")
                
                # Проверка критичности ошибки
                if is_critical_component "$component"; then
                    log_fatal "Критическая ошибка: компонент $component не установлен"
                    return 1
                fi
            fi
        else
            log_err "Не удалось загрузить модуль $component"
            FAILED_COMPONENTS+=("$component")
        fi
    done
    
    log_step_complete "Установка компонентов" "installer"
    return 0
}

# Проверка необходимости пропуска компонента
should_skip_component() {
    local component="$1"
    
    case "$component" in
        "hestia_install")
            # Пропускаем если HestiaCP уже установлен
            [ -f "/usr/local/admin/bin/admin" ] || is_service_active "admin"
            ;;
        "security_install")
            # Пропускаем если компоненты безопасности уже установлены
            is_service_active "fail2ban" || is_service_active "ufw"
            ;;
        "monitoring_install")
            # Пропускаем если мониторинг уже установлен
            is_service_active "grafana-server" || is_service_active "prometheus"
            ;;
        "templates_install")
            # Шаблоны можно переустанавливать
            false
            ;;
        *)
            false
            ;;
    esac
}

# Проверка критичности компонента
is_critical_component() {
    local component="$1"
    
    case "$component" in
        "hestia_install")
            true  # HestiaCP критичен
            ;;
        *)
            false  # Остальные компоненты не критичны
            ;;
    esac
}

# Установка конкретного компонента
install_component() {
    local component="$1"
    
    case "$component" in
        "hestia_install")
            install_hestia
            ;;
        "security_install")
            setup_security_from_module
            ;;
        "monitoring_install")
            install_monitoring
            ;;
        "templates_install")
            install_templates
            ;;
        *)
            log_err "Неизвестный компонент для установки: $component"
            return 1
            ;;
    esac
}

# Финальная настройка
finalize_installation() {
    set_logger_module "installer"
    log_step "ФИНАЛЬНАЯ НАСТРОЙКА"
    
    # Импорт менеджеров
    log_info "Загрузка менеджеров..."
    import_module "service_manager"
    import_module "config_manager"
    import_module "log_manager"
    
    # Перезапуск всех служб
    log_info "Перезапуск всех установленных служб..."
    restart_all_services
    
    # Валидация установки
    log_info "Валидация установки..."
    validate_installation
    
    # Отображение результатов
    show_installation_summary
    
    # Сохранение учетных данных
    save_all_credentials
    
    # Очистка временных файлов
    cleanup_installation_files
    
    INSTALLATION_COMPLETED=true
    log_step_complete "Финальная настройка" "installer"
}

# Валидация установки
validate_installation() {
    set_logger_module "installer"
    log_info "Валидация установки..."
    
    local validation_passed=true
    
    # Проверка основных служб
    local critical_services=("admin" "nginx" "mysql")
    for service in "${critical_services[@]}"; do
        if is_service_active "$service"; then
            log_ok "Служба $service работает"
        else
            log_warn "Служба $service не работает"
            validation_passed=false
        fi
    done
    
    # Проверка веб-интерфейсов
    local web_interfaces=(
        "http://localhost:8083"  # HestiaCP
        "http://localhost:3000"  # Grafana
        "http://localhost:9090"  # Prometheus
    )
    
    for url in "${web_interfaces[@]}"; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
            log_ok "Веб-интерфейс доступен: $url"
        else
            log_warn "Веб-интерфейс недоступен: $url"
            validation_passed=false
        fi
    done
    
    if [ "$validation_passed" = true ]; then
        log_ok "Валидация установки прошла успешно"
    else
        log_warn "Валидация установки выявила проблемы"
    fi
    
    return $([ "$validation_passed" = true ] && echo 0 || echo 1)
}

# Отображение сводки установки
show_installation_summary() {
    set_logger_module "installer"
    
    echo ""
    echo "🎉 УСТАНОВКА TRAFFIC CONNECT SERVER ЗАВЕРШЕНА!"
    echo "================================================"
    
    # Статистика установки
    echo "📊 СТАТИСТИКА УСТАНОВКИ:"
    echo "  Установлено компонентов: ${#INSTALLED_COMPONENTS[@]}"
    echo "  Пропущено компонентов: ${#SKIPPED_COMPONENTS[@]}"
    echo "  Ошибок установки: ${#FAILED_COMPONENTS[@]}"
    
    if [ ${#INSTALLED_COMPONENTS[@]} -gt 0 ]; then
        echo "  Установленные компоненты: ${INSTALLED_COMPONENTS[*]}"
    fi
    
    if [ ${#SKIPPED_COMPONENTS[@]} -gt 0 ]; then
        echo "  Пропущенные компоненты: ${SKIPPED_COMPONENTS[*]}"
    fi
    
    if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
        echo "  Компоненты с ошибками: ${FAILED_COMPONENTS[*]}"
    fi
    
    echo ""
    
    # Доступы к сервисам
    show_access_credentials
    
    # Время установки
    local end_time=$(date +%s)
    local duration=$((end_time - INSTALLATION_START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo ""
    echo "⏱️ Время установки: ${minutes}м ${seconds}с"
    echo "================================================"
}

# Очистка файлов установки
cleanup_installation_files() {
    set_logger_module "installer"
    log_info "Очистка временных файлов установки..."
    
    local files_to_cleanup=(
        "$INSTALL_STAGE_FILE"
        "$HESTIA_INSTALLED_FLAG"
        "$REBOOT_REQUIRED_FLAG"
        "/tmp/hst-install.sh"
        "/tmp/traffic_connect_*"
    )
    
    for pattern in "${files_to_cleanup[@]}"; do
        rm -f $pattern 2>/dev/null || true
    done
    
    log_ok "Очистка временных файлов завершена"
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ УСТАНОВКИ
# ============================================================================

main_installation() {
    echo "🚀 ЗАПУСК УНИВЕРСАЛЬНОГО УСТАНОВЩИКА TRAFFIC CONNECT SERVER"
    echo "================================================"
    echo "Модульная версия 2.0 - улучшенная архитектура"
    echo "================================================"
    
    # Инициализация
    if ! initialize_installation; then
        log_fatal "Ошибка инициализации установки"
        exit 1
    fi
    
    # Проверка существующей установки
    check_existing_installation
    
    # Проверка, требуется ли перезагрузка
    if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
        log_info "Обнаружен флаг перезагрузки, продолжаем установку..."
        rm -f "$REBOOT_REQUIRED_FLAG"
        
        # Продолжение установки после перезагрузки
        log_step "ПРОДОЛЖЕНИЕ УСТАНОВКИ ПОСЛЕ ПЕРЕЗАГРУЗКИ"
        
        # Импорт и выполнение дополнительных модулей
        import_module "security_install"
        setup_security_from_module
        
        import_module "monitoring_install"
        install_monitoring
        
        import_module "templates_install"
        install_templates
        
    else
        # Полная установка с нуля
        log_info "Начинаем полную установку с нуля..."
        
        # Генерация паролей для всех сервисов
        generate_secure_passwords
        
        # Установка компонентов
        if ! install_components; then
            log_err "Ошибка установки компонентов"
            exit 1
        fi
        
        # Проверка, требуется ли перезагрузка
        if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
            echo ""
            echo "🔄 ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА СИСТЕМЫ"
            echo "================================================"
            echo "HestiaCP установлен успешно. Требуется перезагрузка для завершения установки."
            echo ""
            echo "После перезагрузки скрипт автоматически продолжит установку!"
            echo ""
            
            echo ""
            echo "⚠️ ВНИМАНИЕ: Перезагрузка системы приведет к:"
            echo "   • Завершению всех активных процессов"
            echo "   • Потере несохраненных данных"
            echo "   • Прерыванию текущих операций"
            echo ""
            read -p "Вы уверены, что хотите перезагрузить систему сейчас? (yes/NO): " -r
            if [[ "$REPLY" == "yes" ]]; then
                log_info "Подтверждение получено, перезагрузка системы..."
                echo "Перезагрузка через 10 секунд... Нажмите Ctrl+C для отмены"
                sleep 10
                reboot
            else
                log_info "Перезагрузка отменена пользователем"
                echo ""
                echo "Для продолжения установки перезагрузите систему вручную и запустите скрипт снова"
                echo "Команда для перезагрузки: sudo reboot"
                exit 0
            fi
        fi
    fi
    
    # Финальная настройка
    finalize_installation
    
    echo ""
    echo "🎉 ВСЕ ГОТОВО! Система полностью установлена и настроена."
    echo "================================================"
}

# ============================================================================
# ФУНКЦИИ ОТОБРАЖЕНИЯ ИНФОРМАЦИИ
# ============================================================================

# Отображение данных для входа
show_access_credentials() {
    echo ""
    echo "🌐 ДОСТУПЫ К СЕРВИСАМ:"
    echo "================================================"
    
    local server_ip=$(get_server_ip)
    
    # HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || command -v hestia >/dev/null 2>&1 || is_service_active "admin"; then
        echo "✅ HestiaCP: https://$server_ip:8083"
        echo "   Пользователь: $DEFAULT_ADMIN_USER"
        echo "   Пароль: $HESTIA_PASSWORD"
    fi
    
    # Grafana
    if is_service_active "grafana-server"; then
        echo "✅ Grafana: http://$server_ip:3000"
        echo "   Пользователь: admin"
        echo "   Пароль: $GRAFANA_ADMIN_PASSWORD"
    fi
    
    # Prometheus
    if is_service_active "prometheus"; then
        echo "✅ Prometheus: http://$server_ip:9090"
    fi
    
    # Loki
    if is_service_active "loki"; then
        echo "✅ Loki: http://$server_ip:3100"
    fi
    
    # Node Exporter
    if is_service_active "node_exporter"; then
        echo "✅ Node Exporter: http://$server_ip:9100"
    fi
    
    # Pushgateway
    if is_service_active "pushgateway"; then
        echo "✅ Pushgateway: http://$server_ip:9091"
    fi
    
    # Fail2ban Exporter
    if is_service_active "fail2ban_exporter"; then
        echo "✅ Fail2ban Exporter: http://$server_ip:9191"
    fi
    
    echo ""
}

# Сохранение всех учетных данных в файл
save_all_credentials() {
    local server_ip=$(get_server_ip)
    
    log_info "Сохранение всех учетных данных в файл: $CREDENTIALS_FILE"
    
    cat > "$CREDENTIALS_FILE" << EOF
===============================================
TRAFFIC CONNECT SERVER - УЧЕТНЫЕ ДАННЫЕ
===============================================
Дата создания: $(date)
IP сервера: $server_ip
Версия: $PROJECT_VERSION
===============================================

🌐 ДОСТУПЫ К СЕРВИСАМ:
===============================================

EOF

    # HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || command -v hestia >/dev/null 2>&1 || is_service_active "admin"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ HestiaCP: https://$server_ip:8083
   Пользователь: $DEFAULT_ADMIN_USER
   Пароль: $HESTIA_PASSWORD

EOF
    fi

    # Grafana
    if is_service_active "grafana-server"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ Grafana: http://$server_ip:3000
   Пользователь: admin
   Пароль: $GRAFANA_ADMIN_PASSWORD

EOF
    fi

    # Prometheus
    if is_service_active "prometheus"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ Prometheus: http://$server_ip:9090
   Пользователь: $PROMETHEUS_USERNAME
   Пароль: $PROMETHEUS_PASSWORD

EOF
    fi

    # Loki
    if is_service_active "loki"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ Loki: http://$server_ip:3100
   Пользователь: $LOKI_USERNAME
   Пароль: $LOKI_PASSWORD

EOF
    fi

    # Node Exporter
    if is_service_active "node_exporter"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ Node Exporter: http://$server_ip:9100
   Пользователь: $NODE_EXPORTER_USERNAME
   Пароль: $NODE_EXPORTER_PASSWORD

EOF
    fi

    # Pushgateway
    if is_service_active "pushgateway"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ Pushgateway: http://$server_ip:9091
   Пользователь: $PUSHGATEWAY_USERNAME
   Пароль: $PUSHGATEWAY_PASSWORD

EOF
    fi

    # Fail2ban Exporter
    if is_service_active "fail2ban_exporter"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ Fail2ban Exporter: http://$server_ip:9191
   Пользователь: $FAIL2BAN_EXPORTER_USERNAME
   Пароль: $FAIL2BAN_EXPORTER_PASSWORD

EOF
    fi

    cat >> "$CREDENTIALS_FILE" << EOF
🔧 SSH доступ:
   ssh root@$server_ip

🔐 ВСЕ СГЕНЕРИРОВАННЫЕ ПАРОЛИ:
===============================================
EOF

    if [ -n "$HESTIA_PASSWORD" ]; then
        echo "HestiaCP: $HESTIA_PASSWORD" >> "$CREDENTIALS_FILE"
    fi
    
    if [ -n "$GRAFANA_ADMIN_PASSWORD" ]; then
        echo "Grafana Admin: $GRAFANA_ADMIN_PASSWORD" >> "$CREDENTIALS_FILE"
    fi
    
    if [ -n "$PROMETHEUS_PASSWORD" ]; then
        echo "Prometheus: $PROMETHEUS_PASSWORD" >> "$CREDENTIALS_FILE"
    fi
    
    if [ -n "$LOKI_PASSWORD" ]; then
        echo "Loki: $LOKI_PASSWORD" >> "$CREDENTIALS_FILE"
    fi
    
    if [ -n "$NODE_EXPORTER_PASSWORD" ]; then
        echo "Node Exporter: $NODE_EXPORTER_PASSWORD" >> "$CREDENTIALS_FILE"
    fi
    
    if [ -n "$PUSHGATEWAY_PASSWORD" ]; then
        echo "Pushgateway: $PUSHGATEWAY_PASSWORD" >> "$CREDENTIALS_FILE"
    fi
    
    if [ -n "$FAIL2BAN_EXPORTER_PASSWORD" ]; then
        echo "Fail2ban Exporter: $FAIL2BAN_EXPORTER_PASSWORD" >> "$CREDENTIALS_FILE"
    fi
    
    if [ -n "$ROOT_SSH_PASSWORD" ]; then
        echo "Root SSH: $ROOT_SSH_PASSWORD" >> "$CREDENTIALS_FILE"
    else
        echo "Root SSH: не изменялся" >> "$CREDENTIALS_FILE"
    fi

    cat >> "$CREDENTIALS_FILE" << EOF

===============================================
EOF

    # Устанавливаем безопасные права доступа
    chmod 600 "$CREDENTIALS_FILE"
    
    log_ok "Учетные данные сохранены в файл: $CREDENTIALS_FILE"
    echo "📄 Все учетные данные сохранены в: $CREDENTIALS_FILE"
}

# ============================================================================
# ЗАПУСК
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Проверка аргументов командной строки
    case "${1:-}" in
        --install)
            main_installation
            ;;
        --help|"")
            echo "🚀 Traffic Connect Server - ГЛАВНЫЙ УСТАНОВЩИК (Модульная версия 2.0)"
            echo "================================================"
            echo ""
            echo "ИСПОЛЬЗОВАНИЕ:"
            echo "  ./install.sh [ОПЦИЯ]"
            echo ""
            echo "ОПЦИИ:"
            echo "  --install     Запуск полной установки"
            echo "  --help        Показать эту справку"
            echo ""
            echo "ПРИМЕРЫ:"
            echo "  ./install.sh --install"
            echo "  ./install.sh --help"
            echo ""
            echo "ВЕРСИЯ: $PROJECT_VERSION"
            echo "================================================"
            ;;
        *)
            echo "❌ Неизвестная опция: $1"
            echo "Используйте --help для получения справки"
            exit 1
            ;;
    esac
fi
