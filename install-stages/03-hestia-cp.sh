#!/bin/bash

# ============================================================================
# ЭТАП 3: УСТАНОВКА HESTIA CONTROL PANEL
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/configuration.sh"
source "$PROJECT_ROOT/libraries/common.sh"

# Am I root?
if [ "x$(id -u)" != 'x0' ]; then
    log_err "Error: this script can only be executed by root"
    exit 1
fi

# Check admin user account
if [ -n "$(grep ^admin: /etc/passwd)" ] && [ -z "$FORCE" ]; then
    log_err "Error: user admin exists"
    log_info "Please remove admin user before proceeding."
    log_info "If you want to do it automatically run installer with --force option:"
    log_info "Example: bash $0 --force"
    exit 1
fi

# Check admin group
if [ -n "$(grep ^admin: /etc/group)" ] && [ -z "$FORCE" ]; then
    log_err "Error: group admin exists"
    log_info "Please remove admin group before proceeding."
    log_info "If you want to do it automatically run installer with --force option:"
    log_info "Example: bash $0 --force"
    exit 1
fi

# Parse command line arguments (default values)
LANG="${HESTIA_LANG:-ru}"
HOSTNAME="${HESTIA_HOSTNAME:-hostname.domain.tld}"
USERNAME="${HESTIA_USERNAME:-Trafficadmin}"
EMAIL="${HESTIA_EMAIL:-info@domain.tld}"
PASSWORD="${HESTIA_PASSWORD:-12345}"
APACHE="${HESTIA_APACHE:-no}"
NAMED="${HESTIA_NAMED:-no}"
EXIM="${HESTIA_EXIM:-no}"
DOVECOT="${HESTIA_DOVECOT:-no}"
CLAMAV="${HESTIA_CLAMAV:-no}"
SPAMASSASSIN="${HESTIA_SPAMASSASSIN:-no}"
FORCE="${HESTIA_FORCE:---force}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --lang)
            LANG="$2"
            shift 2
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --apache)
            APACHE="$2"
            shift 2
            ;;
        --named)
            NAMED="$2"
            shift 2
            ;;
        --exim)
            EXIM="$2"
            shift 2
            ;;
        --dovecot)
            DOVECOT="$2"
            shift 2
            ;;
        --clamav)
            CLAMAV="$2"
            shift 2
            ;;
        --spamassassin)
            SPAMASSASSIN="$2"
            shift 2
            ;;
        --force)
            FORCE="--force"
            shift
            ;;
        *)
            log_err "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

