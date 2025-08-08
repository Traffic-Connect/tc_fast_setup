#!/bin/bash
# ============================================================================
# Traffic Connect Server - Быстрая установка
# ============================================================================
# Этот скрипт автоматически загружает и устанавливает Traffic Connect Server

set -e  # Остановка при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка root прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_err "Этот скрипт должен быть запущен с правами root"
        log_info "Используйте: sudo bash $0"
        exit 1
    fi
}

# Проверка системы
check_system() {
    log_info "Проверка системы..."
    
    # Проверка на macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_err "❌ Traffic Connect Server не поддерживается на macOS"
        log_info "Система предназначена для Linux серверов"
        exit 1
    fi
    
    # Проверка на Windows
    if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        log_err "❌ Traffic Connect Server не поддерживается на Windows"
        log_info "Система предназначена для Linux серверов"
        exit 1
    fi
    
    # Проверка дистрибутива
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "Обнаружена система: $PRETTY_NAME"
        
        case "$ID" in
            ubuntu|debian)
                log_ok "✅ Поддерживаемая система: $ID"
                ;;
            centos|rhel|rocky|almalinux)
                log_ok "✅ Поддерживаемая система: $ID"
                ;;
            *)
                log_warn "⚠️ Неизвестная система: $ID"
                log_info "Установка может не работать корректно"
                ;;
        esac
    else
        log_warn "⚠️ Не удалось определить систему"
    fi
}

# Установка зависимостей
install_dependencies() {
    log_info "Установка зависимостей..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y git curl wget
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL/Rocky
        yum update -y
        yum install -y git curl wget
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL 8+
        dnf update -y
        dnf install -y git curl wget
    else
        log_err "❌ Не удалось установить зависимости"
        exit 1
    fi
    
    log_ok "✅ Зависимости установлены"
}

# Загрузка проекта
download_project() {
    log_info "Загрузка Traffic Connect Server..."
    
    local temp_dir="/tmp/traffic_connect_install"
    local repo_url="https://github.com/Traffic-Connect/tc_fast_setup.git"
    
    # Очистка временной директории
    rm -rf "$temp_dir"
    
    # Клонирование репозитория
    if git clone "$repo_url" "$temp_dir" 2>/dev/null; then
        log_ok "✅ Проект загружен успешно"
    else
        log_err "❌ Не удалось загрузить проект"
        log_info "Проверьте подключение к интернету"
        exit 1
    fi
}

# Запуск установки
run_installation() {
    log_info "Запуск установки Traffic Connect Server..."
    
    local temp_dir="/tmp/traffic_connect_install"
    
    if [ -f "$temp_dir/install.sh" ]; then
        cd "$temp_dir"
        chmod +x install.sh
        
        log_info "🚀 Начинаем установку..."
        log_info "Это может занять 15-30 минут"
        log_info "Не прерывайте процесс!"
        
        # Запуск установки
        ./install.sh --install
        
        log_ok "✅ Установка завершена!"
        
        # Показ информации о доступах
        if [ -f "/root/traffic_connect_credentials.txt" ]; then
            echo ""
            log_info "📄 Учетные данные сохранены в: /root/traffic_connect_credentials.txt"
            echo ""
            log_info "🌐 Основные доступы:"
            echo "   HestiaCP: https://$(hostname -I | awk '{print $1}'):8083"
            echo "   Grafana: http://$(hostname -I | awk '{print $1}'):3000"
            echo "   Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
            echo ""
        fi
        
    else
        log_err "❌ Файл установки не найден"
        exit 1
    fi
}

# Очистка
cleanup() {
    log_info "Очистка временных файлов..."
    rm -rf "/tmp/traffic_connect_install"
    log_ok "✅ Очистка завершена"
}

# Главная функция
main() {
    echo ""
    echo "🚀 TRAFFIC CONNECT SERVER - БЫСТРАЯ УСТАНОВКА"
    echo "================================================"
    echo "Модульная версия 2.0"
    echo "================================================"
    echo ""
    
    # Проверки
    check_root
    check_system
    
    # Подтверждение установки
    echo ""
    log_warn "⚠️ ВНИМАНИЕ:"
    echo "   • Установка займет 15-30 минут"
    echo "   • Требуется стабильное интернет-соединение"
    echo "   • Система может быть перезагружена"
    echo "   • Все данные будут сохранены"
    echo ""
    
    read -p "Продолжить установку? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Установка отменена"
        exit 0
    fi
    
    echo ""
    
    # Выполнение установки
    install_dependencies
    download_project
    run_installation
    cleanup
    
    echo ""
    echo "🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
    echo "================================================"
    echo "Система готова к использованию"
    echo "================================================"
    echo ""
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
