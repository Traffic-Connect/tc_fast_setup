#!/bin/bash
# ============================================================================
# Traffic Connect Server - Политика безопасности
# ============================================================================
# Этот файл содержит политики безопасности, парольные требования
# и нестандартные логины для всех модулей системы
# Требует Ubuntu/Debian для корректной работы

# Проверка операционной системы
check_ubuntu_compatibility() {
    if [ ! -f /etc/os-release ]; then
        echo "Ошибка: Не удалось определить операционную систему"
        return 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        echo "Ошибка: Данный скрипт предназначен для Ubuntu/Debian. Текущая ОС: $ID"
        return 1
    fi
    
    # Проверка наличия необходимых команд
    local required_commands=("shuf" "openssl" "grep" "sed" "awk")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Ошибка: Команда $cmd не найдена"
            return 1
        fi
    done
    
    return 0
}

# Выполняем проверку совместимости
if ! check_ubuntu_compatibility; then
    exit 1
fi

# ============================================================================
# ПАРОЛЬНАЯ ПОЛИТИКА
# ============================================================================

# Минимальная длина паролей
MIN_PASSWORD_LENGTH=12
RECOMMENDED_PASSWORD_LENGTH=18
MAX_PASSWORD_LENGTH=24

# Сложность паролей
PASSWORD_COMPLEXITY_REQUIREMENTS=(
    "uppercase"      # Заглавные буквы (A-Z)
    "lowercase"      # Строчные буквы (a-z)
    "digits"         # Цифры (0-9)
    "special"        # Специальные символы (!@#$%^&*()_+-=[]{}|;:,.<>?)
    "no_common"      # Запрет общих паролей
    "no_sequential"  # Запрет последовательных символов
    "no_repeating"   # Запрет повторяющихся символов
)

# Специальные символы для паролей
PASSWORD_SPECIAL_CHARS="!@#$%^&*()_+-=[]{}|;:,.<>?"

# Запрещенные пароли (общие и слабые)
FORBIDDEN_PASSWORDS=(
    "password" "123456" "qwerty" "admin" "root"
    "traffic" "connect" "server" "system" "user"
    "test" "demo" "guest" "default" "changeme"
    "password123" "admin123" "root123" "user123"
    "trafficconnect" "traffic123" "connect123"
)

# ============================================================================
# НЕСТАНДАРТНЫЕ ЛОГИНЫ ДЛЯ МОДУЛЕЙ
# ============================================================================

# Основные логины системы (нестандартные)
declare -A SYSTEM_LOGINS=(
    ["admin_panel"]="TrafficAdmin"
    ["grafana"]="TrafficMetrics"
    ["prometheus"]="TrafficMonitor"
    ["loki"]="TrafficLogger"
    ["database"]="TrafficData"
    ["backup"]="TrafficBackup"
    ["monitoring"]="TrafficWatch"
    ["security"]="TrafficGuard"
    ["api"]="TrafficAPI"
    ["webhook"]="TrafficHook"
)

# Логины для различных сервисов мониторинга
declare -A MONITORING_LOGINS=(
    ["node_exporter"]="TrafficNode"
    ["pushgateway"]="TrafficPush"
    ["promtail"]="TrafficTail"
    ["alertmanager"]="TrafficAlert"
    ["blackbox_exporter"]="TrafficBlackbox"
    ["fail2ban_exporter"]="TrafficFail2Ban"
)

# Логины для административных функций
declare -A ADMIN_LOGINS=(
    ["super_admin"]="TrafficSuper"
    ["system_admin"]="TrafficSystem"
    ["security_admin"]="TrafficSecure"
    ["monitoring_admin"]="TrafficMonitor"
    ["backup_admin"]="TrafficBackup"
    ["api_admin"]="TrafficAPI"
)

# Логины для API и интеграций
API_LOGINS_rest_api="TrafficREST"
API_LOGINS_graphql_api="TrafficGraphQL"
API_LOGINS_webhook_api="TrafficWebhook"
API_LOGINS_metrics_api="TrafficMetrics"
API_LOGINS_logs_api="TrafficLogs"
API_LOGINS_alerts_api="TrafficAlerts"

# ============================================================================
# ФУНКЦИИ ГЕНЕРАЦИИ БЕЗОПАСНЫХ ПАРОЛЕЙ
# ============================================================================

