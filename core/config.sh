#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/utils.sh"

# Глобальные переменные конфигурации
declare -gA CONFIG_VALUES

# Функция загрузки конфигурации
load_config() {
    local config_file="$1"
    
    if [ -z "$config_file" ]; then
        config_file="$(dirname "$0")/../config/settings.conf"
    fi
    
    if [ ! -f "$config_file" ]; then
        log_message "WARNING" "Конфигурационный файл не найден: $config_file"
        return 1
    fi
    
    log_message "INFO" "Загрузка конфигурации из: $config_file"
    
    # Читаем конфигурационный файл
    local current_section=""
    while IFS= read -r line; do
        # Пропускаем комментарии и пустые строки
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi
        
        # Проверяем секцию
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Читаем параметры
        if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Убираем пробелы
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Убираем кавычки
            value=$(echo "$value" | sed 's/^"//;s/"$//')
            value=$(echo "$value" | sed "s/^'//;s/'$//")
            
            # Сохраняем в глобальный массив
            CONFIG_VALUES["${current_section}_${key}"]="$value"
        fi
    done < "$config_file"
    
    log_message "SUCCESS" "Конфигурация загружена успешно"
}

# Функция получения значения из конфигурации
get_config_value() {
    local section="$1"
    local key="$2"
    local default_value="$3"
    
    local config_key="${section}_${key}"
    
    if [ -n "${CONFIG_VALUES[$config_key]}" ]; then
        echo "${CONFIG_VALUES[$config_key]}"
    else
        echo "$default_value"
    fi
}





# Функция валидации конфигурации
validate_config() {
    local errors=()
    
    # Проверяем обязательные параметры
    local required_params=(
        "MAIN_TIMEZONE"
        "USER_DEFAULT_USERNAME"
        "SECURITY_FAIL2BAN_BANTIME"
        "MONITORING_GRAFANA_VERSION"
        "PORTS_GRAFANA_PORT"
    )
    
    for param in "${required_params[@]}"; do
        if [ -z "${CONFIG_VALUES[$param]}" ]; then
            errors+=("Отсутствует обязательный параметр: $param")
        fi
    done
    
    # Проверяем корректность значений
    if [ -n "${CONFIG_VALUES[PORTS_GRAFANA_PORT]}" ]; then
        if ! [[ "${CONFIG_VALUES[PORTS_GRAFANA_PORT]}" =~ ^[0-9]+$ ]] || \
           [ "${CONFIG_VALUES[PORTS_GRAFANA_PORT]}" -lt 1 ] || \
           [ "${CONFIG_VALUES[PORTS_GRAFANA_PORT]}" -gt 65535 ]; then
            errors+=("Некорректный порт Grafana: ${CONFIG_VALUES[PORTS_GRAFANA_PORT]}")
        fi
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        log_message "ERROR" "Ошибки в конфигурации:"
        for error in "${errors[@]}"; do
            log_message "ERROR" "  - $error"
        done
        return 1
    fi
    
    log_message "SUCCESS" "Конфигурация валидна"
    return 0
}

# Функция отображения конфигурации
display_config() {
    print_header "⚙️ ТЕКУЩАЯ КОНФИГУРАЦИЯ"
    
    echo -e "${LIGHT_CYAN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ОСНОВНЫЕ НАСТРОЙКИ${NC} ${LIGHT_CYAN}${STAR}${NC}"
    echo -e "${LIGHT_CYAN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}Временная зона:${NC}    ${LIGHT_YELLOW}$(get_config_value "MAIN" "TIMEZONE" "Europe/Minsk")${NC}${LIGHT_CYAN}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}Язык:${NC}            ${LIGHT_YELLOW}$(get_config_value "MAIN" "LANGUAGE" "ru")${NC}${LIGHT_CYAN}${LINE_V:0:20}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}Пользователь:${NC}    ${LIGHT_YELLOW}$(get_config_value "USER" "DEFAULT_USERNAME" "admin")${NC}${LIGHT_CYAN}${LINE_V:0:10}${LINE_V}${NC}"
    echo -e "${LIGHT_CYAN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
    
    echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}НАСТРОЙКИ МОНИТОРИНГА${NC} ${LIGHT_PURPLE}${STAR}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Grafana:${NC}         ${LIGHT_YELLOW}v$(get_config_value "MONITORING" "GRAFANA_VERSION" "10.4.3")${NC}${LIGHT_PURPLE}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Prometheus:${NC}      ${LIGHT_YELLOW}v$(get_config_value "MONITORING" "PROMETHEUS_VERSION" "2.47.0")${NC}${LIGHT_PURPLE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Node Exporter:${NC}   ${LIGHT_YELLOW}v$(get_config_value "MONITORING" "NODE_EXPORTER_VERSION" "1.6.1")${NC}${LIGHT_PURPLE}${LINE_V:0:5}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Loki:${NC}            ${LIGHT_YELLOW}v$(get_config_value "MONITORING" "LOKI_VERSION" "2.9.1")${NC}${LIGHT_PURPLE}${LINE_V:0:18}${LINE_V}${NC}"
    echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
    
    echo -e "\n${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}НАСТРОЙКИ ПОРТОВ${NC} ${LIGHT_BLUE}${STAR}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Grafana:${NC}          ${LIGHT_YELLOW}:$(get_config_value "PORTS" "GRAFANA_PORT" "3000")${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Prometheus:${NC}       ${LIGHT_YELLOW}:$(get_config_value "PORTS" "PROMETHEUS_PORT" "9090")${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Node Exporter:${NC}    ${LIGHT_YELLOW}:$(get_config_value "PORTS" "NODE_EXPORTER_PORT" "9100")${NC}${LIGHT_BLUE}${LINE_V:0:5}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Loki:${NC}             ${LIGHT_YELLOW}:$(get_config_value "PORTS" "LOKI_PORT" "3100")${NC}${LIGHT_BLUE}${LINE_V:0:18}${LINE_V}${NC}"
    echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
}

