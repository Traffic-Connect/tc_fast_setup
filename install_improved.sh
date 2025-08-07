#!/bin/bash
# ============================================================================
# Traffic Connect Server - Улучшенный установщик с правильной очередностью
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

# Проверка места на диске
check_disk_space() {
    log_info "Проверка места на диске..."
    
    local free_space=$(df -m / | awk 'NR==2{print $4}')
    if [ "$free_space" -lt "$REQUIRED_DISK_SPACE" ]; then
        log_err "Недостаточно места на диске: требуется ${REQUIRED_DISK_SPACE}MB, доступно ${free_space}MB"
        return 1
    fi
    
    log_ok "Места на диске достаточно"
    return 0
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

# ============================================================================
# ЭТАП 1: СИСТЕМНЫЕ КОМПОНЕНТЫ
# ============================================================================

install_system_components() {
    log_info "=== ЭТАП 1: Установка системных компонентов ==="
    
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
    
    # Добавление репозитория Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Обновление списков пакетов
    apt update
    
    # 1.4 Установка дополнительных пакетов
    log_info "Установка дополнительных пакетов..."
    local additional_packages="nodejs docker-ce docker-ce-cli containerd.io docker-compose-plugin htop iotop nethogs"
    
    if ! apt install -y $additional_packages; then
        log_warn "Ошибка установки дополнительных пакетов, исправляем..."
        fix_dpkg_locks
        apt install -y $additional_packages
    fi
    
    # 1.5 Настройка Docker
    log_info "Настройка Docker..."
    systemctl enable docker
    systemctl start docker
    
    # 1.6 Создание системных пользователей
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
    log_ok "=== ЭТАП 1 ЗАВЕРШЕН ==="
}

# ============================================================================
# ЭТАП 2: УСТАНОВКА HESTIACP
# ============================================================================

install_hestia() {
    log_info "=== ЭТАП 2: Установка HestiaCP ==="
    
    # Проверка, не установлен ли уже HestiaCP
    if [ -f "/usr/local/admin/bin/admin" ] || [ -d "/usr/local/admin" ] || systemctl is-active --quiet admin 2>/dev/null || [ -f "/usr/local/hestia/install.log" ]; then
        log_warn "HestiaCP уже установлен, пропускаем установку"
        echo "hestia_installed" > "$HESTIA_INSTALLED_FLAG"
        return 0
    fi
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "hestia_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "HestiaCP уже установлен в предыдущем запуске, пропускаем"
        return 0
    fi
    
    # Генерация пароля для HestiaCP
    log_info "Генерация пароля для HestiaCP..."
    if type generate_compliant_password >/dev/null 2>&1; then
        HESTIA_PASSWORD=$(generate_compliant_password $RECOMMENDED_PASSWORD_LENGTH "high")
    else
        HESTIA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
    fi
    
    export HESTIA_PASSWORD
    log_info "Пароль для HestiaCP: $HESTIA_PASSWORD"
    
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
    
    # Предварительная установка Composer с правильными настройками SSL
    log_info "Предварительная настройка Composer для решения проблем SSL..."
    
    # Создаем временный скрипт для установки Composer
    cat > /tmp/install_composer.sh << 'EOF'
#!/bin/bash
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
    bash /tmp/hst-install.sh --lang 'ru' --hostname "$HESTIA_HOSTNAME" --username "$HESTIA_USERNAME" --email "$HESTIA_EMAIL" --password "$HESTIA_PASSWORD" --apache no --named no --exim no --dovecot no --clamav no --spamassassin no --force
    
    if [ $? -eq 0 ]; then
        log_ok "✅ HestiaCP установлен успешно"
        echo "hestia_installed" > "$HESTIA_INSTALLED_FLAG"
    else
        log_err "❌ Ошибка установки HestiaCP"
        return 1
    fi
    
    # Очистка временных файлов
    log_info "Очистка временных файлов..."
    rm -f /tmp/hst-install.sh /tmp/install_composer.sh
    rm -rf /tmp/composer
    
    # Отметка завершения этапа
    echo "hestia_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "=== ЭТАП 2 ЗАВЕРШЕН ==="
    
    # Требуется перезагрузка после установки HestiaCP
    log_warn "⚠️ Требуется перезагрузка системы после установки HestiaCP"
    echo "reboot_required" > "$REBOOT_REQUIRED_FLAG"
    
    return 0
}

# ============================================================================
# ЭТАП 3: ПРОДОЛЖЕНИЕ УСТАНОВКИ ПОСЛЕ ПЕРЕЗАГРУЗКИ
# ============================================================================

continue_installation() {
    log_info "=== ЭТАП 3: Продолжение установки после перезагрузки ==="
    
    # Проверка, установлен ли HestiaCP
    if [ ! -f "$HESTIA_INSTALLED_FLAG" ] && [ ! -f "/usr/local/admin/bin/admin" ]; then
        log_err "HestiaCP не установлен. Сначала выполните установку HestiaCP"
        return 1
    fi
    
    # Проверка, не выполнен ли уже этот этап
    if [ -f "$INSTALL_STAGE_FILE" ] && grep -q "installation_completed" "$INSTALL_STAGE_FILE"; then
        log_warn "Установка уже завершена, пропускаем"
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
    
    # Установка системы мониторинга
    log_info "Установка системы мониторинга..."
    source "$PROJECT_ROOT/system/monitoring/monitoring_install.sh"
    
    if ! install_monitoring; then
        log_warn "Предупреждение: не удалось установить систему мониторинга"
    fi
    
    # Настройка веб-сервера
    log_info "Настройка веб-сервера..."
    source "$PROJECT_ROOT/web/templates/templates_install.sh"
    
    if ! setup_web_server; then
        log_warn "Предупреждение: не удалось настроить веб-сервер"
    fi
    
    # Отметка завершения установки
    echo "installation_completed" >> "$INSTALL_STAGE_FILE"
    log_ok "=== ЭТАП 3 ЗАВЕРШЕН ==="
    
    return 0
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ УСТАНОВКИ
# ============================================================================

main_installation() {
    echo "🚀 Запуск улучшенной установки Traffic Connect Server..."
    echo "================================================"
    
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
    if ! check_internet; then
        log_err "Нет интернет-соединения"
        exit 1
    fi
    
    # Проверка места на диске
    if ! check_disk_space; then
        log_err "Недостаточно места на диске"
        exit 1
    fi
    
    # Проверка, требуется ли перезагрузка
    if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
        log_info "Обнаружен флаг перезагрузки, продолжаем установку..."
        rm -f "$REBOOT_REQUIRED_FLAG"
        continue_installation
    else
        # Полная установка с нуля
        log_info "Начинаем полную установку с нуля..."
        
        # Этап 1: Системные компоненты
        install_system_components
        
        # Этап 2: Установка HestiaCP
        install_hestia
        
        # Проверка, требуется ли перезагрузка
        if [ -f "$REBOOT_REQUIRED_FLAG" ]; then
            echo ""
            echo "🔄 ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА СИСТЕМЫ"
            echo "================================================"
            echo "HestiaCP установлен успешно. Требуется перезагрузка для завершения установки."
            echo ""
            echo "После перезагрузки запустите скрипт снова:"
            echo "  ./install_improved.sh"
            echo ""
            echo "Или используйте единый скрипт:"
            echo "  ./traffic_connect.sh --install"
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
    log_ok "Установка Traffic Connect Server завершена успешно!"
    
    # Отображение данных для входа
    show_access_credentials
    
    # Отображение всех сгенерированных паролей
    show_all_passwords
    
    echo "📚 Документация: $PROJECT_ROOT/docs/"
    echo "🔧 Конфигурация: $PROJECT_ROOT/web/configs/"
    echo "🛡️ Безопасность: $PROJECT_ROOT/system/security/"
    
    # Очистка временных файлов
    rm -f "$INSTALL_STAGE_FILE" "$HESTIA_INSTALLED_FLAG" "$REBOOT_REQUIRED_FLAG"
}

# ============================================================================
# ЗАПУСК
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_installation
fi
