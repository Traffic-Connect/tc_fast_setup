#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Интерактивный установщик
# ============================================================================

# Загрузка общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/interactive.sh"

# ============================================================================
# ОСНОВНАЯ ЛОГИКА
# ============================================================================

main() {
    # Проверка root прав
    check_root

    # Проверка прав на выполнение
    if [ ! -x "$SCRIPT_DIR/install.sh" ]; then
        chmod +x "$SCRIPT_DIR/install.sh"
    fi
    if [ ! -x "$SCRIPT_DIR/install_complete.sh" ]; then
        chmod +x "$SCRIPT_DIR/install_complete.sh"
    fi
    if [ ! -x "$SCRIPT_DIR/install_tools.sh" ]; then
        chmod +x "$SCRIPT_DIR/install_tools.sh"
    fi
    
    # Настройка логирования
    setup_logging
    
    # Расширенная проверка системных требований
    log_info "Выполнение расширенных проверок системы..."
    if ! check_system_requirements; then
        log_err "Системные требования не выполнены"
        exit 1
    fi
    
    # Проверка системы
    log_info "Выполнение предварительных проверок..."
    check_internet
    check_disk_space
    log_ok "Предварительные проверки пройдены"
    
    # Сбор метрик системы
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        collect_system_metrics
    fi
    
    # Показываем статистику системы
    show_system_stats
    
    # Интерактивный ввод данных
    interactive_input
    
    # Генерация паролей с выбранной сложностью
    local password_complexity="${PASSWORD_COMPLEXITY:-high}"
    show_notification "info" "Генерация безопасных паролей..." 2
    GRAFANA_PASSWORD=$(generate_secure_password 24 "$password_complexity")
    HESTIA_PASSWORD=$(generate_secure_password 24 "$password_complexity")
    
    # Сохранение паролей
    show_notification "info" "Сохранение учетных данных..." 2
    save_credentials "$GRAFANA_PASSWORD" "$HESTIA_USER" "$HESTIA_PASSWORD"
    
    # Интерактивный выбор режима установки
    interactive_setup
}

# ============================================================================
# ЗАПУСК
# ============================================================================