# Функция создания конфигурации по умолчанию
create_default_config() {
    local config_file="$1"
    
    if [ -z "$config_file" ]; then
        config_file="$(dirname "$0")/../config/settings.conf"
    fi
    
    # Создаем директорию если не существует
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" <<'EOF'
# Конфигурация TC Fast Setup
# Этот файл содержит настройки для автоматической установки

# Основные настройки
[MAIN]
# Временная зона сервера
TIMEZONE="Europe/Minsk"

# Язык установки
LANGUAGE="ru"

# Версия Hestia CP
HESTIA_VERSION="release"

# Настройки пользователя
[USER]
# Имя пользователя по умолчанию
DEFAULT_USERNAME="admin"

# Домен по умолчанию для email
DEFAULT_DOMAIN="localhost"

# Настройки безопасности
[SECURITY]
# Время блокировки в fail2ban (в часах)
FAIL2BAN_BANTIME=1

# Время поиска попыток входа (в секундах)
FAIL2BAN_FINDTIME=600

# Максимальное количество попыток
FAIL2BAN_MAXRETRY=5

# Настройки мониторинга
[MONITORING]
# Версия Grafana
GRAFANA_VERSION="10.4.3"

# Версия Prometheus
PROMETHEUS_VERSION="2.47.0"

# Версия Node Exporter
NODE_EXPORTER_VERSION="1.6.1"

# Версия Pushgateway
PUSHGATEWAY_VERSION="1.6.1"

# Версия Loki
LOKI_VERSION="2.9.1"

# Настройки портов
[PORTS]
# Grafana
GRAFANA_PORT=3000

# Prometheus
PROMETHEUS_PORT=9090

# Node Exporter
NODE_EXPORTER_PORT=9100

# Pushgateway
PUSHGATEWAY_PORT=9091

# Loki
LOKI_PORT=3100

# Promtail
PROMTAIL_PORT=9080

# Fail2ban Exporter
FAIL2BAN_EXPORTER_PORT=9191

# Hestia CP
HESTIA_PORT=8083

# Настройки файрвола
[FIREWALL]
# Разрешенные порты
ALLOWED_PORTS="22,80,443,3000,9090,9100,3100,9080,9191,9091,8083"

# Настройки установки
[INSTALLATION]
# Установить Apache (yes/no)
INSTALL_APACHE="no"

# Установить Named (yes/no)
INSTALL_NAMED="no"

# Установить Exim (yes/no)
INSTALL_EXIM="no"

# Установить Dovecot (yes/no)
INSTALL_DOVECOT="no"

# Установить ClamAV (yes/no)
INSTALL_CLAMAV="no"

# Установить SpamAssassin (yes/no)
INSTALL_SPAMASSASSIN="no"

# Настройки сети
[NETWORK]
# GitHub URL для проверки доступности
GITHUB_URL="https://github.com"

# Google URL для проверки интернета
GOOGLE_URL="https://google.com"

# Таймаут для сетевых запросов (в секундах)
NETWORK_TIMEOUT=30

# Настройки логирования
[LOGGING]
# Уровень логирования (INFO, WARNING, ERROR, SUCCESS)
LOG_LEVEL="INFO"

# Включить отладочные сообщения (yes/no)
DEBUG_MODE="no"

# Настройки отображения
[DISPLAY]
# Использовать цвета в выводе (yes/no)
USE_COLORS="yes"

# Показывать прогресс-бар (yes/no)
SHOW_PROGRESS="yes"

# Настройки диагностики
[DIAGNOSTICS]
# Автоматически загружать диагностический скрипт (yes/no)
DOWNLOAD_DIAGNOSTIC="yes"

# URL диагностического скрипта
DIAGNOSTIC_URL="https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh"
EOF

    log_message "SUCCESS" "Конфигурация по умолчанию создана: $config_file"
}
