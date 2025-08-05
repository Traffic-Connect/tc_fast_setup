#!/bin/bash

# ============================================================================
# ЭТАП 1: УСТАНОВКА БАЗОВОЙ СИСТЕМЫ
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/configuration.sh"
source "$PROJECT_ROOT/libraries/common.sh"

install_base_system() {
    log_info "=== ЭТАП 1: Установка базовой системы ==="
    
    log_info "Установка базовых пакетов..."
    
    # Обновление системы
    log_info "Обновление системы..."
    apt update && apt upgrade -y
    
    # Установка базовых пакетов
    log_info "Установка базовых пакетов..."
    apt install -y \
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
        nginx 
    
    # Включение и запуск nginx
    log_info "Настройка Nginx..."
    systemctl enable nginx
    systemctl start nginx
    
    # Проверка установки
    if systemctl is-active --quiet nginx; then
        log_ok "✅ Nginx запущен"
    else
        log_err "❌ Ошибка запуска Nginx"
        return 1
    fi
    
    log_ok "✅ Этап 1 завершен успешно"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_base_system
fi 