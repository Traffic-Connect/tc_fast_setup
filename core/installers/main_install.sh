#!/bin/bash

# ============================================================================
# ЭТАП 1: УСТАНОВКА БАЗОВОЙ СИСТЕМЫ
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

install_base_system() {
    log_info "=== ЭТАП 1: Установка базовой системы ==="
    
    log_info "Установка базовых пакетов..."
    
    # Настройка локали
    log_info "Настройка локали..."
    export LC_ALL=C
    export LANG=C
    export LANGUAGE=C
    
    # Обновление системы
    log_info "Обновление системы..."
    
    # Исправление прерванной установки dpkg
    if dpkg -l | grep -q "^iU"; then
        log_info "Обнаружена прерванная установка dpkg, исправляем..."
        dpkg --configure -a
        apt-get install -f -y
    fi
    
    apt update && apt upgrade -y
    
    # Установка базовых пакетов
    log_info "Установка базовых пакетов..."
    
    # Предварительная настройка iptables-persistent для автоматического ответа
    log_info "Настройка автоматического ответа для iptables-persistent..."
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
    
    # Установка пакетов с неинтерактивным режимом
    log_info "Установка основных пакетов..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        fail2ban \
        iptables-persistent \
        netfilter-persistent \
        curl \
        wget \
        software-properties-common \
        apt-transport-https \
        python3 \
        python3-pip \
        python3-venv \
        git \
        gnupg2 \
        ca-certificates \
        adduser \
        ncdu \
        libfontconfig1 \
        unzip \
        cron \
        locales || log_warn "Некоторые пакеты не установились"
    
    # Попытка установки nginx отдельно (может быть конфликт)
    # Проверяем, не установлен ли уже HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || [ -d "/usr/local/admin" ] || is_service_active "admin" || [ -f "/usr/local/hestia/install.log" ]; then
        log_warn "⚠️ HestiaCP уже установлен, пропускаем установку Nginx"
    else
        log_info "Попытка установки Nginx..."
        if DEBIAN_FRONTEND=noninteractive apt install -y nginx 2>/dev/null; then
            log_ok "✅ Nginx установлен"
        else
            log_warn "⚠️ Nginx не установился (возможно, конфликт с другими веб-серверами)"
        fi
    fi 
    
    # Включение и запуск nginx (если установлен)
    log_info "Настройка Nginx..."
    if systemctl list-unit-files | grep -q "nginx.service"; then
        systemctl enable nginx 2>/dev/null || log_warn "Не удалось включить nginx (возможно, не установлен)"
        systemctl start nginx 2>/dev/null || log_warn "Не удалось запустить nginx (возможно, не установлен)"
        
        # Проверка установки
        if is_service_active "nginx"; then
            log_ok "✅ Nginx запущен"
        else
            log_warn "⚠️ Nginx не запущен (возможно, не установлен или конфликт)"
        fi
    else
        log_warn "⚠️ Nginx не установлен, пропускаем настройку"
    fi
    
    log_ok "✅ Этап 1 завершен успешно"
    log_info "Примечание: некоторые пакеты могут быть не установлены из-за конфликтов"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_base_system
fi 