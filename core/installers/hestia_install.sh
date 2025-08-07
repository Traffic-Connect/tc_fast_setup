#!/bin/bash
# ============================================================================
# Traffic Connect Server - Установка HestiaCP
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

# ============================================================================
# КОНСТАНТЫ
# ============================================================================

HESTIA_INSTALLED_FLAG="/tmp/hestia_installed"
REBOOT_REQUIRED_FLAG="/tmp/reboot_required"

# ============================================================================
# ФУНКЦИИ УСТАНОВКИ HESTIACP
# ============================================================================

# Функция загрузки установщика HestiaCP
download_hestia_installer() {
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
            return 1
        fi
    fi
    
    chmod +x /tmp/hst-install.sh
}

install_hestia() {
    log_step "Установка HestiaCP"
    
    # Проверка, не установлен ли уже HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] && [ -d "/usr/local/admin" ] && is_service_active "admin"; then
        log_warn "HestiaCP уже установлен и работает, пропускаем установку"
        echo "hestia_installed" > "$HESTIA_INSTALLED_FLAG"
        return 0
    fi
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "hestia_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "HestiaCP уже установлен в предыдущем запуске, пропускаем"
        return 0
    fi
    
    # Используем уже сгенерированный пароль для HestiaCP
    if [ -z "$HESTIA_PASSWORD" ]; then
        log_info "Генерация пароля для HestiaCP..."
        HESTIA_PASSWORD=$(generate_service_password "hestia" $RECOMMENDED_PASSWORD_LENGTH "high")
        export HESTIA_PASSWORD
    fi
    log_info "Пароль для HestiaCP: [СКРЫТ]"
    
    # Проверка и удаление существующего пользователя если конфликт
    if id "$HESTIA_USERNAME" &>/dev/null; then
        log_warn "Пользователь $HESTIA_USERNAME уже существует, удаляем..."
        userdel -r "$HESTIA_USERNAME" 2>/dev/null || true
        groupdel "$HESTIA_USERNAME" 2>/dev/null || true
    fi
    
    # Полная очистка HestiaCP перед установкой
    log_info "Полная очистка HestiaCP перед установкой..."
    cleanup_hestia
    
    # Настройка SSL для решения проблем с таймаутом
    fix_ssl_timeouts
    
    # Загрузка скрипта установки HestiaCP
    download_hestia_installer
    
    # Выполнение установки HestiaCP
    log_info "Выполнение установки HestiaCP..."
    echo "y" | bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force
    
    # Проверка установки
    sleep 5
    if [ -f "/usr/local/admin/bin/admin" ] && [ -d "/usr/local/admin" ]; then
        log_ok "✅ HestiaCP установлен успешно"
        echo "hestia_installed" > "$HESTIA_INSTALLED_FLAG"
        
        # Запуск службы HestiaCP
        log_info "Запуск службы HestiaCP..."
        systemctl enable admin 2>/dev/null || true
        systemctl start admin 2>/dev/null || true
        
        # Проверка статуса
        if is_service_active "admin"; then
            log_ok "✅ Служба HestiaCP запущена"
        else
            log_warn "⚠️ Служба HestiaCP не запустилась, но установка завершена"
        fi
        
        # Проверка доступности веб-интерфейса
        log_info "Проверка веб-интерфейса HestiaCP..."
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8083 | grep -q "200\|302"; then
            log_ok "✅ Веб-интерфейс HestiaCP доступен"
        else
            log_warn "⚠️ Веб-интерфейс HestiaCP недоступен, но установка завершена"
        fi
        
        # Очистка проблемного домена если он существует
        log_info "Очистка проблемного домена..."
        if [ -d "/home/$HESTIA_USERNAME/web/$HESTIA_HOSTNAME" ]; then
            rm -rf "/home/$HESTIA_USERNAME/web/$HESTIA_HOSTNAME" 2>/dev/null || true
            rm -rf "/home/$HESTIA_USERNAME/conf/web/$HESTIA_HOSTNAME" 2>/dev/null || true
            log_info "Проблемный домен очищен"
        fi
        
        # Исправление прав доступа для cron
        log_info "Исправление прав доступа для cron..."
        chown hestiaweb:hestiaweb /var/spool/cron/crontabs/hestiaweb 2>/dev/null || true
        chmod 600 /var/spool/cron/crontabs/hestiaweb 2>/dev/null || true
        
        # Установка sendmail если отсутствует
        if ! command -v sendmail &> /dev/null; then
            log_info "Установка sendmail..."
            apt install -y postfix 2>/dev/null || true
        fi
    else
        log_err "❌ Ошибка установки HestiaCP"
        return 1
    fi
    
    # Очистка временных файлов
    log_info "Очистка временных файлов..."
    rm -f /tmp/hst-install.sh
    
    # Отметка завершения этапа
    echo "hestia_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "HestiaCP установлен"
    
    # Требуется перезагрузка после установки HestiaCP
    log_warn "⚠️ Требуется перезагрузка системы после установки HestiaCP"
    echo "reboot_required" > "$REBOOT_REQUIRED_FLAG"
    
    return 0
}

