#!/bin/bash
# ============================================================================
# Traffic Connect Server - Установка только системы мониторинга
# ============================================================================
# Этот скрипт устанавливает только систему мониторинга без HestiaCP
# Используется когда HestiaCP не может быть установлен из-за конфликтов

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

# ============================================================================
# ГЕНЕРАЦИЯ БЕЗОПАСНЫХ ПАРОЛЕЙ
# ============================================================================

generate_secure_passwords() {
    log_info "Генерация безопасных паролей..."
    
    # Политика безопасности уже загружена в security_install.sh
    # Проверяем, доступны ли функции генерации паролей
    if command -v generate_compliant_password >/dev/null 2>&1; then
        # Генерируем все необходимые пароли согласно политике безопасности
        ROOT_SSH_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        GRAFANA_ADMIN_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        PROMETHEUS_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        LOKI_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        NODE_EXPORTER_PASSWORD=$(generate_compliant_password $MIN_PASSWORD_LENGTH "medium")
        PUSHGATEWAY_PASSWORD=$(generate_compliant_password $MIN_PASSWORD_LENGTH "medium")
        FAIL2BAN_EXPORTER_PASSWORD=$(generate_compliant_password $MIN_PASSWORD_LENGTH "medium")
        
        log_info "Сгенерирован пароль для root SSH"
        log_info "Сгенерирован пароль для Grafana"
        log_info "Сгенерирован пароль для Prometheus"
        log_info "Сгенерирован пароль для Loki"
        log_info "Сгенерирован пароль для Node Exporter"
        log_info "Сгенерирован пароль для Pushgateway"
        log_info "Сгенерирован пароль для Fail2ban Exporter"
        
        log_ok "Все пароли сгенерированы успешно"
    else
        log_warn "Функции политики безопасности недоступны, используем базовые пароли"
        # Генерируем базовые пароли
        ROOT_SSH_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        PROMETHEUS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        LOKI_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        NODE_EXPORTER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
        PUSHGATEWAY_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
        FAIL2BAN_EXPORTER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
    fi
}

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
    
    # Загружаем security_install.sh для доступа к функциям политики безопасности
    source "$PROJECT_ROOT/system/security/security_install.sh"
    
    # Генерация безопасных паролей
    generate_secure_passwords
}

# ============================================================================
# УСТАНОВКА БАЗОВЫХ ПАКЕТОВ
# ============================================================================

install_base_packages() {
    log_info "Установка базовых пакетов..."
    
    # Использование модульного установщика базовой системы
    source "$PROJECT_ROOT/core/installers/main_install.sh"
    
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
    
    # security_install.sh уже загружен в check_and_init
    # Вызываем функцию из security_install.sh
    if setup_security_from_module; then
        log_ok "Безопасность настроена"
        return 0
    else
        log_err "Ошибка настройки безопасности"
        return 1
    fi
}

# ============================================================================
# УСТАНОВКА СИСТЕМЫ МОНИТОРИНГА
# ============================================================================

install_monitoring() {
    log_info "Установка системы мониторинга..."
    
    # Использование модульного установщика мониторинга
    source "$PROJECT_ROOT/system/monitoring/monitoring_install.sh"
    
    if install_monitoring; then
        log_ok "Система мониторинга установлена"
        return 0
    else
        log_err "Ошибка установки системы мониторинга"
        return 1
    fi
}

# ============================================================================
# НАСТРОЙКА ВЕБ-СЕРВЕРА
# ============================================================================

setup_web_server() {
    log_info "Настройка веб-сервера..."
    
    # Использование модульного установщика шаблонов
    source "$PROJECT_ROOT/web/templates/templates_install.sh"
    
    if install_templates; then
        log_ok "Веб-сервер настроен"
        return 0
    else
        log_err "Ошибка настройки веб-сервера"
        return 1
    fi
}

# ============================================================================
# АУДИТ БЕЗОПАСНОСТИ
# ============================================================================

