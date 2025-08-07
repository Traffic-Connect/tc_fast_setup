#!/bin/bash

# ============================================================================
# Traffic Connect - Исправление проблем SSL таймаута
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

echo "🔧 Исправление проблем SSL таймаута для HestiaCP"
echo "================================================"

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Настройка SSL для решения проблем с таймаутом
log_info "Настройка SSL для стабильной установки..."

# Увеличиваем таймауты для SSL соединений
export CURL_CONNECT_TIMEOUT=60
export CURL_TIMEOUT=300
export WGET_TIMEOUT=300
export COMPOSER_TIMEOUT=300

# Настройка SSL для wget
log_info "Настройка wget..."
echo "check_certificate = off" >> ~/.wgetrc 2>/dev/null || true
echo "timeout = 300" >> ~/.wgetrc 2>/dev/null || true
echo "tries = 3" >> ~/.wgetrc 2>/dev/null || true

# Настройка SSL для curl
log_info "Настройка curl..."
echo "connect-timeout = 60" >> ~/.curlrc 2>/dev/null || true
echo "max-time = 300" >> ~/.curlrc 2>/dev/null || true
echo "retry = 3" >> ~/.curlrc 2>/dev/null || true
echo "insecure" >> ~/.curlrc 2>/dev/null || true

# Настройка Composer
log_info "Настройка Composer..."
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
log_info "Установка Composer с правильными настройками SSL..."

for attempt in 1 2 3; do
    log_info "Попытка установки Composer $attempt/3..."
    
    if curl --connect-timeout 60 --max-time 300 -k -o /tmp/composer.phar https://getcomposer.org/download/2.8.10/composer.phar; then
        log_ok "Composer загружен успешно"
        chmod +x /tmp/composer.phar
        mv /tmp/composer.phar /usr/local/bin/composer
        break
    else
        log_warn "Попытка $attempt не удалась, повторяем..."
        sleep 5
    fi
done

# Проверка установки Composer
if [ -f "/usr/local/bin/composer" ]; then
    log_ok "✅ Composer установлен успешно"
    composer --version
else
    log_err "❌ Не удалось установить Composer"
    exit 1
fi

# Настройка PHP для работы с SSL
log_info "Настройка PHP для работы с SSL..."

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
    log_info "Применение настроек SSL для PHP CLI..."
    cp /tmp/php-ssl.ini /etc/php/8.1/cli/conf.d/99-ssl-fix.ini
fi

if [ -f "/etc/php/8.1/fpm/php.ini" ]; then
    log_info "Применение настроек SSL для PHP FPM..."
    cp /tmp/php-ssl.ini /etc/php/8.1/fpm/conf.d/99-ssl-fix.ini
fi

# Очистка временных файлов
rm -f /tmp/php-ssl.ini

log_ok "✅ Настройки SSL применены успешно"
log_info "Теперь можно запускать установку HestiaCP без проблем с SSL таймаутом"

echo ""
echo "📋 Примененные настройки:"
echo "  • Увеличены таймауты для wget, curl и Composer"
echo "  • Отключена проверка SSL сертификатов для загрузки"
echo "  • Настроены повторные попытки загрузки"
echo "  • Установлен Composer с правильными настройками"
echo "  • Настроен PHP для работы с SSL"
echo ""
echo "🚀 Теперь можно запускать установку HestiaCP!"
