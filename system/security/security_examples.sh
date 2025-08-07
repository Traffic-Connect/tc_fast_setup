#!/bin/bash
# ============================================================================
# Traffic Connect Server - Примеры использования политики безопасности
# ============================================================================
# Этот файл содержит примеры использования функций безопасности
# для разработчиков и администраторов

# Загрузка политики безопасности
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/security_policy.sh"

# ============================================================================
# ПРИМЕРЫ ГЕНЕРАЦИИ ПАРОЛЕЙ
# ============================================================================

example_password_generation() {
    echo "=== ПРИМЕРЫ ГЕНЕРАЦИИ ПАРОЛЕЙ ==="
    echo ""
    
    # Пример 1: Базовый пароль
    echo "1. Базовый пароль (16 символов):"
    basic_pass=$(generate_compliant_password 16 "low")
    echo "   Пароль: $basic_pass"
    echo "   Оценка: $(assess_password_strength "$basic_pass")"
    echo ""
    
    # Пример 2: Средний пароль
    echo "2. Средний пароль (20 символов):"
    medium_pass=$(generate_compliant_password 20 "medium")
    echo "   Пароль: $medium_pass"
    echo "   Оценка: $(assess_password_strength "$medium_pass")"
    echo ""
    
    # Пример 3: Высокий пароль
    echo "3. Высокий пароль (24 символа):"
    high_pass=$(generate_compliant_password 24 "high")
    echo "   Пароль: $high_pass"
    echo "   Оценка: $(assess_password_strength "$high_pass")"
    echo ""
    
    # Пример 4: Максимальный пароль
    echo "4. Максимальный пароль (32 символа):"
    max_pass=$(generate_compliant_password 32 "high")
    echo "   Пароль: $max_pass"
    echo "   Оценка: $(assess_password_strength "$max_pass")"
    echo ""
}

# ============================================================================
# ПРИМЕРЫ ГЕНЕРАЦИИ ЛОГИНОВ
# ============================================================================

example_login_generation() {
    echo "=== ПРИМЕРЫ ГЕНЕРАЦИИ ЛОГИНОВ ==="
    echo ""
    
    # Пример 1: Стандартные логины для модулей
    echo "1. Стандартные логины для модулей:"
    for module in "admin_panel" "grafana" "prometheus" "loki" "database" "backup"; do
        login=$(generate_traffic_login "$module")
        echo "   $module: $login"
    done
    echo ""
    
    # Пример 2: Логины для мониторинга
    echo "2. Логины для мониторинга:"
    for module in "node_exporter" "pushgateway" "promtail" "alertmanager"; do
        login=$(generate_traffic_login "$module")
        echo "   $module: $login"
    done
    echo ""
    
    # Пример 3: Случайные логины
    echo "3. Случайные логины:"
    for i in {1..5}; do
        random_login=$(generate_random_traffic_login 8)
        echo "   Случайный $i: $random_login"
    done
    echo ""
    
    # Пример 4: Логины с кастомными префиксами
    echo "4. Логины с кастомными префиксами:"
    echo "   TC_$(generate_traffic_login "api" "" "" | sed 's/Traffic//'): $(generate_traffic_login "api" "TC_" "")"
    echo "   SEC_$(generate_traffic_login "security" "" "" | sed 's/Traffic//'): $(generate_traffic_login "security" "SEC_" "")"
    echo "   MON_$(generate_traffic_login "monitoring" "" "" | sed 's/Traffic//'): $(generate_traffic_login "monitoring" "MON_" "")"
    echo ""
}

# ============================================================================
# ПРИМЕРЫ ПРОВЕРКИ ПАРОЛЕЙ
# ============================================================================

example_password_validation() {
    echo "=== ПРИМЕРЫ ПРОВЕРКИ ПАРОЛЕЙ ==="
    echo ""
    
    # Пример 1: Хороший пароль
    echo "1. Проверка хорошего пароля:"
    good_password="Kj9#mN2$pQ7@vX5&hL8"
    echo "   Пароль: $good_password"
    echo "   Результат: $(validate_password_policy "$good_password")"
    echo "   Оценка: $(assess_password_strength "$good_password")"
    echo ""
    
    # Пример 2: Слабый пароль
    echo "2. Проверка слабого пароля:"
    weak_password="password123"
    echo "   Пароль: $weak_password"
    echo "   Результат: $(validate_password_policy "$weak_password")"
    echo "   Оценка: $(assess_password_strength "$weak_password")"
    echo ""
    
    # Пример 3: Короткий пароль
    echo "3. Проверка короткого пароля:"
    short_password="Abc123!"
    echo "   Пароль: $short_password"
    echo "   Результат: $(validate_password_policy "$short_password")"
    echo "   Оценка: $(assess_password_strength "$short_password")"
    echo ""
    
    # Пример 4: Пароль без специальных символов
    echo "4. Проверка пароля без специальных символов:"
    no_special_password="Abcdefghijklmnop123"
    echo "   Пароль: $no_special_password"
    echo "   Результат: $(validate_password_policy "$no_special_password")"
    echo "   Оценка: $(assess_password_strength "$no_special_password")"
    echo ""
}

# ============================================================================
# ПРИМЕРЫ СОЗДАНИЯ УЧЕТНЫХ ДАННЫХ ДЛЯ МОДУЛЕЙ
# ============================================================================

