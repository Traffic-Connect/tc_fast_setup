#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Общая библиотека функций
# ============================================================================

# Загрузка конфигурации
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    source "$PROJECT_ROOT/core/configs/configuration.sh"
fi

# Загрузка пользовательской конфигурации если существует
if [ -f "$PROJECT_ROOT/web/configs/config.local.sh" ]; then
    source "$PROJECT_ROOT/web/configs/config.local.sh"
fi

# Глобальные переменные для отслеживания
INSTALLATION_START_TIME=$(date +%s)
INSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()
ROLLBACK_STACK=()

# Системные требования
REQUIRED_MEMORY=1024  # 1GB RAM
REQUIRED_DISK_SPACE=5120  # 5GB свободного места

# Цвета для логирования (импортируются из configuration.sh)
# RED, GREEN, YELLOW, BLUE, NC определены в core/configs/configuration.sh

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ (ИСПОЛЬЗУЙТЕ logger.sh)
# ============================================================================

# Функции логирования перенесены в core/utils/logger.sh
# Используйте source "$PROJECT_ROOT/core/utils/logger.sh" для доступа к функциям



# ============================================================================
# ФУНКЦИИ БЕЗОПАСНОСТИ
# ============================================================================

# Функция генерации паролей перенесена в system/security/security_policy.sh
# Используйте generate_compliant_password() для генерации безопасных паролей

# Дополнительные функции безопасности
secure_file_permissions() {
    local file="$1"
    if [ -f "$file" ]; then
        chmod 600 "$file"
        log_info "Установлены безопасные права для $file"
    fi
}

secure_directory_permissions() {
    local dir="$1"
    if [ -d "$dir" ]; then
        chmod 700 "$dir"
        log_info "Установлены безопасные права для директории $dir"
    fi
}

# Функция проверки сложности пароля перенесена в system/security/security_policy.sh
# Используйте validate_password_policy() для проверки паролей согласно политике безопасности

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ ЦЕЛОСТНОСТИ ФАЙЛОВ
# ============================================================================

# Проверка SHA256 хеша файла
verify_file_sha256() {
    local file="$1"
    local expected_hash="$2"
    
    if [ ! -f "$file" ]; then
        log_err "Файл не найден: $file"
        return 1
    fi
    
    if [ -z "$expected_hash" ]; then
        log_warn "Хеш не указан для файла: $file"
        return 0
    fi
    
    local actual_hash=$(sha256sum "$file" | cut -d' ' -f1)
    if [ "$actual_hash" = "$expected_hash" ]; then
        log_ok "Проверка целостности файла прошла успешно: $file"
        return 0
    else
        log_err "Ошибка проверки целостности файла: $file"
        log_err "Ожидаемый хеш: $expected_hash"
        log_err "Фактический хеш: $actual_hash"
        return 1
    fi
}

# Безопасная загрузка файла с проверкой целостности
download_file_with_verification() {
    local url="$1"
    local target_file="$2"
    local expected_hash="$3"
    local retries="${4:-3}"
    
    log_info "Загрузка файла: $url"
    
    # Валидация URL
    if ! validate_url "$url"; then
        log_err "Некорректный URL: $url"
        return 1
    fi
    
    # Попытки загрузки
    for ((i=1; i<=retries; i++)); do
        log_info "Попытка загрузки $i/$retries: $url"
        
        if download_with_retry "$url" "$target_file" "$retries"; then
            # Проверка целостности если указан хеш
            if [ -n "$expected_hash" ]; then
                if verify_file_sha256 "$target_file" "$expected_hash"; then
                    log_ok "Файл успешно загружен и проверен: $target_file"
                    return 0
                else
                    log_warn "Попытка $i/$retries: Ошибка проверки целостности"
                    rm -f "$target_file"
                    if [ $i -lt $retries ]; then
                        sleep 2
                        continue
                    fi
                fi
            else
                log_ok "Файл успешно загружен (без проверки целостности): $target_file"
                return 0
            fi
        fi
        
        if [ $i -lt $retries ]; then
            log_warn "Попытка $i/$retries не удалась, ожидание 2 секунды..."
            sleep 2
        fi
    done
    
    log_err "Не удалось загрузить файл после $retries попыток: $url"
    return 1
}

