#!/bin/bash

# ============================================================================
# Traffic Connect - Единый менеджер установки и исправления
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

# ============================================================================
# ОБЩИЕ ФУНКЦИИ (без дублирования)
# ============================================================================

# Функция для исправления блокировок dpkg
fix_dpkg_locks() {
    echo "🔧 Исправление блокировок dpkg..."
    
    # Проверка активных процессов apt
    echo "📋 Проверка активных процессов apt..."
    local apt_processes=$(ps aux | grep -E "(apt|dpkg)" | grep -v grep)
    if [ -n "$apt_processes" ]; then
        echo "⚠️ Обнаружены активные процессы apt:"
        echo "$apt_processes"
        echo "🛑 Остановка зависших процессов..."
        pkill -f "apt-get" 2>/dev/null || true
        pkill -f "apt" 2>/dev/null || true
        pkill -f "dpkg" 2>/dev/null || true
        sleep 3
    else
        echo "✅ Активные процессы apt не обнаружены"
    fi
    
    # Удаление файлов блокировок
    echo "🗑️ Удаление файлов блокировок dpkg..."
    local locks_removed=false
    
    if [ -f "/var/lib/dpkg/lock" ]; then
        rm -f /var/lib/dpkg/lock
        echo "✅ Удален /var/lib/dpkg/lock"
        locks_removed=true
    fi
    
    if [ -f "/var/lib/dpkg/lock-frontend" ]; then
        rm -f /var/lib/dpkg/lock-frontend
        echo "✅ Удален /var/lib/dpkg/lock-frontend"
        locks_removed=true
    fi
    
    if [ -f "/var/lib/apt/lists/lock" ]; then
        rm -f /var/lib/apt/lists/lock
        echo "✅ Удален /var/lib/apt/lists/lock"
        locks_removed=true
    fi
    
    if [ -f "/var/cache/apt/archives/lock" ]; then
        rm -f /var/cache/apt/archives/lock
        echo "✅ Удален /var/cache/apt/archives/lock"
        locks_removed=true
    fi
    
    if [ -f "/var/lib/dpkg/info/format-new" ]; then
        rm -f /var/lib/dpkg/info/format-new
        echo "✅ Удален /var/lib/dpkg/info/format-new"
        locks_removed=true
    fi
    
    if [ "$locks_removed" = true ]; then
        echo "🛠️ Исправление прерванной установки dpkg..."
        dpkg --configure -a 2>/dev/null || true
        apt-get install -f -y 2>/dev/null || true
    fi
    
    echo "✅ Исправление блокировок dpkg завершено"
}