# ============================================================================
# ФУНКЦИИ ОЧИСТКИ
# ============================================================================

cleanup_hestia() {
    log_info "Полная очистка HestiaCP перед установкой..."
    
    # Остановка служб HestiaCP
    systemctl stop admin 2>/dev/null || true
    systemctl stop hestia 2>/dev/null || true
    systemctl disable admin 2>/dev/null || true
    systemctl disable hestia 2>/dev/null || true
    
    # Удаление директорий HestiaCP
    rm -rf /usr/local/hestia 2>/dev/null || true
    rm -rf /usr/local/admin 2>/dev/null || true
    rm -f /usr/local/bin/hestia 2>/dev/null || true
    rm -f /usr/local/bin/admin 2>/dev/null || true
    
    # Удаление логов установки
    rm -f /usr/local/hestia/install.log 2>/dev/null || true
    rm -f /tmp/hestia_installed 2>/dev/null || true
    
    # Удаление systemd служб HestiaCP
    rm -f /etc/systemd/system/admin.service 2>/dev/null || true
    rm -f /etc/systemd/system/hestia.service 2>/dev/null || true
    rm -f /lib/systemd/system/admin.service 2>/dev/null || true
    rm -f /lib/systemd/system/hestia.service 2>/dev/null || true
    
    # Удаление системных пользователей HestiaCP
    log_info "Удаление системных пользователей HestiaCP..."
    if id "hestiaweb" &>/dev/null; then
        userdel -r "hestiaweb" 2>/dev/null || true
        groupdel "hestiaweb" 2>/dev/null || true
    fi
    if id "hestiamail" &>/dev/null; then
        userdel -r "hestiamail" 2>/dev/null || true
        groupdel "hestiamail" 2>/dev/null || true
    fi
    if id "hestia-users" &>/dev/null; then
        groupdel "hestia-users" 2>/dev/null || true
    fi
    
    # Удаление пользователей HestiaCP
    if id "$HESTIA_USERNAME" &>/dev/null; then
        log_info "Удаление пользователя $HESTIA_USERNAME..."
        
        # Принудительная остановка всех процессов пользователя
        pkill -u "$HESTIA_USERNAME" 2>/dev/null || true
        sleep 2
        
        # Безопасное удаление пользователя с проверками
        if id "$HESTIA_USERNAME" &>/dev/null; then
            log_info "Удаление пользователя $HESTIA_USERNAME..."
            
            # Graceful завершение процессов пользователя
            if pkill -u "$HESTIA_USERNAME" 2>/dev/null; then
                log_info "Процессы пользователя $HESTIA_USERNAME завершены"
                sleep 2
            fi
            
            # Попытка обычного удаления
            if userdel -r "$HESTIA_USERNAME" 2>/dev/null; then
                log_ok "Пользователь $HESTIA_USERNAME удален"
            else
                log_warn "Не удалось удалить пользователя $HESTIA_USERNAME, пробуем принудительно"
                userdel -f -r "$HESTIA_USERNAME" 2>/dev/null || true
            fi
            
            # Удаление группы
            groupdel "$HESTIA_USERNAME" 2>/dev/null || true
        fi
        
        # Дополнительная очистка если пользователь все еще существует
        if id "$HESTIA_USERNAME" &>/dev/null; then
            log_warn "Пользователь $HESTIA_USERNAME все еще существует, принудительное удаление..."
            sed -i "/^$HESTIA_USERNAME:/d" /etc/passwd 2>/dev/null || true
            sed -i "/^$HESTIA_USERNAME:/d" /etc/shadow 2>/dev/null || true
            sed -i "/^$HESTIA_USERNAME:/d" /etc/group 2>/dev/null || true
            sed -i "/^$HESTIA_USERNAME:/d" /etc/gshadow 2>/dev/null || true
        fi
    fi
    
    # Полная очистка домашней директории пользователя
    log_info "Полная очистка домашней директории пользователя..."
    
    # Принудительная остановка всех процессов пользователя
    pkill -u "$HESTIA_USERNAME" 2>/dev/null || true
    sleep 2
    
    # Удаление всех файлов и директорий пользователя
    find "/home/$HESTIA_USERNAME" -type f -delete 2>/dev/null || true
    find "/home/$HESTIA_USERNAME" -type d -empty -delete 2>/dev/null || true
    
    # Принудительное удаление директорий
    rm -rf "/home/$HESTIA_USERNAME" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/conf" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/web" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/tmp" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.config" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.cache" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.local" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.composer" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.vscode-server" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.ssh" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.npm" 2>/dev/null || true
    rm -rf "/home/$HESTIA_USERNAME/.wp-cli" 2>/dev/null || true
    
    # Проверка и безопасное удаление если директория все еще существует
    if [ -d "/home/$HESTIA_USERNAME" ]; then
        log_warn "Директория /home/$HESTIA_USERNAME все еще существует, безопасное удаление..."
        
        # Создание бэкапа перед удалением
        local backup_dir="/tmp/hestia_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        log_info "Создание бэкапа домашней директории..."
        tar -czf "$backup_dir/home_backup.tar.gz" -C /home "$HESTIA_USERNAME" 2>/dev/null || true
        log_info "Бэкап сохранен в: $backup_dir/home_backup.tar.gz"
        
        # Безопасное удаление с правильными правами
        find "/home/$HESTIA_USERNAME" -type f -exec chmod 644 {} \; 2>/dev/null || true
        find "/home/$HESTIA_USERNAME" -type d -exec chmod 755 {} \; 2>/dev/null || true
        rm -rf "/home/$HESTIA_USERNAME" 2>/dev/null || true
    fi
    
    # Удаление доменных директорий с проверками
    log_info "Очистка доменных директорий..."
    
    # Безопасное удаление доменных директорий
    for dir in /home/*/web/* /home/*/conf/web/*; do
        if [ -d "$dir" ]; then
            log_info "Удаление директории: $dir"
            if rm -rf "$dir" 2>/dev/null; then
                log_ok "Директория удалена: $dir"
            else
                log_warn "Не удалось удалить директорию: $dir"
            fi
        fi
    done
    
    # Очистка логов и временных файлов
    if [ -d "/var/log/hestia" ]; then
        log_info "Удаление логов HestiaCP"
        if rm -rf /var/log/hestia 2>/dev/null; then
            log_ok "Логи HestiaCP удалены"
        else
            log_warn "Не удалось удалить логи HestiaCP"
        fi
    fi
    
    if [ -d "/usr/share/phpmyadmin/tmp" ]; then
        log_info "Удаление временных файлов phpMyAdmin"
        if rm -rf /usr/share/phpmyadmin/tmp 2>/dev/null; then
            log_ok "Временные файлы phpMyAdmin удалены"
        else
            log_warn "Не удалось удалить временные файлы phpMyAdmin"
        fi
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
    
    # Перезагрузка systemd после очистки
    systemctl daemon-reload 2>/dev/null || true
    log_info "Очистка HestiaCP завершена"
    
    # Предварительная настройка прав доступа для cron
    log_info "Предварительная настройка прав доступа для cron..."
    
    # Создание пользователей HestiaCP если они не существуют
    if ! id "hestiaweb" &>/dev/null; then
        useradd -r -s /bin/false -d /var/lib/hestia hestiaweb 2>/dev/null || true
    fi
    if ! id "hestiamail" &>/dev/null; then
        useradd -r -s /bin/false -d /var/lib/hestia hestiamail 2>/dev/null || true
    fi
    if ! getent group "hestia-users" &>/dev/null; then
        groupadd hestia-users 2>/dev/null || true
    fi
    
    # Настройка прав доступа для cron
    mkdir -p /var/spool/cron/crontabs 2>/dev/null || true
    touch /var/spool/cron/crontabs/hestiaweb 2>/dev/null || true
    chown hestiaweb:hestiaweb /var/spool/cron/crontabs/hestiaweb 2>/dev/null || true
    chmod 600 /var/spool/cron/crontabs/hestiaweb 2>/dev/null || true
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
    log_info "=== УСТАНОВКА HESTIACP ==="
    
    # Установка HestiaCP
    if ! install_hestia; then
        log_err "Ошибка установки HestiaCP"
        exit 1
    fi
    
    log_ok "=== УСТАНОВКА HESTIACP ЗАВЕРШЕНА ==="
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
