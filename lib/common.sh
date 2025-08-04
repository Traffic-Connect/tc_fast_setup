#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Общая библиотека функций
# ============================================================================

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/config.sh"

# Загрузка пользовательской конфигурации если существует
if [ -f "$PROJECT_ROOT/$USER_CONFIG_FILE" ]; then
    source "$PROJECT_ROOT/$USER_CONFIG_FILE"
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
    log_json "INFO" "$message"
}

log_ok() {
    local message="$1"
    echo -e "${GREEN}[OK] $message${NC}"
    log_json "INFO" "$message"
}

log_err() {
    local message="$1"
    echo -e "${RED}[ОШИБКА] $message${NC}"
    log_json "ERROR" "$message"
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[ВНИМАНИЕ] $message${NC}"
    log_json "WARN" "$message"
}

log_debug() {
    local message="$1"
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${BLUE}[DEBUG] $message${NC}"
        log_json "DEBUG" "$message"
    fi
}

# Структурированное JSON логирование
log_json() {
    if [[ "$ENABLE_JSON_LOGGING" == "true" && "$LOG_FORMAT" == "JSON" ]]; then
        local level="$1"
        local message="$2"
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local component="${3:-installer}"
        
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"component\":\"$component\",\"message\":\"$message\"}" >> "$LOG_DIR/install.json"
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
        
        # Показываем детальную информацию об ошибке
        show_error_details "$exit_code" "$component" "$suggestion"
        
        if [[ "$ENABLE_ROLLBACK" == "true" ]]; then
            log_info "Выполняется автоматический rollback компонента $component..."
            rollback_component "$component"
        fi
        return 1
    else
        log_ok "$message"
        INSTALLED_COMPONENTS+=("$component")
        return 0
    fi
}

# Детальный rollback для каждого компонента
rollback_component() {
    local component="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_warn "Выполняется откат компонента: $component"
    echo "$timestamp: ROLLBACK $component" >> "$ROLLBACK_LOG"
    
    case $component in
        "grafana")
            systemctl stop grafana-server 2>/dev/null || true
            apt remove -y grafana 2>/dev/null || true
            rm -rf /etc/grafana /var/lib/grafana 2>/dev/null || true
            ;;
        "prometheus")
            systemctl stop prometheus 2>/dev/null || true
            rm -rf /etc/prometheus /var/lib/prometheus /usr/local/bin/prometheus 2>/dev/null || true
            userdel prometheus 2>/dev/null || true
            ;;
        "loki")
            systemctl stop loki 2>/dev/null || true
            rm -rf /etc/loki /var/lib/loki /usr/local/bin/loki 2>/dev/null || true
            userdel loki 2>/dev/null || true
            ;;
        "promtail")
            systemctl stop promtail 2>/dev/null || true
            rm -rf /etc/promtail /usr/local/bin/promtail 2>/dev/null || true
            userdel promtail 2>/dev/null || true
            ;;
        "node_exporter")
            systemctl stop node_exporter 2>/dev/null || true
            rm -f /usr/local/bin/node_exporter 2>/dev/null || true
            userdel node_exporter 2>/dev/null || true
            ;;
        "pushgateway")
            systemctl stop pushgateway 2>/dev/null || true
            rm -f /usr/local/bin/pushgateway 2>/dev/null || true
            userdel pushgateway 2>/dev/null || true
            ;;
        "hestia")
            systemctl stop hestia 2>/dev/null || true
            # Не удаляем Hestia полностью, только останавливаем
            ;;
        "templates")
            rm -f /usr/local/hestia/data/templates/web/nginx/tc-*.tpl 2>/dev/null || true
            rm -f /usr/local/hestia/data/templates/web/nginx/tc-*.stpl 2>/dev/null || true
            ;;
        *)
            log_warn "Неизвестный компонент для отката: $component"
            ;;
    esac
    
    log_ok "Откат компонента $component завершен"
}

