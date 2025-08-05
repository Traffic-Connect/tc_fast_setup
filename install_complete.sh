#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Основной скрипт
# ============================================================================

# Загрузка общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/common.sh"

# ============================================================================
# ПРОВЕРКА РЕЖИМА ПРОДОЛЖЕНИЯ
# ============================================================================

# Проверяем, нужно ли продолжить установку после перезапуска
if [[ "$1" == "--continue" ]]; then
    log_info "Режим продолжения установки после перезапуска"
    log_info "Пропускаем установку Hestia CP и базовых компонентов"
    
    # Продолжаем с установки системы мониторинга
    echo -e "${YELLOW}=== Установка Grafana ===${NC}"
    install_grafana
    check_error "Установка Grafana"
    
    echo -e "${YELLOW}=== Установка Prometheus ===${NC}"
    install_prometheus
    check_error "Установка Prometheus"
    
    echo -e "${YELLOW}=== Установка Node Exporter ===${NC}"
    install_node_exporter
    check_error "Установка Node Exporter"
    
    echo -e "${YELLOW}=== Установка Pushgateway ===${NC}"
    install_pushgateway
    check_error "Установка Pushgateway"
    
    echo -e "${YELLOW}=== Установка Loki и Promtail ===${NC}"
    install_loki
    check_error "Установка Loki и Promtail"
    
    # Продолжаем с остальной настройки
    echo -e "${YELLOW}=== Настройка мониторинга fail2ban ===${NC}"
    setup_fail2ban_monitoring
    check_error "Настройка мониторинга fail2ban"
    
    echo -e "${YELLOW}=== Настройка Grafana ===${NC}"
    setup_grafana
    check_error "Настройка Grafana"
    
    echo -e "${YELLOW}=== Дополнительная настройка Promtail ===${NC}"
    setup_promtail_additional
    check_error "Дополнительная настройка Promtail"
    
    # Финальная проверка и завершение
    log_info "Финальная проверка работоспособности сервисов..."
    verify_installation
    check_version_compatibility
    
    echo -e "${YELLOW}=== Установка завершена ===${NC}"
    
    # Перезапуск всех служб в режиме продолжения
    restart_all_services
    
    show_final_info
    exit 0
fi

# ============================================================================
# ПОШАГОВАЯ УСТАНОВКА С ПРОГРЕССОМ
# ============================================================================

show_installation_progress() {
    local steps=(
        "Проверка системы"
        "Загрузка компонентов"
        "Установка HestiaCP"
        "Установка Grafana"
        "Установка Prometheus"
        "Установка Loki"
        "Установка Node Exporter"
        "Установка Pushgateway"
        "Настройка мониторинга"
        "Проверка сервисов"
        "Финальная настройка"
    )
    
    local total_steps=${#steps[@]}
    local current_step=0
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                🚀 НАЧАЛО УСТАНОВКИ 🚀                   ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ Всего шагов: $total_steps"
    echo "║ Время начала: $(date)"
    echo "╚══════════════════════════════════════════════════════════╝"
    
    for step in "${steps[@]}"; do
        current_step=$((current_step + 1))
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║ Шаг $current_step/$total_steps: $step"
        echo "╚══════════════════════════════════════════════════════════╝"
        
        # Показываем прогресс
        show_progress_bar $current_step $total_steps
        
        # Здесь будет выполняться установка
        case $current_step in
            1) check_system_requirements ;;
            2) download_components ;;
            3) install_hestia ;;
            4) install_grafana ;;
            5) install_prometheus ;;
            6) install_loki ;;
            7) install_node_exporter ;;
            8) install_pushgateway ;;
            9) setup_monitoring ;;
            10) verify_services ;;
            11) final_setup ;;
        esac
        
        if [ $? -eq 0 ]; then
            show_status "success" "Шаг $current_step завершен успешно"
        else
            show_status "error" "Ошибка на шаге $current_step"
            return 1
        fi
    done
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                ✅ УСТАНОВКА ЗАВЕРШЕНА! ✅                ║"
    echo "╚══════════════════════════════════════════════════════════╝"
}

# Live мониторинг установки
show_live_monitoring() {
    local pid=$1
    
    echo ""
    echo "📊 МОНИТОРИНГ УСТАНОВКИ В РЕАЛЬНОМ ВРЕМЕНИ"
    echo "╔══════════════════════════════════════════════════════════╗"
    
    while kill -0 $pid 2>/dev/null; do
        local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        local mem=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
        local disk=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
        
        printf "\r║ CPU: %s%% | Память: %s%% | Диск: %s%% | Время: %s ║" \
               "$cpu" "$mem" "$disk" "$(date +%H:%M:%S)"
        
        sleep 2
    done
    
    echo ""
    echo "╚══════════════════════════════════════════════════════════╝"
}

# ============================================================================
# НЕДОСТАЮЩИЕ ФУНКЦИИ УСТАНОВКИ
# ============================================================================

