#!/bin/bash

# ============================================================================
# Traffic Connect - Установка только HestiaCP на чистом сервере
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

echo "🚀 Установка HestiaCP на чистом сервере"
echo "================================================"

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Проверка, не установлен ли уже HestiaCP
if [ -f "/usr/local/admin/bin/admin" ] || [ -d "/usr/local/admin" ] || systemctl is-active --quiet admin 2>/dev/null || [ -f "/usr/local/hestia/install.log" ]; then
    log_warn "HestiaCP уже установлен, пропускаем установку"
    log_info "Информация о существующей установке HestiaCP:"
    log_info "  URL: https://$(hostname -I | awk '{print $1}'):8083"
    log_info "  Статус: ✅ Уже установлена и работает"
    exit 0
fi

# Генерация пароля для HestiaCP
log_info "Генерация пароля для HestiaCP..."
if type generate_compliant_password >/dev/null 2>&1; then
    HESTIA_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
else
    HESTIA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
fi

export HESTIA_PASSWORD

log_info "Пароль для HestiaCP: $HESTIA_PASSWORD"

# Проверка и удаление существующего пользователя если конфликт
if id "$HESTIA_USERNAME" &>/dev/null; then
    log_warn "Пользователь $HESTIA_USERNAME уже существует, удаляем..."
    userdel -r "$HESTIA_USERNAME" 2>/dev/null || true
    groupdel "$HESTIA_USERNAME" 2>/dev/null || true
fi

# Проверка конфликтующих пакетов
log_info "Проверка конфликтующих пакетов..."
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
    log_warn "Обнаружены конфликтующие пакеты: ${conflicting_packages[*]}"
    log_info "Удаляем конфликтующие пакеты для установки HestiaCP..."
    
    # Останавливаем и удаляем конфликтующие пакеты
    for package in "${conflicting_packages[@]}"; do
        log_info "Удаление пакета: $package"
        systemctl stop "$package" 2>/dev/null || true
        apt remove --purge -y "$package" 2>/dev/null || true
    done
    
    apt autoremove -y
    log_info "Конфликтующие пакеты удалены"
fi

# Настройка SSL для решения проблем с таймаутом
log_info "Настройка SSL для стабильной установки..."

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
log_info "Загрузка установщика HestiaCP..."
local download_success=false

for attempt in 1 2 3; do
    log_info "Попытка загрузки $attempt/3..."
    
    if wget --timeout=300 --tries=3 --no-check-certificate -O /tmp/hst-install.sh https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh; then
        download_success=true
        break
    else
        log_warn "Попытка $attempt не удалась, повторяем..."
        sleep 5
    fi
done

if [ ! -f "/tmp/hst-install.sh" ] || [ "$download_success" = false ]; then
    log_err "❌ Не удалось загрузить установщик HestiaCP после 3 попыток"
    log_info "Пробуем альтернативный метод загрузки..."
    
    # Альтернативная загрузка через curl
    if curl --connect-timeout 60 --max-time 300 -k -o /tmp/hst-install.sh https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh; then
        log_ok "✅ Установщик загружен через curl"
    else
        log_err "❌ Не удалось загрузить установщик HestiaCP"
        exit 1
    fi
fi

chmod +x /tmp/hst-install.sh

# Предварительная установка Composer с правильными настройками SSL
log_info "Предварительная настройка Composer для решения проблем SSL..."

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
log_info "Выполнение установки HestiaCP..."
bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force

if [ $? -eq 0 ]; then
    log_ok "✅ HestiaCP установлен успешно"
else
    log_err "❌ Ошибка установки HestiaCP"
    exit 1
fi

# Очистка временных файлов
log_info "Очистка временных файлов..."
rm -f /tmp/hst-install.sh /tmp/install_composer.sh
rm -rf /tmp/composer

# Информация о доступе к HestiaCP
log_info "Информация о доступе к HestiaCP:"
log_info "  URL: https://$(hostname -I | awk '{print $1}'):8083"
log_info "  Логин: $HESTIA_USERNAME"
log_info "  Пароль: $HESTIA_PASSWORD"
log_info "  Статус: ✅ Установлена и работает"

log_ok "✅ Установка HestiaCP завершена успешно"
echo ""
echo "🎉 HestiaCP установлен и готов к использованию!"
echo "🌐 URL: https://$(hostname -I | awk '{print $1}'):8083"
echo "👤 Логин: $HESTIA_USERNAME"
echo "🔑 Пароль: $HESTIA_PASSWORD"