# Проверка аргументов командной строки
case "${1:-}" in
    --help|-h)
        echo "Traffic Connect Server Installation"
        echo ""
        echo "Использование:"
        echo "  $0                    # Интерактивный режим"
        echo "  $0 --full             # Полная установка"
        echo "  $0 --test             # Запуск тестов"
        echo "  $0 --validate         # Проверка системы"
        echo "  $0 --help             # Показать эту справку"
        exit 0
        ;;
    --full)
        log_info "Запуск полной установки..."
        check_root
        setup_logging
        
        # Расширенная проверка системных требований
        if ! check_system_requirements; then
            log_err "Системные требования не выполнены"
            exit 1
        fi
        
        check_internet
        check_disk_space
        
        # Сбор метрик системы
        if [[ "$ENABLE_METRICS" == "true" ]]; then
            collect_system_metrics
        fi
        
        # Генерация паролей с высокой сложностью
        GRAFANA_PASSWORD=$(generate_secure_password 24 "high")
        HESTIA_PASSWORD=$(generate_secure_password 24 "high")
        HESTIA_USER="$DEFAULT_HESTIA_USER"
        EMAIL="$DEFAULT_EMAIL"
        
        # Сохранение паролей
        save_credentials "$GRAFANA_PASSWORD" "$HESTIA_USER" "$HESTIA_PASSWORD"
        
        # Запуск установки
        install_full
        ;;

    --test)
        log_info "Запуск тестов проекта..."
        if [ -f "$SCRIPT_DIR/tests/run_all_tests.sh" ]; then
            bash "$SCRIPT_DIR/tests/run_all_tests.sh"
        else
            log_err "Тестовый скрипт не найден"
            exit 1
        fi
        ;;


    --validate)
        log_info "Валидация конфигурации..."
        check_root
        setup_logging
        
        # Проверка всех настроек
        echo "=== ВАЛИДАЦИЯ КОНФИГУРАЦИИ ==="
        echo "Порт Grafana: $GRAFANA_PORT"
        echo "Порт Prometheus: $PROMETHEUS_PORT"
        echo "Порт Loki: $LOKI_PORT"
        echo "Порт Hestia: $HESTIA_PORT"
        echo ""
        echo "Проверка целостности: $VERIFY_CHECKSUMS"
        echo "SSL проверка: $SSL_VERIFY"
        echo "GPG проверка: $GPG_VERIFY"
        echo "Автоматический rollback: $ENABLE_ROLLBACK"
        echo ""
        echo "Максимум параллельных процессов: $MAX_PARALLEL_JOBS"
        echo "Размер блока загрузки: $DOWNLOAD_CHUNK_SIZE"
        echo "Уровень сжатия: $COMPRESSION_LEVEL"
        echo ""
        echo "Уровень логирования: $LOG_LEVEL"
        echo "Формат логов: $LOG_FORMAT"
        echo "JSON логирование: $ENABLE_JSON_LOGGING"
        echo ""
        
        # Проверка системных требований
        if check_system_requirements; then
            log_ok "Системные требования выполнены"
        else
            log_err "Системные требования не выполнены"
            exit 1
        fi
        
        # Проверка доступности портов
        local ports_to_check=("$GRAFANA_PORT" "$PROMETHEUS_PORT" "$LOKI_PORT" "$HESTIA_PORT")
        local occupied_ports=()
        
        for port in "${ports_to_check[@]}"; do
            if ! check_port_availability "$port"; then
                occupied_ports+=("$port")
            fi
        done
        
        if [ ${#occupied_ports[@]} -gt 0 ]; then
            log_warn "Следующие порты уже заняты: ${occupied_ports[*]}"
        else
            log_ok "Все порты свободны"
        fi
        
        log_ok "Валидация завершена"
        ;;
    --metrics)
        log_info "Показать метрики системы..."
        check_root
        setup_logging
        
        echo "=== МЕТРИКИ СИСТЕМЫ ==="
        echo "Архитектура: $(uname -m)"
        echo "ОС: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        echo "Ядро: $(uname -r)"
        echo ""
        
        # Память
        local total_mem=$(free -m | awk 'NR==2{print $2}')
        local used_mem=$(free -m | awk 'NR==2{print $3}')
        local free_mem=$(free -m | awk 'NR==2{print $4}')
        echo "Память:"
        echo "  Всего: ${total_mem}MB"
        echo "  Использовано: ${used_mem}MB"
        echo "  Свободно: ${free_mem}MB"
        echo ""
        
        # Диск
        local total_disk=$(df / | awk 'NR==2 {print $2}')
        local used_disk=$(df / | awk 'NR==2 {print $3}')
        local free_disk=$(df / | awk 'NR==2 {print $4}')
        echo "Диск:"
        echo "  Всего: ${total_disk}MB"
        echo "  Использовано: ${used_disk}MB"
        echo "  Свободно: ${free_disk}MB"
        echo ""
        
        # CPU
        local cpu_cores=$(nproc)
        local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        echo "CPU:"
        echo "  Ядра: $cpu_cores"
        echo "  Нагрузка: $cpu_load"
        echo ""
        
        # Сеть
        local ip_address=$(hostname -I | awk '{print $1}')
        echo "Сеть:"
        echo "  IP адрес: $ip_address"
        echo "  Хост: $(hostname)"
        echo ""
        
        # Проверка требований
        echo "=== ПРОВЕРКА ТРЕБОВАНИЙ ==="
        if [ $free_mem -ge $REQUIRED_MEMORY ]; then
            echo -e "${GREEN}✅ Память: OK${NC}"
        else
            echo -e "${RED}❌ Память: Недостаточно${NC}"
        fi
        
        if [ $free_disk -ge $REQUIRED_DISK_SPACE ]; then
            echo -e "${GREEN}✅ Диск: OK${NC}"
        else
            echo -e "${RED}❌ Диск: Недостаточно${NC}"
        fi
        
        if [[ "$(uname -m)" == "x86_64" ]]; then
            echo -e "${GREEN}✅ Архитектура: OK${NC}"
        else
            echo -e "${RED}❌ Архитектура: Неподдерживается${NC}"
        fi
        ;;
    "")
        # Интерактивный режим по умолчанию
        main
        ;;
    *)
        log_err "Неизвестный аргумент: $1"
        echo "Используйте --help для получения справки"
        exit 1
        ;;
esac 