# Полный rollback установки
rollback_installation() {
    log_err "Выполняется полный откат установки..."
    
    # Создаем резервную копию логов
    mkdir -p "$BACKUP_DIR"
    cp -r "$LOG_DIR" "$BACKUP_DIR/logs_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    
    # Откатываем компоненты в обратном порядке
    for component in $(printf '%s\n' "${INSTALLED_COMPONENTS[@]}" | tac); do
        rollback_component "$component"
    done
    
    # Очистка временных файлов
    rm -rf /tmp/grafana.deb /tmp/prometheus.tar.gz /tmp/loki.zip /tmp/promtail.zip 2>/dev/null || true
    
    log_info "Полный откат завершен. Логи сохранены в $BACKUP_DIR"
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
        
        if [[ "$VERSION_ID" < "20.04" ]]; then
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
# ФУНКЦИИ ВАЛИДАЦИИ
# ============================================================================

validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        log_err "Некорректный email: $email"
        return 1
    fi
    return 0
}

validate_username() {
    local username=$1
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        log_err "Некорректное имя пользователя: $username (должно содержать только строчные буквы, цифры, _ и -)"
        return 1
    fi
    return 0
}

validate_url() {
    local url=$1
    [[ "$url" =~ ^https?:// ]] || {
        log_err "Некорректный URL: $url"
        return 1
    }
    
    if [[ "$SSL_VERIFY" == "true" ]]; then
        curl -s --head "$url" >/dev/null 2>&1 || {
            log_err "URL недоступен: $url"
            return 1
        }
    fi
}

# ============================================================================
# ФУНКЦИИ БЕЗОПАСНОСТИ И ПРОВЕРКИ
# ============================================================================

verify_file_integrity() {
    local file_path=$1
    local expected_hash=$2
    
    if [[ "$VERIFY_CHECKSUMS" == "true" ]]; then
        if [[ ! -f "$file_path" ]]; then
            log_err "Файл не найден: $file_path"
            return 1
        fi
        
        local actual_hash=$(sha256sum "$file_path" | cut -d' ' -f1)
        [[ "$actual_hash" == "$expected_hash" ]] || {
            log_err "Ошибка проверки целостности файла: $file_path"
            log_err "Ожидаемый хеш: $expected_hash"
            log_err "Фактический хеш: $actual_hash"
            return 1
        }
        
        log_ok "Проверка целостности файла пройдена: $file_path"
    fi
}

# GPG проверка подписи
verify_gpg_signature() {
    local file_path=$1
    local signature_path=$2
    
    if [[ "$GPG_VERIFY" == "true" ]]; then
        if [[ -f "$signature_path" ]]; then
            if gpg --verify "$signature_path" "$file_path" 2>/dev/null; then
                log_ok "GPG подпись проверена: $file_path"
                return 0
            else
                log_err "Ошибка проверки GPG подписи: $file_path"
                return 1
            fi
        else
            log_warn "Файл подписи не найден: $signature_path"
        fi
    fi
    
    return 0
}

# ============================================================================
# ФУНКЦИИ ЗАГРУЗКИ И КЭШИРОВАНИЯ
# ============================================================================

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
# ФУНКЦИИ МОНИТОРИНГА И МЕТРИК
# ============================================================================

# Отслеживание времени установки компонентов
track_installation_time() {
    local component=$1
    local start_time=$2
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        echo "$component: $duration seconds" >> "$LOG_DIR/installation_metrics.log"
        log_json "INFO" "Component $component installed in ${duration}s" "metrics"
    fi
}

# Метрики производительности системы
collect_system_metrics() {
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        local timestamp=$(date +%s)
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        local memory_usage=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
        local disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
        
        echo "{\"timestamp\":$timestamp,\"cpu\":$cpu_usage,\"memory\":$memory_usage,\"disk\":$disk_usage}" >> "$LOG_DIR/system_metrics.json"
    fi
}

# ============================================================================
# ФУНКЦИИ ОПТИМИЗАЦИИ ПРОИЗВОДИТЕЛЬНОСТИ
# ============================================================================

# Параллельная установка с ограничением
install_components_parallel() {
    local components=("$@")
    local pids=()
    local results=()
    local failed_components=()
    local max_jobs=${MAX_PARALLEL_JOBS:-4}
    
    log_info "Запуск параллельной установки ${#components[@]} компонентов (макс. $max_jobs одновременно)..."
    
    # Функция для ограничения параллельных процессов
    parallel_install() {
        local component=$1
        local start_time=$(date +%s)
        
        log_info "Запуск установки: $component"
        if install_$component; then
            track_installation_time "$component" "$start_time"
            log_ok "Компонент $component установлен успешно"
            return 0
        else
            log_err "Ошибка установки компонента $component"
            return 1
        fi
    }
    
    # Запуск установки компонентов с ограничением
    for component in "${components[@]}"; do
        # Ожидание освобождения слота
        while [ ${#pids[@]} -ge $max_jobs ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 ${pids[$i]} 2>/dev/null; then
                    unset pids[$i]
                    unset results[$i]
                fi
            done
            sleep 1
        done
        
        # Запуск нового процесса
        parallel_install "$component" &
        pids+=($!)
        results+=("$component")
    done
    
    # Ожидание завершения всех процессов
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local component=${results[$i]}
        
        if wait $pid; then
            log_ok "Компонент $component установлен успешно"
        else
            log_err "Ошибка установки компонента $component"
            failed_components+=("$component")
        fi
    done
    
    # Проверка результатов
    if [ ${#failed_components[@]} -gt 0 ]; then
        log_err "Следующие компоненты не установлены: ${failed_components[*]}"
        return 1
    else
        log_ok "Все компоненты установлены успешно"
        return 0
    fi
}

# Оптимизированная установка мониторинга
install_monitoring_parallel() {
    log_info "Параллельная установка компонентов мониторинга..."
    
    # Группируем компоненты по зависимостям
    local independent_components=("grafana" "node_exporter" "pushgateway")
    local dependent_components=("prometheus" "loki")
    
    # Устанавливаем независимые компоненты параллельно
    install_components_parallel "${independent_components[@]}"
    
    # Устанавливаем зависимые компоненты
    for component in "${dependent_components[@]}"; do
        local start_time=$(date +%s)
        install_$component
        track_installation_time "$component" "$start_time"
    done
    
    # Проверка результатов
    local services=("grafana-server" "prometheus" "loki" "node_exporter" "pushgateway")
    for service in "${services[@]}"; do
        check_service "$service"
    done
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
    local hestia_user=$2
    local hestia_password=$3
    
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

Hestia Control Panel:
  URL: http://$(hostname -I | awk '{print $1}'):$HESTIA_PORT
  Логин: $hestia_user
  Пароль: $hestia_password

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

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ ЗАВЕРШЕНИЯ
# ============================================================================

verify_installation() {
    local services=("grafana-server" "prometheus" "loki" "promtail" "node_exporter" "pushgateway")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_err "Следующие сервисы не запущены: ${failed_services[*]}"
        return 1
    else
        log_ok "Все сервисы запущены успешно"
        return 0
    fi
}

# ============================================================================
# ВИЗУАЛИЗАЦИЯ И ПРОГРЕСС
# ============================================================================

# Прогресс-бары и анимации
show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%%" $percentage
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r[%c] Загрузка..." "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r   \r"
}

# Статусные индикаторы
show_status() {
    local status=$1
    local message=$2
    
    case $status in
        "success")
            echo -e "✅ ${GREEN}$message${NC}"
            ;;
        "error")
            echo -e "❌ ${RED}$message${NC}"
            ;;
        "warning")
            echo -e "⚠️  ${YELLOW}$message${NC}"
            ;;
        "info")
            echo -e "ℹ️  ${BLUE}$message${NC}"
            ;;
        "loading")
            echo -e "⏳ ${BLUE}$message${NC}"
            ;;
    esac
}

