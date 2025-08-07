#!/bin/bash

# ============================================================================
# Traffic Connect - Единый скрипт для всех операций
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции логирования
log_info() { echo -e "${BLUE}[Инфо] $1${NC}"; }
log_ok() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[ВНИМАНИЕ] $1${NC}"; }
log_err() { echo -e "${RED}[ОШИБКА] $1${NC}"; }

# ============================================================================
# ОБЩИЕ ФУНКЦИИ
# ============================================================================

# Проверка root прав
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_err "Этот скрипт должен быть запущен от имени root"
        exit 1
    fi
}

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
    chmod +x install.sh install_monitoring_only.sh show_credentials.sh traffic_connect.sh 2>/dev/null || true
    
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
    
    # Запуск универсального скрипта установки
    if ./install_all.sh; then
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
        echo "  • Просмотр паролей: ./traffic_connect.sh --show-credentials"
        echo "  • Этот менеджер: ./traffic_connect.sh"
    else
        echo ""
        echo "❌ УСТАНОВКА ЗАВЕРШИЛАСЬ С ОШИБКАМИ"
        echo "================================================"
        echo ""
        echo "🔧 Рекомендации по исправлению:"
        echo "  • Проверьте логи установки выше"
        echo "  • Запустите исправление dpkg: ./traffic_connect.sh --fix-dpkg"
        echo "  • Запустите исправление Composer: ./traffic_connect.sh --fix-composer"
        echo "  • Попробуйте установку только HestiaCP: ./traffic_connect.sh --install-hestia"
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
# ФУНКЦИИ ПРОВЕРКИ БЕЗОПАСНОСТИ
# ============================================================================

# Проверка SSH безопасности согласно политике безопасности
check_ssh_security() {
    log_info "Проверка SSH безопасности согласно политике безопасности..."
    local score=0
    
    if [ -f /etc/ssh/sshd_config ]; then
        # Проверка root доступа (должен быть включен согласно политике)
        if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
            log_ok "SSH root доступ включен (согласно политике безопасности)"
            score=$((score + 15))
        else
            log_warn "SSH root доступ отключен (не соответствует политике)"
        fi
        
        # Проверка аутентификации по паролю (должна быть включена для root)
        if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
            log_ok "SSH аутентификация по паролю включена (для root)"
            score=$((score + 10))
        else
            log_warn "SSH аутентификация по паролю отключена"
        fi
        
        # Проверка аутентификации по ключам
        if grep -q "PubkeyAuthentication yes" /etc/ssh/sshd_config; then
            log_ok "SSH аутентификация по ключам включена"
            score=$((score + 15))
        else
            log_warn "SSH аутентификация по ключам отключена"
        fi
        
        # Проверка группы ssh-users
        if grep -q "Match Group ssh-users" /etc/ssh/sshd_config; then
            log_ok "Настроена группа ssh-users для пользователей"
            score=$((score + 10))
        else
            log_warn "Группа ssh-users не настроена"
        fi
        
        if grep -q "Port 22" /etc/ssh/sshd_config && ! grep -q "#Port 22" /etc/ssh/sshd_config; then
            log_warn "SSH использует стандартный порт 22"
        else
            log_ok "SSH использует нестандартный порт"
            score=$((score + 10))
        fi
    fi
    
    return $score
}

# Проверка файрвола
check_firewall() {
    log_info "Проверка файрвола..."
    local score=0
    
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        log_ok "UFW активен"
        score=$((score + 20))
    else
        log_warn "UFW не активен"
    fi
    
    if iptables -L | grep -q "DROP"; then
        log_ok "Правила блокировки настроены"
        score=$((score + 15))
    else
        log_warn "Правила блокировки не настроены"
    fi
    
    return $score
}

# Проверка fail2ban
check_fail2ban() {
    log_info "Проверка Fail2ban..."
    local score=0
    
    if systemctl is-active --quiet fail2ban; then
        log_ok "Fail2ban активен"
        score=$((score + 20))
        
        # Проверка активных банов
        local banned_ips=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
        if [ "$banned_ips" -gt 0 ] 2>/dev/null; then
            log_warn "Заблокировано IP адресов: $banned_ips"
        fi
    else
        log_warn "Fail2ban не активен"
    fi
    
    return $score
}