install_hestia_cp() {
    log_info "=== ЭТАП 3: Установка Hestia Control Panel ==="
    
    log_info "Установка Hestia Control Panel..."
    
    # Получение настроек Hestia CP
    local hestia_hostname="${HESTIA_HOSTNAME:-$HOSTNAME}"
    local hestia_email="${HESTIA_EMAIL:-$EMAIL}"
    local hestia_username="${HESTIA_USERNAME:-Trafficadmin}"
    
    log_info "Настройки Hestia CP:"
    log_info "  Hostname: $hestia_hostname"
    log_info "  Email: $hestia_email"
    log_info "  Username: $hestia_username"
    log_info "  Apache: $APACHE"
    log_info "  Named: $NAMED"
    log_info "  Exim: $EXIM"
    log_info "  Dovecot: $DOVECOT"
    log_info "  ClamAV: $CLAMAV"
    log_info "  SpamAssassin: $SPAMASSASSIN"
    
    # Detect Ubuntu version
    if [ -e "/etc/os-release" ]; then
        type=$(grep "^ID=" /etc/os-release | cut -f 2 -d '=')
        if [ "$type" != "ubuntu" ]; then
            log_err "Unsupported OS: $type"
            log_info "This script is designed to run only on Ubuntu"
            return 1
        fi
        
        if [ -e '/usr/bin/lsb_release' ]; then
            release="$(lsb_release -s -r)"
        else
            log_err "lsb_release is currently not installed, please install it:"
            log_info "apt-get update && apt-get install lsb-release"
            return 1
        fi
    else
        log_err "Cannot detect OS"
        return 1
    fi

    log_info "Обнаружена ОС: Ubuntu $release"

    # Check Ubuntu version support
    if [[ "$release" =~ ^(22.04|24.04)$ ]]; then
        log_info "Ubuntu $release поддерживается"
    else
        log_err "Ubuntu $release не поддерживается"
        log_info "Поддерживаемые версии: Ubuntu 22.04, 24.04"
        return 1
    fi
    
    # Очистка предыдущей установки
    log_info "Очистка предыдущей установки..."
    systemctl stop hestia nginx 2>/dev/null || true
    
    # Удаление пользователей и групп
    log_info "Удаление существующих пользователей и групп..."
    userdel -r "$hestia_username" 2>/dev/null || true
    userdel -r admin 2>/dev/null || true
    groupdel "$hestia_username" 2>/dev/null || true
    groupdel admin 2>/dev/null || true
    
    # Удаление директорий
    rm -rf /usr/local/hestia /home/admin "/home/$hestia_username" 2>/dev/null || true
    
    # Установка необходимых пакетов
    log_info "Установка необходимых пакетов..."
    apt-get update
    apt-get install -y nginx apache2-utils wget curl lsb-release
    
    # Проверка и создание пользователя
    log_info "Проверка пользователя $hestia_username..."
    if id "$hestia_username" &>/dev/null; then
        log_warn "Пользователь $hestia_username уже существует, удаляем..."
        userdel -r "$hestia_username" 2>/dev/null || true
        groupdel "$hestia_username" 2>/dev/null || true
        rm -rf "/home/$hestia_username" 2>/dev/null || true
    fi
    
    # Создание пользователя
    log_info "Создание пользователя $hestia_username..."
    useradd -m -s /bin/bash "$hestia_username"
    echo "$hestia_username:$HESTIA_PASSWORD" | chpasswd
    
    # Дополнительная очистка перед установкой
    log_info "Дополнительная очистка перед установкой..."
    pkill -f hestia 2>/dev/null || true
    pkill -f nginx 2>/dev/null || true
    sleep 2
    
    # Установка Hestia CP
    log_info "Установка Hestia Control Panel..."
    cd /tmp || exit
    
    # Загрузка и запуск официального установщика
    log_info "Загружаем официальный установщик Hestia CP..."
    
    # Проверка wget
    if [ -e '/usr/bin/wget' ]; then
        log_info "Используем wget для загрузки..."
        wget -q "https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install-ubuntu.sh" -O "/tmp/hst-install-ubuntu.sh"
        if [ "$?" -eq '0' ] && [ -f "/tmp/hst-install-ubuntu.sh" ]; then
            log_info "Установщик успешно загружен"
            chmod +x /tmp/hst-install-ubuntu.sh
            log_info "Запускаем установку Hestia CP..."
            echo "y" | bash /tmp/hst-install-ubuntu.sh \
                --lang "$LANG" \
                --hostname "$hestia_hostname" \
                --username "$hestia_username" \
                --email "$hestia_email" \
                --password "$HESTIA_PASSWORD" \
                --apache "$APACHE" \
                --named "$NAMED" \
                --exim "$EXIM" \
                --dovecot "$DOVECOT" \
                --clamav "$CLAMAV" \
                --spamassassin "$SPAMASSASSIN" \
                --force
            local install_result=$?
            rm -f /tmp/hst-install-ubuntu.sh
            
            if [ $install_result -eq 0 ]; then
                # Создание директорий для логов
                mkdir -p /var/log/nginx /var/log/hestia
                
                # Проверка установки
                if [ -f "/usr/local/hestia/bin/hestia" ]; then
                    log_ok "✅ Hestia CP установлен"
                    log_info "Панель управления: https://$hestia_hostname:8083"
                    log_info "Логин: $hestia_username"
                    log_info "Пароль: $HESTIA_PASSWORD"
                else
                    log_err "❌ Ошибка установки Hestia CP"
                    return 1
                fi
            else
                log_err "❌ Ошибка при запуске установщика Hestia CP"
                return 1
            fi
        else
            log_err "Error: hst-install-ubuntu.sh download failed."
            return 1
        fi
    # Проверка curl
    elif [ -e '/usr/bin/curl' ]; then
        log_info "Используем curl для загрузки..."
        curl -s -o "/tmp/hst-install-ubuntu.sh" "https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install-ubuntu.sh"
        if [ "$?" -eq '0' ] && [ -f "/tmp/hst-install-ubuntu.sh" ]; then
            log_info "Установщик успешно загружен"
            chmod +x /tmp/hst-install-ubuntu.sh
            log_info "Запускаем установку Hestia CP..."
            echo "y" | bash /tmp/hst-install-ubuntu.sh \
                --lang "$LANG" \
                --hostname "$hestia_hostname" \
                --username "$hestia_username" \
                --email "$hestia_email" \
                --password "$HESTIA_PASSWORD" \
                --apache "$APACHE" \
                --named "$NAMED" \
                --exim "$EXIM" \
                --dovecot "$DOVECOT" \
                --clamav "$CLAMAV" \
                --spamassassin "$SPAMASSASSIN" \
                --force
            local install_result=$?
            rm -f /tmp/hst-install-ubuntu.sh
            
            if [ $install_result -eq 0 ]; then
                # Создание директорий для логов
                mkdir -p /var/log/nginx /var/log/hestia
                
                # Проверка установки
                if [ -f "/usr/local/hestia/bin/hestia" ]; then
                    log_ok "✅ Hestia CP установлен"
                    log_info "Панель управления: https://$hestia_hostname:8083"
                    log_info "Логин: $hestia_username"
                    log_info "Пароль: $HESTIA_PASSWORD"
                else
                    log_err "❌ Ошибка установки Hestia CP"
                    return 1
                fi
            else
                log_err "❌ Ошибка при запуске установщика Hestia CP"
                return 1
            fi
        else
            log_err "Error: hst-install-ubuntu.sh download failed."
            return 1
        fi
    else
        log_err "Error: wget or curl not found"
        return 1
    fi
    
    log_ok "✅ Этап 3 завершен успешно"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_hestia_cp
fi 