# ============================================================================
# ФУНКЦИИ ВАЛИДАЦИИ ВХОДНЫХ ДАННЫХ
# ============================================================================

# Валидация имени пользователя
validate_username() {
    local username="$1"
    
    # Проверка длины
    if [ ${#username} -lt 3 ] || [ ${#username} -gt 32 ]; then
        log_err "Имя пользователя должно быть от 3 до 32 символов"
        return 1
    fi
    
    # Проверка допустимых символов
    if ! echo "$username" | grep -qE '^[a-z_][a-z0-9_-]*$'; then
        log_err "Имя пользователя может содержать только строчные буквы, цифры, дефисы и подчеркивания"
        return 1
    fi
    
    # Проверка на зарезервированные имена
    local reserved_names=("root" "admin" "system" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "libuuid" "syslog" "messagebus" "avahi-autoipd" "kernoops" "usbmux" "dnsmasq" "avahi" "speech-dispatcher" "whoopsie" "kernoops" "saned" "pulse" "colord" "hplip" "lightdm" "nvidia-persistenced" "rtkit" "saned" "usbmux" "whoopsie" "systemd-timesync" "systemd-network" "systemd-resolve" "systemd-bus-proxy" "debian-tor" "mysql" "postgres" "redis" "mongodb" "elasticsearch" "kibana" "logstash" "grafana" "prometheus" "loki" "node_exporter" "pushgateway" "fail2ban_exporter" "promtail" "alertmanager" "blackbox_exporter" "trafficadmin" "trafficmetrics" "trafficmonitor" "trafficlogger" "trafficdata" "trafficbackup" "trafficwatch" "trafficguard" "trafficapi" "traffichook" "trafficnode" "trafficpush" "traffictail" "trafficalert" "trafficblackbox" "trafficfail2ban" "trafficsuper" "trafficsystem" "trafficsecure" "trafficrest" "trafficgraphql" "trafficwebhook" "trafficalerts" "hestiaweb" "hestiamail" "hestia-users")
    
    for reserved in "${reserved_names[@]}"; do
        if [[ "$username" == "$reserved" ]]; then
            log_err "Имя пользователя '$username' зарезервировано системой"
            return 1
        fi
    done
    
    return 0
}

# Валидация доменного имени
validate_domain() {
    local domain="$1"
    
    # Проверка длины
    if [ ${#domain} -lt 3 ] || [ ${#domain} -gt 253 ]; then
        log_err "Доменное имя должно быть от 3 до 253 символов"
        return 1
    fi
    
    # Проверка формата
    if ! echo "$domain" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'; then
        log_err "Некорректный формат доменного имени: $domain"
        return 1
    fi
    
    return 0
}

# Валидация IP адреса
validate_ip() {
    local ip="$1"
    
    # Проверка формата IPv4
    if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        # Проверка диапазонов
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
                log_err "Некорректный IP адрес: $ip"
                return 1
            fi
        done
        return 0
    fi
    
    # Проверка формата IPv6 (базовая)
    if echo "$ip" | grep -qE '^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$'; then
        return 0
    fi
    
    log_err "Некорректный формат IP адреса: $ip"
    return 1
}

# Валидация порта
validate_port() {
    local port="$1"
    
    # Проверка что это число
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_err "Порт должен быть числом: $port"
        return 1
    fi
    
    # Проверка диапазона
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_err "Порт должен быть в диапазоне 1-65535: $port"
        return 1
    fi
    
    return 0
}

# Валидация пути к файлу
validate_file_path() {
    local path="$1"
    
    # Проверка длины
    if [ ${#path} -gt 4096 ]; then
        log_err "Путь слишком длинный: $path"
        return 1
    fi
    
    # Проверка на опасные символы
    if echo "$path" | grep -q '[<>:"|?*]'; then
        log_err "Путь содержит недопустимые символы: $path"
        return 1
    fi
    
    # Проверка на попытки выхода за пределы директории
    if echo "$path" | grep -q '\.\.'; then
        log_err "Путь содержит попытку выхода за пределы директории: $path"
        return 1
    fi
    
    return 0
}

# ============================================================================
# ФУНКЦИИ ПОЛУЧЕНИЯ СИСТЕМНОЙ ИНФОРМАЦИИ
# ============================================================================

# Получение IP адреса сервера
get_server_ip() {
    local interface="${1:-}"
    
    if [ -n "$interface" ]; then
        # Получение IP для конкретного интерфейса
        ip addr show "$interface" 2>/dev/null | grep -oP 'inet \K\S+' | head -1
    else
        # Получение основного IP сервера
        hostname -I | awk '{print $1}'
    fi
}

# Получение всех IP адресов сервера
get_all_server_ips() {
    hostname -I
}

# Получение внешнего IP адреса
get_external_ip() {
    local timeout=10
    local retries=3
    
    # Проверка сетевого подключения
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_warn "Нет подключения к интернету"
        echo "Нет подключения к интернету"
        return 1
    fi
    
    # Попытка получения IP с таймаутами и повторами
    for ((i=1; i<=retries; i++)); do
        log_info "Попытка получения внешнего IP $i/$retries..."
        
        # Попытка через ipinfo.io
        local ip=$(curl -s --max-time $timeout --connect-timeout 5 https://ipinfo.io/ip 2>/dev/null)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
        
        # Попытка через ifconfig.me
        ip=$(curl -s --max-time $timeout --connect-timeout 5 https://ifconfig.me 2>/dev/null)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
        
        # Попытка через icanhazip.com
        ip=$(curl -s --max-time $timeout --connect-timeout 5 https://icanhazip.com 2>/dev/null)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
        
        if [ $i -lt $retries ]; then
            log_warn "Попытка $i не удалась, ожидание 2 секунды..."
            sleep 2
        fi
    done
    
    log_err "Не удалось получить внешний IP после $retries попыток"
    echo "Не удалось получить внешний IP"
    return 1
}

# ============================================================================
# ФУНКЦИИ ОБРАБОТКИ ОШИБОК И ROLLBACK
# ============================================================================

# Улучшенная обработка ошибок
check_error() {
    local exit_code=$?
    local message="$1"
    local component="${2:-unknown}"
    local suggestion="${3:-Проверьте логи для получения дополнительной информации}"
    
    if [ $exit_code -ne 0 ]; then
        log_err "$message (код: $exit_code)"
        FAILED_COMPONENTS+=("$component")
        
        # Логируем детальную информацию об ошибке
        log_err "Компонент: $component, Код ошибки: $exit_code"
        
        if [[ "$ENABLE_ROLLBACK" == "true" ]]; then
            log_info "Автоматический rollback отключен"
        fi
        return 1
    else
        log_ok "$message"
        INSTALLED_COMPONENTS+=("$component")
        return 0
    fi
}



# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ СИСТЕМЫ
# ============================================================================

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_err "Этот скрипт должен быть запущен от имени root"
        exit 1
    fi
}

check_internet() {
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_err "Нет подключения к интернету"
        exit 1
    fi
}

check_disk_space() {
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ $available_space -lt $REQUIRED_DISK_SPACE ]; then
        log_err "Недостаточно места на диске. Требуется: ${REQUIRED_DISK_SPACE}MB, доступно: ${available_space}MB"
        exit 1
    fi
}

# Расширенная проверка системных требований
check_system_requirements() {
    log_info "Проверка системных требований..."
    
    # Проверка памяти
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    if [ $available_memory -lt $REQUIRED_MEMORY ]; then
        log_err "Недостаточно памяти. Требуется: ${REQUIRED_MEMORY}MB, доступно: ${available_memory}MB"
        return 1
    fi
    
    # Проверка места на диске
    local available_disk=$(df / | awk 'NR==2 {print $4}')
    if [ $available_disk -lt $REQUIRED_DISK_SPACE ]; then
        log_err "Недостаточно места на диске. Требуется: ${REQUIRED_DISK_SPACE}MB, доступно: ${available_disk}MB"
        return 1
    fi
    
    # Проверка архитектуры
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_err "Неподдерживаемая архитектура: $arch. Требуется x86_64"
        return 1
    fi
    
    # Проверка ОС
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
            log_err "Неподдерживаемая ОС: $ID. Требуется Ubuntu или Debian"
            return 1
        fi
        
        if [[ "$VERSION_ID" < "20" ]]; then
            log_warn "Рекомендуется Ubuntu 20.04 или новее. Текущая версия: $VERSION_ID"
        fi
    fi
    
    log_ok "Системные требования выполнены"
    return 0
}

# Проверка доступности портов
check_port_availability() {
    local port="$1"
    local service_name="${2:-unknown}"
    
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        log_warn "Порт $port уже занят службой $service_name"
        return 1
    fi
    
    return 0
}





# ============================================================================
# ФУНКЦИИ ЗАГРУЗКИ И КЭШИРОВАНИЯ
# ============================================================================

# Проверка URL
validate_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        log_err "Некорректный URL: $url"
        return 1
    fi
}

# Проверка целостности файла
verify_file_integrity() {
    local file="$1"
    local expected_hash="$2"
    
    if [ -z "$expected_hash" ]; then
        log_warn "Хеш не указан, пропускаем проверку целостности"
        return 0
    fi
    
    if [ ! -f "$file" ]; then
        log_err "Файл не найден: $file"
        return 1
    fi
    
    local actual_hash=$(sha256sum "$file" | cut -d' ' -f1)
    if [ "$actual_hash" = "$expected_hash" ]; then
        log_ok "Проверка целостности файла прошла успешно"
        return 0
    else
        log_err "Ошибка проверки целостности файла"
        log_err "Ожидаемый хеш: $expected_hash"
        log_err "Фактический хеш: $actual_hash"
        return 1
    fi
}

download_with_retry() {
    local url=$1
    local target_file=$2
    local retries=${3:-$CURL_RETRIES}
    
    # Валидация URL
    validate_url "$url" || return 1
    
    for ((i=1; i<=retries; i++)); do
        log_info "Попытка загрузки $i/$retries: $url"
        
        if curl -L --connect-timeout 10 --max-time "$CURL_TIMEOUT" \
           --progress-bar "$url" -o "$target_file"; then
            log_ok "Файл успешно загружен: $target_file"
            return 0
        fi
        
        if [ $i -lt $retries ]; then
            log_warn "Попытка $i/$retries не удалась, ожидание $CURL_RETRY_DELAY секунд..."
            sleep "$CURL_RETRY_DELAY"
        fi
    done
    
    log_err "Не удалось загрузить файл после $retries попыток: $url"
    return 1
}

download_with_cache_and_verify() {
    local url=$1
    local target_file=$2
    local expected_hash=$3
    local cache_file="$CACHE_DIR/$(basename "$target_file")"
    
    # Создание кэш директории
    mkdir -p "$CACHE_DIR"
    
    # Проверка кэша
    if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt $CACHE_TTL ]]; then
        log_info "Использование кэшированного файла: $cache_file"
        cp "$cache_file" "$target_file"
        
        if verify_file_integrity "$target_file" "$expected_hash"; then
            return 0
        else
            log_warn "Кэшированный файл поврежден, загружаем заново"
            rm -f "$target_file" "$cache_file"
        fi
    fi
    
    # Загрузка и кэширование
    if download_with_retry "$url" "$target_file"; then
        if verify_file_integrity "$target_file" "$expected_hash"; then
            cp "$target_file" "$cache_file"
            log_info "Файл закэширован: $cache_file"
            return 0
        else
            log_err "Ошибка проверки целостности загруженного файла"
            return 1
        fi
    fi
    
    return 1
}





# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ СЛУЖБ (ПЕРЕНЕСЕНЫ В service_manager.sh)
# ============================================================================

# Функции проверки служб перенесены в core/managers/service_manager.sh
# Используйте source "$PROJECT_ROOT/core/managers/service_manager.sh" для доступа к функциям:
# - check_service_status_universal()
# - is_service_active()
# - is_service_active_verbose()
# - check_service_status_extended()

# ============================================================================
# ФУНКЦИИ НАСТРОЙКИ ЛОГИРОВАНИЯ
# ============================================================================

# setup_logging() - функция перенесена в core/utils/logger.sh
# Используйте source "$PROJECT_ROOT/core/utils/logger.sh" для доступа к функции

# ============================================================================
# ФУНКЦИИ СОХРАНЕНИЯ ДАННЫХ
# ============================================================================

save_credentials() {
    local grafana_password=$1
    local admin_user=$2
    local admin_password=$3
    
    # Создаем директорию для логов
    mkdir -p "$LOG_DIR"
    
    # Создаем безопасную директорию для учетных данных
    local secure_dir="/root/.traffic_connect"
    mkdir -p "$secure_dir"
    chmod 700 "$secure_dir"
    
    # Загружаем политику безопасности для оценки паролей
    if [ -f "$PROJECT_ROOT/system/security/security_policy.sh" ]; then
        source "$PROJECT_ROOT/system/security/security_policy.sh"
    fi
    
    # Сохраняем пароли в безопасный файл согласно политике безопасности
    local secure_creds_file="$secure_dir/credentials.txt"
    cat > "$secure_creds_file" << EOF
# Traffic Connect Server - Данные для входа (согласно политике безопасности)
# Создано: $(date)
# ВНИМАНИЕ: Храните этот файл в безопасном месте!
# Файл автоматически удалится через 24 часа!

Grafana (TrafficMetrics):
  URL: http://$(get_server_ip):$GRAFANA_PORT
  Логин: $GRAFANA_USERNAME
  Пароль: $grafana_password
  Сложность: $(assess_password_strength "$grafana_password" | cut -d' ' -f1)

Административная панель (TrafficAdmin):
  URL: http://$(get_server_ip):$ADMIN_PORT
  Логин: $admin_user
  Пароль: $admin_password
  Сложность: $(assess_password_strength "$admin_password" | cut -d' ' -f1)

EOF



    cat >> "$CREDENTIALS_FILE" << EOF
Дополнительные сервисы:
  Prometheus: http://$(get_server_ip):$PROMETHEUS_PORT
  Loki: http://$(get_server_ip):$LOKI_PORT
  Pushgateway: http://$(get_server_ip):$PUSHGATEWAY_PORT

Метрики установки:
  Время начала: $(date -d @$INSTALLATION_START_TIME)
  Установленные компоненты: ${INSTALLED_COMPONENTS[*]}
EOF

    # Устанавливаем безопасные права
    chmod 600 "$secure_creds_file"
    
    # Создаем символическую ссылку для совместимости
    ln -sf "$secure_creds_file" "$CREDENTIALS_FILE"
    
    # Настраиваем автоматическое удаление через 24 часа
    echo "rm -f '$secure_creds_file'" | at now + 24 hours 2>/dev/null || true
    
    log_ok "Пароли сохранены в $secure_creds_file"
    log_warn "Файл автоматически удалится через 24 часа!"
    log_warn "Измените пароли после установки!"
}





get_status_icon() {
    local value=$1
    if [ $(echo "$value < 70" | bc 2>/dev/null || echo "0") -eq 1 ]; then
        echo "[OK] Норма"
    elif [ $(echo "$value < 90" | bc 2>/dev/null || echo "0") -eq 1 ]; then
        echo "[!] Высоко"
    else
        echo "[X] Критично"
    fi
}





# ============================================================================
# ФУНКЦИИ УТИЛИТЫ
# ============================================================================

dir_exists() { 
    [ -d "$1" ] 
}

safe_rm() { 
    [ -e "$1" ] && rm -rf "$1" 
}

# ============================================================================
# ОТОБРАЖЕНИЕ ДАННЫХ ДЛЯ ВХОДА (ИСПОЛЬЗУЙТЕ traffic_manager_new.sh)
# ============================================================================

# show_access_credentials() - функция перенесена в traffic_manager_new.sh
# Используйте source "$PROJECT_ROOT/traffic_manager_new.sh" для доступа к функции