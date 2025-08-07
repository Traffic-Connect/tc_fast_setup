#!/bin/bash

# ============================================================================
# ЭТАП 3: УСТАНОВКА АДМИНИСТРАТИВНОЙ ПАНЕЛИ
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

install_admin_panel() {
    log_info "=== ЭТАП 3: Установка административной панели ==="
    
    # Проверка, не установлен ли уже HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || [ -d "/usr/local/admin" ] || systemctl is-active --quiet admin 2>/dev/null || [ -f "/usr/local/hestia/install.log" ]; then
        log_warn "HestiaCP уже установлен, пропускаем установку"
            log_info "Информация о существующей установке HestiaCP:"
    log_info "  URL: https://$(get_server_ip):8083"
        log_info "  Статус: ✅ Уже установлена и работает"
        log_ok "✅ Этап 3 завершен успешно (пропущен)"
        return 0
    fi
    
    log_info "Установка HestiaCP..."
    
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
    
    if [ ${#conflicting_packages[@]} -gt 0 ]; then
        log_warn "Обнаружены конфликтующие пакеты: ${conflicting_packages[*]}"
        log_info "Временно удаляем конфликтующие пакеты для установки HestiaCP..."
        
        # Останавливаем и удаляем конфликтующие пакеты
        for package in "${conflicting_packages[@]}"; do
            log_info "Удаление пакета: $package"
            systemctl stop "$package" 2>/dev/null || true
            apt remove --purge -y "$package" 2>/dev/null || true
            apt autoremove -y
        done
        
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
    
    # Загрузка скрипта установки HestiaCP (используем функцию из hestia_install.sh)
    log_info "Загрузка установщика HestiaCP..."
    
    # Загружаем функцию установки HestiaCP
    if [ -f "$PROJECT_ROOT/core/installers/hestia_install.sh" ]; then
        source "$PROJECT_ROOT/core/installers/hestia_install.sh"
        # Используем функцию загрузки из hestia_install.sh
        download_hestia_installer
    else
        log_err "Файл hestia_install.sh не найден"
        return 1
    fi
    
    # Предварительная установка Composer с правильными настройками SSL
    log_info "Предварительная настройка Composer для решения проблем SSL..."
    
    # Создаем временный скрипт для установки Composer
    cat > /tmp/install_composer.sh << 'EOF'
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
            bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --composer no --force
    
    if [ $? -eq 0 ]; then
        log_ok "✅ HestiaCP установлен успешно"
        
        # Восстановление безопасности после установки HestiaCP
        if [ ${#conflicting_packages[@]} -gt 0 ]; then
            log_info "Восстановление настроек безопасности..."
            
            # Перезапускаем настройку безопасности
            source "$PROJECT_ROOT/system/security/security_install.sh"
            setup_security_from_module
            
            log_ok "✅ Настройки безопасности восстановлены"
        fi
    else
        log_err "❌ Ошибка установки HestiaCP"
        return 1
    fi
    
    # Очистка временных файлов
    log_info "Очистка временных файлов..."
    rm -f /tmp/hst-install.sh /tmp/install_composer.sh
    rm -rf /tmp/composer
    
    # Информация о доступе к HestiaCP
            log_info "Информация о доступе к HestiaCP:"
        log_info "  URL: https://$(get_server_ip):8083"
    log_info "  Логин: $HESTIA_USERNAME"
            log_info "  Пароль: [СКРЫТ]"
    log_info "  Статус: ✅ Установлена и работает"
    
    log_ok "✅ Этап 3 завершен успешно"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_admin_panel
fi
