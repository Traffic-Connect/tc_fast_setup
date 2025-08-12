#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/colors.sh"
source "$(dirname "$0")/../core/utils.sh"
source "$(dirname "$0")/../core/config.sh"

# Функция отображения меню
show_menu() {
    echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🔧 МЕНЕДЖЕР МОДУЛЕЙ TC FAST SETUP${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
    
    echo -e "\n${LIGHT_CYAN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУПНЫЕ ОПЕРАЦИИ${NC} ${LIGHT_CYAN}${STAR}${NC}"
    echo -e "${LIGHT_CYAN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}1.${NC} ${LIGHT_YELLOW}Установить полный стек${NC}${LIGHT_CYAN}${LINE_V:0:25}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}2.${NC} ${LIGHT_YELLOW}Установить только Hestia CP${NC}${LIGHT_CYAN}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}3.${NC} ${LIGHT_YELLOW}Установить только мониторинг${NC}${LIGHT_CYAN}${LINE_V:0:12}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}4.${NC} ${LIGHT_YELLOW}Установить отдельные модули${NC}${LIGHT_CYAN}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}5.${NC} ${LIGHT_YELLOW}Настроить конфигурацию${NC}${LIGHT_CYAN}${LINE_V:0:12}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}6.${NC} ${LIGHT_YELLOW}Запустить диагностику${NC}${LIGHT_CYAN}${LINE_V:0:10}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}7.${NC} ${LIGHT_YELLOW}Проверить статус сервисов${NC}${LIGHT_CYAN}${LINE_V:0:5}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}8.${NC} ${LIGHT_YELLOW}Обновить модули${NC}${LIGHT_CYAN}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}9.${NC} ${LIGHT_YELLOW}Выход${NC}${LIGHT_CYAN}${LINE_V:0:35}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция установки полного стека
install_full_stack() {
    print_header "🚀 УСТАНОВКА ПОЛНОГО СТЕКА"
    
    log_message "INFO" "Запуск установки полного стека..."
    
    # Загружаем главный модуль установки
    source "$(dirname "$0")/../core/installer.sh"
    
    # Инициализируем установку
    initialize_installation
    
    # Отображаем информацию перед установкой
    display_login_info
    display_components
    display_important_info
    
    # Ожидание подтверждения
    wait_for_confirmation
    
    # Основной процесс установки
    main_installation_process
    
    # Отображение результатов
    source "$(dirname "$0")/../output/display.sh"
    display_results
    
    log_message "SUCCESS" "Установка полного стека завершена"
}

# Функция установки только Hestia CP
install_hestia_only() {
    print_header "🎛️ УСТАНОВКА ТОЛЬКО HESTIA CP"
    
    log_message "INFO" "Запуск установки Hestia CP..."
    
    # Запускаем скрипт установки Hestia CP
    bash "$(dirname "$0")/../install_hestia.sh"
    
    log_message "SUCCESS" "Установка Hestia CP завершена"
}

# Функция установки только мониторинга
install_monitoring_only() {
    print_header "📊 УСТАНОВКА ТОЛЬКО МОНИТОРИНГА"
    
    log_message "INFO" "Запуск установки стека мониторинга..."
    
    # Загружаем системные модули
    source "$(dirname "$0")/../core/system.sh"
    
    # Инициализация
    check_root
    restore_system_state
    check_dependencies
    cleanup_system
    update_system
    
    # Установка файрвола и fail2ban
    source "$(dirname "$0")/../core/installer.sh"
    install_firewall
    install_fail2ban
    
    # Установка мониторинга
    install_monitoring_stack
    
    # Отображение результатов
    source "$(dirname "$0")/../output/display.sh"
    display_results
    
    log_message "SUCCESS" "Установка мониторинга завершена"
}

# Функция установки отдельных модулей
install_individual_modules() {
    print_header "🔧 УСТАНОВКА ОТДЕЛЬНЫХ МОДУЛЕЙ"
    
    echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУПНЫЕ МОДУЛИ${NC} ${LIGHT_PURPLE}${STAR}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}1.${NC} ${LIGHT_YELLOW}Grafana${NC}${LIGHT_PURPLE}${LINE_V:0:35}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}2.${NC} ${LIGHT_YELLOW}Prometheus${NC}${LIGHT_PURPLE}${LINE_V:0:30}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}3.${NC} ${LIGHT_YELLOW}Node Exporter${NC}${LIGHT_PURPLE}${LINE_V:0:25}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}4.${NC} ${LIGHT_YELLOW}Pushgateway${NC}${LIGHT_PURPLE}${LINE_V:0:25}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}5.${NC} ${LIGHT_YELLOW}Loki${NC}${LIGHT_PURPLE}${LINE_V:0:35}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}6.${NC} ${LIGHT_YELLOW}Fail2Ban${NC}${LIGHT_PURPLE}${LINE_V:0:30}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}7.${NC} ${LIGHT_YELLOW}Firewall${NC}${LIGHT_PURPLE}${LINE_V:0:30}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
    
    echo -e "\n${LIGHT_CYAN}${ARROW}${NC} Выберите модули для установки (через запятую, например: 1,3,5):"
    read -r selected_modules
    
    # Загружаем системные модули
    source "$(dirname "$0")/../core/system.sh"
    check_root
    restore_system_state
    check_dependencies
    
    # Устанавливаем выбранные модули
    IFS=',' read -ra modules <<< "$selected_modules"
    for module in "${modules[@]}"; do
        case "$module" in
            1)
                log_message "INFO" "Установка Grafana..."
                source "$(dirname "$0")/../modules/grafana.sh"
                install_grafana
                configure_grafana
                ;;
            2)
                log_message "INFO" "Установка Prometheus..."
                source "$(dirname "$0")/../modules/prometheus.sh"
                install_prometheus
                ;;
            3)
                log_message "INFO" "Установка Node Exporter..."
                source "$(dirname "$0")/../modules/node_exporter.sh"
                install_node_exporter
                ;;
            4)
                log_message "INFO" "Установка Pushgateway..."
                source "$(dirname "$0")/../modules/pushgateway.sh"
                install_pushgateway
                ;;
            5)
                log_message "INFO" "Установка Loki..."
                source "$(dirname "$0")/../modules/loki.sh"
                install_loki
                install_promtail
                ;;
            6)
                log_message "INFO" "Установка Fail2Ban..."
                source "$(dirname "$0")/../modules/fail2ban.sh"
                install_fail2ban
                ;;
            7)
                log_message "INFO" "Установка Firewall..."
                source "$(dirname "$0")/../modules/firewall.sh"
                install_firewall
                ;;
            *)
                log_message "WARNING" "Неизвестный модуль: $module"
                ;;
        esac
    done
    
    log_message "SUCCESS" "Установка выбранных модулей завершена"
}

