#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Интерактивный режим
# ============================================================================

source "$(dirname "$0")/common.sh"

# ============================================================================
# ИНТЕРАКТИВНЫЕ ФУНКЦИИ
# ============================================================================

interactive_setup() {
    echo -e "${YELLOW}=== Traffic Connect Server Installation ===${NC}"
    echo ""
    echo "Выберите режим установки:"
    echo "1) Полная установка (Hestia CP + Мониторинг + Дополнительные компоненты)"
    echo "2) Только Hestia CP"
    echo "3) Только система мониторинга"
    echo "4) Только дополнительные компоненты"
    echo "5) Выборочная установка"
    echo "6) Настройка конфигурации"
    echo "7) Выход"
    echo ""
    
    read -p "Ваш выбор [1]: " choice
    case $choice in
        1) install_full ;;
        2) install_hestia_only ;;
        3) install_monitoring_only ;;
        4) install_additional_only ;;
        5) install_selective ;;
        6) interactive_configuration ;;
        7) exit 0 ;;
        *) install_full ;;
    esac
}

install_full() {
    log_info "Запуск полной установки..."
    
    # Проверка системных требований
    if ! check_system_requirements; then
        log_err "Системные требования не выполнены"
        exit 1
    fi
    
    # Интерактивная настройка портов
    interactive_port_config
    
    # Запуск основного скрипта
    bash "$PROJECT_ROOT/install_complete.sh"
    
    # Запуск дополнительных компонентов
    bash "$PROJECT_ROOT/install_tools.sh"
    
    show_final_message
}

install_hestia_only() {
    log_info "Установка только Hestia CP..."
    
    # Проверка системных требований
    if ! check_system_requirements; then
        log_err "Системные требования не выполнены"
        exit 1
    fi
    
    # Интерактивная настройка портов
    interactive_port_config
    
    # Здесь будет вызов функции установки только Hestia CP
    log_info "Функция установки только Hestia CP будет добавлена в следующей версии"
}

install_monitoring_only() {
    log_info "Установка только системы мониторинга..."
    
    # Проверка системных требований
    if ! check_system_requirements; then
        log_err "Системные требования не выполнены"
        exit 1
    fi
    
    # Интерактивная настройка портов
    interactive_port_config
    
    # Здесь будет вызов функции установки только мониторинга
    log_info "Функция установки только мониторинга будет добавлена в следующей версии"
}

install_additional_only() {
    log_info "Установка только дополнительных компонентов..."
    
    bash "$PROJECT_ROOT/install_tools.sh"
}

install_selective() {
    log_info "Выборочная установка..."
    
    echo ""
    echo "Выберите компоненты для установки:"
    echo ""
    
    # Hestia CP
    read -p "Установить Hestia CP? (y/n) [y]: " install_hestia
    install_hestia=${install_hestia:-y}
    
    # Система мониторинга
    read -p "Установить систему мониторинга (Grafana, Prometheus, Loki)? (y/n) [y]: " install_monitoring
    install_monitoring=${install_monitoring:-y}
    
    # Дополнительные компоненты
    read -p "Установить дополнительные компоненты (шаблоны, BadBot, Link Manager)? (y/n) [y]: " install_additional
    install_additional=${install_additional:-y}
    
    # Проверка системных требований
    if [[ "$install_hestia" =~ ^[Yy]$ ]] || [[ "$install_monitoring" =~ ^[Yy]$ ]]; then
        if ! check_system_requirements; then
            log_err "Системные требования не выполнены"
            exit 1
        fi
        
        # Интерактивная настройка портов
        interactive_port_config
    fi
    
    # Выполнение выбранных компонентов
    if [[ "$install_hestia" =~ ^[Yy]$ ]] && [[ "$install_monitoring" =~ ^[Yy]$ ]]; then
        log_info "Установка Hestia CP и системы мониторинга..."
        bash "$PROJECT_ROOT/install_complete.sh"
    elif [[ "$install_hestia" =~ ^[Yy]$ ]]; then
        log_info "Установка только Hestia CP..."
        # Здесь будет вызов функции установки только Hestia CP
    elif [[ "$install_monitoring" =~ ^[Yy]$ ]]; then
        log_info "Установка только системы мониторинга..."
        # Здесь будет вызов функции установки только мониторинга
    fi
    
    if [[ "$install_additional" =~ ^[Yy]$ ]]; then
        log_info "Установка дополнительных компонентов..."
        bash "$PROJECT_ROOT/install_tools.sh"
    fi
}