# Генерация пароля с учетом политики безопасности
generate_compliant_password() {
    local length=${1:-$RECOMMENDED_PASSWORD_LENGTH}
    local complexity=${2:-"high"}
    
    # Проверка минимальной длины
    if [ "$length" -lt "$MIN_PASSWORD_LENGTH" ]; then
        length=$MIN_PASSWORD_LENGTH
    fi
    
    # Проверка максимальной длины
    if [ "$length" -gt "$MAX_PASSWORD_LENGTH" ]; then
        length=$MAX_PASSWORD_LENGTH
    fi
    
    case $complexity in
        "low")
            # Минимальная сложность: буквы + цифры
            generate_basic_password "$length"
            ;;
        "medium")
            # Средняя сложность: буквы + цифры + базовые символы
            generate_medium_password "$length"
            ;;
        "high"|*)
            # Высокая сложность: все типы символов
            generate_high_complexity_password "$length"
            ;;
    esac
}

# Генерация базового пароля
generate_basic_password() {
    local length=$1
    local password=""
    
    # Гарантируем наличие заглавной и строчной буквы, цифры
    password+=$(echo {A..Z} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo {a..z} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo {0..9} | tr ' ' '\n' | shuf | head -c1)
    
    # Дополняем случайными символами
    local remaining=$((length - 3))
    password+=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-$remaining)
    
    # Перемешиваем
    echo "$password" | fold -w1 | shuf | tr -d '\n'
}

# Генерация пароля средней сложности
generate_medium_password() {
    local length=$1
    local password=""
    
    # Гарантируем наличие всех типов символов
    password+=$(echo {A..Z} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo {a..z} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo {0..9} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo "!@#$%^&*" | fold -w1 | shuf | head -c1)
    
    # Дополняем случайными символами
    local remaining=$((length - 4))
    password+=$(openssl rand -base64 32 | tr -d "=" | cut -c1-$remaining)
    
    # Перемешиваем
    echo "$password" | fold -w1 | shuf | tr -d '\n'
}

# Генерация пароля высокой сложности
generate_high_complexity_password() {
    local length=$1
    local password=""
    
    # Гарантируем наличие всех типов символов
    password+=$(echo {A..Z} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo {a..z} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo {0..9} | tr ' ' '\n' | shuf | head -c1)
    password+=$(echo "$PASSWORD_SPECIAL_CHARS" | fold -w1 | shuf | head -c1)
    
    # Дополняем случайными символами из всех категорий
    local remaining=$((length - 4))
    local all_chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789$PASSWORD_SPECIAL_CHARS"
    
    for ((i=0; i<remaining; i++)); do
        password+=$(echo "$all_chars" | fold -w1 | shuf | head -c1)
    done
    
    # Перемешиваем
    echo "$password" | fold -w1 | shuf | tr -d '\n'
}

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ ПАРОЛЕЙ
# ============================================================================

