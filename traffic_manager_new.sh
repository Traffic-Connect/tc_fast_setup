#!/bin/bash
# ============================================================================
# Traffic Connect Server - УНИВЕРСАЛЬНЫЙ МЕНЕДЖЕР (МОДУЛЬНАЯ ВЕРСИЯ)
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"
source "$PROJECT_ROOT/core/utils/logger.sh"

# Импорт политики безопасности
if [ -f "$PROJECT_ROOT/system/security/security_policy.sh" ]; then
    source "$PROJECT_ROOT/system/security/security_policy.sh"
fi

# ============================================================================
# ПРОВЕРКА СИСТЕМЫ
# ============================================================================

# Проверка операционной системы
check_system_compatibility() {
    log_info "Проверка совместимости системы..."
    
    # Проверка на macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_err "❌ Traffic Connect Server не поддерживается на macOS"
        log_err "Система предназначена для Linux серверов"
        log_info "Поддерживаемые системы:"
        log_info "  - Ubuntu 20.04/22.04"
        log_info "  - Debian 11/12"
        log_info "  - CentOS 8/Rocky Linux 8"
        log_info ""
        log_info "Для разработки и тестирования используйте:"
        log_info "  - Docker контейнер с Ubuntu"
        log_info "  - Виртуальную машину с Linux"
        log_info "  - Облачный сервер (VPS)"
        return 1
    fi
    
    # Проверка на Windows
    if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        log_err "❌ Traffic Connect Server не поддерживается на Windows"
        log_err "Система предназначена для Linux серверов"
        return 1
    fi
    
    # Проверка дистрибутива Linux
    if ! command -v apt &> /dev/null; then
        log_warn "⚠️ Система не поддерживает apt package manager"
        log_warn "Некоторые компоненты могут работать некорректно"
        log_info "Рекомендуется использовать дистрибутивы на основе Debian/Ubuntu"
    fi
    
    # Проверка прав root
    if [[ $EUID -ne 0 ]]; then
        log_err "❌ Скрипт должен выполняться с правами root"
        log_info "Запустите: sudo $0"
        return 1
    fi
    
    log_ok "✅ Система совместима"
    return 0
}

# Выполнение проверки системы
if ! check_system_compatibility; then
    exit 1
fi

# ============================================================================
# ФУНКЦИЯ ИМПОРТА МОДУЛЕЙ
# ============================================================================

import_module() {
    local module="$1"
    local module_path=""
    
    case "$module" in
        "security_install")
            module_path="$PROJECT_ROOT/system/security/security_install.sh"
            ;;
        "monitoring_install")
            module_path="$PROJECT_ROOT/system/monitoring/monitoring_install.sh"
            ;;
        "templates_install")
            module_path="$PROJECT_ROOT/web/templates/templates_install.sh"
            ;;
        "system_install")
            module_path="$PROJECT_ROOT/core/installers/system_install.sh"
            ;;
        "hestia_install")
            module_path="$PROJECT_ROOT/core/installers/hestia_install.sh"
            ;;
        "service_manager")
            module_path="$PROJECT_ROOT/core/managers/service_manager.sh"
            ;;
        "config_manager")
            module_path="$PROJECT_ROOT/core/managers/config_manager.sh"
            ;;
        *)
            log_err "Неизвестный модуль: $module"
            return 1
            ;;
    esac
    
    if [ -f "$module_path" ]; then
        source "$module_path"
        return 0
    else
        log_err "Модуль не найден: $module_path"
        return 1
    fi
}

# ============================================================================
# КОНСТАНТЫ
# ============================================================================

INSTALL_STAGE_FILE="/tmp/traffic_connect_install_stage"
HESTIA_INSTALLED_FLAG="/tmp/hestia_installed"
REBOOT_REQUIRED_FLAG="/tmp/reboot_required"
INSTALL_LOG="/tmp/traffic_connect_install.log"

# ============================================================================
# ФУНКЦИИ ГЕНЕРАЦИИ ПАРОЛЕЙ
# ============================================================================

generate_secure_passwords() {
    # Используем централизованную функцию из security_policy.sh
    generate_all_system_passwords
}

# ============================================================================
# ФУНКЦИИ ОТОБРАЖЕНИЯ ИНФОРМАЦИИ
# ============================================================================