# Проверка обновлений системы
check_system_updates() {
    log_info "Проверка обновлений системы..."
    local score=0
    
    if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
        local last_update=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp)
        local current_time=$(date +%s)
        local days_since_update=$(((current_time - last_update) / 86400))
        
        if [ $days_since_update -le 7 ]; then
            log_ok "Система обновлена ($days_since_update дней назад)"
            score=$((score + 15))
        elif [ $days_since_update -le 30 ]; then
            log_warn "Система не обновлялась $days_since_update дней"
            score=$((score + 5))
        else
            log_err "Система не обновлялась $days_since_update дней"
        fi
    else
        log_warn "Не удалось проверить обновления системы"
    fi
    
    return $score
}

# Проверка открытых портов
check_open_ports() {
    log_info "Проверка открытых портов..."
    local score=0
    
    # Проверка критических портов
    local critical_ports=(22 23 21 3389 5900)
    local open_critical=0
    
    for port in "${critical_ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warn "Критический порт $port открыт"
            open_critical=$((open_critical + 1))
        fi
    done
    
    if [ $open_critical -eq 0 ]; then
        log_ok "Критические порты закрыты"
        score=$((score + 15))
    else
        score=$((score - $((open_critical * 5))))
    fi
    
    # Показываем все открытые порты
    log_info "Открытые порты:"
    netstat -tlnp 2>/dev/null | grep LISTEN | while read line; do
        echo "  $line"
    done
    
    return $score
}

# Проверка подозрительной активности
check_suspicious_activity() {
    log_info "Проверка подозрительной активности..."
    local score=0
    
    # Проверка неудачных попыток входа
    local failed_attempts=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    if [ "$failed_attempts" -gt 100 ]; then
        log_warn "Много неудачных попыток входа: $failed_attempts"
        score=$((score - 10))
    else
        log_ok "Неудачных попыток входа: $failed_attempts"
        score=$((score + 5))
    fi
    
    # Проверка подозрительных процессов
    local suspicious_processes=$(ps aux | grep -E "(crypto|miner|bot|scan)" | grep -v grep | wc -l)
    if [ "$suspicious_processes" -gt 0 ]; then
        log_err "Обнаружены подозрительные процессы: $suspicious_processes"
        score=$((score - 20))
    else
        log_ok "Подозрительные процессы не обнаружены"
        score=$((score + 10))
    fi
    
    return $score
}

# Проверка файловой безопасности
check_file_security() {
    log_info "Проверка файловой безопасности..."
    local score=0
    
    # Проверка прав на конфигурационные файлы
    local config_files=("/etc/ssh/sshd_config" "/etc/fail2ban/jail.local" "/etc/nginx/nginx.conf")
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            local perms=$(stat -c %a "$file")
            if [ "$perms" = "600" ] || [ "$perms" = "644" ]; then
                log_ok "Права на $file корректны: $perms"
                score=$((score + 5))
            else
                log_warn "Некорректные права на $file: $perms"
            fi
        fi
    done
    
    return $score
}