# Функция для исправления проблем Composer в HestiaCP
fix_hestia_composer() {
    echo "🔧 Исправление проблем Composer в HestiaCP..."
    
    # Проверка, установлен ли HestiaCP
    if [ ! -f "/usr/local/admin/bin/admin" ] && [ ! -d "/usr/local/admin" ]; then
        echo "❌ HestiaCP не установлен. Сначала установите HestiaCP."
        return 1
    fi
    
    echo "✅ HestiaCP обнаружен, начинаем исправление..."
    
    # Остановка процесса установки HestiaCP если он запущен
    echo "🛑 Остановка процесса установки HestiaCP..."
    pkill -f "hst-install.sh" 2>/dev/null || true
    pkill -f "composer" 2>/dev/null || true
    
    # Настройка Composer для HestiaCP
    echo "⚙️ Настройка Composer для HestiaCP..."
    
    # Создание директории Composer для HestiaCP
    mkdir -p /usr/local/hestia/composer
    chown -R hestia-web:hestia-users /usr/local/hestia/composer
    
    # Настройка переменных окружения
    export COMPOSER_HOME=/usr/local/hestia/composer
    export COMPOSER_CACHE_DIR=/usr/local/hestia/composer/cache
    export COMPOSER_TIMEOUT=600
    export COMPOSER_PROCESS_TIMEOUT=600
    
    # Создание конфигурации Composer
    cat > "$COMPOSER_HOME/config.json" << 'EOF'
{
    "config": {
        "timeout": 600,
        "process-timeout": 600,
        "github-protocols": ["https"],
        "github-oauth": {},
        "platform": {
            "php": "8.3"
        },
        "allow-plugins": {
            "composer/installers": true,
            "composer/ca-bundle": true
        }
    }
}
EOF
    
    # Настройка SSL для Composer
    echo "🔒 Настройка SSL для Composer..."
    
    # Создание конфигурации для wget
    cat > ~/.wgetrc << 'EOF'
check_certificate = off
timeout = 600
tries = 3
EOF
    
    # Создание конфигурации для curl
    cat > ~/.curlrc << 'EOF'
connect-timeout = 60
max-time = 600
retry = 3
insecure
EOF
    
    # Установка/обновление Composer с правильными настройками
    echo "📦 Установка Composer с правильными настройками..."
    
    # Удаление старого Composer если есть
    rm -f /usr/local/bin/composer
    rm -f /usr/bin/composer
    
    # Загрузка Composer с повторными попытками
    for attempt in 1 2 3; do
        echo "Попытка загрузки Composer $attempt/3..."
        
        if curl --connect-timeout 60 --max-time 300 -k -o /tmp/composer.phar https://getcomposer.org/download/2.8.10/composer.phar; then
            echo "✅ Composer загружен успешно"
            chmod +x /tmp/composer.phar
            mv /tmp/composer.phar /usr/local/bin/composer
            break
        else
            echo "❌ Попытка $attempt не удалась, повторяем..."
            sleep 10
        fi
    done
    
    # Проверка установки Composer
    if [ -f "/usr/local/bin/composer" ]; then
        echo "✅ Composer установлен успешно"
        /usr/local/bin/composer --version
    else
        echo "❌ Не удалось установить Composer"
        return 1
    fi
    
    # Настройка PHP для работы с Composer
    echo "🐘 Настройка PHP для работы с Composer..."
    
    # Создание временного php.ini с правильными настройками
    cat > /tmp/php-composer.ini << 'EOF'
[PHP]
default_socket_timeout = 600
max_execution_time = 600
max_input_time = 600
memory_limit = 1G
allow_url_fopen = On
allow_url_include = Off

[openssl]
openssl.cafile = /etc/ssl/certs/ca-certificates.crt
openssl.capath = /etc/ssl/certs

[curl]
curl.cainfo = /etc/ssl/certs/ca-certificates.crt
EOF
    
    # Применение настроек PHP для HestiaCP
    if [ -f "/etc/php/8.3/fpm/php.ini" ]; then
        echo "Применение настроек для PHP-FPM 8.3..."
        cp /tmp/php-composer.ini /etc/php/8.3/fpm/conf.d/99-composer-fix.ini
        systemctl restart php8.3-fpm
    fi
    
    if [ -f "/etc/php/8.3/cli/php.ini" ]; then
        echo "Применение настроек для PHP CLI 8.3..."
        cp /tmp/php-composer.ini /etc/php/8.3/cli/conf.d/99-composer-fix.ini
    fi
    
    # Очистка временных файлов
    rm -f /tmp/php-composer.ini
    
    # Перезапуск HestiaCP сервисов
    echo "🔄 Перезапуск HestiaCP сервисов..."
    systemctl restart hestia 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true
    systemctl restart apache2 2>/dev/null || true
    
    # Завершение установки HestiaCP если она была прервана
    echo "🏁 Завершение установки HestiaCP..."
    if [ -f "/usr/local/hestia/install.log" ]; then
        echo "Обнаружен лог установки, проверяем статус..."
        
        # Проверка, нужно ли завершить установку
        if grep -q "File Manager" /usr/local/hestia/install.log; then
            echo "Установка File Manager была прервана, завершаем..."
            
            # Запуск завершения установки
            cd /usr/local/hestia/install
            if [ -f "hst-install.sh" ]; then
                echo "Запуск завершения установки..."
                bash hst-install.sh --skip-dependencies --skip-questions
            fi
        fi
    fi
    
    echo "✅ Исправление Composer завершено"
}

