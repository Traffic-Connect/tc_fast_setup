#!/bin/bash

# ============================================================================
# ЭТАП 3: УСТАНОВКА АДМИНИСТРАТИВНОЙ ПАНЕЛИ (HestiaCP)
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/scripts/configuration.sh"
source "$PROJECT_ROOT/scripts/libraries/common.sh"

install_admin_panel() {
    log_info "=== ЭТАП 3: Установка административной панели (HestiaCP) ==="
    
    log_info "Установка административной панели HestiaCP..."
    
    # Загрузка скрипта установки HestiaCP
    log_info "Загрузка скрипта установки HestiaCP..."
    if ! wget https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh -O /tmp/hst-install.sh; then
        log_err "Ошибка загрузки скрипта установки HestiaCP"
        return 1
    fi
    
    # Проверка загруженного файла
    if [ ! -f "/tmp/hst-install.sh" ]; then
        log_err "Скрипт установки HestiaCP не найден"
        return 1
    fi
    
    # Сделать скрипт исполняемым
    chmod +x /tmp/hst-install.sh
    
    log_info "Запуск установки HestiaCP..."
    log_info "Параметры установки:"
    log_info "  Hostname: hostname.domain.tld"
    log_info "  Username: Trafficadmin"
    log_info "  Email: info@domain.tld"
    log_info "  Language: ru"
    log_info "  Password: $ADMIN_PASSWORD"
    log_info "  Apache: no"
    log_info "  Named: no"
    log_info "  Exim: no"
    log_info "  Dovecot: no"
    log_info "  ClamAV: no"
    log_info "  SpamAssassin: no"
    
    # Запуск установки HestiaCP с указанными параметрами
    if bash /tmp/hst-install.sh \
        --lang 'ru' \
        --hostname 'hostname.domain.tld' \
        --username 'Trafficadmin' \
        --email 'info@domain.tld' \
        --password "$ADMIN_PASSWORD" \
        --apache no \
        --named no \
        --exim no \
        --dovecot no \
        --clamav no \
        --spamassassin no \
        --force; then
        
        log_ok "✅ HestiaCP установлен успешно"
    else
        log_err "❌ Ошибка установки HestiaCP"
        return 1
    fi
    
    # Очистка временного файла
    rm -f /tmp/hst-install.sh
    
    # Проверка установки
    log_info "Проверка установки HestiaCP..."
    
    # Проверка службы admin
    if systemctl is-active --quiet admin; then
        log_ok "✅ Служба admin активна"
    else
        log_warn "⚠️  Служба admin неактивна"
        # Попытка запуска
        systemctl start admin
        sleep 3
        if systemctl is-active --quiet admin; then
            log_ok "✅ Служба admin запущена"
        else
            log_err "❌ Не удалось запустить службу admin"
            return 1
        fi
    fi
    
    # Проверка файлов административной панели
    if [ -f "/usr/local/admin/bin/admin" ]; then
        log_ok "✅ Файлы административной панели установлены"
    else
        log_err "❌ Файлы административной панели не найдены"
        return 1
    fi
    
    # Проверка доступности веб-интерфейса
    log_info "Проверка доступности веб-интерфейса..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$ADMIN_PORT" >/dev/null 2>&1; then
            log_ok "✅ Веб-интерфейс доступен на порту $ADMIN_PORT"
            break
        else
            log_info "Попытка $attempt/$max_attempts: Ожидание запуска веб-интерфейса..."
            sleep 2
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warn "⚠️  Веб-интерфейс не стал доступен в течение $((max_attempts * 2)) секунд"
    fi
    
    # Информация о доступе
    log_info "Информация о доступе к административной панели:"
    log_info "  URL: http://hostname.domain.tld:$ADMIN_PORT"
    log_info "  Логин: Trafficadmin"
    log_info "  Пароль: $ADMIN_PASSWORD"
    log_info "  Email: info@domain.tld"
    
    log_ok "✅ Этап 3 завершен успешно"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_admin_panel
fi
