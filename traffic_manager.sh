#!/bin/bash
# ============================================================================
# Traffic Connect Server - УНИВЕРСАЛЬНЫЙ УСТАНОВЩИК ВСЕГО
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

# ============================================================================
# КОНСТАНТЫ И ПЕРЕМЕННЫЕ
# ============================================================================

INSTALL_STAGE_FILE="/tmp/traffic_connect_install_stage"
HESTIA_INSTALLED_FLAG="/tmp/hestia_installed"
REBOOT_REQUIRED_FLAG="/tmp/reboot_required"
INSTALL_LOG="/tmp/traffic_connect_install.log"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

log_info() {
    echo -e "${BLUE}[Инфо]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_warn() {
    echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_err() {
    echo -e "${RED}[ОШИБКА]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_step() {
    echo -e "${PURPLE}[ЭТАП]${NC} $1" | tee -a "$INSTALL_LOG"
}

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ И ИНИЦИАЛИЗАЦИИ
# ============================================================================

# Проверка root прав
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_err "Этот скрипт должен быть запущен от имени root"
        exit 1
    fi
}

# Проверка системных требований
check_system_requirements() {
    log_info "Проверка системных требований..."
    
    # Проверка операционной системы
    if ! grep -q "Ubuntu\|Debian" /etc/os-release; then
        log_err "Поддерживаются только Ubuntu и Debian"
        return 1
    fi
    
    # Проверка памяти
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$total_mem" -lt "$REQUIRED_MEMORY" ]; then
        log_err "Недостаточно памяти: требуется ${REQUIRED_MEMORY}MB, доступно ${total_mem}MB"
        return 1
    fi
    
    # Проверка места на диске
    local free_space=$(df -m / | awk 'NR==2{print $4}')
    if [ "$free_space" -lt "$REQUIRED_DISK_SPACE" ]; then
        log_err "Недостаточно места на диске: требуется ${REQUIRED_DISK_SPACE}MB, доступно ${free_space}MB"
        return 1
    fi
    
    log_ok "Системные требования выполнены"
    return 0
}

# Проверка интернета
check_internet() {
    log_info "Проверка интернет-соединения..."
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_ok "Интернет-соединение доступно"
        return 0
    else
        log_err "Нет интернет-соединения"
        return 1
    fi
}

# ============================================================================
# ФУНКЦИИ ИСПРАВЛЕНИЯ ПРОБЛЕМ
# ============================================================================

# Исправление блокировок dpkg
fix_dpkg_locks() {
    log_info "Исправление блокировок dpkg..."
    
    # Проверка активных процессов apt
    local apt_processes=$(ps aux | grep -E "(apt|dpkg)" | grep -v grep)
    if [ -n "$apt_processes" ]; then
        log_warn "Обнаружены активные процессы apt, останавливаем..."
        pkill -f "apt-get" 2>/dev/null || true
        pkill -f "apt" 2>/dev/null || true
        pkill -f "dpkg" 2>/dev/null || true
        sleep 3
    fi
    
    # Удаление файлов блокировок
    rm -f /var/lib/dpkg/lock* 2>/dev/null || true
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/dpkg/info/format-new 2>/dev/null || true
    
    # Исправление прерванной установки
    dpkg --configure -a 2>/dev/null || true
    apt-get install -f -y 2>/dev/null || true
    
    log_ok "Блокировки dpkg исправлены"
}

# Исправление SSL таймаутов
fix_ssl_timeouts() {
    log_info "Настройка SSL для стабильной работы..."
    
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
    
    log_ok "SSL настройки применены"
}

# ============================================================================
# ЭТАП 1: СИСТЕМНЫЕ КОМПОНЕНТЫ
# ============================================================================

install_system_components() {
    log_step "ЭТАП 1: Установка системных компонентов"
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "system_components_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "Системные компоненты уже установлены, пропускаем"
        return 0
    fi
    
    # 1.1 Обновление системы
    log_info "Обновление системы..."
    if ! apt update; then
        log_warn "Ошибка обновления списков пакетов, исправляем..."
        fix_dpkg_locks
        apt update
    fi
    
    if ! apt upgrade -y; then
        log_warn "Ошибка обновления системы, исправляем..."
        fix_dpkg_locks
        apt upgrade -y
    fi
    
    # 1.2 Установка базовых пакетов
    log_info "Установка базовых пакетов..."
    local base_packages="git curl wget unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release"
    
    if ! apt install -y $base_packages; then
        log_warn "Ошибка установки базовых пакетов, исправляем..."
        fix_dpkg_locks
        apt install -y $base_packages
    fi
    
    # 1.3 Настройка репозиториев
    log_info "Настройка репозиториев..."
    
    # Добавление репозитория Node.js
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    
    # Обновление списков пакетов
    apt update
    
    # 1.4 Установка дополнительных пакетов
    log_info "Установка дополнительных пакетов..."
    local additional_packages="nodejs htop iotop nethogs"
    
    if ! apt install -y $additional_packages; then
        log_warn "Ошибка установки дополнительных пакетов, исправляем..."
        fix_dpkg_locks
        apt install -y $additional_packages
    fi
    
    # 1.5 Создание системных пользователей
    log_info "Создание системных пользователей..."
    
    # Создание пользователей для мониторинга
    local monitoring_users=("prometheus" "grafana" "loki" "node_exporter")
    for user in "${monitoring_users[@]}"; do
        if ! id "$user" &>/dev/null; then
            useradd --no-create-home --shell /bin/false "$user"
            log_info "Создан пользователь: $user"
        fi
    done
    
    # Отметка завершения этапа
    echo "system_components_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "ЭТАП 1 ЗАВЕРШЕН"
}

# ============================================================================
# ЭТАП 2: УСТАНОВКА HESTIACP
# ============================================================================