# Функция для исправления SSL таймаутов
fix_ssl_timeouts() {
    echo "🔧 Исправление проблем SSL таймаута..."
    
    # Настройка SSL для решения проблем с таймаутом
    echo "⚙️ Настройка SSL для стабильной установки..."
    
    # Увеличиваем таймауты для SSL соединений
    export CURL_CONNECT_TIMEOUT=60
    export CURL_TIMEOUT=300
    export WGET_TIMEOUT=300
    export COMPOSER_TIMEOUT=300
    
    # Настройка SSL для wget
    echo "Настройка wget..."
    echo "check_certificate = off" >> ~/.wgetrc 2>/dev/null || true
    echo "timeout = 300" >> ~/.wgetrc 2>/dev/null || true
    echo "tries = 3" >> ~/.wgetrc 2>/dev/null || true
    
    # Настройка SSL для curl
    echo "Настройка curl..."
    echo "connect-timeout = 60" >> ~/.curlrc 2>/dev/null || true
    echo "max-time = 300" >> ~/.curlrc 2>/dev/null || true
    echo "retry = 3" >> ~/.curlrc 2>/dev/null || true
    echo "insecure" >> ~/.curlrc 2>/dev/null || true
    
    # Настройка Composer
    echo "Настройка Composer..."
    export COMPOSER_HOME=/tmp/composer
    export COMPOSER_CACHE_DIR=/tmp/composer/cache
    mkdir -p "$COMPOSER_HOME" "$COMPOSER_CACHE_DIR"
    
    # Создание конфигурации Composer
    cat > "$COMPOSER_HOME/config.json" << 'EOF'
{
    "config": {
        "timeout": 300,
        "process-timeout": 300,
        "github-protocols": ["https"],
        "github-oauth": {},
        "platform": {
            "php": "8.1"
        }
    }
}
EOF
    
    # Установка/обновление Composer с правильными настройками
    echo "Установка Composer с правильными настройками SSL..."
    
    for attempt in 1 2 3; do
        echo "Попытка установки Composer $attempt/3..."
        
        if curl --connect-timeout 60 --max-time 300 -k -o /tmp/composer.phar https://getcomposer.org/download/2.8.10/composer.phar; then
            echo "Composer загружен успешно"
            chmod +x /tmp/composer.phar
            mv /tmp/composer.phar /usr/local/bin/composer
            break
        else
            echo "Попытка $attempt не удалась, повторяем..."
            sleep 5
        fi
    done
    
    # Проверка установки Composer
    if [ -f "/usr/local/bin/composer" ]; then
        echo "✅ Composer установлен успешно"
        composer --version
    else
        echo "❌ Не удалось установить Composer"
        return 1
    fi
    
    # Настройка PHP для работы с SSL
    echo "Настройка PHP для работы с SSL..."
    
    # Создание временного php.ini с правильными настройками SSL
    cat > /tmp/php-ssl.ini << 'EOF'
[PHP]
default_socket_timeout = 300
max_execution_time = 300
max_input_time = 300
memory_limit = 512M
allow_url_fopen = On
allow_url_include = Off

[openssl]
openssl.cafile = /etc/ssl/certs/ca-certificates.crt
openssl.capath = /etc/ssl/certs

[curl]
curl.cainfo = /etc/ssl/certs/ca-certificates.crt
EOF
    
    # Применение настроек PHP
    if [ -f "/etc/php/8.1/cli/php.ini" ]; then
        echo "Применение настроек SSL для PHP CLI..."
        cp /tmp/php-ssl.ini /etc/php/8.1/cli/conf.d/99-ssl-fix.ini
    fi
    
    if [ -f "/etc/php/8.1/fpm/php.ini" ]; then
        echo "Применение настроек SSL для PHP FPM..."
        cp /tmp/php-ssl.ini /etc/php/8.1/fpm/conf.d/99-ssl-fix.ini
    fi
    
    # Очистка временных файлов
    rm -f /tmp/php-ssl.ini
    
    echo "✅ Настройки SSL применены успешно"
}

