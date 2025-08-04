#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - GUI Launcher
# ============================================================================

# Загрузка библиотек
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

# Настройки GUI
GUI_PORT="8080"
GUI_HOST="0.0.0.0"
GUI_DIR="$SCRIPT_DIR"

# Функция запуска простого HTTP сервера
start_http_server() {
    log_info "Запуск GUI интерфейса на http://$GUI_HOST:$GUI_PORT"
    log_info "Откройте браузер и перейдите по адресу: http://localhost:$GUI_PORT"
    
    # Проверяем наличие Python
    if command -v python3 &> /dev/null; then
        cd "$GUI_DIR"
        python3 -m http.server "$GUI_PORT" --bind "$GUI_HOST"
    elif command -v python &> /dev/null; then
        cd "$GUI_DIR"
        python -m SimpleHTTPServer "$GUI_PORT"
    elif command -v php &> /dev/null; then
        cd "$GUI_DIR"
        php -S "$GUI_HOST:$GUI_PORT"
    else
        log_err "Не найден Python или PHP для запуска HTTP сервера"
        log_info "Установите Python3: sudo apt install python3"
        exit 1
    fi
}

# Функция проверки порта
check_port() {
    if netstat -tlnp 2>/dev/null | grep -q ":$GUI_PORT "; then
        log_warn "Порт $GUI_PORT уже занят"
        read -p "Продолжить? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Функция показа справки
show_help() {
    echo "Traffic Connect Server Installation - GUI Launcher"
    echo ""
    echo "Использование:"
    echo "  $0                    # Запуск GUI"
    echo "  $0 --port PORT        # Запуск на указанном порту"
    echo "  $0 --host HOST        # Запуск на указанном хосте"
    echo "  $0 --help             # Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 --port 9000        # Запуск на порту 9000"
    echo "  $0 --host 127.0.0.1   # Запуск только для localhost"
}

# Обработка аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            GUI_PORT="$2"
            shift 2
            ;;
        --host)
            GUI_HOST="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_err "Неизвестный аргумент: $1"
            show_help
            exit 1
            ;;
    esac
done

# Проверка root прав (не требуется для GUI)
# check_root

# Проверка интернета
check_internet

# Проверка порта
check_port

# Запуск GUI
start_http_server 