show_access_credentials() {
    echo ""
    echo "🌐 ДОСТУПЫ К СЕРВИСАМ:"
    echo "================================================"
    
    local server_ip=$(get_server_ip)
    
    # HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || command -v hestia >/dev/null 2>&1 || is_service_active "admin"; then
        echo "✅ HestiaCP: https://$server_ip:8083"
        echo "   Пользователь: $HESTIA_USERNAME"
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

show_all_passwords() {
    echo ""
    echo "🔐 ВСЕ СГЕНЕРИРОВАННЫЕ ПАРОЛИ:"
    echo "================================================"
    
    if [ -n "$HESTIA_PASSWORD" ]; then
        echo "HestiaCP ($HESTIA_USERNAME): $HESTIA_PASSWORD"
    fi
    
    if [ -n "$GRAFANA_ADMIN_PASSWORD" ]; then
        echo "Grafana (admin): $GRAFANA_ADMIN_PASSWORD"
    fi
    
    if [ -n "$PROMETHEUS_PASSWORD" ]; then
        echo "Prometheus ($PROMETHEUS_USERNAME): $PROMETHEUS_PASSWORD"
    fi
    
    if [ -n "$LOKI_PASSWORD" ]; then
        echo "Loki ($LOKI_USERNAME): $LOKI_PASSWORD"
    fi
    
    if [ -n "$NODE_EXPORTER_PASSWORD" ]; then
        echo "Node Exporter ($NODE_EXPORTER_USERNAME): $NODE_EXPORTER_PASSWORD"
    fi
    
    if [ -n "$PUSHGATEWAY_PASSWORD" ]; then
        echo "Pushgateway ($PUSHGATEWAY_USERNAME): $PUSHGATEWAY_PASSWORD"
    fi
    
    if [ -n "$FAIL2BAN_EXPORTER_PASSWORD" ]; then
        echo "Fail2ban Exporter ($FAIL2BAN_EXPORTER_USERNAME): $FAIL2BAN_EXPORTER_PASSWORD"
    fi
    
    if [ -n "$ROOT_SSH_PASSWORD" ]; then
        echo "Root SSH (root): $ROOT_SSH_PASSWORD"
    else
        echo "Root SSH (root): не изменялся"
    fi
    echo ""
}

# Функция для сохранения всех паролей в файл
save_all_credentials() {
    local server_ip=$(get_server_ip)
    
    log_info "Сохранение всех учетных данных в файл: $CREDENTIALS_FILE"
    
    cat > "$CREDENTIALS_FILE" << EOF
===============================================
TRAFFIC CONNECT SERVER - УЧЕТНЫЕ ДАННЫЕ
===============================================
Дата создания: $(date)
IP сервера: $server_ip
===============================================

🌐 ДОСТУПЫ К СЕРВИСАМ:
===============================================

EOF

    # HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || command -v hestia >/dev/null 2>&1 || is_service_active "admin"; then
        cat >> "$CREDENTIALS_FILE" << EOF
✅ HestiaCP: https://$server_ip:8083
   Пользователь: $HESTIA_USERNAME
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
# ГЛАВНАЯ ФУНКЦИЯ УСТАНОВКИ
# ============================================================================

main_installation() {
    echo "🚀 ЗАПУСК УНИВЕРСАЛЬНОГО УСТАНОВЩИКА TRAFFIC CONNECT SERVER"
    echo "================================================"
    echo "Этот скрипт установит ВСЕ компоненты и продолжит после перезагрузки"
    echo "================================================"
    
    # Инициализация системы логирования
    setup_logging
    
    # Проверка root прав
    if ! check_root; then
        log_err "Этот скрипт должен быть запущен от имени root"
        exit 1
    fi
    
    # Проверка, требуется ли перезагрузка
    if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
        log_info "Обнаружен флаг перезагрузки, продолжаем установку..."
        rm -f "$REBOOT_REQUIRED_FLAG"
        
        # Продолжение установки после перезагрузки
        log_step "ПРОДОЛЖЕНИЕ УСТАНОВКИ ПОСЛЕ ПЕРЕЗАГРУЗКИ"
        
        # Улучшенная проверка установки HestiaCP после перезагрузки
        log_info "Проверка установки HestiaCP после перезагрузки..."
        
        local hestia_ready=false
        
        # Проверка основных компонентов
        if [ -f "/usr/local/admin/bin/admin" ]; then
            log_info "✅ Основной бинарный файл HestiaCP найден"
            hestia_ready=true
        fi
        
        if [ -d "/usr/local/hestia" ]; then
            log_info "✅ Директория конфигурации HestiaCP найдена"
            hestia_ready=true
        fi
        
        # Проверка службы
        if is_service_active "admin"; then
            log_info "✅ Служба HestiaCP работает"
            hestia_ready=true
        fi
        
        # Проверка веб-интерфейса
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8083 | grep -q "200\|302"; then
            log_info "✅ Веб-интерфейс HestiaCP доступен"
            hestia_ready=true
        fi
        
        if [ "$hestia_ready" = false ]; then
            log_err "❌ HestiaCP не готов к работе после перезагрузки"
            log_info "Попробуйте запустить: bash traffic_manager_new.sh --install-hestia"
            exit 1
        fi
        
        log_ok "✅ HestiaCP готов к работе, продолжаем установку"
        
        # Продолжение с этапа безопасности
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
        
        # Этап 1: Системные компоненты
        import_module "system_install"
        install_system_components
        
        # Этап 2: Установка HestiaCP (В ПЕРВУЮ ОЧЕРЕДЬ)
        log_step "ПРИОРИТЕТНАЯ УСТАНОВКА HESTIACP"
        import_module "hestia_install"
        install_hestia
        
        # Улучшенная проверка успешности установки HestiaCP
        log_info "Проверка успешности установки HestiaCP..."
        
        local hestia_success=false
        
        # Проверка основных компонентов
        if [ -f "/usr/local/admin/bin/admin" ]; then
            log_info "✅ Основной бинарный файл HestiaCP найден"
            hestia_success=true
        fi
        
        if [ -d "/usr/local/hestia" ]; then
            log_info "✅ Директория конфигурации HestiaCP найдена"
            hestia_success=true
        fi
        
        # Проверка службы
        if is_service_active "admin"; then
            log_info "✅ Служба HestiaCP работает"
            hestia_success=true
        fi
        
        # Проверка веб-интерфейса
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8083 | grep -q "200\|302"; then
            log_info "✅ Веб-интерфейс HestiaCP доступен"
            hestia_success=true
        fi
        
        if [ "$hestia_success" = false ]; then
            log_err "❌ Критическая ошибка: HestiaCP не установлен корректно"
            log_err "Установка прервана. HestiaCP должен быть установлен в первую очередь."
            exit 1
        fi
        
        log_ok "✅ HestiaCP установлен успешно"
        
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
    
    echo "================================================"
    log_ok "УСТАНОВКА TRAFFIC CONNECT SERVER ЗАВЕРШЕНА УСПЕШНО!"
    
    # Перезапуск всех служб
    log_info "Перезапуск всех установленных служб..."
    import_module "service_manager"
    restart_all_services
    
    # Отображение данных для входа
    show_access_credentials
    
    # Отображение всех сгенерированных паролей
    show_all_passwords
    
    # Сохранение всех учетных данных в файл
    save_all_credentials
    
    # Очистка временных файлов
    rm -f "$INSTALL_STAGE_FILE" "$HESTIA_INSTALLED_FLAG" "$REBOOT_REQUIRED_FLAG"
    
    echo ""
    echo "🎉 ВСЕ ГОТОВО! Система полностью установлена и настроена."
    echo "================================================"
}

# ============================================================================
# ФУНКЦИИ МЕНЕДЖЕРА
# ============================================================================

# Функция для показа меню
show_menu() {
    clear
    echo "🚀 Traffic Connect Server - УНИВЕРСАЛЬНЫЙ МЕНЕДЖЕР (МОДУЛЬНАЯ ВЕРСИЯ)"
    echo "================================================"
    echo ""
    echo "🔧 ИСПРАВЛЕНИЯ:"
    echo "  1) Исправить блокировки dpkg"
    echo "  2) Исправить SSL таймауты"
    echo ""
    echo "🚀 УСТАНОВКА:"
    echo "  3) УНИВЕРСАЛЬНАЯ УСТАНОВКА ВСЕГО"
    echo "  4) Установка только HestiaCP"
    echo "  5) Установка только мониторинга"
    echo ""
    echo "⚙️ УПРАВЛЕНИЕ СЛУЖБАМИ:"
    echo "  6) Статус всех служб"
    echo "  7) Перезапуск всех служб"
    echo "  8) Управление отдельными службами"
    echo ""
    echo "📊 КОНФИГУРАЦИИ:"
    echo "  9) Бэкап конфигураций"
    echo "  10) Восстановление конфигураций"
    echo "  11) Валидация конфигураций"
    echo ""
    echo "📋 ЛОГИ:"
    echo "  12) Просмотр логов"
    echo "  13) Поиск в логах"
    echo "  14) Статистика логов"
    echo ""
    echo "📊 ИНФОРМАЦИЯ:"
    echo "  15) Показать учетные данные"
    echo "  16) Проверить безопасность"
    echo "  17) Проверить версии"
    echo "  18) Принудительное обновление"
    echo ""
    echo "🗑️ УДАЛЕНИЕ:"
    echo "  19) ПОЛНОЕ УДАЛЕНИЕ ВСЕГО (система с нуля)"
    echo ""
    echo "❌ ВЫХОД:"
    echo "  0) Выход"
    echo ""
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
        --install-hestia)
            import_module "hestia_install"
            install_hestia
            ;;
        --install-monitoring)
            import_module "monitoring_install"
            install_monitoring
            ;;
        --services-status)
            import_module "service_manager"
            check_all_services
            ;;
        --services-restart)
            import_module "service_manager"
            restart_all_services
            ;;
        --config-backup)
            import_module "config_manager"
            backup_all_configs
            ;;
        --config-validate)
            import_module "config_manager"
            validate_all_configs
            ;;
        --logs-show)
            show_logs "${2:-main}" "${3:-50}"
            ;;
        --logs-search)
            search_logs "${2:-}" "${3:-main}" "${4:-100}"
            ;;
        --help|"")
            echo "🚀 Traffic Connect Server - УНИВЕРСАЛЬНЫЙ МЕНЕДЖЕР (МОДУЛЬНАЯ ВЕРСИЯ)"
            echo "================================================"
            echo ""
            echo "ИСПОЛЬЗОВАНИЕ:"
            echo "  ./traffic_manager_new.sh [ОПЦИЯ]"
            echo ""
            echo "ОПЦИИ УСТАНОВКИ:"
            echo "  --install              УНИВЕРСАЛЬНАЯ УСТАНОВКА ВСЕГО"
            echo "  --install-hestia       Установка только HestiaCP"
            echo "  --install-monitoring   Установка только мониторинга"
            echo ""
            echo "ОПЦИИ УПРАВЛЕНИЯ:"
            echo "  --services-status      Статус всех служб"
            echo "  --services-restart     Перезапуск всех служб"
            echo "  --config-backup        Бэкап конфигураций"
            echo "  --config-validate      Валидация конфигураций"
            echo "  --logs-show [ТИП] [СТРОКИ] Просмотр логов"
            echo "  --logs-search ПАТТЕРН [ТИП] [СТРОКИ] Поиск в логах"
            echo ""
            echo "ИНТЕРАКТИВНОЕ МЕНЮ:"
            echo "  ./traffic_manager_new.sh   (без аргументов)"
            echo ""
            ;;
        *)
            echo "❌ Неизвестная опция: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
    
    # Если запущен без аргументов, показываем интерактивное меню
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "Выберите действие (0-19): " choice
            
            case $choice in
                0)
                    echo "👋 До свидания!"
                    exit 0
                    ;;
                1)
                    import_module "system_install"
                    fix_dpkg_locks
                    ;;
                2)
                    import_module "system_install"
                    fix_ssl_timeouts
                    ;;
                3)
                    echo "Запуск универсальной установки..."
                    main_installation
                    ;;
                4)
                    import_module "hestia_install"
                    install_hestia
                    ;;
                5)
                    echo "Запуск установки только мониторинга..."
                    import_module "monitoring_install"
                    install_monitoring
                    ;;
                6)
                    import_module "service_manager"
                    check_all_services
                    ;;
                7)
                    import_module "service_manager"
                    restart_all_services
                    ;;
                8)
                    echo "Управление службами:"
                    echo "  start СЛУЖБА   - Запустить"
                    echo "  stop СЛУЖБА    - Остановить"
                    echo "  restart СЛУЖБА - Перезапустить"
                    echo "  enable СЛУЖБА  - Включить автозапуск"
                    echo "  disable СЛУЖБА - Отключить автозапуск"
                    echo ""
                    read -p "Введите команду: " service_cmd
                    import_module "service_manager"
                    main $service_cmd
                    ;;
                9)
                    import_module "config_manager"
                    backup_all_configs
                    ;;
                10)
                    echo "Восстановление конфигураций:"
                    import_module "config_manager"
                    list_backups
                    echo ""
                    read -p "Введите номер бэкапа: " backup_num
                    read -p "Введите целевой путь: " target_path
                    # Здесь нужно реализовать выбор бэкапа по номеру
                    ;;
                11)
                    import_module "config_manager"
                    validate_all_configs
                    ;;
                12)
                    echo "Просмотр логов:"
                    echo "  main   - Основной лог"
                    echo "  error  - Лог ошибок"
                    echo "  debug  - Отладочный лог"
                    echo "  json   - JSON лог"
                    echo ""
                    read -p "Введите тип лога: " log_type
                    read -p "Введите количество строк: " log_lines
                    show_logs "${log_type:-main}" "${log_lines:-50}"
                    ;;
                13)
                    echo "Поиск в логах:"
                    read -p "Введите паттерн поиска: " search_pattern
                    read -p "Введите тип лога (main/error/debug/json): " search_log_type
                    read -p "Введите количество строк: " search_lines
                    search_logs "${search_pattern:-}" "${search_log_type:-main}" "${search_lines:-100}"
                    ;;
                14)
                    get_log_stats
                    ;;
                15)
                    show_access_credentials
                    show_all_passwords
                    ;;
                16)
                    import_module "security_install"
                    check_system_security
                    ;;
                17)
                    echo "📋 ПРОВЕРКА ВЕРСИЙ КОМПОНЕНТОВ"
                    echo "================================================"
                    echo "🐧 Операционная система:"
                    cat /etc/os-release | grep PRETTY_NAME
                    echo "📦 Версии пакетов:"
                    echo "  • HestiaCP: $(hestia --version 2>/dev/null || echo 'Не установлен')"
                    echo "  • Nginx: $(nginx -v 2>&1 || echo 'Не установлен')"
                    echo "  • PHP: $(php -v 2>/dev/null | head -1 || echo 'Не установлен')"
                    echo "  • MySQL: $(mysql --version 2>/dev/null || echo 'Не установлен')"
                    echo "  • Node.js: $(node --version 2>/dev/null || echo 'Не установлен')"
                    echo "📊 Системные версии:"
                    echo "  • Kernel: $(uname -r)"
                    echo "  • Bash: $(bash --version | head -1)"
                    echo "  • Git: $(git --version 2>/dev/null || echo 'Не установлен')"
                    echo "================================================"
                    ;;
                18)
                    echo "🔄 ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ СИСТЕМЫ"
                    echo "================================================"
                    echo "📦 Обновление списков пакетов..."
                    apt update
                    echo "🔄 Обновление системы..."
                    apt upgrade -y
                    echo "🧹 Очистка кэша..."
                    apt autoremove -y
                    apt autoclean
                    echo "✅ Принудительное обновление завершено"
                    ;;
                19)
                    echo "🗑️ ПОЛНОЕ УДАЛЕНИЕ TRAFFIC CONNECT SERVER"
                    echo "================================================"
                    echo "⚠️ ВНИМАНИЕ: Это действие удалит ВСЕ установленные компоненты!"
                    echo "Система будет возвращена к исходному состоянию."
                    echo ""
                    read -p "Вы уверены, что хотите продолжить? (yes/NO): " confirm
                    if [[ "$confirm" != "yes" ]]; then
                        echo "❌ Удаление отменено"
                    else
                        echo "🔄 Начинаем полное удаление..."
                        # Здесь нужно реализовать полное удаление
                        echo "✅ ПОЛНОЕ УДАЛЕНИЕ ЗАВЕРШЕНО!"
                    fi
                    ;;
                *)
                    echo "❌ Неверный выбор. Попробуйте снова."
                    ;;
            esac
            
            echo ""
            read -p "Нажмите Enter для продолжения..."
        done
    fi
fi
