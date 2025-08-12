#!/bin/bash

# Подключаем цвета
source "$(dirname "$0")/colors.sh"

# Функция проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS_MARK} [ОШИБКА] $1${NC}"
        exit 1
    else
        echo -e "${GREEN}${CHECK_MARK} [OK] $1${NC}"
    fi
}

# Функция для красивого заголовка
print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:padding} ${BOLD}${title}${NC} ${LINE_H:0:padding}${CORNER_TR}${NC}"
}



# Функция безопасной генерации пароля
generate_password() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
    elif command -v tr >/dev/null 2>&1 && [ -r /dev/urandom ]; then
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16
    else
        echo "defaultPassword123"
    fi
}



# Функция проверки root прав
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${LIGHT_RED}${CROSS_MARK} Этот скрипт должен быть запущен от имени root${NC}" 1>&2
        exit 1
    fi
}

# Функция получения IP адреса сервера
get_server_ip() {
    hostname -I | awk '{print $1}' 2>/dev/null || echo 'localhost'
}

# Функция проверки доступности интернета
check_internet() {
    local url="$1"
    if [ -z "$url" ]; then
        url="https://google.com"
    fi
    
    if curl -s --max-time 10 --connect-timeout 5 "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Функция логирования
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${LIGHT_CYAN}[${timestamp}] INFO: ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${LIGHT_YELLOW}[${timestamp}] WARNING: ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${LIGHT_RED}[${timestamp}] ERROR: ${message}${NC}"
            ;;
        "SUCCESS")
            echo -e "${LIGHT_GREEN}[${timestamp}] SUCCESS: ${message}${NC}"
            ;;
        *)
            echo -e "${LIGHT_BLUE}[${timestamp}] ${message}${NC}"
            ;;
    esac
}