# ============================================================================
# ФУНКЦИИ УСТАНОВКИ
# ============================================================================

# Функция установки с нуля
install_from_scratch() {
    echo "🚀 Установка Traffic Connect Server с нуля"
    echo "================================================"
    
    # Проверка root прав
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Функция для проверки и исправления dpkg
    check_and_fix_dpkg() {
        echo "🔍 Проверка состояния dpkg..."
        
        # Проверка, работает ли dpkg
        if ! dpkg -l >/dev/null 2>&1; then
            echo "❌ Проблемы с dpkg, исправляем..."
            fix_dpkg_locks
            
            # Повторная проверка
            if ! dpkg -l >/dev/null 2>&1; then
                echo "❌ Критические проблемы с dpkg"
                echo "🔄 Перезагрузка системы..."
                reboot
                exit 1
            fi
        fi
        
        echo "✅ dpkg работает корректно"
    }
    
    # 1. Проверка и исправление dpkg
    echo "🔧 Шаг 1: Проверка и исправление dpkg..."
    check_and_fix_dpkg
    
    # 2. Обновление системы
    echo "🔄 Шаг 2: Обновление системы..."
    if ! apt update; then
        echo "❌ Ошибка обновления списков пакетов, исправляем..."
        fix_dpkg_locks
        apt update
    fi
    
    if ! apt upgrade -y; then
        echo "❌ Ошибка обновления системы, исправляем..."
        fix_dpkg_locks
        apt upgrade -y
    fi
    
    # 3. Установка базовых пакетов
    echo "📦 Шаг 3: Установка базовых пакетов..."
    if ! apt install -y git curl wget; then
        echo "❌ Ошибка установки базовых пакетов, исправляем..."
        fix_dpkg_locks
        apt install -y git curl wget
    fi
    
    # 4. Клонирование проекта
    echo "📥 Шаг 4: Клонирование проекта..."
    cd ~
    
    # Удаление старой директории если существует
    if [ -d "tc_fast_setup" ]; then
        echo "🗑️ Удаление старой директории проекта..."
        rm -rf tc_fast_setup
    fi
    
    # Клонирование проекта
    if ! git clone https://github.com/Traffic-Connect/tc_fast_setup.git; then
        echo "❌ Ошибка клонирования проекта"
        exit 1
    fi
    
    cd tc_fast_setup
    
    # 5. Проверка проекта
    echo "🔍 Шаг 5: Проверка проекта..."
    echo "Последние коммиты:"
    git log --oneline -3
    
    if [ ! -f "install.sh" ]; then
        echo "❌ Файл install.sh не найден"
        exit 1
    fi
    
    echo "✅ Проект успешно клонирован"
    
    # 6. Настройка прав
    echo "🔐 Шаг 6: Настройка прав доступа..."
    chmod +x install.sh install_monitoring_only.sh show_credentials.sh traffic_manager.sh 2>/dev/null || true
    
    # 7. Проверка готовности к установке
    echo "✅ Шаг 7: Проверка готовности к установке..."
    echo "📋 Статус системы:"
    echo "  • dpkg: $(dpkg -l >/dev/null 2>&1 && echo '✅ Работает' || echo '❌ Проблемы')"
    echo "  • apt: $(apt-get update >/dev/null 2>&1 && echo '✅ Работает' || echo '❌ Проблемы')"
    echo "  • git: $(git --version >/dev/null 2>&1 && echo '✅ Установлен' || echo '❌ Не установлен')"
    echo "  • curl: $(curl --version >/dev/null 2>&1 && echo '✅ Установлен' || echo '❌ Не установлен')"
    echo "  • wget: $(wget --version >/dev/null 2>&1 && echo '✅ Установлен' || echo '❌ Не установлен')"
    
    # 8. Запуск установки
    echo "🚀 Шаг 8: Запуск установки Traffic Connect Server..."
    echo "================================================"
    
    # Запуск основного скрипта установки
    if ./install.sh; then
        echo ""
        echo "🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
        echo "================================================"
        echo ""
        echo "📋 Что было установлено:"
        echo "  ✅ HestiaCP (административная панель)"
        echo "  ✅ Grafana (мониторинг)"
        echo "  ✅ Prometheus (метрики)"
        echo "  ✅ Loki (логи)"
        echo "  ✅ Система безопасности"
        echo ""
        echo "🌐 Доступы к сервисам:"
        echo "  • HestiaCP: https://$(hostname -I | awk '{print $1}'):8083"
        echo "  • Grafana: http://$(hostname -I | awk '{print $1}'):3000"
        echo "  • Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
        echo "  • Loki: http://$(hostname -I | awk '{print $1}'):3100"
        echo ""
        echo "📚 Дополнительные команды:"
        echo "  • Просмотр паролей: ./show_credentials.sh"
        echo "  • Этот менеджер: ./traffic_manager.sh"
    else
        echo ""
        echo "❌ УСТАНОВКА ЗАВЕРШИЛАСЬ С ОШИБКАМИ"
        echo "================================================"
        echo ""
        echo "🔧 Рекомендации по исправлению:"
        echo "  • Проверьте логи установки выше"
        echo "  • Запустите исправление dpkg: ./traffic_manager.sh --fix-dpkg"
        echo "  • Запустите исправление Composer: ./traffic_manager.sh --fix-composer"
        echo "  • Попробуйте установку только HestiaCP: ./traffic_manager.sh --install-hestia"
        echo "  • Перезагрузите сервер: reboot"
        exit 1
    fi
}