perform_security_audit() {
    log_info "Выполнение аудита безопасности..."
    
    local security_score=0
    local issues=()
    
    # Проверка SSH конфигурации
    if [ -f /etc/ssh/sshd_config ]; then
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
            security_score=$((security_score + 20))
            log_ok "SSH root доступ отключен"
        else
            issues+=("SSH root доступ включен")
        fi
        
        if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
            security_score=$((security_score + 15))
            log_ok "SSH аутентификация по паролю отключена"
        else
            issues+=("SSH аутентификация по паролю включена")
        fi
    fi
    
    # Проверка файрвола
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        security_score=$((security_score + 20))
        log_ok "UFW активен"
    else
        issues+=("UFW не активен")
    fi
    
    # Проверка fail2ban
    if systemctl is-active --quiet fail2ban; then
        security_score=$((security_score + 15))
        log_ok "Fail2ban активен"
    else
        issues+=("Fail2ban не активен")
    fi
    
    # Проверка обновлений системы
    if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
        local last_update=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp)
        local current_time=$(date +%s)
        local days_since_update=$(((current_time - last_update) / 86400))
        
        if [ $days_since_update -le 7 ]; then
            security_score=$((security_score + 10))
            log_ok "Система обновлена"
        else
            issues+=("Система не обновлялась $days_since_update дней")
        fi
    fi
    
    # Вывод результатов
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                АУДИТ БЕЗОПАСНОСТИ 🔒                   ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ Общий балл: $security_score/100"
    
    if [ $security_score -ge 80 ]; then
        echo "║ Статус: ОТЛИЧНО ✅"
    elif [ $security_score -ge 60 ]; then
        echo "║ Статус: ХОРОШО ✅"
    elif [ $security_score -ge 40 ]; then
        echo "║ Статус: СРЕДНЕ ⚠️"
    else
        echo "║ Статус: ТРЕБУЕТ ВНИМАНИЯ ❌"
    fi
    
    if [ ${#issues[@]} -gt 0 ]; then
        echo "║"
        echo "║ Рекомендации по безопасности:"
        for issue in "${issues[@]}"; do
            echo "║   • $issue"
        done
    fi
    
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ $security_score -lt 60 ]; then
        log_warn "Рекомендуется улучшить безопасность системы"
    fi
}

# ============================================================================
# УСТАНОВКА ТОЛЬКО МОНИТОРИНГА
# ============================================================================

main_monitoring_installation() {
    echo "🚀 Запуск установки системы мониторинга Traffic Connect Server..."
    echo "================================================"
    
    # Проверка и инициализация
    check_and_init
    
    # Установка базовых пакетов
    if ! install_base_packages; then
        log_err "Критическая ошибка: не удалось установить базовые пакеты"
        exit 1
    fi
    
    # Настройка безопасности
    if ! setup_security; then
        log_err "Критическая ошибка: не удалось настроить безопасность"
        exit 1
    fi
    
    # Дополнительные проверки безопасности
    perform_security_audit
    
    # Установка системы мониторинга
    if ! install_monitoring; then
        log_err "Критическая ошибка: не удалось установить систему мониторинга"
        exit 1
    fi
    
    # Настройка веб-сервера
    if ! setup_web_server; then
        log_warn "Предупреждение: не удалось настроить веб-сервер"
    fi
    
    echo "================================================"
    log_ok "Установка системы мониторинга Traffic Connect Server завершена успешно!"
    
    # Отображение данных для входа
    show_access_credentials_monitoring_only
    
    # Отображение всех сгенерированных паролей
    show_all_passwords_monitoring_only
    
    echo "📚 Документация: $PROJECT_ROOT/docs/"
    echo "🔧 Конфигурация: $PROJECT_ROOT/web/configs/"
    echo "🛡️ Безопасность: $PROJECT_ROOT/system/security/"
    echo ""
    echo "⚠️ ВНИМАНИЕ: HestiaCP не установлен из-за конфликтов пакетов"
    echo "   Для установки HestiaCP используйте чистый сервер или"
    echo "   запустите: sudo bash install.sh"
}

# ============================================================================
# ОТОБРАЖЕНИЕ ДАННЫХ ДЛЯ ВХОДА (ТОЛЬКО МОНИТОРИНГ)
# ============================================================================

show_access_credentials_monitoring_only() {
    echo ""
    echo "🔐 ДАННЫЕ ДЛЯ ВХОДА В СИСТЕМУ МОНИТОРИНГА"
    echo "================================================"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Grafana
    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        echo "📊 GRAFANA (Мониторинг):"
        echo "  🌐 URL: http://$server_ip:$GRAFANA_PORT"
        echo "  👤 Логин: $GRAFANA_USERNAME"
        echo "  🔑 Пароль: $GRAFANA_ADMIN_PASSWORD"
        echo ""
    fi
    
    # Prometheus
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        echo "📈 PROMETHEUS (Метрики):"
        echo "  🌐 URL: http://$server_ip:$PROMETHEUS_PORT"
        echo "  👤 Логин: $PROMETHEUS_USERNAME"
        echo "  🔑 Пароль: $PROMETHEUS_PASSWORD"
        echo ""
    fi
    
    # Node Exporter
    if systemctl is-active --quiet node_exporter 2>/dev/null; then
        echo "🖥️ NODE EXPORTER (Системные метрики):"
        echo "  🌐 URL: http://$server_ip:$NODE_EXPORTER_PORT"
        echo "  👤 Логин: $NODE_EXPORTER_USERNAME"
        echo "  🔑 Пароль: $NODE_EXPORTER_PASSWORD"
        echo ""
    fi
    
    # Loki
    if systemctl is-active --quiet loki 2>/dev/null; then
        echo "📝 LOKI (Логи):"
        echo "  🌐 URL: http://$server_ip:$LOKI_PORT"
        echo "  👤 Логин: $LOKI_USERNAME"
        echo "  🔑 Пароль: $LOKI_PASSWORD"
        echo ""
    fi
    
    echo "🔧 ДОПОЛНИТЕЛЬНЫЕ СЕРВИСЫ:"
    echo "  📊 Pushgateway: http://$server_ip:$PUSHGATEWAY_PORT"
    echo "  🛡️ Fail2ban Exporter: http://$server_ip:$FAIL2BAN_EXPORTER_PORT"
    echo ""
    
    echo "📋 СТАТУС УСТАНОВКИ:"
    echo "  ⏰ Время установки: $(date)"
    echo "  🖥️ Сервер: $(hostname)"
    echo "  🌐 IP адрес: $server_ip"
    echo ""
    
    echo "⚠️ ВАЖНО:"
    echo "  • Измените пароли после первого входа"
    echo "  • Настройте файрвол для безопасности"
    echo "  • Регулярно обновляйте систему"
    echo "  • HestiaCP не установлен (используйте чистый сервер)"
    echo ""
    
    echo "📁 ФАЙЛЫ КОНФИГУРАЦИИ:"
    echo "  🔧 Основная конфигурация: $PROJECT_ROOT/core/configs/configuration.sh"
    echo "  🛡️ Политика безопасности: $PROJECT_ROOT/system/security/security_policy.sh"
    echo "  📚 Документация: $PROJECT_ROOT/docs/"
    echo ""
    
    echo "================================================"
    echo "🎉 Установка системы мониторинга завершена успешно!"
    echo "================================================"
}