install_hestia() {
    log_step "ЭТАП 2: Установка HestiaCP"
    
    # Проверка, не установлен ли уже HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] && [ -d "/usr/local/admin" ] && systemctl is-active --quiet admin 2>/dev/null; then
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
        if type generate_compliant_password >/dev/null 2>&1; then
            HESTIA_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        else
            HESTIA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        fi
        export HESTIA_PASSWORD
    fi
    log_info "Пароль для HestiaCP: $HESTIA_PASSWORD"
    
    # Проверка и удаление существующего пользователя если конфликт
    if id "$HESTIA_USERNAME" &>/dev/null; then
        log_warn "Пользователь $HESTIA_USERNAME уже существует, удаляем..."
        userdel -r "$HESTIA_USERNAME" 2>/dev/null || true
        groupdel "$HESTIA_USERNAME" 2>/dev/null || true
    fi
    
    # Полная очистка HestiaCP перед установкой
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
        
        # Принудительное удаление пользователя
        userdel -f -r "$HESTIA_USERNAME" 2>/dev/null || true
        groupdel "$HESTIA_USERNAME" 2>/dev/null || true
        
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
    
    # Проверка и принудительное удаление если директория все еще существует
    if [ -d "/home/$HESTIA_USERNAME" ]; then
        log_warn "Директория /home/$HESTIA_USERNAME все еще существует, принудительное удаление..."
        chmod -R 777 "/home/$HESTIA_USERNAME" 2>/dev/null || true
        rm -rf "/home/$HESTIA_USERNAME" 2>/dev/null || true
    fi
    
    # Удаление доменных директорий
    log_info "Очистка доменных директорий..."
    rm -rf /home/*/web/* 2>/dev/null || true
    rm -rf /home/*/conf/web/* 2>/dev/null || true
    rm -rf /var/log/hestia 2>/dev/null || true
    rm -rf /usr/share/phpmyadmin/tmp 2>/dev/null || true
    
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
    
    # Настройка SSL для решения проблем с таймаутом
    fix_ssl_timeouts
    
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
            return 1
        fi
    fi
    
    chmod +x /tmp/hst-install.sh
    
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
                        if systemctl is-active --quiet admin 2>/dev/null; then
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
    log_ok "ЭТАП 2 ЗАВЕРШЕН"
    
    # Требуется перезагрузка после установки HestiaCP
    log_warn "⚠️ Требуется перезагрузка системы после установки HestiaCP"
    echo "reboot_required" > "$REBOOT_REQUIRED_FLAG"
    
    return 0
}

# ============================================================================
# ЭТАП 3: НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================================

setup_security() {
    log_step "ЭТАП 3: Настройка безопасности"
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "security_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "Безопасность уже настроена, пропускаем"
        return 0
    fi
    
    # Загружаем политику безопасности
    source "$PROJECT_ROOT/system/security/security_install.sh"
    
    # Генерация безопасных паролей
    log_info "Генерация безопасных паролей..."
    generate_secure_passwords
    
    # Настройка безопасности
    log_info "Настройка безопасности..."
    if ! setup_security_from_module; then
        log_err "Критическая ошибка: не удалось настроить безопасность"
        return 1
    fi
    
    # Дополнительные проверки безопасности
    log_info "Дополнительные проверки безопасности..."
    perform_security_audit
    
    # Отметка завершения этапа
    echo "security_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "ЭТАП 3 ЗАВЕРШЕН"
}

# ============================================================================
# ЭТАП 4: УСТАНОВКА МОНИТОРИНГА
# ============================================================================

install_monitoring() {
    log_step "ЭТАП 4: Установка системы мониторинга"
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "monitoring_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "Мониторинг уже установлен, пропускаем"
        return 0
    fi
    
    log_info "Установка системы мониторинга..."
    source "$PROJECT_ROOT/system/monitoring/monitoring_install.sh"
    
    if ! install_monitoring; then
        log_warn "Предупреждение: не удалось установить систему мониторинга"
        return 1
    fi
    
    # Отметка завершения этапа
    echo "monitoring_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "ЭТАП 4 ЗАВЕРШЕН"
}

# ============================================================================
# ЭТАП 5: НАСТРОЙКА ВЕБ-СЕРВЕРА
# ============================================================================

setup_web_server() {
    log_step "ЭТАП 5: Настройка веб-сервера"
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "web_server_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "Веб-сервер уже настроен, пропускаем"
        return 0
    fi
    
    log_info "Настройка веб-сервера..."
    source "$PROJECT_ROOT/web/templates/templates_install.sh"
    
    if ! setup_web_server; then
        log_warn "Предупреждение: не удалось настроить веб-сервер"
        return 1
    fi
    
    # Отметка завершения этапа
    echo "web_server_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "ЭТАП 5 ЗАВЕРШЕН"
}

# ============================================================================
# ФУНКЦИИ ГЕНЕРАЦИИ ПАРОЛЕЙ
# ============================================================================

generate_secure_passwords() {
    log_info "Генерация безопасных паролей для всех сервисов..."
    
    # Загружаем политику безопасности если доступна
    if [ -f "$PROJECT_ROOT/system/security/security_policy.sh" ]; then
        source "$PROJECT_ROOT/system/security/security_policy.sh"
    fi
    
    # Генерация паролей для всех сервисов
    if type generate_compliant_password >/dev/null 2>&1; then
        HESTIA_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        GRAFANA_ADMIN_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        PROMETHEUS_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        LOKI_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        NODE_EXPORTER_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        PUSHGATEWAY_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        FAIL2BAN_EXPORTER_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
        ROOT_SSH_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
    else
        # Fallback генерация паролей
        HESTIA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        PROMETHEUS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        LOKI_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        NODE_EXPORTER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        PUSHGATEWAY_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        FAIL2BAN_EXPORTER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
        ROOT_SSH_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
    fi
    
    # Экспорт переменных
    export HESTIA_PASSWORD
    export GRAFANA_ADMIN_PASSWORD
    export PROMETHEUS_PASSWORD
    export LOKI_PASSWORD
    export NODE_EXPORTER_PASSWORD
    export PUSHGATEWAY_PASSWORD
    export FAIL2BAN_EXPORTER_PASSWORD
    export ROOT_SSH_PASSWORD
    
    log_ok "Пароли сгенерированы успешно"
}

# ============================================================================
# ФУНКЦИИ ОТОБРАЖЕНИЯ ИНФОРМАЦИИ
# ============================================================================

show_access_credentials() {
    echo ""
    echo "🌐 ДОСТУПЫ К СЕРВИСАМ:"
    echo "================================================"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || command -v hestia >/dev/null 2>&1 || systemctl is-active --quiet admin 2>/dev/null; then
        echo "✅ HestiaCP: https://$server_ip:8083"
        echo "   Пользователь: $HESTIA_USERNAME"
        echo "   Пароль: $HESTIA_PASSWORD"
    fi
    
    # Grafana
    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        echo "✅ Grafana: http://$server_ip:3000"
        echo "   Пользователь: admin"
        echo "   Пароль: $GRAFANA_ADMIN_PASSWORD"
    fi
    
    # Prometheus
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        echo "✅ Prometheus: http://$server_ip:9090"
    fi
    
    # Loki
    if systemctl is-active --quiet loki 2>/dev/null; then
        echo "✅ Loki: http://$server_ip:3100"
    fi
    
    # Node Exporter
    if systemctl is-active --quiet node_exporter 2>/dev/null; then
        echo "✅ Node Exporter: http://$server_ip:9100"
    fi
    
    # Pushgateway
    if systemctl is-active --quiet pushgateway 2>/dev/null; then
        echo "✅ Pushgateway: http://$server_ip:9091"
    fi
    
    # Fail2ban Exporter
    if systemctl is-active --quiet fail2ban_exporter 2>/dev/null; then
        echo "✅ Fail2ban Exporter: http://$server_ip:9191"
    fi
    
    echo ""
}

show_all_passwords() {
    echo ""
    echo "🔐 ВСЕ СГЕНЕРИРОВАННЫЕ ПАРОЛИ:"
    echo "================================================"
    
    if [ -n "$HESTIA_PASSWORD" ]; then
        echo "HestiaCP ($HESTIA_USERNAME): $HESTIA_PASSWORD"
    fi
    
    if [ -n "$GRAFANA_ADMIN_PASSWORD" ]; then
        echo "Grafana (admin): $GRAFANA_ADMIN_PASSWORD"
    fi
    
    if [ -n "$PROMETHEUS_PASSWORD" ]; then
        echo "Prometheus ($PROMETHEUS_USERNAME): $PROMETHEUS_PASSWORD"
    fi
    
    if [ -n "$LOKI_PASSWORD" ]; then
        echo "Loki ($LOKI_USERNAME): $LOKI_PASSWORD"
    fi
    
    if [ -n "$NODE_EXPORTER_PASSWORD" ]; then
        echo "Node Exporter ($NODE_EXPORTER_USERNAME): $NODE_EXPORTER_PASSWORD"
    fi
    
    if [ -n "$PUSHGATEWAY_PASSWORD" ]; then
        echo "Pushgateway ($PUSHGATEWAY_USERNAME): $PUSHGATEWAY_PASSWORD"
    fi
    
    if [ -n "$FAIL2BAN_EXPORTER_PASSWORD" ]; then
        echo "Fail2ban Exporter ($FAIL2BAN_EXPORTER_USERNAME): $FAIL2BAN_EXPORTER_PASSWORD"
    fi
    
    if [ -n "$ROOT_SSH_PASSWORD" ]; then
        echo "Root SSH (root): $ROOT_SSH_PASSWORD"
    else
        echo "Root SSH (root): не изменялся"
    fi
    echo ""
}

# ============================================================================
# ФУНКЦИЯ ПЕРЕЗАПУСКА СЛУЖБ
# ============================================================================

restart_all_services() {
    # Список служб для перезапуска
    local services=(
        "ssh"
        "sshd"
        "fail2ban"
        "ufw"
        "nginx"
        "apache2"
        "admin"
        "hestia"
        "grafana-server"
        "prometheus"
        "loki"
        "node_exporter"
        "pushgateway"
        "fail2ban_exporter"
        "promtail"
    )
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service.service"; then
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                systemctl restart "$service" 2>/dev/null || true
            elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
                systemctl start "$service" 2>/dev/null || true
            fi
        fi
    done
    
    # Специальная обработка для HestiaCP
    if command -v hestia >/dev/null 2>&1; then
        systemctl restart admin 2>/dev/null || systemctl restart hestia 2>/dev/null || true
    fi
}

# Функция для сохранения всех паролей в файл
save_all_credentials() {
    local credentials_file="/root/traffic_connect_credentials.txt"
    local server_ip=$(hostname -I | awk '{print $1}')
    
    log_info "Сохранение всех учетных данных в файл: $credentials_file"
    
    cat > "$credentials_file" << EOF
===============================================
TRAFFIC CONNECT SERVER - УЧЕТНЫЕ ДАННЫЕ
===============================================
Дата создания: $(date)
IP сервера: $server_ip
===============================================

🌐 ДОСТУПЫ К СЕРВИСАМ:
===============================================

EOF

    # HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || command -v hestia >/dev/null 2>&1 || systemctl is-active --quiet admin 2>/dev/null; then
        cat >> "$credentials_file" << EOF
✅ HestiaCP: https://$server_ip:8083
   Пользователь: $HESTIA_USERNAME
   Пароль: $HESTIA_PASSWORD

EOF
    fi

    # Grafana
    if systemctl is-active --quiet grafana-server 2>/dev/null; then
        cat >> "$credentials_file" << EOF
✅ Grafana: http://$server_ip:3000
   Пользователь: admin
   Пароль: $GRAFANA_ADMIN_PASSWORD

EOF
    fi

    # Prometheus
    if systemctl is-active --quiet prometheus 2>/dev/null; then
        cat >> "$credentials_file" << EOF
✅ Prometheus: http://$server_ip:9090
   Пользователь: $PROMETHEUS_USERNAME
   Пароль: $PROMETHEUS_PASSWORD

EOF
    fi

    # Loki
    if systemctl is-active --quiet loki 2>/dev/null; then
        cat >> "$credentials_file" << EOF
✅ Loki: http://$server_ip:3100
   Пользователь: $LOKI_USERNAME
   Пароль: $LOKI_PASSWORD

EOF
    fi

    # Node Exporter
    if systemctl is-active --quiet node_exporter 2>/dev/null; then
        cat >> "$credentials_file" << EOF
✅ Node Exporter: http://$server_ip:9100
   Пользователь: $NODE_EXPORTER_USERNAME
   Пароль: $NODE_EXPORTER_PASSWORD

EOF
    fi

    # Pushgateway
    if systemctl is-active --quiet pushgateway 2>/dev/null; then
        cat >> "$credentials_file" << EOF
✅ Pushgateway: http://$server_ip:9091
   Пользователь: $PUSHGATEWAY_USERNAME
   Пароль: $PUSHGATEWAY_PASSWORD

EOF
    fi

    # Fail2ban Exporter
    if systemctl is-active --quiet fail2ban_exporter 2>/dev/null; then
        cat >> "$credentials_file" << EOF
✅ Fail2ban Exporter: http://$server_ip:9191
   Пользователь: $FAIL2BAN_EXPORTER_USERNAME
   Пароль: $FAIL2BAN_EXPORTER_PASSWORD

EOF
    fi

    cat >> "$credentials_file" << EOF
🔧 SSH доступ:
   ssh root@$server_ip

🔐 ВСЕ СГЕНЕРИРОВАННЫЕ ПАРОЛИ:
===============================================
EOF

    if [ -n "$HESTIA_PASSWORD" ]; then
        echo "HestiaCP: $HESTIA_PASSWORD" >> "$credentials_file"
    fi
    
    if [ -n "$GRAFANA_ADMIN_PASSWORD" ]; then
        echo "Grafana Admin: $GRAFANA_ADMIN_PASSWORD" >> "$credentials_file"
    fi
    
    if [ -n "$PROMETHEUS_PASSWORD" ]; then
        echo "Prometheus: $PROMETHEUS_PASSWORD" >> "$credentials_file"
    fi
    
    if [ -n "$LOKI_PASSWORD" ]; then
        echo "Loki: $LOKI_PASSWORD" >> "$credentials_file"
    fi
    
    if [ -n "$NODE_EXPORTER_PASSWORD" ]; then
        echo "Node Exporter: $NODE_EXPORTER_PASSWORD" >> "$credentials_file"
    fi
    
    if [ -n "$PUSHGATEWAY_PASSWORD" ]; then
        echo "Pushgateway: $PUSHGATEWAY_PASSWORD" >> "$credentials_file"
    fi
    
    if [ -n "$FAIL2BAN_EXPORTER_PASSWORD" ]; then
        echo "Fail2ban Exporter: $FAIL2BAN_EXPORTER_PASSWORD" >> "$credentials_file"
    fi
    
    if [ -n "$ROOT_SSH_PASSWORD" ]; then
        echo "Root SSH: $ROOT_SSH_PASSWORD" >> "$credentials_file"
    else
        echo "Root SSH: не изменялся" >> "$credentials_file"
    fi

    cat >> "$credentials_file" << EOF

===============================================
EOF

    # Устанавливаем безопасные права доступа
    chmod 600 "$credentials_file"
    
    log_ok "Учетные данные сохранены в файл: $credentials_file"
    echo "📄 Все учетные данные сохранены в: $credentials_file"
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ УСТАНОВКИ
# ============================================================================

main_installation() {
    echo "🚀 ЗАПУСК УНИВЕРСАЛЬНОГО УСТАНОВЩИКА TRAFFIC CONNECT SERVER"
    echo "================================================"
    echo "Этот скрипт установит ВСЕ компоненты и продолжит после перезагрузки"
    echo "================================================"
    
    # Проверка root прав
    check_root
    
    # Проверка системных требований
    if ! check_system_requirements; then
        log_err "Системные требования не выполнены"
        exit 1
    fi
    
    # Проверка интернета
    if ! check_internet; then
        log_err "Нет интернет-соединения"
        exit 1
    fi
    
    # Проверка, требуется ли перезагрузка
    if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
        log_info "Обнаружен флаг перезагрузки, продолжаем установку..."
        rm -f "$REBOOT_REQUIRED_FLAG"
        
        # Продолжение установки после перезагрузки
        log_step "ПРОДОЛЖЕНИЕ УСТАНОВКИ ПОСЛЕ ПЕРЕЗАГРУЗКИ"
        
        # Проверка, установлен ли HestiaCP
        if [ ! -f "$HESTIA_INSTALLED_FLAG" ] && [ ! -f "/usr/local/admin/bin/admin" ]; then
            log_err "HestiaCP не установлен. Сначала выполните установку HestiaCP"
            exit 1
        fi
        
        # Продолжение с этапа безопасности
        setup_security
        install_monitoring
        setup_web_server
        
    else
        # Полная установка с нуля
        log_info "Начинаем полную установку с нуля..."
        
        # Генерация паролей для всех сервисов
        generate_secure_passwords
        
        # Этап 1: Системные компоненты
        install_system_components
        
        # Этап 2: Установка HestiaCP (В ПЕРВУЮ ОЧЕРЕДЬ)
        log_step "ПРИОРИТЕТНАЯ УСТАНОВКА HESTIACP"
        install_hestia
        
        # Проверка успешности установки HestiaCP
        if [ ! -f "$HESTIA_INSTALLED_FLAG" ] && [ ! -f "/usr/local/admin/bin/admin" ]; then
            log_err "❌ Критическая ошибка: HestiaCP не установлен"
            log_err "Установка прервана. HestiaCP должен быть установлен в первую очередь."
            exit 1
        fi
        
        # Проверка, требуется ли перезагрузка
        if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
            echo ""
            echo "🔄 ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА СИСТЕМЫ"
            echo "================================================"
            echo "HestiaCP установлен успешно. Требуется перезагрузка для завершения установки."
            echo ""
            echo "После перезагрузки скрипт автоматически продолжит установку!"
            echo ""
            
            read -p "Перезагрузить систему сейчас? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Перезагрузка системы..."
                reboot
            else
                log_info "Перезагрузите систему вручную и запустите скрипт снова"
                exit 0
            fi
        fi
    fi
    
    echo "================================================"
    log_ok "УСТАНОВКА TRAFFIC CONNECT SERVER ЗАВЕРШЕНА УСПЕШНО!"
    
    # Перезапуск всех служб
    log_info "Перезапуск всех установленных служб..."
    restart_all_services
    
    # Отображение данных для входа
    show_access_credentials
    
    # Отображение всех сгенерированных паролей
    show_all_passwords
    
    # Сохранение всех учетных данных в файл
    save_all_credentials
    
    # Очистка временных файлов
    rm -f "$INSTALL_STAGE_FILE" "$HESTIA_INSTALLED_FLAG" "$REBOOT_REQUIRED_FLAG"
    
    echo ""
    echo "🎉 ВСЕ ГОТОВО! Система полностью установлена и настроена."
    echo "================================================"
}

# ============================================================================
# ФУНКЦИИ МЕНЕДЖЕРА
# ============================================================================

# Функция для исправления блокировок dpkg
fix_dpkg_locks_manager() {
    echo "🔧 Исправление блокировок dpkg..."
    
    # Проверка активных процессов apt
    echo "📋 Проверка активных процессов apt..."
    local apt_processes=$(ps aux | grep -E "(apt|dpkg)" | grep -v grep)
    if [ -n "$apt_processes" ]; then
        echo "⚠️ Обнаружены активные процессы apt:"
        echo "$apt_processes"
        echo "🛑 Остановка зависших процессов..."
        pkill -f "apt-get" 2>/dev/null || true
        pkill -f "apt" 2>/dev/null || true
        pkill -f "dpkg" 2>/dev/null || true
        sleep 3
    else
        echo "✅ Активные процессы apt не обнаружены"
    fi
    
    # Удаление файлов блокировок
    echo "🗑️ Удаление файлов блокировок dpkg..."
    local locks_removed=false
    
    if [ -f "/var/lib/dpkg/lock" ]; then
        rm -f /var/lib/dpkg/lock
        echo "✅ Удален /var/lib/dpkg/lock"
        locks_removed=true
    fi
    
    if [ -f "/var/lib/dpkg/lock-frontend" ]; then
        rm -f /var/lib/dpkg/lock-frontend
        echo "✅ Удален /var/lib/dpkg/lock-frontend"
        locks_removed=true
    fi
    
    if [ -f "/var/lib/apt/lists/lock" ]; then
        rm -f /var/lib/apt/lists/lock
        echo "✅ Удален /var/lib/apt/lists/lock"
        locks_removed=true
    fi
    
    if [ -f "/var/cache/apt/archives/lock" ]; then
        rm -f /var/cache/apt/archives/lock
        echo "✅ Удален /var/cache/apt/archives/lock"
        locks_removed=true
    fi
    
    if [ -f "/var/lib/dpkg/info/format-new" ]; then
        rm -f /var/lib/dpkg/info/format-new
        echo "✅ Удален /var/lib/dpkg/info/format-new"
        locks_removed=true
    fi
    
    if [ "$locks_removed" = true ]; then
        echo "🛠️ Исправление прерванной установки dpkg..."
        dpkg --configure -a 2>/dev/null || true
        apt-get install -f -y 2>/dev/null || true
    fi
    
    echo "✅ Исправление блокировок dpkg завершено"
}



# Функция для исправления SSL таймаутов
fix_ssl_timeouts_manager() {
    echo "🔧 Исправление SSL таймаутов..."
    
    # Настройка переменных окружения
    export CURL_CONNECT_TIMEOUT=60
    export CURL_TIMEOUT=300
    export WGET_TIMEOUT=300
    
    # Настройка wget
    echo "⚙️ Настройка wget..."
    echo "check_certificate = off" >> ~/.wgetrc 2>/dev/null || true
    echo "timeout = 300" >> ~/.wgetrc 2>/dev/null || true
    
    # Настройка curl
    echo "⚙️ Настройка curl..."
    echo "connect-timeout = 60" >> ~/.curlrc 2>/dev/null || true
    echo "max-time = 300" >> ~/.curlrc 2>/dev/null || true
    
    echo "✅ SSL таймауты исправлены"
}

# Функция для проверки безопасности SSH
check_ssh_security() {
    echo "🔍 Проверка безопасности SSH..."
    
    local ssh_config="/etc/ssh/sshd_config"
    local issues=0
    
    echo "📋 Проверка конфигурации SSH..."
    
    # Проверка RootLogin
    if grep -q "^PermitRootLogin yes" "$ssh_config"; then
        echo "⚠️ Root login разрешен (небезопасно)"
        ((issues++))
    else
        echo "✅ Root login запрещен"
    fi
    
    # Проверка PasswordAuthentication
    if grep -q "^PasswordAuthentication yes" "$ssh_config"; then
        echo "⚠️ Парольная аутентификация разрешена"
        ((issues++))
    else
        echo "✅ Парольная аутентификация отключена"
    fi
    
    # Проверка порта
    if grep -q "^Port 22" "$ssh_config"; then
        echo "⚠️ SSH работает на стандартном порту 22"
        ((issues++))
    else
        echo "✅ SSH работает на нестандартном порту"
    fi
    
    # Проверка активных соединений
    echo "📊 Активные SSH соединения:"
    ss -tuln | grep :22 || echo "Нет активных соединений на порту 22"
    
    if [ $issues -eq 0 ]; then
        echo "✅ SSH безопасность в порядке"
    else
        echo "⚠️ Обнаружено $issues проблем с безопасностью SSH"
    fi
}

# Функция для проверки файрвола
check_firewall() {
    echo "🔍 Проверка файрвола..."
    
    # Проверка UFW
    if command -v ufw >/dev/null 2>&1; then
        echo "📋 Статус UFW:"
        ufw status verbose
    else
        echo "❌ UFW не установлен"
    fi
    
    # Проверка iptables
    echo "📋 Правила iptables:"
    iptables -L -n | head -20
}

# Функция для проверки Fail2ban
check_fail2ban() {
    echo "🔍 Проверка Fail2ban..."
    
    if command -v fail2ban-client >/dev/null 2>&1; then
        echo "📋 Статус Fail2ban:"
        fail2ban-client status
        
        echo "📊 Заблокированные IP:"
        fail2ban-client status sshd | grep "Banned IP list" || echo "Нет заблокированных IP"
    else
        echo "❌ Fail2ban не установлен"
    fi
}

# Функция для проверки обновлений системы
check_system_updates() {
    echo "🔍 Проверка обновлений системы..."
    
    echo "📋 Доступные обновления:"
    apt list --upgradable 2>/dev/null | head -10
    
    echo "📊 Последние обновления:"
    tail -5 /var/log/apt/history.log | grep "upgrade" || echo "Нет записей об обновлениях"
}

# Функция для проверки открытых портов
check_open_ports() {
    echo "🔍 Проверка открытых портов..."
    
    echo "📋 Открытые порты:"
    ss -tuln | grep LISTEN | head -10
    
    echo "📊 Сетевые соединения:"
    netstat -tuln | grep LISTEN | head -10
}

# Функция для проверки подозрительной активности
check_suspicious_activity() {
    echo "🔍 Проверка подозрительной активности..."
    
    echo "📋 Последние неудачные попытки входа:"
    tail -10 /var/log/auth.log | grep "Failed password" || echo "Нет неудачных попыток"
    
    echo "📊 Активные пользователи:"
    who
    
    echo "📋 Последние команды root:"
    tail -10 /root/.bash_history | grep -v "^#" || echo "Нет записей команд"
}

# Функция для проверки безопасности файлов
check_file_security() {
    echo "🔍 Проверка безопасности файлов..."
    
    echo "📋 Файлы с SUID:"
    find / -perm -4000 -type f 2>/dev/null | head -10
    
    echo "📋 Файлы с SGID:"
    find / -perm -2000 -type f 2>/dev/null | head -10
    
    echo "📋 Мировые записи:"
    find / -perm -o+w -type f 2>/dev/null | head -10
}

# Функция для проверки политики пользователей
check_users_policy() {
    echo "🔍 Проверка политики пользователей..."
    
    echo "📋 Пользователи системы:"
    cat /etc/passwd | grep -E ":[0-9]{4}:" | head -10
    
    echo "📋 Группы:"
    cat /etc/group | grep -E ":[0-9]+:" | head -10
    
    echo "📋 Пользователи с shell:"
    cat /etc/passwd | grep -E ":/bin/(bash|sh)" | head -10
}

# Главная функция проверки безопасности
main_security_check() {
    echo "🛡️ ПОЛНАЯ ПРОВЕРКА БЕЗОПАСНОСТИ"
    echo "================================================"
    
    check_ssh_security
    echo ""
    check_firewall
    echo ""
    check_fail2ban
    echo ""
    check_system_updates
    echo ""
    check_open_ports
    echo ""
    check_suspicious_activity
    echo ""
    check_file_security
    echo ""
    check_users_policy
    
    echo "================================================"
    echo "✅ Проверка безопасности завершена"
}

# Функция для проверки версий
check_version() {
    echo "📋 ПРОВЕРКА ВЕРСИЙ КОМПОНЕНТОВ"
    echo "================================================"
    
    echo "🐧 Операционная система:"
    cat /etc/os-release | grep PRETTY_NAME
    
    echo "📦 Версии пакетов:"
    echo "  • HestiaCP: $(hestia --version 2>/dev/null || echo 'Не установлен')"
    echo "  • Nginx: $(nginx -v 2>&1 || echo 'Не установлен')"
    echo "  • PHP: $(php -v 2>/dev/null | head -1 || echo 'Не установлен')"
    echo "  • MySQL: $(mysql --version 2>/dev/null || echo 'Не установлен')"
    echo "  • Node.js: $(node --version 2>/dev/null || echo 'Не установлен')"
    
    echo "📊 Системные версии:"
    echo "  • Kernel: $(uname -r)"
    echo "  • Bash: $(bash --version | head -1)"
    echo "  • Git: $(git --version 2>/dev/null || echo 'Не установлен')"
    
    echo "================================================"
}

# Функция для принудительного обновления
force_update() {
    echo "🔄 ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ СИСТЕМЫ"
    echo "================================================"
    
    echo "📦 Обновление списков пакетов..."
    apt update
    
    echo "🔄 Обновление системы..."
    apt upgrade -y
    
    echo "🧹 Очистка кэша..."
    apt autoremove -y
    apt autoclean
    
    echo "✅ Принудительное обновление завершено"
}

# Функция для показа учетных данных
show_credentials() {
    echo "🔐 УЧЕТНЫЕ ДАННЫЕ СИСТЕМЫ"
    echo "================================================"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo "🌐 Доступы к сервисам:"
    
    if [ -f "/usr/local/admin/bin/admin" ]; then
        echo "✅ HestiaCP: https://$server_ip:8083"
        echo "   Пользователь: admin"
        echo "   Пароль: (смотрите ниже)"
    fi
    
    if systemctl is-active --quiet grafana-server; then
        echo "✅ Grafana: http://$server_ip:3000"
        echo "   Пользователь: admin"
        echo "   Пароль: (смотрите ниже)"
    fi
    
    if systemctl is-active --quiet prometheus; then
        echo "✅ Prometheus: http://$server_ip:9090"
    fi
    
    if systemctl is-active --quiet loki; then
        echo "✅ Loki: http://$server_ip:3100"
    fi
    
    echo ""
    echo "🔧 SSH доступ:"
    echo "   ssh root@$server_ip"
    
    echo ""
    echo "📋 Сгенерированные пароли:"
    if [ -n "$HESTIA_PASSWORD" ]; then
        echo "HestiaCP: $HESTIA_PASSWORD"
    fi
    
    if [ -n "$GRAFANA_ADMIN_PASSWORD" ]; then
        echo "Grafana: $GRAFANA_ADMIN_PASSWORD"
    fi
    
    echo "================================================"
}

# Функция для установки только мониторинга
install_monitoring_only() {
    echo "🚀 Установка только системы мониторинга"
    echo "================================================"
    
    # Проверка root прав
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Проверка и инициализация
    echo "🔧 Проверка и инициализация..."
    
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
    echo "🔐 Генерация безопасных паролей..."
    generate_secure_passwords
    
    # Установка базовых пакетов
    echo "📦 Установка базовых пакетов..."
    source "$PROJECT_ROOT/core/installers/main_install.sh"
    
    if install_base_system; then
        log_ok "Базовые пакеты установлены"
    else
        log_err "Критическая ошибка: не удалось установить базовые пакеты"
        exit 1
    fi
    
    # Настройка безопасности
    echo "🛡️ Настройка безопасности..."
    if setup_security_from_module; then
        log_ok "Безопасность настроена"
    else
        log_err "Критическая ошибка: не удалось настроить безопасность"
        exit 1
    fi
    
    # Дополнительные проверки безопасности
    echo "🔍 Дополнительные проверки безопасности..."
    perform_security_audit
    
    # Установка системы мониторинга
    echo "📊 Установка системы мониторинга..."
    source "$PROJECT_ROOT/system/monitoring/monitoring_install.sh"
    
    if install_monitoring; then
        log_ok "Система мониторинга установлена"
    else
        log_err "Критическая ошибка: не удалось установить систему мониторинга"
        exit 1
    fi
    
    # Настройка веб-сервера
    echo "🌐 Настройка веб-сервера..."
    source "$PROJECT_ROOT/web/templates/templates_install.sh"
    
    if setup_web_server; then
        log_ok "Веб-сервер настроен"
    else
        log_warn "Предупреждение: не удалось настроить веб-сервер"
    fi
    
    echo "================================================"
    log_ok "Установка системы мониторинга завершена успешно!"
    
    # Отображение данных для входа
    show_access_credentials
    
    # Отображение всех сгенерированных паролей
    show_all_passwords
    
    echo ""
    echo "⚠️ ВНИМАНИЕ: HestiaCP не установлен из-за конфликтов пакетов"
    echo "   Для установки HestiaCP используйте чистый сервер или"
    echo "   запустите: ./traffic_manager.sh --install"
}

# Функция для установки только HestiaCP
install_hestia_only() {
    echo "🚀 Установка только HestiaCP"
    echo "================================================"
    
    # Проверка root прав
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Проверка, не установлен ли уже HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] && [ -d "/usr/local/admin" ] && systemctl is-active --quiet admin 2>/dev/null; then
        echo "⚠️ HestiaCP уже установлен и работает"
        exit 0
    fi
    
    # Генерация пароля для HestiaCP
    echo "🔐 Генерация пароля для HestiaCP..."
    if type generate_compliant_password >/dev/null 2>&1; then
        HESTIA_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
    else
        HESTIA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
    fi
    
    export HESTIA_PASSWORD
    echo "Пароль для HestiaCP: $HESTIA_PASSWORD"
    
    # Проверка и удаление существующего пользователя если конфликт
    if id "$HESTIA_USERNAME" &>/dev/null; then
        echo "⚠️ Пользователь $HESTIA_USERNAME уже существует, удаляем..."
        userdel -r "$HESTIA_USERNAME" 2>/dev/null || true
        groupdel "$HESTIA_USERNAME" 2>/dev/null || true
    fi
    
    # Проверка конфликтующих пакетов
    echo "🔍 Проверка конфликтующих пакетов..."
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
        echo "⚠️ Обнаружены конфликтующие пакеты: ${conflicting_packages[*]}"
        echo "🗑️ Удаляем конфликтующие пакеты..."
        
        for package in "${conflicting_packages[@]}"; do
            echo "Удаление пакета: $package"
            systemctl stop "$package" 2>/dev/null || true
            apt remove --purge -y "$package" 2>/dev/null || true
        done
        
        apt autoremove -y
    fi
    
    # Настройка SSL для стабильной установки
    fix_ssl_timeouts_manager
    
    # Загрузка установщика HestiaCP
    echo "📥 Загрузка установщика HestiaCP..."
    local download_success=false
    
    for attempt in 1 2 3; do
        echo "Попытка загрузки $attempt/3..."
        
        if wget --timeout=300 --tries=3 --no-check-certificate -O /tmp/hst-install.sh https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh; then
            download_success=true
            break
        else
            echo "Попытка $attempt не удалась, повторяем..."
            sleep 5
        fi
    done
    
    if [ ! -f "/tmp/hst-install.sh" ] || [ "$download_success" = false ]; then
        echo "❌ Не удалось загрузить установщик HestiaCP"
        exit 1
    fi
    
    chmod +x /tmp/hst-install.sh
    
    # Выполнение установки HestiaCP
    echo "🚀 Выполнение установки HestiaCP..."
    echo "y" | bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force
    
    if [ $? -eq 0 ]; then
        echo "✅ HestiaCP установлен успешно"
    else
        echo "❌ Ошибка установки HestiaCP"
        exit 1
    fi
    
    # Очистка временных файлов
    rm -f /tmp/hst-install.sh
    
    echo "================================================"
    echo "✅ Установка HestiaCP завершена успешно!"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    echo "🌐 Доступ к HestiaCP: https://$server_ip:8083"
    echo "👤 Пользователь: $HESTIA_USERNAME"
    echo "🔐 Пароль: $HESTIA_PASSWORD"
}

# Функция для установки с нуля
install_from_scratch() {
    echo "🚀 Установка Traffic Connect Server с нуля"
    echo "================================================"
    
    # Проверка root прав
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Функция проверки и исправления dpkg
    check_and_fix_dpkg() {
        echo "🔧 Проверка состояния dpkg..."
        
        if ! dpkg -l >/dev/null 2>&1; then
            echo "❌ Проблемы с dpkg, исправляем..."
            fix_dpkg_locks_manager
            
            if ! dpkg -l >/dev/null 2>&1; then
                echo "❌ Критические проблемы с dpkg"
                echo "🔄 Перезагрузка системы..."
                reboot
                exit 1
            fi
        fi
        
        echo "✅ dpkg работает корректно"
    }
    
    # 1. Проверка и исправление dpkg
    echo "🔧 Шаг 1: Проверка и исправление dpkg..."
    check_and_fix_dpkg
    
    # 2. Обновление системы
    echo "🔄 Шаг 2: Обновление системы..."
    if ! apt update; then
        echo "❌ Ошибка обновления списков пакетов, исправляем..."
        fix_dpkg_locks_manager
        apt update
    fi
    
    if ! apt upgrade -y; then
        echo "❌ Ошибка обновления системы, исправляем..."
        fix_dpkg_locks_manager
        apt upgrade -y
    fi
    
    # 3. Установка базовых пакетов
    echo "📦 Шаг 3: Установка базовых пакетов..."
    if ! apt install -y git curl wget; then
        echo "❌ Ошибка установки базовых пакетов, исправляем..."
        fix_dpkg_locks_manager
        apt install -y git curl wget
    fi
    
    # 4. Клонирование проекта
    echo "📥 Шаг 4: Клонирование проекта..."
    cd ~
    
    # Удаление старой директории если существует
    if [ -d "tc_fast_setup" ]; then
        echo "🗑️ Удаление старой директории проекта..."
        rm -rf tc_fast_setup
    fi
    
    # Клонирование проекта
    if ! git clone https://github.com/Traffic-Connect/tc_fast_setup.git; then
        echo "❌ Ошибка клонирования проекта"
        exit 1
    fi
    
    cd tc_fast_setup
    
    # 5. Проверка проекта
    echo "🔍 Шаг 5: Проверка проекта..."
    echo "Последние коммиты:"
    git log --oneline -3
    
    if [ ! -f "traffic_manager.sh" ]; then
        echo "❌ Файл traffic_manager.sh не найден"
        exit 1
    fi
    
    echo "✅ Проект успешно клонирован"
    
    # 6. Настройка прав
    echo "🔐 Шаг 6: Настройка прав доступа..."
    chmod +x traffic_manager.sh
    
    # 7. Проверка готовности к установке
    echo "✅ Шаг 7: Проверка готовности к установке..."
    echo "📋 Статус системы:"
    echo "  • dpkg: $(dpkg -l >/dev/null 2>&1 && echo '✅ Работает' || echo '❌ Проблемы')"
    echo "  • apt: $(apt-get update >/dev/null 2>&1 && echo '✅ Работает' || echo '❌ Проблемы')"
    echo "  • git: $(git --version >/dev/null 2>&1 && echo '✅ Установлен' || echo '❌ Не установлен')"
    echo "  • curl: $(curl --version >/dev/null 2>&1 && echo '✅ Установлен' || echo '❌ Не установлен')"
    echo "  • wget: $(wget --version >/dev/null 2>&1 && echo '✅ Установлен' || echo '❌ Не установлен')"
    
    # 8. Запуск установки
    echo "🚀 Шаг 8: Запуск установки Traffic Connect Server..."
    echo "================================================"
    
    # Запуск универсального скрипта установки
    if ./traffic_manager.sh --install; then
        echo ""
        echo "🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!"
        echo "================================================"
        echo ""
        echo "📋 Что было установлено:"
        echo "  ✅ HestiaCP (административная панель)"
        echo "  ✅ Grafana (мониторинг)"
        echo "  ✅ Prometheus (метрики)"
        echo "  ✅ Loki (логи)"
        echo "  ✅ Система безопасности"
        echo ""
        echo "🌐 Доступы к сервисам:"
        echo "  • HestiaCP: https://$(hostname -I | awk '{print $1}'):8083"
        echo "  • Grafana: http://$(hostname -I | awk '{print $1}'):3000"
        echo "  • Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
        echo "  • Loki: http://$(hostname -I | awk '{print $1}'):3100"
        echo ""
        echo "🔧 Для управления используйте:"
        echo "  ./traffic_manager.sh"
    else
        echo "❌ Ошибка установки"
        exit 1
    fi
}

# Функция для полного удаления всего установленного
complete_removal() {
    echo "🗑️ ПОЛНОЕ УДАЛЕНИЕ TRAFFIC CONNECT SERVER"
    echo "================================================"
    echo "⚠️ ВНИМАНИЕ: Это действие удалит ВСЕ установленные компоненты!"
    echo "Система будет возвращена к исходному состоянию."
    echo ""
    echo "Будет удалено:"
    echo "  • HestiaCP (административная панель)"
    echo "  • Grafana (мониторинг)"
    echo "  • Prometheus (метрики)"
    echo "  • Loki (логи)"
    echo "  • Node Exporter"
    echo "  • Pushgateway"
    echo "  • Fail2ban Exporter"
    echo "  • Все пользователи мониторинга"
    echo "  • Все конфигурации"
    echo "  • Все данные"
    echo ""
    
    read -p "Вы уверены, что хотите продолжить? (yes/NO): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "❌ Удаление отменено"
        return 0
    fi
    
    echo ""
    echo "🔄 Начинаем полное удаление..."
    
    # 1. Остановка всех служб
    echo "🛑 Остановка всех служб..."
    local services=(
        "grafana-server"
        "prometheus"
        "loki"
        "node_exporter"
        "pushgateway"
        "fail2ban_exporter"
        "promtail"
        "admin"
        "hestia"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "  Остановка $service..."
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
        fi
    done
    
    # 2. Удаление HestiaCP
    echo "🗑️ Удаление HestiaCP..."
    if [ -f "/usr/local/admin/bin/admin" ] || command -v hestia >/dev/null 2>&1; then
        echo "  Удаление административной панели..."
        /usr/local/admin/bin/admin delete admin 2>/dev/null || true
        rm -rf /usr/local/admin 2>/dev/null || true
        rm -rf /usr/local/hestia 2>/dev/null || true
        rm -f /usr/local/bin/hestia 2>/dev/null || true
        rm -f /usr/local/bin/admin 2>/dev/null || true
    fi
    
    # 3. Удаление Grafana
    echo "🗑️ Удаление Grafana..."
    if dpkg -l | grep -q "^ii.*grafana"; then
        apt remove --purge -y grafana 2>/dev/null || true
        apt autoremove --purge -y 2>/dev/null || true
        rm -rf /etc/grafana 2>/dev/null || true
        rm -rf /var/lib/grafana 2>/dev/null || true
        rm -rf /var/log/grafana 2>/dev/null || true
        rm -rf /var/cache/grafana 2>/dev/null || true
    fi
    
    # 4. Удаление Prometheus
    echo "🗑️ Удаление Prometheus..."
    if [ -f "/usr/local/bin/prometheus" ]; then
        rm -f /usr/local/bin/prometheus 2>/dev/null || true
        rm -rf /etc/prometheus 2>/dev/null || true
        rm -rf /var/lib/prometheus 2>/dev/null || true
    fi
    
    # 5. Удаление Loki
    echo "🗑️ Удаление Loki..."
    if [ -f "/usr/local/bin/loki" ]; then
        rm -f /usr/local/bin/loki 2>/dev/null || true
        rm -rf /etc/loki 2>/dev/null || true
        rm -rf /var/lib/loki 2>/dev/null || true
    fi
    
    # 6. Удаление Node Exporter
    echo "🗑️ Удаление Node Exporter..."
    if [ -f "/usr/local/bin/node_exporter" ]; then
        rm -f /usr/local/bin/node_exporter 2>/dev/null || true
    fi
    
    # 7. Удаление Pushgateway
    echo "🗑️ Удаление Pushgateway..."
    if [ -f "/usr/local/bin/pushgateway" ]; then
        rm -f /usr/local/bin/pushgateway 2>/dev/null || true
    fi
    
    # 8. Удаление Fail2ban Exporter
    echo "🗑️ Удаление Fail2ban Exporter..."
    if [ -f "/usr/local/bin/fail2ban_exporter" ]; then
        rm -f /usr/local/bin/fail2ban_exporter 2>/dev/null || true
    fi
    
    # 8.1 Удаление связанных пакетов
    echo "🗑️ Удаление связанных пакетов..."
    local related_packages=(
        "musl"
        "nodejs"
        "npm"
        "curl"
        "wget"
        "unzip"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "htop"
        "iotop"
        "nethogs"
    )
    
    for package in "${related_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package"; then
            echo "  Удаление пакета $package..."
            apt remove --purge -y "$package" 2>/dev/null || true
        fi
    done
    
    # 9. Удаление пользователей мониторинга
    echo "🗑️ Удаление пользователей мониторинга..."
    local monitoring_users=(
        "prometheus"
        "grafana"
        "loki"
        "node_exporter"
        "pushgateway"
        "fail2ban_exporter"
        "TrafficMetrics"
        "TrafficMonitor"
        "TrafficLogger"
        "TrafficNode"
        "TrafficPush"
        "TrafficFail2Ban"
        "TrafficAdmin"
    )
    
    for user in "${monitoring_users[@]}"; do
        if id "$user" &>/dev/null; then
            echo "  Удаление пользователя $user..."
            userdel -r "$user" 2>/dev/null || true
            groupdel "$user" 2>/dev/null || true
        fi
    done
    
    # 10. Удаление конфигураций и данных
    echo "🗑️ Удаление конфигураций и данных..."
    rm -rf /var/log/install 2>/dev/null || true
    rm -rf /var/cache/install 2>/dev/null || true
    rm -rf /var/backup/install 2>/dev/null || true
    rm -f /root/traffic_connect_credentials.txt 2>/dev/null || true
    rm -f /root/.traffic_connect 2>/dev/null || true
    rm -f /tmp/traffic_connect_install_stage 2>/dev/null || true
    rm -f /tmp/hestia_installed 2>/dev/null || true
    rm -f /tmp/reboot_required 2>/dev/null || true
    
    # 11. Удаление systemd служб
    echo "🗑️ Удаление systemd служб..."
    local service_files=(
        "/etc/systemd/system/prometheus.service"
        "/etc/systemd/system/loki.service"
        "/etc/systemd/system/node_exporter.service"
        "/etc/systemd/system/pushgateway.service"
        "/etc/systemd/system/fail2ban_exporter.service"
        "/etc/systemd/system/promtail.service"
    )
    
    for service_file in "${service_files[@]}"; do
        if [ -f "$service_file" ]; then
            echo "  Удаление $service_file..."
            rm -f "$service_file" 2>/dev/null || true
        fi
    done
    
    # 12. Полная очистка пакетов
    echo "🧹 Полная очистка пакетов..."
    apt autoremove --purge -y 2>/dev/null || true
    apt autoclean 2>/dev/null || true
    apt clean 2>/dev/null || true
    
    # Очистка кэша apt
    echo "🧹 Очистка кэша apt..."
    rm -rf /var/cache/apt/archives/* 2>/dev/null || true
    rm -rf /var/lib/apt/lists/* 2>/dev/null || true
    apt update 2>/dev/null || true
    
    # 13. Перезагрузка systemd
    echo "🔄 Перезагрузка systemd..."
    systemctl daemon-reload 2>/dev/null || true
    
    # 14. Удаление репозиториев и ключей
    echo "🗑️ Удаление репозиториев и ключей..."
    rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
    rm -f /usr/share/keyrings/nodesource.gpg 2>/dev/null || true
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || true
    
    # 15. Очистка временных файлов
    echo "🧹 Очистка временных файлов..."
    rm -rf /tmp/hst-install.sh 2>/dev/null || true
    rm -rf /tmp/grafana.deb 2>/dev/null || true
    rm -rf /tmp/prometheus.tar.gz 2>/dev/null || true
    rm -rf /tmp/loki.tar.gz 2>/dev/null || true
    rm -rf /tmp/node_exporter.tar.gz 2>/dev/null || true
    rm -rf /tmp/pushgateway.tar.gz 2>/dev/null || true
    rm -rf /tmp/fail2ban_exporter.tar.gz 2>/dev/null || true
    
    echo ""
    echo "✅ ПОЛНОЕ УДАЛЕНИЕ ЗАВЕРШЕНО!"
    echo "================================================"
    echo "Система возвращена к исходному состоянию."
    echo ""
    echo "Что было удалено:"
    echo "  ✅ HestiaCP"
    echo "  ✅ Grafana"
    echo "  ✅ Prometheus"
    echo "  ✅ Loki"
    echo "  ✅ Node Exporter"
    echo "  ✅ Pushgateway"
    echo "  ✅ Fail2ban Exporter"
    echo "  ✅ Все пользователи мониторинга"
    echo "  ✅ Все конфигурации"
    echo "  ✅ Все данные"
    echo ""
    echo "🎯 Система готова для чистой установки!"
}

# Функция для показа меню
show_menu() {
    clear
    echo "🚀 Traffic Connect Server - УНИВЕРСАЛЬНЫЙ МЕНЕДЖЕР"
    echo "================================================"
    echo ""
    echo "🔧 ИСПРАВЛЕНИЯ:"
    echo "  1) Исправить блокировки dpkg"
    echo "  2) Исправить проблемы Composer в HestiaCP"
    echo "  3) Исправить SSL таймауты"
    echo ""
    echo "🚀 УСТАНОВКА:"
    echo "  4) УНИВЕРСАЛЬНАЯ УСТАНОВКА ВСЕГО"
    echo "  5) Установка только HestiaCP"
    echo "  6) Установка только мониторинга"
    echo "  7) Установка с нуля (клонирование + установка)"
    echo ""
    echo "📊 ИНФОРМАЦИЯ:"
    echo "  8) Показать учетные данные"
    echo "  9) Проверить безопасность"
    echo "  10) Проверить версии"
    echo "  11) Принудительное обновление"
    echo ""
    echo "🗑️ УДАЛЕНИЕ:"
    echo "  12) ПОЛНОЕ УДАЛЕНИЕ ВСЕГО (система с нуля)"
    echo ""
    echo "❌ ВЫХОД:"
    echo "  0) Выход"
    echo ""
}

# ============================================================================
# ЗАПУСК
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Проверка аргументов командной строки
    case "${1:-}" in
        --install)
            main_installation
            ;;
        --install-hestia)
            install_hestia_only
            ;;
        --install-monitoring)
            install_monitoring_only
            ;;
        --fix-dpkg)
            fix_dpkg_locks_manager
            ;;

        --fix-ssl)
            fix_ssl_timeouts_manager
            ;;
        --check-security)
            main_security_check
            ;;
        --show-credentials)
            show_credentials
            ;;
        --check-version)
            check_version
            ;;
        --force-update)
            force_update
            ;;
        --install-from-scratch)
            install_from_scratch
            ;;
        --complete-removal)
            complete_removal
            ;;
        --help|"")
            echo "🚀 Traffic Connect Server - УНИВЕРСАЛЬНЫЙ МЕНЕДЖЕР"
            echo "================================================"
            echo ""
            echo "ИСПОЛЬЗОВАНИЕ:"
            echo "  ./traffic_manager.sh [ОПЦИЯ]"
            echo ""
            echo "ОПЦИИ:"
            echo "  --install              УНИВЕРСАЛЬНАЯ УСТАНОВКА ВСЕГО"
            echo "  --install-hestia       Установка только HestiaCP"
            echo "  --install-monitoring   Установка только мониторинга"
            echo "  --install-from-scratch Установка с нуля (клонирование + установка)"
            echo "  --complete-removal     ПОЛНОЕ УДАЛЕНИЕ ВСЕГО (система с нуля)"
            echo "  --fix-dpkg             Исправить блокировки dpkg"

            echo "  --fix-ssl              Исправить SSL таймауты"
            echo "  --check-security       Проверить безопасность"
            echo "  --show-credentials     Показать учетные данные"
            echo "  --check-version        Проверить версии"
            echo "  --force-update         Принудительное обновление"
            echo "  --help                 Показать эту справку"
            echo ""
            echo "ИНТЕРАКТИВНОЕ МЕНЮ:"
            echo "  ./traffic_manager.sh   (без аргументов)"
            echo ""
            ;;
        *)
            echo "❌ Неизвестная опция: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
    
    # Если запущен без аргументов, показываем интерактивное меню
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "Выберите действие (0-12): " choice
            
            case $choice in
                0)
                    echo "👋 До свидания!"
                    exit 0
                    ;;
                1)
                    fix_dpkg_locks_manager
                    ;;
                2)
                    echo "❌ Функция исправления Composer удалена"
                    ;;
                3)
                    fix_ssl_timeouts_manager
                    ;;
                4)
                    echo "Запуск универсальной установки..."
                    main_installation
                    ;;
                5)
                    install_hestia_only
                    ;;
                6)
                    echo "Запуск установки только мониторинга..."
                    install_monitoring_only
                    ;;
                7)
                    install_from_scratch
                    ;;
                8)
                    show_credentials
                    ;;
                9)
                    main_security_check
                    ;;
                10)
                    check_version
                    ;;
                11)
                    force_update
                    ;;
                12)
                    complete_removal
                    ;;
                *)
                    echo "❌ Неверный выбор. Попробуйте снова."
                    ;;
            esac
            
            echo ""
            read -p "Нажмите Enter для продолжения..."
        done
    fi
fi