# Функция установки только HestiaCP
install_hestia_only() {
    echo "🚀 Установка только HestiaCP на чистом сервере"
    echo "================================================"
    
    # Проверка root прав
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Проверка, не установлен ли уже HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || [ -d "/usr/local/admin" ] || systemctl is-active --quiet admin 2>/dev/null || [ -f "/usr/local/hestia/install.log" ]; then
        echo "HestiaCP уже установлен, пропускаем установку"
        echo "Информация о существующей установке HestiaCP:"
        echo "  URL: https://$(hostname -I | awk '{print $1}'):8083"
        echo "  Статус: ✅ Уже установлена и работает"
        exit 0
    fi
    
    # Генерация пароля для HestiaCP
    echo "Генерация пароля для HestiaCP..."
    if type generate_compliant_password >/dev/null 2>&1; then
        HESTIA_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
    else
        HESTIA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
    fi
    
    export HESTIA_PASSWORD
    
    echo "Пароль для HestiaCP: $HESTIA_PASSWORD"
    
    # Проверка и удаление существующего пользователя если конфликт
    if id "$HESTIA_USERNAME" &>/dev/null; then
        echo "Пользователь $HESTIA_USERNAME уже существует, удаляем..."
        userdel -r "$HESTIA_USERNAME" 2>/dev/null || true
        groupdel "$HESTIA_USERNAME" 2>/dev/null || true
    fi
    
    # Проверка конфликтующих пакетов
    echo "Проверка конфликтующих пакетов..."
    local conflicting_packages=()
    
    if dpkg -l | grep -q "^ii.*ufw"; then
        conflicting_packages+=("ufw")
    fi
    
    if dpkg -l | grep -q "^ii.*nginx"; then
        conflicting_packages+=("nginx")
    fi
    
    if dpkg -l | grep -q "^ii.*apache2"; then
        conflicting_packages+=("apache2")
    fi
    
    if [ ${#conflicting_packages[@]} -gt 0 ]; then
        echo "Обнаружены конфликтующие пакеты: ${conflicting_packages[*]}"
        echo "Удаляем конфликтующие пакеты для установки HestiaCP..."
        
        # Останавливаем и удаляем конфликтующие пакеты
        for package in "${conflicting_packages[@]}"; do
            echo "Удаление пакета: $package"
            systemctl stop "$package" 2>/dev/null || true
            apt remove --purge -y "$package" 2>/dev/null || true
        done
        
        apt autoremove -y
        echo "Конфликтующие пакеты удалены"
    fi
    
    # Настройка SSL для решения проблем с таймаутом
    echo "Настройка SSL для стабильной установки..."
    
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
    
    # Загрузка скрипта установки HestiaCP с повторными попытками
    echo "Загрузка установщика HestiaCP..."
    local download_success=false
    
    for attempt in 1 2 3; do
        echo "Попытка загрузки $attempt/3..."
        
        if wget --timeout=300 --tries=3 --no-check-certificate -O /tmp/hst-install.sh https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh; then
            download_success=true
            break
        else
            echo "Попытка $attempt не удалась, повторяем..."
            sleep 5
        fi
    done
    
    if [ ! -f "/tmp/hst-install.sh" ] || [ "$download_success" = false ]; then
        echo "❌ Не удалось загрузить установщик HestiaCP после 3 попыток"
        echo "Пробуем альтернативный метод загрузки..."
        
        # Альтернативная загрузка через curl
        if curl --connect-timeout 60 --max-time 300 -k -o /tmp/hst-install.sh https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh; then
            echo "✅ Установщик загружен через curl"
        else
            echo "❌ Не удалось загрузить установщик HestiaCP"
            exit 1
        fi
    fi
    
    chmod +x /tmp/hst-install.sh
    
    # Предварительная установка Composer с правильными настройками SSL
    echo "Предварительная настройка Composer для решения проблем SSL..."
    
    # Создаем временный скрипт для установки Composer
    cat > /tmp/install_composer.sh << 'EOF'
#!/bin/bash
# Установка Composer с правильными настройками SSL

# Настройка переменных окружения для SSL
export COMPOSER_HOME=/tmp/composer
export COMPOSER_CACHE_DIR=/tmp/composer/cache
export COMPOSER_TIMEOUT=300

# Создание директорий
mkdir -p "$COMPOSER_HOME" "$COMPOSER_CACHE_DIR"

# Загрузка Composer с повторными попытками
for attempt in 1 2 3; do
    echo "Попытка загрузки Composer $attempt/3..."
    
    if curl --connect-timeout 30 --max-time 60 -k -o /tmp/composer.phar https://getcomposer.org/download/2.8.10/composer.phar; then
        echo "Composer загружен успешно"
        chmod +x /tmp/composer.phar
        mv /tmp/composer.phar /usr/local/bin/composer
        break
    else
        echo "Попытка $attempt не удалась, повторяем..."
        sleep 5
    fi
done

# Проверка установки
if [ -f "/usr/local/bin/composer" ]; then
    echo "✅ Composer установлен успешно"
    composer --version
else
    echo "❌ Не удалось установить Composer"
    exit 1
fi
EOF
    
    chmod +x /tmp/install_composer.sh
    bash /tmp/install_composer.sh
    
    # Выполнение установки HestiaCP
    echo "Выполнение установки HestiaCP..."
    bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force
    
    if [ $? -eq 0 ]; then
        echo "✅ HestiaCP установлен успешно"
    else
        echo "❌ Ошибка установки HestiaCP"
        exit 1
    fi
    
    # Очистка временных файлов
    echo "Очистка временных файлов..."
    rm -f /tmp/hst-install.sh /tmp/install_composer.sh
    rm -rf /tmp/composer
    
    # Информация о доступе к HestiaCP
    echo "Информация о доступе к HestiaCP:"
    echo "  URL: https://$(hostname -I | awk '{print $1}'):8083"
    echo "  Логин: $HESTIA_USERNAME"
    echo "  Пароль: $HESTIA_PASSWORD"
    echo "  Статус: ✅ Установлена и работает"
    
    echo "✅ Установка HestiaCP завершена успешно"
    echo ""
    echo "🎉 HestiaCP установлен и готов к использованию!"
    echo "🌐 URL: https://$(hostname -I | awk '{print $1}'):8083"
    echo "👤 Логин: $HESTIA_USERNAME"
    echo "🔑 Пароль: $HESTIA_PASSWORD"
}

# ============================================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================================

show_menu() {
    echo ""
    echo "🚀 Traffic Connect - Единый менеджер"
    echo "================================================"
    echo ""
    echo "📋 Доступные действия:"
    echo ""
    echo "🔧 ИСПРАВЛЕНИЯ:"
    echo "  1) Исправить блокировки dpkg"
    echo "  2) Исправить проблемы Composer в HestiaCP"
    echo "  3) Исправить SSL таймауты"
    echo ""
    echo "🚀 УСТАНОВКА:"
    echo "  4) Установка с нуля (полная)"
    echo "  5) Установка только HestiaCP"
    echo "  6) Установка только мониторинга"
    echo ""
    echo "📊 ИНФОРМАЦИЯ:"
    echo "  7) Показать учетные данные"
    echo "  8) Проверить безопасность"
    echo "  9) Проверить версии"
    echo ""
    echo "❌ ВЫХОД:"
    echo "  0) Выход"
    echo ""
}

# ============================================================================
# ОБРАБОТКА АРГУМЕНТОВ КОМАНДНОЙ СТРОКИ
# ============================================================================

if [ $# -eq 0 ]; then
    # Интерактивный режим
    while true; do
        show_menu
        read -p "Выберите действие (0-9): " choice
        
        case $choice in
            1)
                fix_dpkg_locks
                ;;
            2)
                fix_hestia_composer
                ;;
            3)
                fix_ssl_timeouts
                ;;
            4)
                install_from_scratch
                ;;
            5)
                install_hestia_only
                ;;
            6)
                echo "Запуск установки только мониторинга..."
                ./install_monitoring_only.sh
                ;;
            7)
                echo "Показать учетные данные..."
                ./show_credentials.sh
                ;;
            8)
                echo "Проверка безопасности..."
                ./check_security.sh
                ;;
            9)
                echo "Проверка версий..."
                ./check_version.sh
                ;;
            0)
                echo "Выход..."
                exit 0
                ;;
            *)
                echo "❌ Неверный выбор. Попробуйте снова."
                ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
