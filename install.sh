#!/bin/bash
# ============================================================================
# Traffic Connect Server - Модульный установщик
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/scripts/configuration.sh"
source "$PROJECT_ROOT/scripts/libraries/common.sh"

# ============================================================================
# ПРОВЕРКА И ИНИЦИАЛИЗАЦИЯ
# ============================================================================

# Функции проверки и инициализации
check_and_init() {
    # Проверка root прав
    check_root
    
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
}

# ============================================================================
# УСТАНОВКА БАЗОВЫХ ПАКЕТОВ
# ============================================================================

install_base_packages() {
    log_info "Установка базовых пакетов..."
    
    # Использование модульного установщика базовой системы
    source "$PROJECT_ROOT/modules/base/install.sh"
    
    if install_base_system; then
        log_ok "Базовые пакеты установлены"
        return 0
    else
        log_err "Ошибка установки базовых пакетов"
        return 1
    fi
}

# ============================================================================
# НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================================

setup_security() {
    log_info "Настройка безопасности..."
    
    # Использование модульного установщика безопасности
    source "$PROJECT_ROOT/modules/security/install.sh"
    
    if setup_security; then
        log_ok "Безопасность настроена"
        return 0
    else
        log_err "Ошибка настройки безопасности"
        return 1
    fi
}

# ============================================================================
# УСТАНОВКА АДМИНИСТРАТИВНОЙ ПАНЕЛИ
# ============================================================================

install_admin_panel() {
    log_info "Установка административной панели..."
    
    # Использование модульного установщика административной панели
    source "$PROJECT_ROOT/modules/admin/install.sh"
    
    if install_admin_panel; then
        log_ok "Административная панель установлена"
        return 0
    else
        log_err "Ошибка установки административной панели"
        return 1
    fi
}

# ============================================================================
# УСТАНОВКА СИСТЕМЫ МОНИТОРИНГА
# ============================================================================

install_monitoring() {
    log_info "Установка системы мониторинга..."
    
    # Использование модульного установщика мониторинга
    source "$PROJECT_ROOT/modules/monitoring/install.sh"
    
    if install_monitoring; then
        log_ok "Система мониторинга установлена"
        return 0
    else
        log_err "Ошибка установки системы мониторинга"
        return 1
    fi
}

# ============================================================================
# УСТАНОВКА ШАБЛОНОВ
# ============================================================================

install_templates() {
    log_info "Установка шаблонов..."
    
    # Использование модульного установщика шаблонов
    source "$PROJECT_ROOT/modules/templates/install.sh"
    
    if install_templates; then
        log_ok "Шаблоны установлены"
        return 0
    else
        log_err "Ошибка установки шаблонов"
        return 1
    fi
}



# ============================================================================
# УСТАНОВКА УТИЛИТ
# ============================================================================

