#!/bin/bash
# ============================================================================
# Traffic Connect Server - Установка системных компонентов
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/main.conf"
source "$PROJECT_ROOT/core/utils/common.sh"

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ И ИНИЦИАЛИЗАЦИИ (ИСПОЛЬЗУЙТЕ common.sh)
# ============================================================================

# Функции check_root(), check_system_requirements(), check_internet() 
# перенесены в core/utils/common.sh
# Используйте source "$PROJECT_ROOT/core/utils/common.sh" для доступа к функциям

# ============================================================================
# ФУНКЦИИ ИСПРАВЛЕНИЯ ПРОБЛЕМ
# ============================================================================

fix_dpkg_locks() {
    log_info "Исправление блокировок dpkg..."
    
    # Проверка активных процессов apt
    local apt_processes=$(ps aux | grep -E "(apt|dpkg)" | grep -v grep)
    if [ -n "$apt_processes" ]; then
        log_warn "Обнаружены активные процессы apt, ожидаем завершения..."
        
        # Ожидание graceful завершения процессов
        local timeout=30
        local counter=0
        
        while [ $counter -lt $timeout ] && [ -n "$(ps aux | grep -E "(apt|dpkg)" | grep -v grep)" ]; do
            log_info "Ожидание завершения процессов apt/dpkg... ($counter/$timeout)"
            sleep 1
            counter=$((counter + 1))
        done
        
        # Принудительное завершение только если процессы все еще активны
        if [ -n "$(ps aux | grep -E "(apt|dpkg)" | grep -v grep)" ]; then
            log_warn "Процессы не завершились, принудительное завершение..."
            pkill -f "apt-get" 2>/dev/null || true
            pkill -f "apt" 2>/dev/null || true
            pkill -f "dpkg" 2>/dev/null || true
            sleep 3
        else
            log_ok "Процессы apt/dpkg завершились gracefully"
        fi
    fi
    
    # Удаление файлов блокировок
    rm -f /var/lib/dpkg/lock* 2>/dev/null || true
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/dpkg/info/format-new 2>/dev/null || true
    
    # Исправление прерванной установки
    dpkg --configure -a 2>/dev/null || true
    apt-get install -f -y 2>/dev/null || true
    
    log_ok "Блокировки dpkg исправлены"
}

fix_ssl_timeouts() {
    log_info "Настройка SSL для стабильной работы..."
    
    # Увеличиваем таймауты для SSL соединений
    export CURL_CONNECT_TIMEOUT=60
    export CURL_TIMEOUT=300
    export WGET_TIMEOUT=300
    
    # Настройка SSL для wget
    echo "check_certificate = off" >> ~/.wgetrc 2>/dev/null || true
    echo "timeout = 300" >> ~/.wgetrc 2>/dev/null || true
    
    # Настройка SSL для curl
    echo "connect-timeout = 60" >> ~/.curlrc 2>/dev/null || true
    echo "max-time = 300" >> ~/.curlrc 2>/dev/null || true
    
    log_ok "SSL настройки применены"
}

# ============================================================================
# УСТАНОВКА СИСТЕМНЫХ КОМПОНЕНТОВ
# ============================================================================

install_system_components() {
    log_step "Установка системных компонентов"
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "system_components_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "Системные компоненты уже установлены, пропускаем"
        return 0
    fi
    
    # 1.1 Обновление системы
    log_info "Обновление системы..."
    if ! apt update; then
        log_warn "Ошибка обновления списков пакетов, исправляем..."
        fix_dpkg_locks
        apt update
    fi
    
    if ! apt upgrade -y; then
        log_warn "Ошибка обновления системы, исправляем..."
        fix_dpkg_locks
        apt upgrade -y
    fi
    
    # 1.2 Установка базовых пакетов
    log_info "Установка базовых пакетов..."
    local base_packages="git curl wget unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release"
    
    if ! apt install -y $base_packages; then
        log_warn "Ошибка установки базовых пакетов, исправляем..."
        fix_dpkg_locks
        apt install -y $base_packages
    fi
    
    # 1.3 Настройка репозиториев
    log_info "Настройка репозиториев..."
    
    # Добавление репозитория Node.js
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    
    # Обновление списков пакетов
    apt update
    
    # 1.4 Установка дополнительных пакетов
    log_info "Установка дополнительных пакетов..."
    local additional_packages="nodejs htop iotop nethogs"
    
    if ! apt install -y $additional_packages; then
        log_warn "Ошибка установки дополнительных пакетов, исправляем..."
        fix_dpkg_locks
        apt install -y $additional_packages
    fi
    
    # 1.5 Создание системных пользователей
    log_info "Создание системных пользователей..."
    
    # Создание пользователей для мониторинга
    local monitoring_users=("prometheus" "grafana" "loki" "node_exporter")
    for user in "${monitoring_users[@]}"; do
        if ! id "$user" &>/dev/null; then
            useradd --no-create-home --shell /bin/false "$user"
            log_info "Создан пользователь: $user"
        fi
    done
    
    # Отметка завершения этапа
    echo "system_components_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "Системные компоненты установлены"
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
    log_info "=== УСТАНОВКА СИСТЕМНЫХ КОМПОНЕНТОВ ==="
    
    # Проверки
    check_root
    if ! check_system_requirements; then
        log_err "Системные требования не выполнены"
        exit 1
    fi
    if ! check_internet; then
        log_err "Нет интернет-соединения"
        exit 1
    fi
    
    # Установка системных компонентов
    install_system_components
    
    log_ok "=== УСТАНОВКА СИСТЕМНЫХ КОМПОНЕНТОВ ЗАВЕРШЕНА ==="
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