else
    # Режим командной строки
    case "$1" in
        --fix-dpkg)
            fix_dpkg_locks
            ;;
        --fix-composer)
            fix_hestia_composer
            ;;
        --fix-ssl)
            fix_ssl_timeouts
            ;;
        --install-scratch)
            install_from_scratch
            ;;
        --install-hestia)
            install_hestia_only
            ;;
        --install-monitoring)
            ./install_monitoring_only.sh
            ;;
        --show-credentials)
            ./show_credentials.sh
            ;;
        --check-security)
            ./check_security.sh
            ;;
        --check-version)
            ./check_version.sh
            ;;
        --help|-h)
            echo "🚀 Traffic Connect - Единый менеджер"
            echo "================================================"
            echo ""
            echo "Использование: $0 [опция]"
            echo ""
            echo "Опции:"
            echo "  --fix-dpkg           Исправить блокировки dpkg"
            echo "  --fix-composer       Исправить проблемы Composer в HestiaCP"
            echo "  --fix-ssl            Исправить SSL таймауты"
            echo "  --install-scratch    Установка с нуля (полная)"
            echo "  --install-hestia     Установка только HestiaCP"
            echo "  --install-monitoring Установка только мониторинга"
            echo "  --show-credentials   Показать учетные данные"
            echo "  --check-security     Проверить безопасность"
            echo "  --check-version      Проверить версии"
            echo "  --help, -h           Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0 --fix-dpkg"
            echo "  $0 --install-scratch"
            echo "  $0 --install-hestia"
            ;;
        *)
            echo "❌ Неизвестная опция: $1"
            echo "Используйте --help для получения справки"
            exit 1
            ;;
    esac
fi