install_utils() {
    log_info "Установка дополнительных утилит..."
    
    # Установка дополнительных утилит с неинтерактивным режимом
    DEBIAN_FRONTEND=noninteractive apt install -y \
        htop \
        iotop \
        nethogs \
        iftop \
        vnstat \
        logwatch \
        fail2ban \
        ufw
    
    log_ok "Дополнительные утилиты установлены"
    return 0
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ УСТАНОВКИ
# ============================================================================

main() {
    log_info "Начало установки Traffic Connect Server..."
    
    # Настройка локали для избежания предупреждений
    log_info "Настройка локали..."
    export LC_ALL=C
    export LANG=C
    export LANGUAGE=C
    
    # Отображение текущих настроек
    log_info "Текущие настройки:"
    log_info "  Admin Hostname: hostname.domain.tld"
    log_info "  Admin Email: info@domain.tld"
    log_info "  Admin Username: Trafficadmin"
    log_info "  Admin Language: ru"
    log_info "  Apache: no"
    log_info "  BIND: no"
    log_info "  Exim: no"
    log_info "  Dovecot: no"
    log_info "  ClamAV: no"
    log_info "  SpamAssassin: no"
    
    # Выполнение проверок и инициализации
    check_and_init
    
    log_ok "Системные требования выполнены"
    
    # Генерация случайных паролей
    log_info "Генерация случайных паролей..."
    
    # Генерация пароля Grafana
    if [ -z "$GRAFANA_PASSWORD" ]; then
        GRAFANA_PASSWORD=$(generate_secure_password 24 "high")
        log_info "Пароль Grafana сгенерирован автоматически"
    fi
    
    # Генерация пароля административной панели
    ADMIN_PASSWORD=$(generate_secure_password 16 "high")
    log_info "Пароль административной панели сгенерирован автоматически (16 символов)"
    
    # Сохранение паролей
    save_credentials "$GRAFANA_PASSWORD" "Trafficadmin" "$ADMIN_PASSWORD"
    log_ok "Пароли сохранены"
    
    # ============================================================================
    # ЭТАП 1: БАЗОВАЯ СИСТЕМА
    # ============================================================================
    log_info "=== ЭТАП 1: Установка базовой системы ==="
    if install_base_packages; then
        log_ok "✅ Этап 1 завершен успешно"
    else
        log_err "❌ Ошибка на этапе 1"
        exit 1
    fi
    
    # ============================================================================
    # ЭТАП 2: БЕЗОПАСНОСТЬ
    # ============================================================================
    log_info "=== ЭТАП 2: Настройка безопасности ==="
    if setup_security; then
        log_ok "✅ Этап 2 завершен успешно"
    else
        log_err "❌ Ошибка на этапе 2"
        exit 1
    fi
    
    # ============================================================================
    # ЭТАП 3: АДМИНИСТРАТИВНАЯ ПАНЕЛЬ
    # ============================================================================
    log_info "=== ЭТАП 3: Установка административной панели ==="
    if install_admin_panel; then
        log_ok "✅ Этап 3 завершен успешно"
    else
        log_err "❌ Ошибка на этапе 3"
        exit 1
    fi
    
    # ============================================================================
    # ЭТАП 4: СИСТЕМА МОНИТОРИНГА
    # ============================================================================
    log_info "=== ЭТАП 4: Установка системы мониторинга ==="
    if install_monitoring; then
        log_ok "✅ Этап 4 завершен успешно"
    else
        log_warn "⚠️  Проблемы на этапе 4 (продолжаем)"
    fi
    
    # ============================================================================
    # ЭТАП 5: ШАБЛОНЫ
    # ============================================================================
    log_info "=== ЭТАП 5: Установка шаблонов ==="
    if install_templates; then
        log_ok "✅ Этап 5 завершен успешно"
    else
        log_warn "⚠️  Проблемы на этапе 5 (продолжаем)"
    fi
    
    # ============================================================================
    # ЭТАП 6: ДОПОЛНИТЕЛЬНЫЕ УТИЛИТЫ
    # ============================================================================
    log_info "=== ЭТАП 6: Установка дополнительных утилит ==="
    if install_utils; then
        log_ok "✅ Этап 6 завершен успешно"
    else
        log_warn "⚠️  Проблемы на этапе 6 (продолжаем)"
    fi
    
    # ============================================================================
    # ФИНАЛЬНАЯ ПРОВЕРКА И ОТЧЕТ
    # ============================================================================
    log_info "=== ФИНАЛЬНАЯ ПРОВЕРКА ==="
    
    # Проверка основных служб
    local critical_services=("nginx" "admin")
    local monitoring_services=("grafana-server" "prometheus" "loki" "node_exporter" "pushgateway" "promtail")
    local failed_critical=()
    local failed_monitoring=()
    
    # Проверка критических служб
    log_info "Проверка критических служб..."
    for service in "${critical_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            if systemctl is-active --quiet "$service"; then
                log_ok "✅ $service - активна"
            else
                log_warn "⚠️  $service - неактивна"
                failed_critical+=("$service")
            fi
        else
            log_warn "⚠️  $service - не найдена"
            failed_critical+=("$service")
        fi
    done
    
    # Проверка служб мониторинга
    log_info "Проверка служб мониторинга..."
    for service in "${monitoring_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            if systemctl is-active --quiet "$service"; then
                log_ok "✅ $service - активна"
            else
                log_warn "⚠️  $service - неактивна"
                failed_monitoring+=("$service")
            fi
        else
            log_warn "⚠️  $service - не найдена"
            failed_monitoring+=("$service")
        fi
    done
    

    
    # Проверка файлов административной панели
    log_info "Проверка файлов административной панели..."
    if [ -f "/usr/local/admin/bin/admin" ]; then
        log_ok "✅ Административная панель - установлена"
    else
        log_err "❌ Административная панель - не установлена"
        failed_critical+=("admin-files")
    fi
    
    # Проверка шаблонов
    log_info "Проверка шаблонов..."
    if [ -d "/usr/local/admin/data/templates/web/nginx" ]; then
        local template_count=$(find /usr/local/admin/data/templates/web/nginx -name "*.tpl" -o -name "*.stpl" | wc -l)
        if [ "$template_count" -gt 0 ]; then
            log_ok "✅ Шаблоны - установлены ($template_count файлов)"
        else
            log_warn "⚠️  Шаблоны - не найдены"
        fi
    else
        log_warn "⚠️  Директория шаблонов - не найдена"
    fi
    
    # Итоговая оценка
    if [ ${#failed_critical[@]} -eq 0 ]; then
        log_ok "✅ Все критические компоненты работают"
    else
        log_warn "⚠️  Проблемы с критическими компонентами: ${failed_critical[*]}"
    fi
    
    if [ ${#failed_monitoring[@]} -eq 0 ]; then
        log_ok "✅ Все службы мониторинга работают"
    else
        log_warn "⚠️  Проблемы со службами мониторинга: ${failed_monitoring[*]}"
    fi
    
    # Финальный отчет
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                УСТАНОВКА ЗАВЕРШЕНА! 🎉                   ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ ДОСТУПНЫЕ СЕРВИСЫ:"
    echo "║    • Админ панель: http://$(hostname -I | awk '{print $1}'):$ADMIN_PORT"
    echo "║    • Grafana: http://$(hostname -I | awk '{print $1}'):$GRAFANA_PORT"
    echo "║    • Prometheus: http://$(hostname -I | awk '{print $1}'):$PROMETHEUS_PORT"
    echo "║    • Loki: http://$(hostname -I | awk '{print $1}'):$LOKI_PORT"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "💡 Для настройки параметров создайте файл config.local.sh:"
    echo "   cp scripts/configuration.sh scripts/config.local.sh"
    echo "   nano scripts/config.local.sh"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                ДАННЫЕ ДЛЯ ВХОДА 🔑                      ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ Админ панель:"
    echo "║    Логин: Trafficadmin"
    echo "║    Пароль: $ADMIN_PASSWORD"
    echo "║"
    echo "║ Grafana:"
    echo "║    Логин: admin"
    echo "║    Пароль: $GRAFANA_PASSWORD"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "💾 Пароли сохранены в: $CREDENTIALS_FILE"
    echo "⚠️  ВАЖНО: Измените пароли после установки!"
    echo ""
    
    log_ok "Установка завершена успешно!"
}

# ============================================================================
# ЗАПУСК УСТАНОВКИ
# ============================================================================

# Проверка пользовательской конфигурации
if [ -f "$PROJECT_ROOT/scripts/config.local.sh" ]; then
    log_info "Загружена пользовательская конфигурация: scripts/config.local.sh"
    source "$PROJECT_ROOT/scripts/config.local.sh"
else
    log_info "Используются настройки по умолчанию"
    log_info "Для настройки создайте файл scripts/config.local.sh на основе scripts/configuration.sh"
fi

main 