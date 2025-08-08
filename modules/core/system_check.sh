#!/bin/bash
# ============================================================================
# Traffic Connect Server - Модуль проверки системы
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ СИСТЕМЫ
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

# Проверка root прав
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Проверка подключения к интернету
check_internet_connection() {
    log_info "Проверка подключения к интернету..."
    
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_ok "✅ Подключение к интернету активно"
        return 0
    else
        log_err "❌ Нет подключения к интернету"
        log_info "Проверьте сетевое подключение"
        return 1
    fi
}

# Проверка доступности портов
check_ports_availability() {
    log_info "Проверка доступности портов..."
    
    local ports=(80 443 8083 9090 9091)
    local unavailable_ports=()
    
    for port in "${ports[@]}"; do
        if netstat -tlnp | grep -q ":$port "; then
            log_warn "⚠️ Порт $port уже занят"
            unavailable_ports+=("$port")
        fi
    done
    
    if [ ${#unavailable_ports[@]} -gt 0 ]; then
        log_warn "Занятые порты: ${unavailable_ports[*]}"
        log_info "Возможно, некоторые сервисы уже установлены"
    else
        log_ok "✅ Все необходимые порты свободны"
    fi
    
    return 0
}

# Проверка свободного места на диске
check_disk_space() {
    log_info "Проверка свободного места на диске..."
    
    local required_space=10240  # 10GB в MB
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local available_space_mb=$((available_space / 1024))
    
    if [ "$available_space_mb" -lt "$required_space" ]; then
        log_err "❌ Недостаточно места на диске"
        log_info "Доступно: ${available_space_mb}MB"
        log_info "Требуется: ${required_space}MB"
        return 1
    else
        log_ok "✅ Достаточно места на диске: ${available_space_mb}MB"
        return 0
    fi
}

# Проверка оперативной памяти
check_memory() {
    log_info "Проверка оперативной памяти..."
    
    local required_memory=2048  # 2GB в MB
    local total_memory=$(free -m | awk 'NR==2{print $2}')
    
    if [ "$total_memory" -lt "$required_memory" ]; then
        log_warn "⚠️ Мало оперативной памяти"
        log_info "Доступно: ${total_memory}MB"
        log_info "Рекомендуется: ${required_memory}MB"
        log_info "Установка может работать медленно"
    else
        log_ok "✅ Достаточно оперативной памяти: ${total_memory}MB"
    fi
    
    return 0
}

# Полная проверка системы
full_system_check() {
    log_step "ПОЛНАЯ ПРОВЕРКА СИСТЕМЫ"
    
    local checks_passed=0
    local total_checks=5
    
    # Проверка совместимости
    if check_system_compatibility; then
        ((checks_passed++))
    fi
    
    # Проверка root прав
    if check_root; then
        ((checks_passed++))
    else
        log_err "❌ Требуются права root"
    fi
    
    # Проверка интернета
    if check_internet_connection; then
        ((checks_passed++))
    fi
    
    # Проверка портов
    if check_ports_availability; then
        ((checks_passed++))
    fi
    
    # Проверка места на диске
    if check_disk_space; then
        ((checks_passed++))
    fi
    
    # Проверка памяти
    check_memory  # Не критично
    
    # Результат проверки
    local percentage=$((checks_passed * 100 / total_checks))
    
    if [ $percentage -ge 80 ]; then
        log_ok "✅ Система готова к установке ($percentage%)"
        return 0
    else
        log_err "❌ Система не готова к установке ($percentage%)"
        return 1
    fi
}

# ============================================================================
# ЭКСПОРТ ФУНКЦИЙ
# ============================================================================

export -f check_system_compatibility
export -f check_root
export -f check_internet_connection
export -f check_ports_availability
export -f check_disk_space
export -f check_memory
export -f full_system_check