# Цветные таблицы и статистика
show_table() {
    local title="$1"
    shift
    local headers=("$@")
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    $title                    ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    
    # Заголовки
    printf "║"
    for header in "${headers[@]}"; do
        printf " %-20s ║" "$header"
    done
    printf "\n"
    
    echo "╠══════════════════════════════════════════════════════════╣"
}

show_system_stats() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    show_table "📊 СТАТИСТИКА СИСТЕМЫ" "Компонент" "Использование" "Статус"
    
    printf "║ %-20s ║ %-20s ║ %-20s ║\n" "CPU" "${cpu_usage}%" "$(get_status_icon $cpu_usage)"
    printf "║ %-20s ║ %-20s ║ %-20s ║\n" "Память" "${mem_usage}%" "$(get_status_icon $mem_usage)"
    printf "║ %-20s ║ %-20s ║ %-20s ║\n" "Диск" "${disk_usage}%" "$(get_status_icon $disk_usage)"
    
    echo "╚══════════════════════════════════════════════════════════╝"
}

get_status_icon() {
    local value=$1
    if [ $(echo "$value < 70" | bc 2>/dev/null || echo "0") -eq 1 ]; then
        echo "✅ Норма"
    elif [ $(echo "$value < 90" | bc 2>/dev/null || echo "0") -eq 1 ]; then
        echo "⚠️  Высоко"
    else
        echo "❌ Критично"
    fi
}