# Загрузка компонентов
download_components() {
    log_info "Загрузка компонентов..."
    mkdir -p /tmp/install
    cd /tmp/install
    
    # Загрузка Grafana
    wget -q "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb" -O grafana.deb
    check_error "Загрузка Grafana" "grafana"
    
    # Загрузка Prometheus
    wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" -O prometheus.tar.gz
    check_error "Загрузка Prometheus" "prometheus"
    
    # Загрузка Loki
    wget -q "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip" -O loki.zip
    check_error "Загрузка Loki" "loki"
    
    # Загрузка Node Exporter
    wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" -O node_exporter.tar.gz
    check_error "Загрузка Node Exporter" "node_exporter"
    
    # Загрузка Pushgateway
    wget -q "https://github.com/prometheus/pushgateway/releases/download/v${PUSHGATEWAY_VERSION}/pushgateway-${PUSHGATEWAY_VERSION}.linux-amd64.tar.gz" -O pushgateway.tar.gz
    check_error "Загрузка Pushgateway" "pushgateway"
    
    log_ok "Все компоненты загружены"
}

# Настройка мониторинга
setup_monitoring() {
    log_info "Настройка системы мониторинга..."
    
    # Создание пользователей
    useradd --system --no-create-home --shell /bin/false prometheus
    useradd --system --no-create-home --shell /bin/false loki
    useradd --system --no-create-home --shell /bin/false node_exporter
    useradd --system --no-create-home --shell /bin/false pushgateway
    
    # Создание директорий
    mkdir -p /etc/prometheus /var/lib/prometheus
    mkdir -p /etc/loki /var/lib/loki
    mkdir -p /etc/promtail
    
    # Настройка прав
    chown prometheus:prometheus /etc/prometheus /var/lib/prometheus
    chown loki:loki /etc/loki /var/lib/loki
    
    log_ok "Система мониторинга настроена"
}

# Проверка сервисов
verify_services() {
    log_info "Проверка установленных сервисов..."
    
    local services=("grafana-server" "prometheus" "loki" "node_exporter" "pushgateway")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_ok "Сервис $service запущен"
        else
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warn "Следующие сервисы не запущены: ${failed_services[*]}"
        return 1
    else
        log_ok "Все сервисы запущены успешно"
        return 0
    fi
}

# Финальная настройка
final_setup() {
    log_info "Выполнение финальной настройки..."
    
    # Настройка автозапуска
    systemctl enable grafana-server prometheus loki node_exporter pushgateway
    
    # Настройка firewall для мониторинга
    for port in $GRAFANA_PORT $PROMETHEUS_PORT $LOKI_PORT $NODE_EXPORTER_PORT $PUSHGATEWAY_PORT; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
    done
    
    # Сохранение правил firewall
    netfilter-persistent save
    
    log_ok "Финальная настройка завершена"
}

# ============================================================================
# ОСНОВНАЯ ЛОГИКА УСТАНОВКИ
# ============================================================================

# Проверка root прав
check_root

# Настройка логирования
setup_logging

# Проверка системы
log_info "Выполнение предварительных проверок..."
check_internet
check_disk_space
log_ok "Предварительные проверки пройдены"

# Генерация паролей
GRAFANA_PASSWORD=$(generate_secure_password)
HESTIA_PASSWORD=$(generate_secure_password)

# Установка переменных по умолчанию
HESTIA_USER="${HESTIA_USER:-$DEFAULT_HESTIA_USER}"
EMAIL="${EMAIL:-$DEFAULT_EMAIL}"

# Сохранение паролей
save_credentials "$GRAFANA_PASSWORD" "$HESTIA_USER" "$HESTIA_PASSWORD"

# Установка обработчика ошибок для отката
trap rollback_installation ERR

# Конфигурация для логов
GEOIP_DB_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb"
LOG_DIR="/var/log/nginx"

# Автоопределение путей логов
find_log_directories() {
    local log_dirs=()
    for dir in /var/log/nginx /var/log/hestia; do
        if [ -d "$dir" ] && [ "$(ls -A $dir/*.log 2>/dev/null)" ]; then
            log_dirs+=("$dir")
        fi
    done
    echo "${log_dirs[@]}"
}

# Загрузка GeoIP базы
download_geoip() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if wget -q "$GEOIP_DB_URL" -O /etc/promtail/geoip/GeoLite2-City.mmdb; then
            echo -e "${GREEN}✓ GeoIP база загружена${NC}"
            return 0
        else
            echo -e "${RED}✗ Попытка $attempt из $max_attempts не удалась${NC}"
            sleep 5
            ((attempt++))
        fi
    done
    return 1
}

