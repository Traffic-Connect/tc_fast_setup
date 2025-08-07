#!/bin/bash

# ============================================================================
# Traffic Connect - Исправление проблем Composer в HestiaCP
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

echo "🔧 Исправление проблем Composer в HestiaCP"
echo "================================================"

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Проверка, установлен ли HestiaCP
if [ ! -f "/usr/local/admin/bin/admin" ] && [ ! -d "/usr/local/admin" ]; then
    echo "❌ HestiaCP не установлен. Сначала установите HestiaCP."
    exit 1
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
    exit 1
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

echo ""
echo "✅ Исправление завершено!"
echo ""
echo "📋 Выполненные действия:"
echo "  • Настроен Composer с увеличенными таймаутами"
echo "  • Установлен Composer 2.8.10"
echo "  • Настроен PHP для работы с SSL"
echo "  • Перезапущены сервисы HestiaCP"
echo "  • Попытка завершения прерванной установки"
echo ""
echo "🌐 Проверьте доступ к HestiaCP:"
echo "  URL: https://$(hostname -I | awk '{print $1}'):8083"
echo ""
echo "🔧 Если установка все еще зависла, перезапустите сервер:"
echo "  reboot"