# Проверка соответствия пароля политике безопасности
validate_password_policy() {
    local password="$1"
    local strict=${2:-true}
    
    # Проверка длины
    if [ ${#password} -lt $MIN_PASSWORD_LENGTH ]; then
        echo "Пароль слишком короткий. Минимум: $MIN_PASSWORD_LENGTH символов"
        return 1
    fi
    
    if [ ${#password} -gt $MAX_PASSWORD_LENGTH ]; then
        echo "Пароль слишком длинный. Максимум: $MAX_PASSWORD_LENGTH символов"
        return 1
    fi
    
    # Проверка наличия заглавных букв
    if ! echo "$password" | grep -q '[A-Z]'; then
        echo "Пароль должен содержать заглавные буквы"
        return 1
    fi
    
    # Проверка наличия строчных букв
    if ! echo "$password" | grep -q '[a-z]'; then
        echo "Пароль должен содержать строчные буквы"
        return 1
    fi
    
    # Проверка наличия цифр
    if ! echo "$password" | grep -q '[0-9]'; then
        echo "Пароль должен содержать цифры"
        return 1
    fi
    
    # Проверка наличия специальных символов
    if ! echo "$password" | grep -q "[$PASSWORD_SPECIAL_CHARS]"; then
        echo "Пароль должен содержать специальные символы"
        return 1
    fi
    
    # Проверка на запрещенные пароли
    for forbidden in "${FORBIDDEN_PASSWORDS[@]}"; do
        if [[ "$password" == *"$forbidden"* ]]; then
            echo "Пароль содержит запрещенную последовательность: $forbidden"
            return 1
        fi
    done
    
    # Строгие проверки (опционально)
    if [ "$strict" = true ]; then
        # Проверка на последовательные символы
        if echo "$password" | grep -q '\([a-z]\{3,\}\|[A-Z]\{3,\}\|[0-9]\{3,\}\)'; then
            echo "Пароль содержит слишком много последовательных символов"
            return 1
        fi
        
        # Проверка на повторяющиеся символы
        if echo "$password" | grep -q '\(.\)\1\{2,\}'; then
            echo "Пароль содержит повторяющиеся символы"
            return 1
        fi
    fi
    
    echo "Пароль соответствует политике безопасности"
    return 0
}

# Оценка силы пароля
assess_password_strength() {
    local password="$1"
    local score=0
    local feedback=""
    
    # Базовая оценка по длине
    if [ ${#password} -ge $MIN_PASSWORD_LENGTH ]; then
        score=$((score + 20))
    fi
    
    if [ ${#password} -ge $RECOMMENDED_PASSWORD_LENGTH ]; then
        score=$((score + 10))
    fi
    
    # Оценка по типам символов
    if echo "$password" | grep -q '[A-Z]'; then
        score=$((score + 10))
    else
        feedback+="Добавьте заглавные буквы. "
    fi
    
    if echo "$password" | grep -q '[a-z]'; then
        score=$((score + 10))
    else
        feedback+="Добавьте строчные буквы. "
    fi
    
    if echo "$password" | grep -q '[0-9]'; then
        score=$((score + 10))
    else
        feedback+="Добавьте цифры. "
    fi
    
    if echo "$password" | grep -q "[$PASSWORD_SPECIAL_CHARS]"; then
        score=$((score + 15))
    else
        feedback+="Добавьте специальные символы. "
    fi
    
    # Штрафы за слабости
    for forbidden in "${FORBIDDEN_PASSWORDS[@]}"; do
        if [[ "$password" == *"$forbidden"* ]]; then
            score=$((score - 30))
            feedback+="Избегайте общих слов. "
            break
        fi
    done
    
    # Определение уровня безопасности
    if [ $score -ge 80 ]; then
        echo "ОТЛИЧНО ($score/100): $feedback"
        return 0
    elif [ $score -ge 60 ]; then
        echo "ХОРОШО ($score/100): $feedback"
        return 0
    elif [ $score -ge 40 ]; then
        echo "СРЕДНЕ ($score/100): $feedback"
        return 1
    else
        echo "СЛАБО ($score/100): $feedback"
        return 1
    fi
}

# ============================================================================
# ФУНКЦИИ ГЕНЕРАЦИИ ЛОГИНОВ
# ============================================================================

# Генерация нестандартного логина для модуля
generate_traffic_login() {
    local module="$1"
    local prefix="${2:-Traffic}"
    local suffix="${3:-}"
    
    # Проверяем, есть ли готовый логин для модуля
    if [[ -n "${SYSTEM_LOGINS[$module]:-}" ]]; then
        echo "${SYSTEM_LOGINS[$module]}"
        return 0
    fi
    
    if [[ -n "${MONITORING_LOGINS[$module]:-}" ]]; then
        echo "${MONITORING_LOGINS[$module]}"
        return 0
    fi
    
    if [[ -n "${ADMIN_LOGINS[$module]:-}" ]]; then
        echo "${ADMIN_LOGINS[$module]}"
        return 0
    fi
    
    if [[ -n "${API_LOGINS[$module]:-}" ]]; then
        echo "${API_LOGINS[$module]}"
        return 0
    fi
    
    # Генерируем новый логин если нет готового
    local module_capitalized=$(echo "$module" | sed 's/^./\U&/; s/_\([a-z]\)/\U\1/g')
    echo "${prefix}${module_capitalized}${suffix}"
}

# Генерация случайного логина с префиксом Traffic
generate_random_traffic_login() {
    local length=${1:-8}
    local prefix="${2:-Traffic}"
    
    # Генерируем случайную часть
    local random_part=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-$length | sed 's/[0-9]/&/g')
    
    # Первая буква заглавная
    random_part=$(echo "$random_part" | sed 's/^./\U&/')
    
    echo "${prefix}${random_part}"
}

# ============================================================================
# ФУНКЦИИ СОХРАНЕНИЯ БЕЗОПАСНЫХ ДАННЫХ
# ============================================================================

# Безопасное сохранение учетных данных
save_secure_credentials() {
    local service="$1"
    local username="$2"
    local password="$3"
    local file="${4:-$CREDENTIALS_FILE}"
    
    # Создаем директорию если не существует
    mkdir -p "$(dirname "$file")"
    
    # Добавляем данные в файл
    cat >> "$file" << EOF

# $service - $(date)
Логин: $username
Пароль: $password
Сложность: $(assess_password_strength "$password" | cut -d' ' -f1)
EOF
    
    # Устанавливаем безопасные права
    chmod 600 "$file"
    
    echo "✅ Учетные данные для $service сохранены"
}

# Генерация и сохранение учетных данных для модуля
generate_and_save_module_credentials() {
    local module="$1"
    local password_length="${2:-$RECOMMENDED_PASSWORD_LENGTH}"
    local complexity="${3:-high}"
    
    # Генерируем логин
    local username=$(generate_traffic_login "$module")
    
    # Генерируем пароль
    local password=$(generate_compliant_password "$password_length" "$complexity")
    
    # Проверяем пароль
    if ! validate_password_policy "$password" >/dev/null; then
        echo "⚠️  Сгенерированный пароль не соответствует политике, генерируем новый..."
        password=$(generate_compliant_password "$password_length" "$complexity")
    fi
    
    # Сохраняем данные
    save_secure_credentials "$module" "$username" "$password"
    
    echo "$username:$password"
}

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ БЕЗОПАСНОСТИ
# ============================================================================

# Проверка безопасности системы
check_system_security() {
    echo "🔒 Проверка безопасности системы..."
    
    local security_score=0
    local issues=()
    
    # Проверка файрвола
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        security_score=$((security_score + 20))
        echo "✅ UFW активен"
    else
        issues+=("UFW не активен")
    fi
    
    # Проверка fail2ban
    if systemctl is-active --quiet fail2ban; then
        security_score=$((security_score + 20))
        echo "✅ Fail2ban активен"
    else
        issues+=("Fail2ban не активен")
    fi
    
    # Проверка SSH конфигурации
    if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
        security_score=$((security_score + 15))
        echo "✅ SSH root доступ отключен"
    else
        issues+=("SSH root доступ включен")
    fi
    
    # Проверка обновлений системы
    if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
        local last_update=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp)
        local current_time=$(date +%s)
        local days_since_update=$(((current_time - last_update) / 86400))
        
        if [ $days_since_update -le 7 ]; then
            security_score=$((security_score + 15))
            echo "✅ Система обновлена (последнее обновление: $days_since_update дней назад)"
        else
            issues+=("Система не обновлялась $days_since_update дней")
        fi
    else
        issues+=("Не удалось проверить обновления системы")
    fi
    
    # Проверка сложных паролей
    if [ -f "$CREDENTIALS_FILE" ]; then
        security_score=$((security_score + 10))
        echo "✅ Файл с учетными данными существует"
    else
        issues+=("Файл с учетными данными не найден")
    fi
    
    # Проверка SSL/TLS
    if command -v openssl >/dev/null 2>&1; then
        security_score=$((security_score + 10))
        echo "✅ OpenSSL установлен"
    else
        issues+=("OpenSSL не установлен")
    fi
    
    # Проверка антивируса
    if command -v clamav >/dev/null 2>&1 || command -v rkhunter >/dev/null 2>&1; then
        security_score=$((security_score + 10))
        echo "✅ Антивирусное ПО установлено"
    else
        issues+=("Антивирусное ПО не установлено")
    fi
    
    # Вывод результатов
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                ОЦЕНКА БЕЗОПАСНОСТИ 🔒                   ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ Общий балл: $security_score/100"
    
    if [ $security_score -ge 80 ]; then
        echo "║ Статус: ОТЛИЧНО ✅"
    elif [ $security_score -ge 60 ]; then
        echo "║ Статус: ХОРОШО ✅"
    elif [ $security_score -ge 40 ]; then
        echo "║ Статус: СРЕДНЕ ⚠️"
    else
        echo "║ Статус: ТРЕБУЕТ ВНИМАНИЯ ❌"
    fi
    
    if [ ${#issues[@]} -gt 0 ]; then
        echo "║"
        echo "║ Проблемы безопасности:"
        for issue in "${issues[@]}"; do
            echo "║   • $issue"
        done
    fi
    
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    return $([ $security_score -ge 60 ] && echo 0 || echo 1)
}

# ============================================================================
# ЭКСПОРТ ФУНКЦИЙ И ПЕРЕМЕННЫХ
# ============================================================================

# Экспортируем функции для использования в других скриптах
export -f generate_compliant_password
export -f validate_password_policy
export -f assess_password_strength
export -f generate_traffic_login
export -f generate_random_traffic_login
export -f save_secure_credentials
export -f generate_and_save_module_credentials
export -f check_system_security

# Экспортируем переменные
export MIN_PASSWORD_LENGTH
export RECOMMENDED_PASSWORD_LENGTH
export MAX_PASSWORD_LENGTH
export PASSWORD_SPECIAL_CHARS
export FORBIDDEN_PASSWORDS
export SYSTEM_LOGINS
export MONITORING_LOGINS
export ADMIN_LOGINS
export API_LOGINS
