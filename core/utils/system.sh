#!/bin/bash
# ============================================================================
# Traffic Connect Server - Системные утилиты
# ============================================================================

# Загрузка конфигурации
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    source "$PROJECT_ROOT/core/configs/main.conf"
fi

# Загрузка системы логирования
source "$PROJECT_ROOT/core/utils/logger.sh"

# ============================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================================================

# Состояние системы
SYSTEM_CHECKED=false
SYSTEM_COMPATIBLE=false
SYSTEM_INFO=()

# Кэш системной информации
SYSTEM_CACHE_FILE="$TEMP_DIR/system_info.cache"
SYSTEM_CACHE_TTL=3600  # 1 час

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ СИСТЕМЫ
# ============================================================================

# Полная проверка системы
full_system_check() {
    set_logger_module "system_check"
    log_info "Начинаем полную проверку системы..."
    
    local all_checks_passed=true
    
    # Проверка операционной системы
    if ! check_operating_system; then
        all_checks_passed=false
    fi
    
    # Проверка прав доступа
    if ! check_root_permissions; then
        all_checks_passed=false
    fi
    
    # Проверка системных требований
    if ! check_system_requirements; then
        all_checks_passed=false
    fi
    
    # Проверка сетевого подключения
    if ! check_network_connectivity; then
        all_checks_passed=false
    fi
    
    # Проверка доступности портов
    if ! check_port_availability; then
        all_checks_passed=false
    fi
    
    # Проверка зависимостей
    if ! check_dependencies; then
        all_checks_passed=false
    fi
    
    SYSTEM_CHECKED=true
    SYSTEM_COMPATIBLE=$all_checks_passed
    
    if [ "$all_checks_passed" = true ]; then
        log_ok "Все проверки системы пройдены успешно"
        return 0
    else
        log_err "Система не прошла все проверки"
        return 1
    fi
}

# Проверка операционной системы
check_operating_system() {
    log_info "Проверка операционной системы..."
    
    # Проверка на macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_err "❌ Traffic Connect Server не поддерживается на macOS"
        log_info "Система предназначена для Linux серверов"
        log_info "Поддерживаемые системы:"
        log_info "  - Ubuntu 20.04/22.04"
        log_info "  - Debian 11/12"
        log_info "  - CentOS 8/Rocky Linux 8"
        return 1
    fi
    
    # Проверка на Windows
    if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        log_err "❌ Traffic Connect Server не поддерживается на Windows"
        log_info "Система предназначена для Linux серверов"
        return 1
    fi
    
    # Определение дистрибутива Linux
    local os_info=""
    local os_version=""
    
    if [ -f "/etc/os-release" ]; then
        source "/etc/os-release"
        os_info="$NAME"
        os_version="$VERSION_ID"
    elif [ -f "/etc/redhat-release" ]; then
        os_info=$(cat /etc/redhat-release)
        os_version=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    elif [ -f "/etc/debian_version" ]; then
        os_info="Debian"
        os_version=$(cat /etc/debian_version)
    else
        log_warn "⚠️ Не удалось определить дистрибутив Linux"
        os_info="Unknown Linux"
        os_version="Unknown"
    fi
    
    log_info "Обнаружена ОС: $os_info $os_version"
    
    # Проверка совместимости дистрибутива
    case "$os_info" in
        *"Ubuntu"*)
            if [[ "$os_version" == "20.04" ]] || [[ "$os_version" == "22.04" ]]; then
                log_ok "✅ Ubuntu $os_version поддерживается"
                SYSTEM_INFO["os"]="ubuntu"
                SYSTEM_INFO["version"]="$os_version"
                return 0
            else
                log_warn "⚠️ Ubuntu $os_version может работать, но не тестировался"
                SYSTEM_INFO["os"]="ubuntu"
                SYSTEM_INFO["version"]="$os_version"
                return 0
            fi
            ;;
        *"Debian"*)
            if [[ "$os_version" == "11" ]] || [[ "$os_version" == "12" ]]; then
                log_ok "✅ Debian $os_version поддерживается"
                SYSTEM_INFO["os"]="debian"
                SYSTEM_INFO["version"]="$os_version"
                return 0
            else
                log_warn "⚠️ Debian $os_version может работать, но не тестировался"
                SYSTEM_INFO["os"]="debian"
                SYSTEM_INFO["version"]="$os_version"
                return 0
            fi
            ;;
        *"CentOS"*|*"Rocky"*|*"Red Hat"*)
            if [[ "$os_version" == "8" ]] || [[ "$os_version" == "9" ]]; then
                log_ok "✅ $os_info $os_version поддерживается"
                SYSTEM_INFO["os"]="rhel"
                SYSTEM_INFO["version"]="$os_version"
                return 0
            else
                log_warn "⚠️ $os_info $os_version может работать, но не тестировался"
                SYSTEM_INFO["os"]="rhel"
                SYSTEM_INFO["version"]="$os_version"
                return 0
            fi
            ;;
        *)
            log_warn "⚠️ Дистрибутив $os_info не тестировался"
            log_info "Система может работать, но возможны проблемы"
            SYSTEM_INFO["os"]="unknown"
            SYSTEM_INFO["version"]="$os_version"
            return 0
            ;;
    esac
}