example_module_credentials() {
    echo "=== ПРИМЕРЫ СОЗДАНИЯ УЧЕТНЫХ ДАННЫХ ДЛЯ МОДУЛЕЙ ==="
    echo ""
    
    # Пример 1: Создание учетных данных для Grafana
    echo "1. Создание учетных данных для Grafana:"
    grafana_creds=$(generate_and_save_module_credentials "grafana" 24 "high")
    grafana_username=$(echo "$grafana_creds" | cut -d: -f1)
    grafana_password=$(echo "$grafana_creds" | cut -d: -f2)
    echo "   Логин: $grafana_username"
    echo "   Пароль: $grafana_password"
    echo "   Оценка: $(assess_password_strength "$grafana_password")"
    echo ""
    
    # Пример 2: Создание учетных данных для Prometheus
    echo "2. Создание учетных данных для Prometheus:"
    prometheus_creds=$(generate_and_save_module_credentials "prometheus" 24 "high")
    prometheus_username=$(echo "$prometheus_creds" | cut -d: -f1)
    prometheus_password=$(echo "$prometheus_creds" | cut -d: -f2)
    echo "   Логин: $prometheus_username"
    echo "   Пароль: $prometheus_password"
    echo "   Оценка: $(assess_password_strength "$prometheus_password")"
    echo ""
    
    # Пример 3: Создание учетных данных для API
    echo "3. Создание учетных данных для API:"
    api_creds=$(generate_and_save_module_credentials "api" 20 "medium")
    api_username=$(echo "$api_creds" | cut -d: -f1)
    api_password=$(echo "$api_creds" | cut -d: -f2)
    echo "   Логин: $api_username"
    echo "   Пароль: $api_password"
    echo "   Оценка: $(assess_password_strength "$api_password")"
    echo ""
}

# ============================================================================
# ПРИМЕРЫ ИНТЕГРАЦИИ В СКРИПТЫ
# ============================================================================

example_integration() {
    echo "=== ПРИМЕРЫ ИНТЕГРАЦИИ В СКРИПТЫ ==="
    echo ""
    
    echo "1. Пример интеграции в установочный скрипт:"
    cat << 'EOF'
# В начале скрипта
source "$SCRIPT_DIR/security_policy.sh"

# Генерация учетных данных для сервиса
service_creds=$(generate_and_save_module_credentials "my_service" 24 "high")
service_username=$(echo "$service_creds" | cut -d: -f1)
service_password=$(echo "$service_creds" | cut -d: -f2)

# Использование в конфигурации
echo "username: $service_username" >> /etc/my_service/config.yml
echo "password: $service_password" >> /etc/my_service/config.yml
EOF
    echo ""
    
    echo "2. Пример проверки пароля пользователя:"
    cat << 'EOF'
# Проверка пароля при создании пользователя
read -s -p "Введите пароль: " user_password
echo

if validate_password_policy "$user_password" >/dev/null; then
    echo "Пароль соответствует политике безопасности"
    # Создаем пользователя
else
    echo "Пароль не соответствует политике безопасности"
    echo "Требования:"
    echo "- Минимум $MIN_PASSWORD_LENGTH символов"
    echo "- Заглавные и строчные буквы"
    echo "- Цифры и специальные символы"
    exit 1
fi
EOF
    echo ""
    
    echo "3. Пример массовой генерации паролей:"
    cat << 'EOF'
# Генерация паролей для всех сервисов
services=("grafana" "prometheus" "loki" "node_exporter" "pushgateway")

for service in "${services[@]}"; do
    echo "Генерация пароля для $service..."
    creds=$(generate_and_save_module_credentials "$service" 24 "high")
    username=$(echo "$creds" | cut -d: -f1)
    password=$(echo "$creds" | cut -d: -f2)
    
    echo "$service: $username / $password"
done
EOF
    echo ""
}

# ============================================================================
# ПРИМЕРЫ НАСТРОЙКИ БЕЗОПАСНОСТИ
# ============================================================================

example_security_setup() {
    echo "=== ПРИМЕРЫ НАСТРОЙКИ БЕЗОПАСНОСТИ ==="
    echo ""
    
    echo "1. Настройка SSH с нестандартным пользователем:"
    cat << 'EOF'
# Создание нестандартного административного пользователя
admin_username=$(generate_traffic_login "super_admin")
admin_password=$(generate_compliant_password 24 "high")

# Создание пользователя
useradd -m -s /bin/bash "$admin_username"
echo "$admin_username:$admin_password" | chpasswd

# Добавление в sudo группу
usermod -aG sudo "$admin_username"

# Настройка SSH
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Перезапуск SSH
systemctl restart sshd
EOF
    echo ""
    
    echo "2. Настройка файрвола с нестандартными портами:"
    cat << 'EOF'
# Настройка UFW с нестандартными портами
ufw --force reset

# Базовые правила
ufw default deny incoming
ufw default allow outgoing

# SSH (нестандартный порт)
ufw allow 2222/tcp

# Веб-сервисы
ufw allow 80/tcp
ufw allow 443/tcp

# Мониторинг (нестандартные порты)
ufw allow 3001/tcp  # Grafana
ufw allow 9091/tcp  # Prometheus
ufw allow 3101/tcp  # Loki

# Активация
ufw --force enable
EOF
    echo ""
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║        ПРИМЕРЫ ПОЛИТИКИ БЕЗОПАСНОСТИ TRAFFICCONNECT      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # Запуск примеров
    example_password_generation
    example_login_generation
    example_password_validation
    example_module_credentials
    example_integration
    example_security_setup
    
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    ПРИМЕРЫ ЗАВЕРШЕНЫ                     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Для использования в своих скриптах:"
    echo "1. Подключите файл: source '\$SCRIPT_DIR/security_policy.sh'"
    echo "2. Используйте функции: generate_compliant_password, generate_traffic_login"
    echo "3. Проверяйте пароли: validate_password_policy, assess_password_strength"
    echo ""
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
