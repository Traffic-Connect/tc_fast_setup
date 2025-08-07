#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Общая библиотека функций
# ============================================================================

# Загрузка конфигурации
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    source "$PROJECT_ROOT/core/configs/configuration.sh"
fi

# Загрузка пользовательской конфигурации если существует
if [ -f "$PROJECT_ROOT/config.local.sh" ]; then
    source "$PROJECT_ROOT/web/configs/config.local.sh"
fi

# Глобальные переменные для отслеживания
INSTALLATION_START_TIME=$(date +%s)
INSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()
ROLLBACK_STACK=()

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log_info() {
    local message="$1"
    echo -e "${BLUE}[Инфо] $message${NC}"
}

log_ok() {
    local message="$1"
    echo -e "${GREEN}[OK] $message${NC}"
}

log_err() {
    local message="$1"
    echo -e "${RED}[ОШИБКА] $message${NC}"
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[ВНИМАНИЕ] $message${NC}"
}

log_debug() {
    local message="$1"
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${BLUE}[DEBUG] $message${NC}"
    fi
}



# ============================================================================
# ФУНКЦИИ БЕЗОПАСНОСТИ
# ============================================================================

# Улучшенная генерация паролей с специальными символами
generate_secure_password() {
    local length=${1:-24}
    local complexity=${2:-"high"}  # low, medium, high
    
    case $complexity in
        "low")
            # Только буквы и цифры
            openssl rand -base64 32 | tr -d "=+/" | cut -c1-$length
            ;;
        "medium")
            # Буквы, цифры и базовые символы
            openssl rand -base64 32 | tr -d "=" | cut -c1-$length
            ;;
        "high"|*)
            # Максимальная сложность с специальными символами
            local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
            local password=""
            
            # Гарантируем наличие разных типов символов
            password+=$(echo $chars | fold -w1 | shuf | head -c1)  # Заглавная буква
            password+=$(echo $chars | fold -w1 | shuf | head -c1)  # Строчная буква
            password+=$(echo $chars | fold -w1 | shuf | head -c1)  # Цифра
            password+=$(echo $chars | fold -w1 | shuf | head -c1)  # Специальный символ
            
            # Дополняем до нужной длины
            local remaining=$((length - 4))
            password+=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-$remaining)
            
            # Перемешиваем
            echo "$password" | fold -w1 | shuf | tr -d '\n'
            ;;
    esac
}

# Проверка сложности пароля
validate_password_strength() {
    local password="$1"
    local min_length=${2:-12}
    
    # Проверка длины
    if [ ${#password} -lt $min_length ]; then
        return 1
    fi
    
    # Проверка наличия разных типов символов
    local has_upper=$(echo "$password" | grep -q '[A-Z]' && echo "1" || echo "0")
    local has_lower=$(echo "$password" | grep -q '[a-z]' && echo "1" || echo "0")
    local has_digit=$(echo "$password" | grep -q '[0-9]' && echo "1" || echo "0")
    local has_special=$(echo "$password" | grep -q '[!@#$%^&*()_+-=\[\]{}|;:,.<>?]' && echo "1" || echo "0")
    
    local score=$((has_upper + has_lower + has_digit + has_special))
    
    [ $score -ge 3 ]
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
# ФУНКЦИИ ПРОВЕРКИ СЛУЖБ
# ============================================================================

check_service() {
    local service_name=$1
    local port=${2:-0}
    local max_attempts=${3:-$SERVICE_START_TIMEOUT}
    local attempt=1
    
    log_info "Проверка службы $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        # Проверка systemd службы
        if systemctl is-active --quiet "$service_name"; then
            # Если указан порт, проверяем веб-интерфейс
            if [ "$port" -gt 0 ]; then
                if curl -s "http://localhost:$port" >/dev/null 2>&1; then
                    log_ok "Служба $service_name работает (порт $port)"
                    return 0
                else
                    log_info "Попытка $attempt/$max_attempts: Веб-интерфейс недоступен, ожидание..."
                    sleep 2
                fi
            else
                log_ok "Служба $service_name работает"
                return 0
            fi
        else
            log_info "Попытка $attempt/$max_attempts: Служба $service_name не запущена, ожидание..."
            sleep 3
        fi
        attempt=$((attempt + 1))
    done
    
    log_err "Служба $service_name не запустилась после $max_attempts попыток"
    journalctl -u "$service_name" -n 20 --no-pager
    return 1
}

# ============================================================================
# ФУНКЦИИ НАСТРОЙКИ ЛОГИРОВАНИЯ
# ============================================================================

setup_logging() {
    mkdir -p "$LOG_DIR"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Основной лог
    exec 1> >(tee -a "$LOG_DIR/install_${timestamp}.log")
    exec 2> >(tee -a "$LOG_DIR/install_error_${timestamp}.log" >&2)
    
    # JSON лог если включен
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        touch "$LOG_DIR/install.json"
        chmod 600 "$LOG_DIR/install.json"
    fi
    
    # Очистка старых логов
    find "$LOG_DIR" -name "*.log" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
}

# ============================================================================
# ФУНКЦИИ СОХРАНЕНИЯ ДАННЫХ
# ============================================================================

save_credentials() {
    local grafana_password=$1
    local admin_user=$2
    local admin_password=$3
    
    # Создаем директорию для логов
    mkdir -p "$LOG_DIR"
    
    # Сохраняем пароли в безопасный файл
    cat > "$CREDENTIALS_FILE" << EOF
# Traffic Connect Server - Данные для входа
# Создано: $(date)
# ВНИМАНИЕ: Храните этот файл в безопасном месте!

Grafana:
  URL: http://$(hostname -I | awk '{print $1}'):$GRAFANA_PORT
  Логин: admin
  Пароль: $grafana_password

Административная панель:
  URL: http://$(hostname -I | awk '{print $1}'):$ADMIN_PORT
  Логин: $admin_user
  Пароль: $admin_password

EOF



    cat >> "$CREDENTIALS_FILE" << EOF
Дополнительные сервисы:
  Prometheus: http://$(hostname -I | awk '{print $1}'):$PROMETHEUS_PORT
  Loki: http://$(hostname -I | awk '{print $1}'):$LOKI_PORT
  Pushgateway: http://$(hostname -I | awk '{print $1}'):$PUSHGATEWAY_PORT

Метрики установки:
  Время начала: $(date -d @$INSTALLATION_START_TIME)
  Установленные компоненты: ${INSTALLED_COMPONENTS[*]}
EOF

    # Устанавливаем безопасные права
    chmod 600 "$CREDENTIALS_FILE"
    log_ok "Пароли сохранены в $CREDENTIALS_FILE"
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



 