# Проверка прав root
check_root_permissions() {
    log_info "Проверка прав доступа..."
    
    if [[ $EUID -ne 0 ]]; then
        log_err "❌ Скрипт должен выполняться с правами root"
        log_info "Запустите: sudo $0"
        return 1
    fi
    
    log_ok "✅ Права root подтверждены"
    return 0
}

# Проверка системных требований
check_system_requirements() {
    log_info "Проверка системных требований..."
    
    local requirements_met=true
    
    # Проверка памяти
    local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_mb=$((total_memory_kb / 1024))
    
    if [ $total_memory_mb -lt $REQUIRED_MEMORY ]; then
        log_warn "⚠️ Недостаточно памяти: ${total_memory_mb}MB (требуется ${REQUIRED_MEMORY}MB)"
        requirements_met=false
    else
        log_ok "✅ Память: ${total_memory_mb}MB"
    fi
    
    # Проверка дискового пространства
    local free_space_mb=$(df / | awk 'NR==2 {print $4}')
    local free_space_mb=$((free_space_mb / 1024))
    
    if [ $free_space_mb -lt $REQUIRED_DISK_SPACE ]; then
        log_warn "⚠️ Недостаточно места на диске: ${free_space_mb}MB (требуется ${REQUIRED_DISK_SPACE}MB)"
        requirements_met=false
    else
        log_ok "✅ Свободное место: ${free_space_mb}MB"
    fi
    
    # Проверка CPU
    local cpu_cores=$(nproc)
    if [ $cpu_cores -lt $REQUIRED_CPU_CORES ]; then
        log_warn "⚠️ Недостаточно ядер CPU: $cpu_cores (требуется $REQUIRED_CPU_CORES)"
        requirements_met=false
    else
        log_ok "✅ CPU ядер: $cpu_cores"
    fi
    
    # Сохранение информации о системе
    SYSTEM_INFO["memory_mb"]="$total_memory_mb"
    SYSTEM_INFO["disk_space_mb"]="$free_space_mb"
    SYSTEM_INFO["cpu_cores"]="$cpu_cores"
    
    return $([ "$requirements_met" = true ] && echo 0 || echo 1)
}

# Проверка сетевого подключения
check_network_connectivity() {
    log_info "Проверка сетевого подключения..."
    
    local connectivity_ok=true
    
    # Проверка подключения к интернету
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_warn "⚠️ Нет подключения к интернету"
        connectivity_ok=false
    else
        log_ok "✅ Подключение к интернету работает"
    fi
    
    # Проверка DNS
    if ! nslookup google.com >/dev/null 2>&1; then
        log_warn "⚠️ Проблемы с DNS"
        connectivity_ok=false
    else
        log_ok "✅ DNS работает"
    fi
    
    # Проверка GitHub (для загрузки компонентов)
    if ! curl -s --connect-timeout 10 https://github.com >/dev/null 2>&1; then
        log_warn "⚠️ Нет доступа к GitHub"
        connectivity_ok=false
    else
        log_ok "✅ Доступ к GitHub работает"
    fi
    
    return $([ "$connectivity_ok" = true ] && echo 0 || echo 1)
}

# Проверка доступности портов
check_port_availability() {
    log_info "Проверка доступности портов..."
    
    local ports_to_check=(
        "$SSH_PORT"
        "$HTTP_PORT"
        "$HTTPS_PORT"
        "$ADMIN_PORT"
        "$GRAFANA_PORT"
        "$PROMETHEUS_PORT"
        "$LOKI_PORT"
    )
    
    local ports_available=true
    
    for port in "${ports_to_check[@]}"; do
        if netstat -tlnp | grep -q ":$port "; then
            log_warn "⚠️ Порт $port уже занят"
            ports_available=false
        else
            log_debug "Порт $port свободен"
        fi
    done
    
    if [ "$ports_available" = true ]; then
        log_ok "✅ Все необходимые порты свободны"
    fi
    
    return $([ "$ports_available" = true ] && echo 0 || echo 1)
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка системных зависимостей..."
    
    local required_packages=(
        "curl"
        "wget"
        "grep"
        "awk"
        "sed"
        "tar"
        "gzip"
        "unzip"
    )
    
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! command -v "$package" >/dev/null 2>&1; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_warn "⚠️ Отсутствуют пакеты: ${missing_packages[*]}"
        log_info "Установка недостающих пакетов..."
        
        # Попытка установки недостающих пакетов
        case "${SYSTEM_INFO[os]}" in
            "ubuntu"|"debian")
                apt update && apt install -y "${missing_packages[@]}" || {
                    log_err "❌ Не удалось установить пакеты"
                    return 1
                }
                ;;
            "rhel")
                yum install -y "${missing_packages[@]}" || {
                    log_err "❌ Не удалось установить пакеты"
                    return 1
                }
                ;;
            *)
                log_warn "⚠️ Неизвестный дистрибутив, установите пакеты вручную"
                return 1
                ;;
        esac
    fi
    
    log_ok "✅ Все зависимости установлены"
    return 0
}

