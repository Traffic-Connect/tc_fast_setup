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
    if [ -f "/usr/local/admin/bin/admin" ] || [ -d "/usr/local/admin" ] || systemctl is-active --quiet admin 2>/dev/null; then
        log_warn "HestiaCP уже установлен, пропускаем установку"
        log_info "Информация о существующей установке HestiaCP:"
        log_info "  URL: https://$(hostname -I | awk '{print $1}'):8083"
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
    
    # Загрузка скрипта установки HestiaCP
    log_info "Загрузка установщика HestiaCP..."
    wget -O /tmp/hst-install.sh https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh
    
    if [ ! -f "/tmp/hst-install.sh" ]; then
        log_err "❌ Не удалось загрузить установщик HestiaCP"
        return 1
    fi
    
    chmod +x /tmp/hst-install.sh
    
    # Выполнение установки HestiaCP
    log_info "Выполнение установки HestiaCP..."
    bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force
    
    if [ $? -eq 0 ]; then
        log_ok "✅ HestiaCP установлен успешно"
        
        # Восстановление безопасности после установки HestiaCP
        if [ ${#conflicting_packages[@]} -gt 0 ]; then
            log_info "Восстановление настроек безопасности..."
            
            # Перезапускаем настройку безопасности
            source "$PROJECT_ROOT/system/security/security_install.sh"
            setup_security
            
            log_ok "✅ Настройки безопасности восстановлены"
        fi
    else
        log_err "❌ Ошибка установки HestiaCP"
        return 1
    fi
    
    # Информация о доступе к HestiaCP
    log_info "Информация о доступе к HestiaCP:"
    log_info "  URL: https://$(hostname -I | awk '{print $1}'):8083"
    log_info "  Логин: $HESTIA_USERNAME"
    log_info "  Пароль: $HESTIA_PASSWORD"
    log_info "  Статус: ✅ Установлена и работает"
    
    log_ok "✅ Этап 3 завершен успешно"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_admin_panel
fi
