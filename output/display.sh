#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция отображения результатов установки
display_results() {
    print_header "🎉 УСТАНОВКА ЗАВЕРШЕНА"
    
    # Генерируем все пароли для отображения
    local phpmysql_password=$(generate_password)
    local server_ip=$(get_server_ip)
    
    display_services_info "$server_ip"
    display_credentials "$phpmysql_password"
    display_success_message
    display_useful_info
    display_final_message "$server_ip"
}

# Функция отображения информации о сервисах
display_services_info() {
    local server_ip="$1"
    
    echo -e "\n${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУПНЫЕ СЕРВИСЫ${NC} ${LIGHT_BLUE}${STAR}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🌐 ВЕБ-ИНТЕРФЕЙСЫ${NC}${LIGHT_BLUE}${LINE_V:0:42}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"

    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📊 Grafana:${NC}      ${LIGHT_YELLOW}http://${server_ip}:3000${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📈 Prometheus:${NC}   ${LIGHT_YELLOW}http://${server_ip}:9090${NC}${LIGHT_BLUE}${LINE_V:0:6}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📝 Loki:${NC}         ${LIGHT_YELLOW}http://${server_ip}:3100${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📤 Pushgateway:${NC}  ${LIGHT_YELLOW}http://${server_ip}:9091${NC}${LIGHT_BLUE}${LINE_V:0:6}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция отображения учетных данных
display_credentials() {
    local phpmysql_password="$1"
    
    echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДАННЫЕ ДЛЯ ВХОДА${NC} ${LIGHT_PURPLE}${STAR}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🔐 УЧЕТНЫЕ ДАННЫЕ${NC}${LIGHT_PURPLE}${LINE_V:0:40}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"

    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📊 Grafana:${NC}       ${LIGHT_YELLOW}TrafficGrafana${NC}     ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$GRAFANA_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:4}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}🗄️  phpMyAdmin:${NC}    ${LIGHT_YELLOW}TrafficPhpMyAdmin${NC}  ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$phpmysql_password${NC}${LIGHT_PURPLE}${LINE_V:0:2}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция отображения сообщения об успехе
display_success_message() {
    echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! 🎉${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция отображения полезной информации
display_useful_info() {
    echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ПОЛЕЗНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_PURPLE}${STAR}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Grafana:${NC}    ${LIGHT_YELLOW}/var/log/grafana/grafana.log${NC}${LIGHT_PURPLE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Prometheus:${NC}  ${LIGHT_YELLOW}/var/log/prometheus/${NC}${LIGHT_PURPLE}${LINE_V:0:12}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Loki:${NC}        ${LIGHT_YELLOW}/var/log/loki/${NC}${LIGHT_PURPLE}${LINE_V:0:18}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Promtail:${NC}   ${LIGHT_YELLOW}/var/log/promtail/${NC}${LIGHT_PURPLE}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Fail2ban:${NC}   ${LIGHT_YELLOW}/var/log/fail2ban.log${NC}${LIGHT_PURPLE}${LINE_V:0:10}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция отображения финального сообщения
display_final_message() {
    local server_ip="$1"
    
    echo -e "\n${LIGHT_GREEN}${CHECK_MARK}${NC} ${BOLD}Все сервисы установлены и настроены!${NC}"
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Рекомендуется перезагрузить сервер после установки"
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Для мониторинга используйте Grafana: ${LIGHT_YELLOW}http://${server_ip}:3000${NC}"
}

# Функция загрузки диагностического скрипта
download_diagnostic_script() {
    echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДИАГНОСТИКА СИСТЕМЫ${NC} ${LIGHT_PURPLE}${STAR}${NC}"
    log_message "INFO" "Загрузка диагностического скрипта..."
    
    if wget -q https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh -O /usr/local/bin/diagnostic.sh; then
        chmod +x /usr/local/bin/diagnostic.sh
        log_message "SUCCESS" "Диагностический скрипт загружен"
        log_message "INFO" "Для диагностики запустите: diagnostic.sh"
    else
        log_message "WARNING" "Не удалось загрузить диагностический скрипт"
    fi
}