# Анимированные уведомления
show_notification() {
    local type=$1
    local message=$2
    local duration=${3:-3}
    
    case $type in
        "success")
            local icon="✅"
            local color=$GREEN
            ;;
        "error")
            local icon="❌"
            local color=$RED
            ;;
        "warning")
            local icon="⚠️"
            local color=$YELLOW
            ;;
        "info")
            local icon="ℹ️"
            local color=$BLUE
            ;;
    esac
    
    echo -e "$icon ${color}$message${NC}"
    
    # Анимация исчезновения
    for i in $(seq $duration -1 1); do
        printf "\r%*s" $(tput cols) ""
        printf "\r$icon ${color}$message${NC} (исчезнет через $i сек)"
        sleep 1
    done
    printf "\r%*s" $(tput cols) ""
}

# Детальные сообщения об ошибках
show_error_details() {
    local error_code=$1
    local component=$2
    local suggestion=$3
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    ❌ ОШИБКА УСТАНОВКИ ❌                ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ Компонент: $component"
    echo "║ Код ошибки: $error_code"
    echo "║ Время: $(date)"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ 💡 РЕКОМЕНДАЦИЯ:"
    echo "║ $suggestion"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

# Улучшенный вывод команд
show_command_output() {
    local command="$1"
    local description="$2"
    
    echo ""
    echo "🔧 Выполнение: $description"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║ Команда: $command"
    echo "╠══════════════════════════════════════════════════════════╣"
    
    # Выполнение команды с цветным выводом
    if eval "$command" 2>&1 | while IFS= read -r line; do
        echo "║ $line"
    done; then
        echo "╚══════════════════════════════════════════════════════════╝"
        echo "✅ Команда выполнена успешно"
    else
        echo "╚══════════════════════════════════════════════════════════╝"
        echo "❌ Ошибка выполнения команды"
        return 1
    fi
}

# Финальный отчет с визуализацией
show_installation_report() {
    local install_time=$(( $(date +%s) - INSTALLATION_START_TIME ))
    local minutes=$((install_time / 60))
    local seconds=$((install_time % 60))
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                🎉 УСТАНОВКА ЗАВЕРШЕНА! 🎉                ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ 📊 СТАТИСТИКА:"
    echo "║    • Время установки: ${minutes}м ${seconds}с"
    echo "║    • Установлено компонентов: ${#INSTALLED_COMPONENTS[@]}"
    echo "║    • Ошибок: ${#FAILED_COMPONENTS[@]}"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ 🌐 ДОСТУПНЫЕ СЕРВИСЫ:"
    echo "║    • HestiaCP: http://$(hostname -I | awk '{print $1}'):$HESTIA_PORT"
    echo "║    • Grafana: http://$(hostname -I | awk '{print $1}'):$GRAFANA_PORT"
    echo "║    • Prometheus: http://$(hostname -I | awk '{print $1}'):$PROMETHEUS_PORT"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
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

show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%%" $percentage
}

# Функция для получения версии компонента
get_version() {
    local component="$1"
    case $component in
        "GRAFANA") echo "$GRAFANA_VERSION" ;;
        "PROMETHEUS") echo "$PROMETHEUS_VERSION" ;;
        "LOKI") echo "$LOKI_VERSION" ;;
        "NODE_EXPORTER") echo "$NODE_EXPORTER_VERSION" ;;
        "PUSHGATEWAY") echo "$PUSHGATEWAY_VERSION" ;;
        *) echo "" ;;
    esac
}

# Функция для создания заглушек установки (для тестирования)
install_grafana() {
    log_info "Установка Grafana..."
    sleep 2  # Имитация установки
    log_ok "Grafana установлен"
}

install_prometheus() {
    log_info "Установка Prometheus..."
    sleep 2  # Имитация установки
    log_ok "Prometheus установлен"
}

install_loki() {
    log_info "Установка Loki..."
    sleep 2  # Имитация установки
    log_ok "Loki установлен"
}

install_node_exporter() {
    log_info "Установка Node Exporter..."
    sleep 2  # Имитация установки
    log_ok "Node Exporter установлен"
}

install_pushgateway() {
    log_info "Установка Pushgateway..."
    sleep 2  # Имитация установки
    log_ok "Pushgateway установлен"
} 