# Проверка совместимости версий
check_version_compatibility() {
    local loki_version=$(curl -s http://localhost:3100/ready | jq -r '.version' 2>/dev/null)
    if [ "$loki_version" != "$LOKI_VERSION" ]; then
        echo -e "${YELLOW}⚠ Версии Loki ($loki_version) и Promtail ($LOKI_VERSION) могут быть несовместимы${NC}"
    fi
}

# Проверка совместимости
check_compatibility() {
    log_info "Проверка совместимости системы..."
    
    # Проверка архитектуры
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_err "Неподдерживаемая архитектура: $arch. Требуется x86_64"
        return 1
    fi
    
    # Проверка ОС
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
            log_err "Неподдерживаемая ОС: $ID. Требуется Ubuntu или Debian"
            return 1
        fi
    fi
    
    log_ok "Система совместима"
    return 0
}

# Вариант A: Добавить проверку зависимостей
check_dependencies() {
    local deps=("wget" "curl" "jq" "unzip" "setfacl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Отсутствуют зависимости: ${missing_deps[*]}${NC}"
        echo -e "${BLUE}Устанавливаем...${NC}"
        apt install -y "${missing_deps[@]}"
    fi
}

# Настройка множественных источников логов
setup_multiple_log_sources() {
    local log_sources=()
    
    # Поиск всех возможных источников логов
    for pattern in "/var/log/nginx/*.log" "/var/log/hestia/*.log"; do
        if ls $pattern >/dev/null 2>&1; then
            log_sources+=("$pattern")
        fi
    done
    
    # Создание конфигурации для каждого источника
    for source in "${log_sources[@]}"; do
        local job_name=$(basename $(dirname "$source"))
        cat >> /etc/promtail/promtail-config.yaml <<EOF
- job_name: $job_name
  static_configs:
  - targets: [localhost]
    labels:
      job: $job_name
      __path__: "$source"
EOF
    done
}

# ============================================================================
# ОСНОВНАЯ УСТАНОВКА
# ============================================================================

# 2. Обновление системы и установка базовых пакетов
echo -e "${YELLOW}=== Установка базовых пакетов ===${NC}"
apt update && apt upgrade -y
apt install -y fail2ban iptables-persistent netfilter-persistent curl wget \
               software-properties-common apt-transport-https python3 \
               python3-pip python3-venv git gnupg2 ca-certificates \
               adduser libfontconfig1 unzip cron nginx
check_error "Установка базовых пакетов"

# Включение и запуск nginx
systemctl enable nginx
systemctl start nginx
log_ok "Nginx включен и запущен"

# 3. Установка Hestia CP
echo -e "${YELLOW}=== Установка Hestia CP ===${NC}"
install_hestia() {
    log_info "Установка HestiaCP..."
    
    # Проверяем, установлен ли уже Hestia CP
    if [ -f "/usr/local/hestia/bin/hestia" ]; then
        log_info "Hestia CP уже установлен"
        
        # Проверяем, есть ли служба
        if systemctl list-unit-files | grep -q hestia.service; then
            log_ok "Служба Hestia CP найдена"
        else
            log_warn "Служба Hestia CP не найдена, создаем..."
            # Создаем службу если её нет
            cat > /etc/systemd/system/hestia.service << 'EOF'
[Unit]
Description=Hestia Control Panel
After=network.target

[Service]
Type=forking
User=root
ExecStart=/usr/local/hestia/bin/hestia start
ExecStop=/usr/local/hestia/bin/hestia stop
ExecReload=/usr/local/hestia/bin/hestia reload
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable hestia
            log_ok "Служба Hestia CP создана и включена"
        fi
        
        # Пытаемся запустить службу если она не запущена
        if ! systemctl is-active --quiet hestia; then
            log_info "Запускаем службу Hestia CP..."
            systemctl start hestia
            sleep 5
        fi
        
        # Создаем директории для логов если их нет
        mkdir -p /var/log/nginx
        mkdir -p /var/log/hestia
        
        log_ok "Hestia CP уже установлен и настроен"
        return 0
    else
        log_info "Начинаем установку Hestia CP..."
        
        # Очищаем все следы предыдущей установки Hestia CP
        log_info "Очистка следов предыдущей установки Hestia CP..."
        rm -rf /usr/local/hestia
        rm -rf /home/admin
        rm -rf /home/*/conf
        rm -f /etc/systemd/system/hestia.service
        rm -f /etc/nginx/sites-available/hestia
        rm -f /etc/nginx/sites-enabled/hestia
        
        # Удаляем пользователей и группы Hestia CP
        log_info "Удаление пользователей и групп Hestia CP..."
        userdel -r Trafficadmin 2>/dev/null || true
        userdel -r admin 2>/dev/null || true
        groupdel Trafficadmin 2>/dev/null || true
        groupdel admin 2>/dev/null || true
        
        systemctl daemon-reload
        
        wget https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh -O /tmp/hst-install.sh
        chmod +x /tmp/hst-install.sh
        
        # Создаем автоматический скрипт установки
        cat > /tmp/hestia_auto_install.sh << 'EOF'
#!/bin/bash
# Автоматическая установка Hestia CP
set -e

# Устанавливаем Hestia CP с фиксированными значениями
echo "y" | bash /tmp/hst-install.sh \
    --lang 'ru' \
    --hostname "$(hostname).local" \
    --username 'Trafficadmin' \
    --email 'info@hestia.ru' \
    --password "$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)" \
    --apache no \
    --named no \
    --exim no \
    --dovecot no \
    --clamav no \
    --spamassassin no \
    --force

echo "Hestia CP установлен успешно"
EOF

        chmod +x /tmp/hestia_auto_install.sh
        bash /tmp/hestia_auto_install.sh
        
        # Проверяем успешность установки
        if [ -f "/usr/local/hestia/bin/hestia" ]; then
            log_ok "Hestia CP успешно установлен"
        else
            log_err "Ошибка установки Hestia CP"
            rm -f /tmp/hst-install.sh /tmp/hestia_auto_install.sh
            exit 1
        fi
        rm -f /tmp/hst-install.sh /tmp/hestia_auto_install.sh
        
        # Создаем директории для логов если их нет
        mkdir -p /var/log/nginx
        mkdir -p /var/log/hestia
        
        log_ok "Установка Hestia CP завершена"
        
        # Проверяем, нужен ли перезапуск после установки Hestia CP
        if [ ! -f "/tmp/hestia_restart_done" ]; then
            log_warn "После установки Hestia CP требуется перезапуск системы"
            log_info "Создаю маркер для продолжения установки после перезапуска..."
            
            # Создаем маркер и скрипт для продолжения
            echo "$(date)" > /tmp/hestia_restart_done
            cat > /tmp/continue_installation.sh << 'EOF'
#!/bin/bash
# Скрипт продолжения установки после перезапуска
cd /root/tc_fast_setup
echo "Продолжение установки после перезапуска..."
bash install.sh --continue
EOF
            chmod +x /tmp/continue_installation.sh
            
            # Добавляем в автозапуск
            echo "/tmp/continue_installation.sh" >> /etc/rc.local
            chmod +x /etc/rc.local
            
            log_info "Система будет перезапущена через 10 секунд..."
            log_info "После перезапуска установка продолжится автоматически"
            sleep 10
            reboot
        fi
    fi
}

# Вызов функции установки Hestia CP
install_hestia

# Ожидание и проверка службы Hestia CP
log_info "Ожидание запуска службы Hestia CP..."
sleep 30

# Проверка службы Hestia CP
if systemctl is-active --quiet hestia; then
    log_ok "Служба Hestia CP запущена"
else
    log_warn "Служба Hestia CP не запущена, попытка запуска..."
    systemctl start hestia
    sleep 10
    
    # Проверяем несколько раз
    for i in {1..3}; do
        if systemctl is-active --quiet hestia; then
            log_ok "Служба Hestia CP запущена"
            break
        else
            log_warn "Попытка $i/3: Служба Hestia CP не запущена, ожидание..."
            sleep 10
        fi
    done
    
    if ! systemctl is-active --quiet hestia; then
        log_err "Не удалось запустить службу Hestia CP"
        log_info "Проверка статуса службы:"
        systemctl status hestia --no-pager
        log_info "Последние логи службы:"
        journalctl -u hestia -n 20 --no-pager
    fi
fi

# Проверка веб-интерфейса Hestia CP
log_info "Проверка веб-интерфейса Hestia CP..."
check_service "hestia" "8083"

# 4. Настройка iptables
echo -e "${YELLOW}=== Настройка firewall ===${NC}"
iptables -F && iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Базовые правила
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Разрешение HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Разрешение Cloudflare IPs
echo -e "${BLUE}Добавление правил для Cloudflare...${NC}"
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
    iptables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT
done

# Порты Hestia CP и мониторинга
for port in 22 80 443 8083 3306 5432 8080 25 465 587 993 995 143 110 53 3000 9090 9100 3100 9080 9191 9091; do
    iptables -A INPUT -p tcp --dport $port -j ACCEPT
done
iptables -A INPUT -p udp --dport 53 -j ACCEPT  # DNS UDP

# Защита от атак
iptables -N SYN_FLOOD
iptables -A INPUT -p tcp --syn -j SYN_FLOOD
iptables -A SYN_FLOOD -m limit --limit 10/s --limit-burst 25 -j RETURN
iptables -A SYN_FLOOD -j DROP

iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Защита от портовых сканеров
iptables -N PORT_SCAN
iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST -j PORT_SCAN
iptables -A PORT_SCAN -m limit --limit 1/s -j RETURN
iptables -A PORT_SCAN -j DROP

netfilter-persistent save
check_error "Настройка firewall"

# 5. Настройка fail2ban
echo -e "${YELLOW}=== Настройка fail2ban ===${NC}"
cat > /etc/fail2ban/jail.local <<EOL
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 1h
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-botsearch]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 10
findtime = 3600
bantime = 86400

[nginx-dos]
enabled = true
port = http,https
filter = nginx-dos
logpath = /var/log/nginx/access.log
maxretry = 100
findtime = 300
bantime = 3600

[hestia-auth]
enabled = true
port = 8083
filter = hestia-auth
logpath = /var/log/hestia/auth.log
maxretry = 5
findtime = 600
bantime = 86400
EOL

# Создаем фильтры для fail2ban
cat > /etc/fail2ban/filter.d/nginx-dos.conf <<EOL
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (404|503|400|499) .*$
ignoreregex =
EOL

cat > /etc/fail2ban/filter.d/hestia-auth.conf <<EOL
[Definition]
failregex = .*Authentication failed for .* from <HOST>
ignoreregex =
EOL

systemctl enable --now fail2ban
check_service "fail2ban"
check_error "Настройка fail2ban"

# 6. Установка Grafana
echo -e "${YELLOW}=== Установка Grafana ===${NC}"
{
    wget https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb -O /tmp/grafana.deb
    dpkg -i /tmp/grafana.deb || apt-get install -fy
    rm -f /tmp/grafana.deb
    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server
} > /dev/null 2>&1
check_service "grafana-server" "3000"
check_error "Установка Grafana"

# 7. Установка Prometheus
echo -e "${YELLOW}=== Установка Prometheus ===${NC}"
{
    useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
    mkdir -p /etc/prometheus /var/lib/prometheus
    chown prometheus:prometheus /var/lib/prometheus

    wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
    tar xvf /tmp/prometheus.tar.gz -C /tmp/
    mv /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
    mv /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool

    cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'loki'
    static_configs:
      - targets: ['localhost:9080']
  - job_name: 'fail2ban'
    static_configs:
      - targets: ['localhost:9191']
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['localhost:9091']
EOF

    cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/var/lib/prometheus \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle

Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
} > /dev/null 2>&1
check_service "prometheus" "9090"
check_error "Установка Prometheus"

# 8. Установка Node Exporter
echo -e "${YELLOW}=== Установка Node Exporter ===${NC}"
{
    wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
    tar xvf /tmp/node_exporter.tar.gz -C /tmp/
    mv /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
    useradd --no-create-home --shell /bin/false node_exporter
    chown node_exporter:node_exporter /usr/local/bin/node_exporter

    cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
} > /dev/null 2>&1
check_service "node_exporter" "9100"
check_error "Установка Node Exporter"

# 9. Установка Pushgateway
echo -e "${YELLOW}=== Установка Pushgateway ===${NC}"
{
    wget https://github.com/prometheus/pushgateway/releases/download/v${PUSHGATEWAY_VERSION}/pushgateway-${PUSHGATEWAY_VERSION}.linux-amd64.tar.gz -O /tmp/pushgateway.tar.gz
    tar xvf /tmp/pushgateway.tar.gz -C /tmp/
    mv /tmp/pushgateway-${PUSHGATEWAY_VERSION}.linux-amd64/pushgateway /usr/local/bin/
    useradd --no-create-home --shell /bin/false pushgateway
    chown pushgateway:pushgateway /usr/local/bin/pushgateway

    cat > /etc/systemd/system/pushgateway.service <<EOF
[Unit]
Description=Prometheus Pushgateway
After=network.target

[Service]
User=pushgateway
Group=pushgateway
ExecStart=/usr/local/bin/pushgateway \\
    --web.listen-address=:9091

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable pushgateway
    systemctl start pushgateway
} > /dev/null 2>&1
check_service "pushgateway" "9091"
check_error "Установка Pushgateway"

# 10. Установка Loki и Promtail
echo -e "${YELLOW}=== Установка Loki и Promtail ===${NC}"
{

    
    # Установка Loki
    wget https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip -O /tmp/loki.zip
    unzip /tmp/loki.zip -d /tmp/
    mv /tmp/loki-linux-amd64 /usr/local/bin/loki
    chmod +x /usr/local/bin/loki

    useradd --no-create-home --shell /bin/false loki
    mkdir -p /etc/loki /var/lib/loki
    chown loki:loki /var/lib/loki

    cat > /etc/loki/loki-config.yaml <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  http_server_read_timeout: 5m
  http_server_write_timeout: 5m
  grpc_server_max_recv_msg_size: 104857600  # 100MB
  grpc_server_max_send_msg_size: 104857600  # 100MB

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  query_timeout: 5m  # Явно устанавливаем 5 минут
  max_query_length: 168h
  max_query_parallelism: 32
  max_streams_matchers_per_query: 1000
  max_concurrent_tail_requests: 10
  max_entries_limit_per_query: 5000
  max_chunks_per_query: 2000000
  max_query_series: 500

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

ruler:
  alertmanager_url: http://localhost:9093

query_scheduler:
  max_outstanding_requests_per_tenant: 100
EOF

    cat > /etc/systemd/system/loki.service <<EOF
[Unit]
Description=Loki log aggregation system
After=network.target

[Service]
User=loki
Group=loki
Type=simple
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yaml

[Install]
WantedBy=multi-user.target
EOF

    # Установка Promtail
    wget https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/promtail-linux-amd64.zip -O /tmp/promtail.zip
    unzip /tmp/promtail.zip -d /tmp/
    mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
    chmod +x /usr/local/bin/promtail

    useradd --no-create-home --shell /bin/false promtail
    mkdir -p /etc/promtail
    chown promtail:promtail /etc/promtail

    systemctl daemon-reload
    systemctl enable --now loki
} > /dev/null 2>&1
check_service "loki" "3100"
check_error "Установка Loki и Promtail"

# 11. Настройка экспортера для fail2ban
echo -e "${YELLOW}=== Настройка мониторинга fail2ban ===${NC}"
{
    apt-get install -y python3-prometheus-client
    cat <<'EOF' | tee /usr/local/bin/fail2ban_exporter.py
from prometheus_client import start_http_server, Gauge
import subprocess
import time

banned_ips = Gauge('fail2ban_banned_ips', 'Number of banned IPs by fail2ban')

def collect():
    try:
        output = subprocess.check_output(["fail2ban-client", "status"])
        banned = 0
        for line in output.decode().splitlines():
            if "Total banned" in line:
                banned = int(line.split(":")[1].strip())
        banned_ips.set(banned)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    start_http_server(9191)
    while True:
        collect()
        time.sleep(15)
EOF

    chmod +x /usr/local/bin/fail2ban_exporter.py

    cat <<EOF | tee /etc/systemd/system/fail2ban_exporter.service
[Unit]
Description=Fail2Ban Metrics Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/fail2ban_exporter.py

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now fail2ban_exporter
} > /dev/null 2>&1
check_service "fail2ban_exporter" "9191"
check_error "Настройка мониторинга fail2ban"

# 12. Настройка Grafana
echo -e "${YELLOW}=== Настройка Grafana ===${NC}"
{
    while ! systemctl is-active --quiet grafana-server; do
        sleep 1
    done

    grafana-cli admin reset-admin-password "$GRAFANA_PASSWORD"

    until curl -u admin:admin -X POST -H "Content-Type: application/json" \
      -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy"}' \
      http://localhost:3000/api/datasources; do
        sleep 2
    done

    until curl -u admin:admin -X POST -H "Content-Type: application/json" \
      -d '{"name":"Loki","type":"loki","url":"http://localhost:3100","access":"proxy"}' \
      http://localhost:3000/api/datasources; do
        sleep 2
    done

    DASHBOARD_IDS="1860 11074 13659 13639"
    for DASH in $DASHBOARD_IDS; do
        curl -u admin:admin -X POST -H "Content-Type: application/json" \
          -d "{\"dashboard\":$(curl -s https://grafana.com/api/dashboards/$DASH/revisions/latest/download),\"overwrite\":true}" \
          http://localhost:3000/api/dashboards/import
    done
} > /dev/null 2>&1
check_error "Настройка Grafana"

# ============================================================================
# ДОПОЛНИТЕЛЬНАЯ НАСТРОЙКА PROMTAIL (из файла 2 (2).sh)
# ============================================================================

echo -e "${YELLOW}=== Дополнительная настройка Promtail ===${NC}"

# Проверка зависимостей
echo -e "${BLUE}Проверка зависимостей...${NC}"
check_dependencies

# Подготовка
systemctl stop promtail 2>/dev/null || true
rm -f /tmp/positions.yaml

# Автоопределение путей логов (Nginx и Hestia)
echo -e "${BLUE}Поиск директорий с логами...${NC}"
FOUND_LOG_DIRS=$(find_log_directories)
if [ -n "$FOUND_LOG_DIRS" ]; then
    LOG_DIRS=($FOUND_LOG_DIRS)
    echo -e "${GREEN}Найдены директории с логами:${NC}"
    for dir in "${LOG_DIRS[@]}"; do
        echo -e "  - $dir"
    done
    # Используем первую найденную директорию как основную
    LOG_DIR="${LOG_DIRS[0]}"
    echo -e "${GREEN}Основная директория логов: $LOG_DIR${NC}"
else
    echo -e "${YELLOW}Директории с логами не найдены, используем стандартную: $LOG_DIR${NC}"
fi

# Настройка GeoIP
echo -e "${YELLOW}=== Настройка GeoIP ===${NC}"
mkdir -p /etc/promtail/geoip
if download_geoip; then
    chown -R promtail:promtail /etc/promtail
else
    echo -e "${RED}ОШИБКА: Не удалось загрузить GeoIP базу данных${NC}"
    echo -e "${YELLOW}Продолжаем без GeoIP...${NC}"
fi



# Оптимизированная конфигурация Promtail
echo -e "${YELLOW}=== Создание оптимизированной конфигурации ===${NC}"
cat > /etc/promtail/promtail-config.yaml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push
    batchwait: 1s
    batchsize: 1024
    timeout: 10s

scrape_configs:
- job_name: nginx
  static_configs:
  - targets: [localhost]
    labels:
      job: nginx
      __path__: "$LOG_DIR/*.log"
  pipeline_stages:
    - regex:
        expression: '^(?P<remote_addr>\S+) \S+ \S+ \[(?P<timestamp>[^\]]+)\] "(?P<method>\S+) (?P<path>\S+) (?P<protocol>\S+)" (?P<status>\d+) (?P<bytes>\d+) "(?P<referer>[^"]*)" "(?P<user_agent>[^"]*)"'
    - labels:
        method:
        status:
        path:
        protocol:
        remote_addr:
        user_agent:
        referer:
    - timestamp:
        source: timestamp
        format: "02/Jan/2006:15:04:05 -0700"
    - geoip:
        db: "/etc/promtail/geoip/GeoLite2-City.mmdb"
        db_type: "city"
        source: "remote_addr"
        target: "geoip"
    - output:
        source: user_agent
    - output:
        source: remote_addr
EOF

# Добавление множественных источников логов
echo -e "${BLUE}Настройка множественных источников логов...${NC}"
setup_multiple_log_sources

# Настройка прав
echo -e "${YELLOW}=== Настройка прав доступа ===${NC}"
# Создаем директории если их нет
mkdir -p "$LOG_DIR"
mkdir -p /var/log/hestia

# Настраиваем права доступа
if [ -d "$LOG_DIR" ]; then
    chown -R root:adm "$LOG_DIR" 2>/dev/null || true
    chmod -R 750 "$LOG_DIR" 2>/dev/null || true
    setfacl -Rm u:promtail:rx "$LOG_DIR" 2>/dev/null || true
    setfacl -dm u:promtail:rx "$LOG_DIR" 2>/dev/null || true
    log_ok "Права доступа к логам настроены"
else
    log_warn "Директория логов не существует: $LOG_DIR"
fi

# Проверка доступа
echo -e "${BLUE}Проверка доступа к логам...${NC}"
if [ -d "$LOG_DIR" ] && [ "$(ls -A $LOG_DIR/*.log 2>/dev/null)" ]; then
    if ! sudo -u promtail head -n 1 "$LOG_DIR"/*.log >/dev/null 2>&1; then
        echo -e "${RED}ОШИБКА: Promtail не может читать логи${NC}"
        echo "Проблемные файлы:"
        sudo -u promtail ls -la "$LOG_DIR"/*.log
        exit 1
    else
        echo -e "${GREEN}✓ Доступ к логам настроен корректно${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Директория логов пуста или не существует: $LOG_DIR${NC}"
    echo -e "${YELLOW}Promtail будет запущен, но логи не будут собираться${NC}"
fi

# Обновленный systemd сервис
echo -e "${YELLOW}=== Обновление сервиса ===${NC}"
cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
User=promtail
Group=promtail
ExecStart=/usr/local/bin/promtail \\
    -config.file=/etc/promtail/promtail-config.yaml \\
    -config.expand-env=true
Restart=always
RestartSec=5s
LimitNOFILE=65536
Environment="LOG_DIR=$LOG_DIR"

[Install]
WantedBy=multi-user.target
EOF

# Перезапуск Promtail
echo -e "${YELLOW}=== Перезапуск Promtail ===${NC}"
systemctl daemon-reload
systemctl restart promtail
check_service "promtail" "9080"

# Проверка сбора логов
echo -e "${YELLOW}=== Проверка работы ===${NC}"
echo "Ожидание 20 секунд для сбора логов..."
sleep 20

# Проверка извлечения полей
LOG_CHECK=$(curl -s -G "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="nginx"} | logfmt | line_format "{{.remote_addr}} {{.user_agent}}"' | jq -r '.data.result[0].values[0][1]')

if [ -n "$LOG_CHECK" ]; then
  echo -e "${GREEN}✓ Логи успешно собираются${NC}"
  echo "Пример извлеченных данных:"
  echo "$LOG_CHECK"
  
  # Проверка GeoIP
  GEOIP_CHECK=$(curl -s -G "http://localhost:3100/loki/api/v1/query" \
    --data-urlencode 'query={job="nginx"} | logfmt | remote_addr!="" | geoip_country_name!=""' \
    | jq -r '.data.result[0].values[0][1]')
  
  if [ -n "$GEOIP_CHECK" ]; then
    echo -e "${GREEN}✓ GeoIP работает! Пример данных:${NC}"
    echo "$GEOIP_CHECK"
  else
    echo -e "${YELLOW}⚠ GeoIP не возвращает данные. Проверьте IP в логах${NC}"
  fi
else
  echo -e "${RED}ОШИБКА: Логи не поступают в Loki или поля не извлекаются${NC}"
  echo "Дополнительная диагностика:"
  echo "1. Проверьте файл позиций: cat /tmp/positions.yaml"
  echo "2. Проверьте логи Promtail: journalctl -u promtail -n 20 --no-pager"
  echo "3. Проверьте подключение к Loki: curl -v http://localhost:3100/ready"
  exit 1
fi

# Финальная проверка
log_info "Финальная проверка работоспособности сервисов..."

# Проверка целостности установки
log_info "Проверка целостности установки..."
verify_installation

# Проверка совместимости версий
echo -e "${YELLOW}=== Проверка совместимости версий ===${NC}"
check_version_compatibility

# Перезапуск всех установленных служб
echo -e "${YELLOW}=== Перезапуск всех установленных служб ===${NC}"
restart_all_services() {
    log_info "Перезапуск всех установленных служб..."
    
    # Список служб для перезапуска
    local services=(
        "nginx"
        "hestia"
        "grafana-server"
        "prometheus"
        "loki"
        "node_exporter"
        "pushgateway"
        "promtail"
        "fail2ban"
    )
    
    # Перезагрузка systemd
    log_info "Перезагрузка systemd daemon..."
    systemctl daemon-reload
    
    # Перезапуск каждой службы
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            log_info "Перезапуск службы: $service"
            if systemctl restart "$service"; then
                log_ok "Служба $service перезапущена успешно"
            else
                log_warn "Не удалось перезапустить службу $service"
            fi
        else
            log_info "Служба $service не найдена, пропускаем"
        fi
    done
    
    # Дополнительные службы
    log_info "Проверка и перезапуск дополнительных служб..."
    
    # MySQL/MariaDB если установлен
    if systemctl list-unit-files | grep -q "mysql.service"; then
        log_info "Перезапуск MySQL/MariaDB..."
        systemctl restart mysql
    elif systemctl list-unit-files | grep -q "mariadb.service"; then
        log_info "Перезапуск MariaDB..."
        systemctl restart mariadb
    fi
    
    # PHP-FPM если установлен
    if systemctl list-unit-files | grep -q "php.*fpm.service"; then
        log_info "Перезапуск PHP-FPM..."
        systemctl restart php*-fpm
    fi
    
    # Проверка статуса всех служб
    log_info "Проверка статуса всех служб..."
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            if systemctl is-active --quiet "$service"; then
                log_ok "Служба $service активна"
            else
                log_warn "Служба $service неактивна"
            fi
        fi
    done
    
    log_ok "Перезапуск всех служб завершен"
}

# Вызов функции перезапуска
restart_all_services

# 13. Завершение установки
echo -e "${YELLOW}=== Установка завершена ===${NC}"
echo -e "${GREEN}Доступные сервисы:${NC}"
echo -e "Hestia CP:    http://$(hostname -I | awk '{print $1}'):8083"
echo -e "Grafana:      http://$(hostname -I | awk '{print $1}'):3000"
echo -e "Prometheus:   http://$(hostname -I | awk '{print $1}'):9090"
echo -e "Loki:         http://$(hostname -I | awk '{print $1}'):3100"
echo -e "Pushgateway:  http://$(hostname -I | awk '{print $1}'):9091"
echo -e "\n${GREEN}Данные для входа:${NC}"
echo -e "Hestia CP:  $HESTIA_USER / $HESTIA_PASSWORD"
echo -e "Grafana:    admin / $GRAFANA_PASSWORD"
echo -e "\n${RED}ВАЖНО: Измените пароли${NC}"

# Функция показа финальной информации
show_final_info() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                🎉 УСТАНОВКА ЗАВЕРШЕНА! 🎉                ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ 📊 СТАТИСТИКА:"
    echo "║    • Время установки: $(date)"
    echo "║    • Все службы перезапущены"
    echo "║    • Система готова к работе"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ 🌐 ДОСТУПНЫЕ СЕРВИСЫ:"
    echo "║    • HestiaCP: http://$(hostname -I | awk '{print $1}'):8083"
    echo "║    • Grafana: http://$(hostname -I | awk '{print $1}'):3000"
    echo "║    • Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
    echo "║    • Loki: http://$(hostname -I | awk '{print $1}'):3100"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                📋 СЛЕДУЮЩИЕ ШАГИ 📋                     ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ 1. Откройте HestiaCP и настройте домены"
    echo "║ 2. Настройте дашборды в Grafana"
    echo "║ 3. Проверьте метрики в Prometheus"
    echo "║ 4. Настройте алерты и уведомления"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                🔧 ПОЛЕЗНЫЕ КОМАНДЫ 🔧                   ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ • Проверка статуса: systemctl status grafana-server"
    echo "║ • Просмотр логов: journalctl -u grafana-server -f"
    echo "║ • Перезапуск Hestia: systemctl restart hestia"
    echo "║ • Проверка Nginx: nginx -t"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "💾 Пароли сохранены в: /root/credentials.txt"
    echo "⚠️  ВАЖНО: Измените пароли после установки!"
} 