# Интерактивная настройка конфигурации
interactive_configuration() {
    echo -e "${YELLOW}=== Настройка конфигурации ===${NC}"
    echo ""
    
    echo "1) Настройка портов сервисов"
    echo "2) Настройка безопасности"
    echo "3) Настройка производительности"
    echo "4) Настройка логирования"
    echo "5) Назад"
    echo ""
    
    read -p "Выберите раздел [1]: " config_choice
    case $config_choice in
        1) interactive_port_config ;;
        2) interactive_security_config ;;
        3) interactive_performance_config ;;
        4) interactive_logging_config ;;
        5) interactive_setup ;;
        *) interactive_port_config ;;
    esac
}

# ============================================================================
# ИНТЕРАКТИВНЫЙ ВВОД ДАННЫХ
# ============================================================================

interactive_input() {
    echo -e "${YELLOW}=== Настройка параметров ===${NC}"
    echo ""
    
    # Ввод имени пользователя Hestia CP
    while true; do
        read -p "Введите имя пользователя Hestia CP [$DEFAULT_HESTIA_USER]: " HESTIA_USER_INPUT
        HESTIA_USER=${HESTIA_USER_INPUT:-$DEFAULT_HESTIA_USER}
        
        if validate_username "$HESTIA_USER"; then
            break
        else
            echo "Попробуйте еще раз..."
        fi
    done
    
    # Ввод email
    while true; do
        read -p "Введите email администратора [$DEFAULT_EMAIL]: " EMAIL_INPUT
        EMAIL=${EMAIL_INPUT:-$DEFAULT_EMAIL}
        
        if validate_email "$EMAIL"; then
            break
        else
            echo "Попробуйте еще раз..."
        fi
    done
    
    # Настройка сложности паролей
    echo ""
    echo "Настройка сложности паролей:"
    echo "1) Низкая (только буквы и цифры)"
    echo "2) Средняя (буквы, цифры, базовые символы)"
    echo "3) Высокая (все символы, максимальная безопасность)"
    echo ""
    
    read -p "Выберите сложность паролей [3]: " password_complexity
    case $password_complexity in
        1) PASSWORD_COMPLEXITY="low" ;;
        2) PASSWORD_COMPLEXITY="medium" ;;
        3|*) PASSWORD_COMPLEXITY="high" ;;
    esac
    
    # Подтверждение
    echo ""
    echo "Параметры установки:"
    echo "Пользователь Hestia CP: $HESTIA_USER"
    echo "Email: $EMAIL"
    echo "Сложность паролей: $PASSWORD_COMPLEXITY"
    echo ""
    
    read -p "Продолжить установку? (y/n) [y]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]] && [[ "$confirm" != "" ]]; then
        log_info "Установка отменена пользователем"
        exit 0
    fi
    
    # Экспорт переменных для использования в других скриптах
    export HESTIA_USER
    export EMAIL
    export PASSWORD_COMPLEXITY
}