# Функция настройки конфигурации
configure_settings() {
    print_header "⚙️ НАСТРОЙКА КОНФИГУРАЦИИ"
    
    # Загружаем конфигурацию
    load_config
    
    echo -e "\n${LIGHT_CYAN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ОПЕРАЦИИ С КОНФИГУРАЦИЕЙ${NC} ${LIGHT_CYAN}${STAR}${NC}"
    echo -e "${LIGHT_CYAN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}1.${NC} ${LIGHT_YELLOW}Показать текущую конфигурацию${NC}${LIGHT_CYAN}${LINE_V:0:5}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}2.${NC} ${LIGHT_YELLOW}Создать конфигурацию по умолчанию${NC}${LIGHT_CYAN}${LINE_V:0:2}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}3.${NC} ${LIGHT_YELLOW}Валидировать конфигурацию${NC}${LIGHT_CYAN}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}4.${NC} ${LIGHT_YELLOW}Редактировать конфигурацию${NC}${LIGHT_CYAN}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
    
    echo -e "\n${LIGHT_CYAN}${ARROW}${NC} Выберите операцию:"
    read -r config_choice
    
    case "$config_choice" in
        1)
            display_config
            ;;
        2)
            create_default_config
            ;;
        3)
            if validate_config; then
                log_message "SUCCESS" "Конфигурация валидна"
            else
                log_message "ERROR" "Конфигурация содержит ошибки"
            fi
            ;;
        4)
            local config_file="$(dirname "$0")/../config/settings.conf"
            if command -v nano >/dev/null 2>&1; then
                nano "$config_file"
            elif command -v vim >/dev/null 2>&1; then
                vim "$config_file"
            else
                log_message "WARNING" "Редактор не найден, откройте файл вручную: $config_file"
            fi
            ;;
        *)
            log_message "WARNING" "Неизвестный выбор"
            ;;
    esac
}