# ============================================================================
# ФУНКЦИИ ПОЛУЧЕНИЯ ИНФОРМАЦИИ О СИСТЕМЕ
# ============================================================================

# Получение IP адреса сервера
get_server_ip() {
    # Попытка получить внешний IP
    local external_ip=$(curl -s --connect-timeout 5 https://ipinfo.io/ip 2>/dev/null)
    
    if [ -n "$external_ip" ]; then
        echo "$external_ip"
        return 0
    fi
    
    # Fallback на локальные IP
    local local_ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null)
    
    if [ -n "$local_ip" ]; then
        echo "$local_ip"
        return 0
    fi
    
    # Последний fallback
    echo "127.0.0.1"
}

# Получение имени хоста
get_hostname() {
    hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown"
}

# Получение информации о системе
get_system_info() {
    if [ ${#SYSTEM_INFO[@]} -eq 0 ]; then
        # Загрузка из кэша если доступен
        if [ -f "$SYSTEM_CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c%Y "$SYSTEM_CACHE_FILE" 2>/dev/null || echo 0))) -lt $SYSTEM_CACHE_TTL ]; then
            source "$SYSTEM_CACHE_FILE"
        else
            # Сбор информации о системе
            collect_system_info
            # Сохранение в кэш
            save_system_info_cache
        fi
    fi
    
    # Вывод информации
    echo "=== ИНФОРМАЦИЯ О СИСТЕМЕ ==="
    for key in "${!SYSTEM_INFO[@]}"; do
        echo "$key: ${SYSTEM_INFO[$key]}"
    done
}

# Сбор информации о системе
collect_system_info() {
    SYSTEM_INFO["hostname"]=$(get_hostname)
    SYSTEM_INFO["ip"]=$(get_server_ip)
    SYSTEM_INFO["kernel"]=$(uname -r)
    SYSTEM_INFO["architecture"]=$(uname -m)
    SYSTEM_INFO["uptime"]=$(uptime -p 2>/dev/null || echo "unknown")
    SYSTEM_INFO["load_average"]=$(uptime | awk -F'load average:' '{print $2}' | xargs 2>/dev/null || echo "unknown")
    
    # Информация о памяти
    local mem_info=$(free -m 2>/dev/null | grep Mem)
    if [ -n "$mem_info" ]; then
        SYSTEM_INFO["memory_total"]=$(echo "$mem_info" | awk '{print $2}')
        SYSTEM_INFO["memory_used"]=$(echo "$mem_info" | awk '{print $3}')
        SYSTEM_INFO["memory_free"]=$(echo "$mem_info" | awk '{print $4}')
    fi
    
    # Информация о диске
    local disk_info=$(df -h / | awk 'NR==2')
    if [ -n "$disk_info" ]; then
        SYSTEM_INFO["disk_total"]=$(echo "$disk_info" | awk '{print $2}')
        SYSTEM_INFO["disk_used"]=$(echo "$disk_info" | awk '{print $3}')
        SYSTEM_INFO["disk_free"]=$(echo "$disk_info" | awk '{print $4}')
    fi
}

# Сохранение информации о системе в кэш
save_system_info_cache() {
    mkdir -p "$(dirname "$SYSTEM_CACHE_FILE")" 2>/dev/null || true
    
    {
        echo "# Кэш системной информации"
        echo "# Создан: $(date)"
        echo ""
        for key in "${!SYSTEM_INFO[@]}"; do
            echo "SYSTEM_INFO[\"$key\"]=\"${SYSTEM_INFO[$key]}\""
        done
    } > "$SYSTEM_CACHE_FILE"
}

# ============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ СИСТЕМОЙ
# ============================================================================

# Проверка статуса службы
is_service_active() {
    local service="$1"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet "$service" 2>/dev/null
    elif command -v service >/dev/null 2>&1; then
        service "$service" status >/dev/null 2>&1
    else
        # Fallback проверка через ps
        pgrep -f "$service" >/dev/null 2>&1
    fi
}

# Запуск службы
start_service() {
    local service="$1"
    local timeout="${2:-$SERVICE_START_TIMEOUT}"
    
    log_info "Запуск службы: $service"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl start "$service" 2>/dev/null
    elif command -v service >/dev/null 2>&1; then
        service "$service" start 2>/dev/null
    else
        log_warn "Неизвестный способ управления службами"
        return 1
    fi
    
    # Ожидание запуска службы
    local count=0
    while [ $count -lt $timeout ]; do
        if is_service_active "$service"; then
            log_ok "Служба $service запущена"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_err "Служба $service не запустилась за $timeout секунд"
    return 1
}

# Остановка службы
stop_service() {
    local service="$1"
    local timeout="${2:-$SERVICE_STOP_TIMEOUT}"
    
    log_info "Остановка службы: $service"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$service" 2>/dev/null
    elif command -v service >/dev/null 2>&1; then
        service "$service" stop 2>/dev/null
    else
        log_warn "Неизвестный способ управления службами"
        return 1
    fi
    
    # Ожидание остановки службы
    local count=0
    while [ $count -lt $timeout ]; do
        if ! is_service_active "$service"; then
            log_ok "Служба $service остановлена"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_warn "Служба $service не остановилась за $timeout секунд"
    return 1
}

# Перезапуск службы
restart_service() {
    local service="$1"
    
    log_info "Перезапуск службы: $service"
    
    stop_service "$service" || true
    sleep 2
    start_service "$service"
}

# ============================================================================
# ФУНКЦИИ ОЧИСТКИ И ОБСЛУЖИВАНИЯ
# ============================================================================

# Очистка временных файлов
cleanup_temp_files() {
    log_info "Очистка временных файлов..."
    
    local temp_dirs=(
        "/tmp"
        "$TEMP_DIR"
    )
    
    local patterns=(
        "*.tmp"
        "*.temp"
        "*.cache"
        "*.log"
        "*.pid"
    )
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [ -d "$temp_dir" ]; then
            for pattern in "${patterns[@]}"; do
                find "$temp_dir" -name "$pattern" -mtime +1 -delete 2>/dev/null || true
            done
        fi
    done
    
    log_ok "Очистка временных файлов завершена"
}

# Очистка кэша пакетов
cleanup_package_cache() {
    log_info "Очистка кэша пакетов..."
    
    case "${SYSTEM_INFO[os]}" in
        "ubuntu"|"debian")
            apt clean 2>/dev/null || true
            apt autoremove -y 2>/dev/null || true
            ;;
        "rhel")
            yum clean all 2>/dev/null || true
            ;;
    esac
    
    log_ok "Очистка кэша пакетов завершена"
}

# Полная очистка системы
full_system_cleanup() {
    log_info "Начинаем полную очистку системы..."
    
    cleanup_temp_files
    cleanup_package_cache
    
    # Очистка логов
    if [ "$ENABLE_DEBUG_LOGGING" = true ]; then
        cleanup_logs 7
    fi
    
    log_ok "Полная очистка системы завершена"
}

# ============================================================================
# ФУНКЦИИ ДИАГНОСТИКИ
# ============================================================================

# Диагностика системы
diagnose_system() {
    echo ""
    echo "🔍 ДИАГНОСТИКА СИСТЕМЫ:"
    echo "================================================"
    
    # Основная информация
    echo "📋 ОСПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ:"
    echo "  ОС: $(uname -s)"
    echo "  Версия ядра: $(uname -r)"
    echo "  Архитектура: $(uname -m)"
    echo "  Имя хоста: $(get_hostname)"
    echo "  IP адрес: $(get_server_ip)"
    echo ""
    
    # Системные ресурсы
    echo "💾 СИСТЕМНЫЕ РЕСУРСЫ:"
    echo "  Загрузка CPU: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    echo "  Использование памяти: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "  Свободное место: $(df -h / | awk 'NR==2 {print $4}')"
    echo ""
    
    # Сетевые соединения
    echo "🌐 СЕТЕВЫЕ СОЕДИНЕНИЯ:"
    echo "  Активные соединения: $(netstat -tuln | wc -l)"
    echo "  Открытые порты:"
    netstat -tlnp | grep LISTEN | head -5 | while read line; do
        echo "    $line"
    done
    echo ""
    
    # Службы
    echo "⚙️ СЛУЖБЫ:"
    local services=("ssh" "nginx" "apache2" "mysql" "postgresql")
    for service in "${services[@]}"; do
        if is_service_active "$service"; then
            echo "  ✅ $service: активна"
        else
            echo "  ❌ $service: неактивна"
        fi
    done
    echo ""
    
    echo "================================================"
}

# ============================================================================
# АВТОМАТИЧЕСКАЯ ИНИЦИАЛИЗАЦИЯ
# ============================================================================

# Автоматическая инициализация при загрузке модуля
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Если скрипт запущен напрямую
    setup_logging
    full_system_check
    diagnose_system
else
    # Если скрипт загружен через source
    setup_logging
fi