# Интерактивная настройка портов
interactive_port_config() {
    echo ""
    echo -e "${YELLOW}=== Настройка портов сервисов ===${NC}"
    echo ""
    
    # Проверка доступности портов
    check_ports_availability() {
        local ports=("$@")
        local occupied_ports=()
        
        for port in "${ports[@]}"; do
            if ! check_port_availability "$port"; then
                occupied_ports+=("$port")
            fi
        done
        
        if [ ${#occupied_ports[@]} -gt 0 ]; then
            echo -e "${YELLOW}Следующие порты уже заняты: ${occupied_ports[*]}${NC}"
            read -p "Продолжить? (y/n) [y]: " continue_choice
            if [[ ! "$continue_choice" =~ ^[Yy]$ ]] && [[ "$continue_choice" != "" ]]; then
                return 1
            fi
        fi
        
        return 0
    }
    
    # Настройка портов с проверкой
    echo "Настройка портов сервисов:"
    
    read -p "Порт Grafana [$GRAFANA_PORT]: " input_port
    if [[ -n "$input_port" ]]; then
        GRAFANA_PORT="$input_port"
    fi
    
    read -p "Порт Prometheus [$PROMETHEUS_PORT]: " input_port
    if [[ -n "$input_port" ]]; then
        PROMETHEUS_PORT="$input_port"
    fi
    
    read -p "Порт Loki [$LOKI_PORT]: " input_port
    if [[ -n "$input_port" ]]; then
        LOKI_PORT="$input_port"
    fi
    
    read -p "Порт Hestia CP [$HESTIA_PORT]: " input_port
    if [[ -n "$input_port" ]]; then
        HESTIA_PORT="$input_port"
    fi
    
    # Проверка доступности портов
    local ports_to_check=("$GRAFANA_PORT" "$PROMETHEUS_PORT" "$LOKI_PORT" "$HESTIA_PORT")
    if ! check_ports_availability "${ports_to_check[@]}"; then
        log_info "Настройка портов отменена"
        return 1
    fi
    
    # Экспорт настроенных портов
    export GRAFANA_PORT
    export PROMETHEUS_PORT
    export LOKI_PORT
    export HESTIA_PORT
    
    log_ok "Порты настроены успешно"
}

# Интерактивная настройка безопасности
interactive_security_config() {
    echo ""
    echo -e "${YELLOW}=== Настройка безопасности ===${NC}"
    echo ""
    
    echo "1) Проверка целостности файлов: $VERIFY_CHECKSUMS"
    read -p "Включить проверку целостности файлов? (y/n) [$([ "$VERIFY_CHECKSUMS" == "true" ] && echo "y" || echo "n")]: " verify_choice
    if [[ "$verify_choice" =~ ^[Yy]$ ]]; then
        VERIFY_CHECKSUMS="true"
    elif [[ "$verify_choice" =~ ^[Nn]$ ]]; then
        VERIFY_CHECKSUMS="false"
    fi
    
    echo "2) GPG проверка подписей: $GPG_VERIFY"
    read -p "Включить GPG проверку подписей? (y/n) [$([ "$GPG_VERIFY" == "true" ] && echo "y" || echo "n")]: " gpg_choice
    if [[ "$gpg_choice" =~ ^[Yy]$ ]]; then
        GPG_VERIFY="true"
    elif [[ "$gpg_choice" =~ ^[Nn]$ ]]; then
        GPG_VERIFY="false"
    fi
    
    echo "3) Автоматический rollback: $ENABLE_ROLLBACK"
    read -p "Включить автоматический rollback при ошибках? (y/n) [$([ "$ENABLE_ROLLBACK" == "true" ] && echo "y" || echo "n")]: " rollback_choice
    if [[ "$rollback_choice" =~ ^[Yy]$ ]]; then
        ENABLE_ROLLBACK="true"
    elif [[ "$rollback_choice" =~ ^[Nn]$ ]]; then
        ENABLE_ROLLBACK="false"
    fi
    
    # Экспорт настроек безопасности
    export VERIFY_CHECKSUMS
    export GPG_VERIFY
    export ENABLE_ROLLBACK
    
    log_ok "Настройки безопасности обновлены"
}

# Интерактивная настройка производительности
interactive_performance_config() {
    echo ""
    echo -e "${YELLOW}=== Настройка производительности ===${NC}"
    echo ""
    
    echo "1) Максимальное количество параллельных процессов: $MAX_PARALLEL_JOBS"
    read -p "Введите количество параллельных процессов [1-8]: " parallel_choice
    if [[ -n "$parallel_choice" ]] && [[ "$parallel_choice" =~ ^[1-8]$ ]]; then
        MAX_PARALLEL_JOBS="$parallel_choice"
    fi
    
    echo "2) Размер блока загрузки: $DOWNLOAD_CHUNK_SIZE байт"
    read -p "Введите размер блока загрузки [4096-32768]: " chunk_choice
    if [[ -n "$chunk_choice" ]] && [[ "$chunk_choice" =~ ^[0-9]+$ ]] && [ "$chunk_choice" -ge 4096 ] && [ "$chunk_choice" -le 32768 ]; then
        DOWNLOAD_CHUNK_SIZE="$chunk_choice"
    fi
    
    echo "3) Уровень сжатия: $COMPRESSION_LEVEL"
    read -p "Введите уровень сжатия [1-9]: " compression_choice
    if [[ -n "$compression_choice" ]] && [[ "$compression_choice" =~ ^[1-9]$ ]]; then
        COMPRESSION_LEVEL="$compression_choice"
    fi
    
    # Экспорт настроек производительности
    export MAX_PARALLEL_JOBS
    export DOWNLOAD_CHUNK_SIZE
    export COMPRESSION_LEVEL
    
    log_ok "Настройки производительности обновлены"
}

# Интерактивная настройка логирования
interactive_logging_config() {
    echo ""
    echo -e "${YELLOW}=== Настройка логирования ===${NC}"
    echo ""
    
    echo "1) Уровень логирования: $LOG_LEVEL"
    echo "   Доступные уровни: DEBUG, INFO, WARN, ERROR"
    read -p "Введите уровень логирования: " log_level_choice
    if [[ -n "$log_level_choice" ]] && [[ "$log_level_choice" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]]; then
        LOG_LEVEL="$log_level_choice"
    fi
    
    echo "2) Формат логов: $LOG_FORMAT"
    read -p "Выберите формат логов (TEXT/JSON) [$LOG_FORMAT]: " log_format_choice
    if [[ "$log_format_choice" =~ ^(TEXT|JSON)$ ]]; then
        LOG_FORMAT="$log_format_choice"
    fi
    
    echo "3) Включить JSON логирование: $ENABLE_JSON_LOGGING"
    read -p "Включить JSON логирование? (y/n) [$([ "$ENABLE_JSON_LOGGING" == "true" ] && echo "y" || echo "n")]: " json_choice
    if [[ "$json_choice" =~ ^[Yy]$ ]]; then
        ENABLE_JSON_LOGGING="true"
    elif [[ "$json_choice" =~ ^[Nn]$ ]]; then
        ENABLE_JSON_LOGGING="false"
    fi
    
    echo "4) Время хранения логов: $LOG_RETENTION_DAYS дней"
    read -p "Введите время хранения логов в днях [1-365]: " retention_choice
    if [[ -n "$retention_choice" ]] && [[ "$retention_choice" =~ ^[0-9]+$ ]] && [ "$retention_choice" -ge 1 ] && [ "$retention_choice" -le 365 ]; then
        LOG_RETENTION_DAYS="$retention_choice"
    fi
    
    # Экспорт настроек логирования
    export LOG_LEVEL
    export LOG_FORMAT
    export ENABLE_JSON_LOGGING
    export LOG_RETENTION_DAYS
    
    log_ok "Настройки логирования обновлены"
}

# ============================================================================
# ПРОГРЕСС-БАР
# ============================================================================

show_installation_progress() {
    local total_steps=$1
    local current_step=0
    
    # Список шагов установки
    local steps=(
        "Проверка системы"
        "Установка базовых пакетов"
        "Установка Hestia CP"
        "Настройка firewall"
        "Установка Grafana"
        "Установка Prometheus"
        "Установка Node Exporter"
        "Установка Pushgateway"
        "Установка Loki и Promtail"
        "Настройка мониторинга"
        "Проверка установки"
    )
    
    for step in "${steps[@]}"; do
        current_step=$((current_step + 1))
        show_progress $current_step $total_steps
        echo " - $step"
        sleep 1  # Имитация выполнения
    done
    
    echo ""
    log_ok "Прогресс-бар завершен"
}

# ============================================================================
# ФИНАЛЬНОЕ СООБЩЕНИЕ
# ============================================================================

show_final_message() {
    echo ""
    echo -e "${GREEN}=== Установка завершена успешно! ===${NC}"
    echo ""
    echo -e "${BLUE}Доступные сервисы:${NC}"
    echo -e "Hestia CP:    http://$(hostname -I | awk '{print $1}'):$HESTIA_PORT"
    echo -e "Grafana:      http://$(hostname -I | awk '{print $1}'):$GRAFANA_PORT"
    echo -e "Prometheus:   http://$(hostname -I | awk '{print $1}'):$PROMETHEUS_PORT"
    echo -e "Loki:         http://$(hostname -I | awk '{print $1}'):$LOKI_PORT"
    echo -e "Pushgateway:  http://$(hostname -I | awk '{print $1}'):$PUSHGATEWAY_PORT"
    echo ""
    echo -e "${YELLOW}Данные для входа сохранены в: $CREDENTIALS_FILE${NC}"
    echo ""
    echo -e "${RED}ВАЖНО: Измените пароли после установки!${NC}"
    echo ""
    echo -e "${BLUE}Полезные команды:${NC}"
    echo -e "• Проверка статуса служб: systemctl status grafana-server prometheus loki"
    echo -e "• Просмотр логов: journalctl -u grafana-server -f"
    echo -e "• Перезапуск Hestia CP: systemctl restart hestia"
    echo -e "• Проверка конфигурации Nginx: nginx -t"
    echo ""
    echo -e "${BLUE}Метрики установки:${NC}"
    if [[ "$ENABLE_METRICS" == "true" ]] && [ -f "$LOG_DIR/installation_metrics.log" ]; then
        echo "Время установки компонентов:"
        cat "$LOG_DIR/installation_metrics.log" | head -10
    fi
} 