# Функция запуска диагностики
run_diagnostic() {
    print_header "🔍 ДИАГНОСТИКА СИСТЕМЫ"
    
    log_message "INFO" "Запуск диагностики..."
    
    # Проверяем наличие диагностического скрипта
    local diagnostic_script="$(dirname "$0")/../diagnostic.sh"
    if [ -f "$diagnostic_script" ]; then
        bash "$diagnostic_script"
    else
        log_message "WARNING" "Диагностический скрипт не найден"
        log_message "INFO" "Загружаем диагностический скрипт..."
        
        if wget -q https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh -O "$diagnostic_script"; then
            chmod +x "$diagnostic_script"
            bash "$diagnostic_script"
        else
            log_message "ERROR" "Не удалось загрузить диагностический скрипт"
        fi
    fi
}

# Функция проверки статуса сервисов
check_services_status() {
    print_header "📊 СТАТУС СЕРВИСОВ"
    
    local services=("grafana-server" "prometheus" "node_exporter" "pushgateway" "loki" "promtail" "fail2ban_exporter" "fail2ban")
    
    echo -e "\n${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}СТАТУС СЕРВИСОВ${NC} ${LIGHT_BLUE}${STAR}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}${service}:${NC}    ${LIGHT_GREEN}АКТИВЕН${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
        else
            echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}${service}:${NC}    ${LIGHT_RED}НЕ АКТИВЕН${NC}${LIGHT_BLUE}${LINE_V:0:10}${LINE_V}${NC}"
        fi
    done
    
    echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
    
    # Проверка портов
    echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ПРОВЕРКА ПОРТОВ${NC} ${LIGHT_PURPLE}${STAR}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    
    local ports=("3000:Grafana" "9090:Prometheus" "9100:Node Exporter" "9091:Pushgateway" "3100:Loki" "9080:Promtail" "9191:Fail2Ban Exporter")
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%:*}"
        local service_name="${port_info#*:}"
        
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Порт ${port} (${service_name}):${NC} ${LIGHT_GREEN}ОТКРЫТ${NC}${LIGHT_PURPLE}${LINE_V:0:5}${LINE_V}${NC}"
        else
            echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Порт ${port} (${service_name}):${NC} ${LIGHT_RED}ЗАКРЫТ${NC}${LIGHT_PURPLE}${LINE_V:0:5}${LINE_V}${NC}"
        fi
    done
    
    echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция обновления модулей
update_modules() {
    print_header "🔄 ОБНОВЛЕНИЕ МОДУЛЕЙ"
    
    log_message "INFO" "Обновление модулей..."
    
    # Обновляем систему
    apt update && apt upgrade -y
    
    # Перезапускаем сервисы
    local services=("grafana-server" "prometheus" "node_exporter" "pushgateway" "loki" "promtail" "fail2ban_exporter")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "INFO" "Перезапуск $service..."
            systemctl restart "$service" 2>/dev/null || true
        fi
    done
    
    log_message "SUCCESS" "Модули обновлены"
}

# Главная функция
main() {
    # Проверяем root права
    check_root
    
    while true; do
        show_menu
        echo -e "\n${LIGHT_CYAN}${ARROW}${NC} Выберите операцию (1-9):"
        read -r choice
        
        case "$choice" in
            1)
                install_full_stack
                ;;
            2)
                install_hestia_only
                ;;
            3)
                install_monitoring_only
                ;;
            4)
                install_individual_modules
                ;;
            5)
                configure_settings
                ;;
            6)
                run_diagnostic
                ;;
            7)
                check_services_status
                ;;
            8)
                update_modules
                ;;
            9)
                echo -e "\n${LIGHT_GREEN}${CHECK_MARK}${NC} Выход из менеджера модулей"
                exit 0
                ;;
            *)
                log_message "WARNING" "Неизвестный выбор: $choice"
                ;;
        esac
        
        echo -e "\n${LIGHT_CYAN}${ARROW}${NC} Нажмите любую клавишу для продолжения..."
        read -n 1 -s
    done
}

# Запуск главной функции
main "$@"