# Проверка пользователей согласно политике безопасности
check_users_policy() {
    log_info "Проверка пользователей согласно политике безопасности..."
    local score=0
    
    # Загружаем политику безопасности
    if [ -f "$PROJECT_ROOT/system/security/security_policy.sh" ]; then
        source "$PROJECT_ROOT/system/security/security_policy.sh"
        
        # Проверяем наличие пользователей мониторинга
        local monitoring_users=("TrafficMetrics" "TrafficMonitor" "TrafficLogger" "TrafficNode" "TrafficPush" "TrafficFail2Ban")
        local found_users=0
        
        for username in "${monitoring_users[@]}"; do
            if id "$username" &>/dev/null; then
                log_ok "Пользователь $username существует"
                found_users=$((found_users + 1))
            else
                log_warn "Пользователь $username не найден"
            fi
        done
        
        if [ $found_users -eq ${#monitoring_users[@]} ]; then
            log_ok "Все пользователи мониторинга созданы согласно политике"
            score=$((score + 15))
        else
            log_warn "Не все пользователи мониторинга созданы"
        fi
        
        # Проверяем группу ssh-users
        if getent group ssh-users >/dev/null 2>&1; then
            log_ok "Группа ssh-users существует"
            score=$((score + 5))
        else
            log_warn "Группа ssh-users не найдена"
        fi
    else
        log_warn "Файл политики безопасности не найден"
    fi
    
    return $score
}

# Главная функция проверки безопасности
main_security_check() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              ПРОВЕРКА БЕЗОПАСНОСТИ 🔒                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    local total_score=0
    
    # Выполняем все проверки
    check_ssh_security
    total_score=$((total_score + $?))
    
    check_firewall
    total_score=$((total_score + $?))
    
    check_fail2ban
    total_score=$((total_score + $?))
    
    check_system_updates
    total_score=$((total_score + $?))
    
    check_open_ports
    total_score=$((total_score + $?))
    
    check_suspicious_activity
    total_score=$((total_score + $?))
    
    check_file_security
    total_score=$((total_score + $?))
    
    check_users_policy
    total_score=$((total_score + $?))
    
    # Вывод результатов
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    РЕЗУЛЬТАТЫ ПРОВЕРКИ                  ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ Общий балл безопасности: $total_score/100"
    
    if [ $total_score -ge 80 ]; then
        echo "║ Статус: ОТЛИЧНО ✅"
        echo "║ Система хорошо защищена"
    elif [ $total_score -ge 60 ]; then
        echo "║ Статус: ХОРОШО ✅"
        echo "║ Система защищена, но есть возможности для улучшения"
    elif [ $total_score -ge 40 ]; then
        echo "║ Статус: СРЕДНЕ ⚠️"
        echo "║ Требуется улучшение безопасности"
    else
        echo "║ Статус: КРИТИЧНО ❌"
        echo "║ Требуется немедленное улучшение безопасности"
    fi
    
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # Рекомендации
    if [ $total_score -lt 80 ]; then
        echo "📋 РЕКОМЕНДАЦИИ ПО УЛУЧШЕНИЮ БЕЗОПАСНОСТИ:"
        echo "1. Отключите root доступ по SSH"
        echo "2. Настройте аутентификацию по ключам"
        echo "3. Активируйте UFW файрвол"
        echo "4. Настройте fail2ban"
        echo "5. Регулярно обновляйте систему"
        echo "6. Проверяйте логи безопасности"
        echo ""
        echo "📖 Подробные инструкции: cat PRODUCTION_SECURITY.md"
    fi
}

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ ВЕРСИЙ И ОБНОВЛЕНИЯ
# ============================================================================

# Проверка версии
check_version() {
    echo "🔍 Проверка версии Traffic Connect Fast Setup"
    echo "=============================================="

    # Проверка, что мы в правильной папке
    if [ ! -f "install.sh" ]; then
        echo "❌ Ошибка: файл install.sh не найден"
        echo "Убедитесь, что вы находитесь в папке tc_fast_setup"
        exit 1
    fi

    echo "📋 Текущая версия:"
    git log --oneline -1

    echo ""
    echo "📥 Последняя версия на GitHub:"
    git fetch origin 2>/dev/null
    git log --oneline -1 origin/main

    echo ""
    echo "🔄 Статус обновлений:"
    if git status --porcelain | grep -q .; then
        echo "⚠️  Есть локальные изменения"
        echo "   Рекомендуется: ./traffic_connect.sh --force-update"
    else
        echo "✅ Нет локальных изменений"
    fi

    echo ""
    echo "📊 Разница с GitHub:"
    local_commit=$(git rev-parse HEAD)
    remote_commit=$(git rev-parse origin/main 2>/dev/null || echo "unknown")

    if [ "$local_commit" = "$remote_commit" ]; then
        echo "✅ Версия актуальна"
    else
        echo "⚠️  Версия устарела"
        echo "   Рекомендуется: ./traffic_connect.sh --force-update"
    fi

    echo ""
    echo "🚀 Для обновления выполните:"
    echo "   ./traffic_connect.sh --force-update"
}

# Принудительное обновление
force_update() {
    echo "🔄 Принудительное обновление Traffic Connect Fast Setup..."

    # Проверка, что мы в правильной папке
    if [ ! -f "install.sh" ]; then
        echo "❌ Ошибка: файл install.sh не найден"
        echo "Убедитесь, что вы находитесь в папке tc_fast_setup"
        exit 1
    fi

    echo "📥 Получение последних изменений..."
    git fetch origin

    echo "🔄 Принудительное обновление..."
    git reset --hard origin/main

    echo "🧹 Очистка кэша..."
    git clean -fd

    echo "✅ Обновление завершено!"
    echo ""
    echo "📋 Проверка изменений:"
    git log --oneline -3
    echo ""
    echo "🚀 Теперь можно запускать установку:"
    echo "   ./traffic_connect.sh --install"
}

# ============================================================================
# ФУНКЦИИ ОТОБРАЖЕНИЯ УЧЕТНЫХ ДАННЫХ
# ============================================================================

# Отображение учетных данных
show_credentials() {
    echo "🔍 Traffic Connect Fast Setup - Данные для входа"
    echo "================================================"

    # Проверка, что мы в правильной папке
    if [ ! -f "install.sh" ]; then
        echo "❌ Ошибка: файл install.sh не найден"
        echo "Убедитесь, что вы находитесь в папке tc_fast_setup"
        exit 1
    fi

    # Загрузка политики безопасности для функций генерации паролей
    source "$PROJECT_ROOT/system/security/security_policy.sh"

    # Отображение данных для входа
    show_access_credentials

    echo ""
    echo "💾 Сохранение данных в файл..."
    save_credentials "$GRAFANA_ADMIN_PASSWORD" "$HESTIA_USERNAME" "$HESTIA_PASSWORD"

    echo ""
    echo "📄 Данные также сохранены в файл: $CREDENTIALS_FILE"
    echo "🔒 Файл защищен правами 600 (только для root)"
}

# ============================================================================
# ФУНКЦИЯ УСТАНОВКИ МОНИТОРИНГА
# ============================================================================

# Функция установки только мониторинга
install_monitoring_only() {
    echo "🚀 Установка только системы мониторинга Traffic Connect Server"
    echo "================================================"
    
    # Проверка root прав
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Проверка и инициализация
    echo "🔧 Проверка и инициализация..."
    
    # Настройка логирования
    setup_logging
    
    # Проверка системных требований
    if ! check_system_requirements; then
        log_err "Системные требования не выполнены"
        exit 1
    fi
    
    # Проверка интернета
    check_internet

    # Проверка места на диске
    check_disk_space
    
    # Загружаем security_install.sh для доступа к функциям политики безопасности
    source "$PROJECT_ROOT/system/security/security_install.sh"
    
    # Генерация безопасных паролей
    echo "🔐 Генерация безопасных паролей..."
    generate_secure_passwords
    
    # Установка базовых пакетов
    echo "📦 Установка базовых пакетов..."
    source "$PROJECT_ROOT/core/installers/main_install.sh"
    
    if install_base_system; then
        log_ok "Базовые пакеты установлены"
    else
        log_err "Критическая ошибка: не удалось установить базовые пакеты"
        exit 1
    fi
    
    # Настройка безопасности
    echo "🛡️ Настройка безопасности..."
    if setup_security_from_module; then
        log_ok "Безопасность настроена"
    else
        log_err "Критическая ошибка: не удалось настроить безопасность"
        exit 1
    fi
    
    # Дополнительные проверки безопасности
    echo "🔍 Дополнительные проверки безопасности..."
    perform_security_audit
    
    # Установка системы мониторинга
    echo "📊 Установка системы мониторинга..."
    source "$PROJECT_ROOT/system/monitoring/monitoring_install.sh"
    
    if install_monitoring; then
        log_ok "Система мониторинга установлена"
    else
        log_err "Критическая ошибка: не удалось установить систему мониторинга"
        exit 1
    fi
    
    # Настройка веб-сервера
    echo "🌐 Настройка веб-сервера..."
    source "$PROJECT_ROOT/web/templates/templates_install.sh"
    
    if setup_web_server; then
        log_ok "Веб-сервер настроен"
    else
        log_warn "Предупреждение: не удалось настроить веб-сервер"
    fi
    
    echo "================================================"
    log_ok "Установка системы мониторинга Traffic Connect Server завершена успешно!"
    
    # Отображение данных для входа
    show_access_credentials_monitoring_only
    
    # Отображение всех сгенерированных паролей
    show_all_passwords_monitoring_only
    
    echo "📚 Документация: $PROJECT_ROOT/docs/"
    echo "🔧 Конфигурация: $PROJECT_ROOT/web/configs/"
    echo "🛡️ Безопасность: $PROJECT_ROOT/system/security/"
    echo ""
    echo "⚠️ ВНИМАНИЕ: HestiaCP не установлен из-за конфликтов пакетов"
    echo "   Для установки HestiaCP используйте чистый сервер или"
    echo "   запустите: ./traffic_connect.sh --install"
}

# Функция отображения данных для входа (только мониторинг)
show_access_credentials_monitoring_only() {
    echo ""
    echo "🔐 ДАННЫЕ ДЛЯ ВХОДА В СИСТЕМУ МОНИТОРИНГА"
    echo "================================================"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Grafana
    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        echo "📊 GRAFANA (Мониторинг):"
        echo "  🌐 URL: http://$server_ip:$GRAFANA_PORT"
        echo "  👤 Логин: $GRAFANA_USERNAME"
        echo "  🔑 Пароль: $GRAFANA_ADMIN_PASSWORD"
        echo ""
    fi
    
    # Prometheus
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        echo "📈 PROMETHEUS (Метрики):"
        echo "  🌐 URL: http://$server_ip:$PROMETHEUS_PORT"
        echo "  👤 Логин: $PROMETHEUS_USERNAME"
        echo "  🔑 Пароль: $PROMETHEUS_PASSWORD"
        echo ""
    fi
    
    # Node Exporter
    if systemctl is-active --quiet node_exporter 2>/dev/null; then
        echo "🖥️ NODE EXPORTER (Системные метрики):"
        echo "  🌐 URL: http://$server_ip:$NODE_EXPORTER_PORT"
        echo "  👤 Логин: $NODE_EXPORTER_USERNAME"
        echo "  🔑 Пароль: $NODE_EXPORTER_PASSWORD"
        echo ""
    fi
    
    # Loki
    if systemctl is-active --quiet loki 2>/dev/null; then
        echo "📝 LOKI (Логи):"
        echo "  🌐 URL: http://$server_ip:$LOKI_PORT"
        echo "  👤 Логин: $LOKI_USERNAME"
        echo "  🔑 Пароль: $LOKI_PASSWORD"
        echo ""
    fi
    
    echo "🔧 ДОПОЛНИТЕЛЬНЫЕ СЕРВИСЫ:"
    echo "  📊 Pushgateway: http://$server_ip:$PUSHGATEWAY_PORT"
    echo "  🛡️ Fail2ban Exporter: http://$server_ip:$FAIL2BAN_EXPORTER_PORT"
    echo ""
    
    echo "📋 СТАТУС УСТАНОВКИ:"
    echo "  ⏰ Время установки: $(date)"
    echo "  🖥️ Сервер: $(hostname)"
    echo "  🌐 IP адрес: $server_ip"
    echo ""
    
    echo "⚠️ ВАЖНО:"
    echo "  • Измените пароли после первого входа"
    echo "  • Настройте файрвол для безопасности"
    echo "  • Регулярно обновляйте систему"
    echo "  • HestiaCP не установлен (используйте чистый сервер)"
    echo ""
    
    echo "📁 ФАЙЛЫ КОНФИГУРАЦИИ:"
    echo "  🔧 Основная конфигурация: $PROJECT_ROOT/core/configs/configuration.sh"
    echo "  🛡️ Политика безопасности: $PROJECT_ROOT/system/security/security_policy.sh"
    echo "  📚 Документация: $PROJECT_ROOT/docs/"
    echo ""
    
    echo "================================================"
    echo "🎉 Установка системы мониторинга завершена успешно!"
    echo "================================================"
}

# Функция отображения всех паролей (только мониторинг)
show_all_passwords_monitoring_only() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║        ВСЕ СГЕНЕРИРОВАННЫЕ ПАРОЛИ (МОНИТОРИНГ) 🔑       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo "🔐 SSH ДОСТУП:"
    echo "  👤 Логин: root"
    echo "  🔑 Пароль: не изменялся"
    echo "  📝 Тип: Парольная аутентификация"
    echo ""
    
    echo "📊 GRAFANA (Мониторинг):"
    echo "  🌐 URL: http://$server_ip:$GRAFANA_PORT"
    echo "  👤 Логин: $GRAFANA_USERNAME"
    echo "  🔑 Пароль: $GRAFANA_ADMIN_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$GRAFANA_ADMIN_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "📈 PROMETHEUS (Метрики):"
    echo "  🌐 URL: http://$server_ip:$PROMETHEUS_PORT"
    echo "  👤 Логин: $PROMETHEUS_USERNAME"
    echo "  🔑 Пароль: $PROMETHEUS_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$PROMETHEUS_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "📝 LOKI (Логи):"
    echo "  🌐 URL: http://$server_ip:$LOKI_PORT"
    echo "  👤 Логин: $LOKI_USERNAME"
    echo "  🔑 Пароль: $LOKI_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$LOKI_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "🖥️ NODE EXPORTER (Системные метрики):"
    echo "  🌐 URL: http://$server_ip:$NODE_EXPORTER_PORT"
    echo "  👤 Логин: $NODE_EXPORTER_USERNAME"
    echo "  🔑 Пароль: $NODE_EXPORTER_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$NODE_EXPORTER_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "📤 PUSHGATEWAY (Отправка метрик):"
    echo "  🌐 URL: http://$server_ip:$PUSHGATEWAY_PORT"
    echo "  👤 Логин: $PUSHGATEWAY_USERNAME"
    echo "  🔑 Пароль: $PUSHGATEWAY_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$PUSHGATEWAY_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "🛡️ FAIL2BAN EXPORTER (Мониторинг безопасности):"
    echo "  🌐 URL: http://$server_ip:$FAIL2BAN_EXPORTER_PORT"
    echo "  👤 Логин: $FAIL2BAN_EXPORTER_USERNAME"
    echo "  🔑 Пароль: $FAIL2BAN_EXPORTER_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$FAIL2BAN_EXPORTER_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "⚠️ ВАЖНЫЕ НАПОМИНАНИЯ:"
    echo "  • Все пароли сгенерированы автоматически"
    echo "  • Сохраните эти данные в безопасном месте"
    echo "  • Рекомендуется изменить пароли после первого входа"
    echo "  • SSH ключи для пользователей нужно добавить вручную"
    echo "  • HestiaCP не установлен (используйте чистый сервер)"
    echo ""
    
    echo "📁 ФАЙЛЫ С ПАРОЛЯМИ:"
    echo "  🔒 Основной файл: /root/.traffic_connect/credentials.txt"
    echo "  🔒 SSH доступ: /root/.traffic_connect/ssh_access.txt"
    echo "  ⏰ Автоматическое удаление через 24 часа"
    echo ""
    
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              ПАРОЛИ СОХРАНЕНЫ ✅                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================================

show_menu() {
    echo ""
    echo "🚀 Traffic Connect - Единый скрипт для всех операций"
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
    echo "  4) УНИВЕРСАЛЬНАЯ УСТАНОВКА ВСЕГО (install_all.sh)"
    echo "  5) Установка только HestiaCP"
    echo "  6) Установка только мониторинга"
    echo ""
    echo "📊 ИНФОРМАЦИЯ:"
    echo "  8) Показать учетные данные"
    echo "  9) Проверить безопасность"
    echo "  10) Проверить версии"
    echo "  11) Принудительное обновление"
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
        read -p "Выберите действие (0-10): " choice
        
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
                echo "Запуск универсальной установки..."
                ./install_all.sh
                ;;
            5)
                install_hestia_only
                ;;
            6)
                echo "Запуск установки только мониторинга..."
                install_monitoring_only
                ;;
            7)
                show_credentials
                ;;
            8)
                main_security_check
                ;;
            9)
                check_version
                ;;
            10)
                force_update
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
            install_monitoring_only
            ;;
        --install)
            ./install_all.sh
            ;;
        --install-all)
            ./install_all.sh
            ;;
        --show-credentials)
            show_credentials
            ;;
        --check-security)
            main_security_check
            ;;
        --check-version)
            check_version
            ;;
        --force-update)
            force_update
            ;;
        --help|-h)
            echo "🚀 Traffic Connect - Единый скрипт для всех операций"
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
            echo "  --install            УНИВЕРСАЛЬНАЯ УСТАНОВКА ВСЕГО"
            echo "  --install-all        УНИВЕРСАЛЬНАЯ УСТАНОВКА ВСЕГО"
            echo "  --show-credentials   Показать учетные данные"
            echo "  --check-security     Проверить безопасность"
            echo "  --check-version      Проверить версии"
            echo "  --force-update       Принудительное обновление"
            echo "  --help, -h           Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0 --fix-dpkg"
            echo "  $0 --install-scratch"
            echo "  $0 --install-hestia"
            echo "  $0 --check-security"
            echo ""
            echo "💡 Без аргументов запускается интерактивное меню"
            ;;
        *)
            echo "❌ Неизвестная опция: $1"
            echo "Используйте --help для получения справки"
            exit 1
            ;;
    esac
fi