# ============================================================================
# ОТОБРАЖЕНИЕ ВСЕХ ПАРОЛЕЙ (ТОЛЬКО МОНИТОРИНГ)
# ============================================================================

show_all_passwords_monitoring_only() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║        ВСЕ СГЕНЕРИРОВАННЫЕ ПАРОЛИ (МОНИТОРИНГ) 🔑       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo "🔐 SSH ДОСТУП:"
    echo "  👤 Логин: root"
    echo "  🔑 Пароль: $ROOT_SSH_PASSWORD"
    echo "  📝 Тип: Парольная аутентификация"
    echo "  📊 Сложность: $(assess_password_strength "$ROOT_SSH_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "📊 GRAFANA (Мониторинг):"
    echo "  🌐 URL: http://$server_ip:$GRAFANA_PORT"
    echo "  👤 Логин: $GRAFANA_USERNAME"
    echo "  🔑 Пароль: $GRAFANA_ADMIN_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$GRAFANA_ADMIN_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "📈 PROMETHEUS (Метрики):"
    echo "  🌐 URL: http://$server_ip:$PROMETHEUS_PORT"
    echo "  👤 Логин: $PROMETHEUS_USERNAME"
    echo "  🔑 Пароль: $PROMETHEUS_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$PROMETHEUS_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "📝 LOKI (Логи):"
    echo "  🌐 URL: http://$server_ip:$LOKI_PORT"
    echo "  👤 Логин: $LOKI_USERNAME"
    echo "  🔑 Пароль: $LOKI_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$LOKI_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "🖥️ NODE EXPORTER (Системные метрики):"
    echo "  🌐 URL: http://$server_ip:$NODE_EXPORTER_PORT"
    echo "  👤 Логин: $NODE_EXPORTER_USERNAME"
    echo "  🔑 Пароль: $NODE_EXPORTER_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$NODE_EXPORTER_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "📤 PUSHGATEWAY (Отправка метрик):"
    echo "  🌐 URL: http://$server_ip:$PUSHGATEWAY_PORT"
    echo "  👤 Логин: $PUSHGATEWAY_USERNAME"
    echo "  🔑 Пароль: $PUSHGATEWAY_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$PUSHGATEWAY_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "🛡️ FAIL2BAN EXPORTER (Мониторинг безопасности):"
    echo "  🌐 URL: http://$server_ip:$FAIL2BAN_EXPORTER_PORT"
    echo "  👤 Логин: $FAIL2BAN_EXPORTER_USERNAME"
    echo "  🔑 Пароль: $FAIL2BAN_EXPORTER_PASSWORD"
    echo "  📊 Сложность: $(assess_password_strength "$FAIL2BAN_EXPORTER_PASSWORD" | cut -d' ' -f1)"
    echo ""
    
    echo "⚠️ ВАЖНЫЕ НАПОМИНАНИЯ:"
    echo "  • Все пароли сгенерированы автоматически"
    echo "  • Сохраните эти данные в безопасном месте"
    echo "  • Рекомендуется изменить пароли после первого входа"
    echo "  • SSH ключи для пользователей нужно добавить вручную"
    echo "  • HestiaCP не установлен (используйте чистый сервер)"
    echo ""
    
    echo "📁 ФАЙЛЫ С ПАРОЛЯМИ:"
    echo "  🔒 Основной файл: /root/.traffic_connect/credentials.txt"
    echo "  🔒 SSH доступ: /root/.traffic_connect/ssh_access.txt"
    echo "  ⏰ Автоматическое удаление через 24 часа"
    echo ""
    
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              ПАРОЛИ СОХРАНЕНЫ ✅                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# ЗАПУСК
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_monitoring_installation
fi
