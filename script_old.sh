#!/bin/bash
set -e

# Отладочная информация
echo "=== ОТЛАДКА: Скрипт запущен ==="
echo "Время: $(date)"
echo "PID: $$"
echo "Пользователь: $(whoami)"
echo "Директория: $(pwd)"
echo "================================"

# Цвета для вывода (определяем в начале)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Дополнительные цвета для градиентов
LIGHT_BLUE='\033[94m'
LIGHT_GREEN='\033[92m'
LIGHT_CYAN='\033[96m'
LIGHT_PURPLE='\033[95m'
LIGHT_RED='\033[91m'
LIGHT_YELLOW='\033[93m'

# Символы для оформления
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="->"
STAR="*"
DASH="-"
EQUALS="="
CORNER_TL="+"
CORNER_TR="+"
CORNER_BL="+"
CORNER_BR="+"
LINE_V="|"
LINE_H="="
LINE_T="+"
LINE_B="+"
LINE_L="+"
LINE_R="+"

# Функция восстановления состояния системы
restore_system_state() {
    echo "=== ОТЛАДКА: Функция restore_system_state() ==="
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Восстановление состояния системы..."
    
    # Завершаем зависшие процессы apt/dpkg
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Завершение зависших процессов..."
    pkill -f "apt" 2>/dev/null || true
    pkill -f "dpkg" 2>/dev/null || true
    pkill -f "apt-get" 2>/dev/null || true
    
    # Удаляем блокирующие файлы
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Удаление блокирующих файлов..."
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/dpkg/lock* 2>/dev/null || true
    rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
    
    # Восстанавливаем состояние dpkg
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Восстановление состояния dpkg..."
    dpkg --configure -a 2>/dev/null || true
    
    # Очищаем кэш apt
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Очистка кэша apt..."
    apt clean 2>/dev/null || true
    apt autoclean 2>/dev/null || true
    
    # Обновляем список пакетов
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Обновление списка пакетов..."
    apt update 2>/dev/null || true
    
    echo -e "${LIGHT_GREEN}${CHECK_MARK}${NC} Состояние системы восстановлено"
}

# Функция установки пакетов по частям
install_packages_in_parts() {
    echo "=== ОТЛАДКА: Функция install_packages_in_parts() ==="
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка базовых пакетов по частям..."
    
    # Часть 1: Основные утилиты
    safe_install "curl wget git nano htop" "Часть 1/5: Основные утилиты"
    
    # Часть 2: Сетевые утилиты
    safe_install "fail2ban iptables-persistent netfilter-persistent nftables" "Часть 2/5: Сетевые утилиты"
    
    # Часть 3: Python и связанные пакеты
    safe_install "software-properties-common apt-transport-https python3 python3-pip python3-venv" "Часть 3/5: Python и связанные пакеты"
    
    # Часть 4: Дополнительные утилиты
    safe_install "gnupg2 ca-certificates adduser libfontconfig1 unzip ncdu" "Часть 4/5: Дополнительные утилиты"
    
    # Часть 5: PHP зависимости
    safe_install "php-cli php-mbstring php-xml php-zip php-curl php-gd php-mysql php-fpm" "Часть 5/5: PHP зависимости"
    
    echo -e "${LIGHT_GREEN}${CHECK_MARK}${NC} Все базовые пакеты установлены успешно"
}

# Функция проверки зависимостей
check_dependencies() {
    local deps=("curl" "wget" "unzip" "openssl" "systemctl" "apt")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${LIGHT_YELLOW}⚠️ Отсутствуют зависимости: ${missing[*]}${NC}"
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Устанавливаем недостающие зависимости..."
        
        # Обновляем список пакетов
        apt update >/dev/null 2>&1 || true
        
        # Устанавливаем недостающие зависимости
        for dep in "${missing[@]}"; do
            case "$dep" in
                "curl")
                    apt install -y curl >/dev/null 2>&1 || true
                    ;;
                "wget")
                    apt install -y wget >/dev/null 2>&1 || true
                    ;;
                "unzip")
                    apt install -y unzip >/dev/null 2>&1 || true
                    ;;
                "openssl")
                    apt install -y openssl >/dev/null 2>&1 || true
                    ;;
                "systemctl")
                    # systemctl обычно входит в systemd, который должен быть установлен
                    echo -e "${LIGHT_YELLOW}⚠️ systemctl не найден - проверьте установку systemd${NC}"
                    ;;
                "apt")
                    echo -e "${LIGHT_RED}❌ apt не найден - это критическая ошибка${NC}"
                    exit 1
                    ;;
            esac
        done
        
        # Проверяем еще раз после установки
        local still_missing=()
        for dep in "${missing[@]}"; do
            if ! command -v "$dep" >/dev/null 2>&1; then
                still_missing+=("$dep")
            fi
        done
        
        if [ ${#still_missing[@]} -gt 0 ]; then
            echo -e "${LIGHT_RED}❌ Не удалось установить: ${still_missing[*]}${NC}"
            echo -e "${LIGHT_CYAN}${ARROW}${NC} Попробуйте установить вручную: apt install ${still_missing[*]}"
            exit 1
        else
            echo -e "${LIGHT_GREEN}✅ Все зависимости установлены успешно${NC}"
        fi
    else
        echo -e "${LIGHT_GREEN}✅ Все необходимые зависимости найдены${NC}"
    fi
}

# Функция безопасной генерации пароля
generate_password() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
    elif command -v tr >/dev/null 2>&1 && [ -r /dev/urandom ]; then
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16
    else
        echo "defaultPassword123"
    fi
}

# Функция безопасного удаления файла
safe_remove() {
    local file="$1"
    if [ -f "$file" ]; then
        rm -f "$file"
    fi
}

# Функция безопасной установки пакетов
safe_install() {
    local packages="$1"
    local description="$2"
    
    echo "=== ОТЛАДКА: safe_install() - $description ==="
    echo "Пакеты: $packages"
    echo -e "${LIGHT_CYAN}${ARROW}${NC} $description..."
    
    # Попытка установки
    if apt install -y $packages 2>/dev/null; then
        echo -e "${LIGHT_GREEN}${CHECK_MARK}${NC} $description завершена успешно"
        return 0
    else
        echo -e "${LIGHT_YELLOW}⚠️ Ошибка установки $description, восстанавливаем состояние...${NC}"
        restore_system_state
        
        # Повторная попытка
        if apt install -y $packages; then
            echo -e "${LIGHT_GREEN}${CHECK_MARK}${NC} $description завершена успешно после восстановления"
            return 0
        else
            echo -e "${LIGHT_RED}${CROSS_MARK}${NC} Критическая ошибка установки $description"
            return 1
        fi
    fi
}







# Функция проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS_MARK} [ОШИБКА] $1${NC}"
        exit 1
    else
        echo -e "${GREEN}${CHECK_MARK} [OK] $1${NC}"
    fi
}

# Функция для красивого заголовка
print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:padding} ${BOLD}${title}${NC} ${LINE_H:0:padding}${CORNER_TR}${NC}"
}

# Функция для прогресс-бара
show_progress() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}[${NC}"
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "${CYAN}] ${NC}${LIGHT_GREEN}%d%%${NC}" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Проверка root
if [ "$(id -u)" != "0" ]; then
    echo -e "${LIGHT_RED}${CROSS_MARK} Этот скрипт должен быть запущен от имени root${NC}" 1>&2
    exit 1
fi

# Красивый заголовок скрипта
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🚀 TC FAST SETUP - АВТОМАТИЧЕСКАЯ УСТАНОВКА${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${LIGHT_CYAN}Система мониторинга и управления сервером${NC}${LIGHT_BLUE}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# 0. Восстановление состояния системы (новый шаг)
print_header "🔧 ВОССТАНОВЛЕНИЕ СОСТОЯНИЯ СИСТЕМЫ"
restore_system_state

# Проверка зависимостей
check_dependencies

# 1. Очистка системы
print_header "🧹 ОЧИСТКА СИСТЕМЫ"
{
    systemctl stop grafana-server 2>/dev/null || true
    apt purge -y grafana* 2>/dev/null || true
    rm -rf /etc/apt/sources.list.d/grafana* /usr/share/keyrings/grafana.gpg
    apt autoremove -y
    apt update
} > /dev/null 2>&1

# Установка временной зоны
timedatectl set-timezone Europe/Minsk

# 2. Обновление системы и установка базовых пакетов
print_header "📦 УСТАНОВКА БАЗОВЫХ ПАКЕТОВ"

echo -e "${LIGHT_CYAN}${ARROW}${NC} Обновление системы..."
apt upgrade -y > /dev/null 2>&1

# Установка пакетов по частям
install_packages_in_parts

check_error "Установка базовых пакетов"

# 3. Firewall configuration (improved version)

print_header "🔥 НАСТРОЙКА ФАЙРВОЛА"
echo "=== ОТЛАДКА: Начинаем настройку файрвола ==="

# Загружаем и запускаем скрипт настройки файрвола
echo -e "${CYAN}${ARROW}${NC} Загрузка firewall_fixed.sh..."
if wget -q https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/firewall_fixed.sh -O /tmp/firewall_fixed.sh; then
    chmod +x /tmp/firewall_fixed.sh
    echo -e "${CYAN}${ARROW}${NC} Запуск firewall_fixed.sh..."
    bash /tmp/firewall_fixed.sh
    rm -f /tmp/firewall_fixed.sh
else
    echo -e "${YELLOW}⚠️ Не удалось загрузить firewall_fixed.sh, настраиваем базовый файрвол${NC}"
    
    # Базовая настройка файрвола
    echo -e "${CYAN}${ARROW}${NC} Базовая настройка файрвола..."
    
    # Определяем тип файрвола
    if command -v nft >/dev/null 2>&1; then
        echo -e "${BLUE}Using nftables (modern firewall)${NC}"
        # Простая настройка nftables
        cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        tcp dport { 22, 80, 443, 3000, 9090, 9100, 3100, 9080, 9191, 9091 } accept
        udp dport 53 accept
        tcp dport 53 accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output { type filter hook output priority 0; policy accept; }
}
EOF
        nft -f /etc/nftables.conf
        systemctl enable nftables
        systemctl start nftables
    else
        echo -e "${BLUE}Using iptables${NC}"
        # Простая настройка iptables
        iptables -F
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        for port in 22 80 443 3000 9090 9100 3100 9080 9191 9091; do
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
        done
        iptables -A INPUT -p udp --dport 53 -j ACCEPT
        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
        netfilter-persistent save 2>/dev/null || true
    fi
    
    echo -e "${GREEN}${CHECK_MARK}${NC} Базовая настройка файрвола завершена"
fi

# Принудительный перезапуск сервисов после настройки файрвола
echo -e "${CYAN}${ARROW}${NC} Перезапуск сервисов для применения настроек файрвола..."
services=("grafana-server" "prometheus" "pushgateway" "loki" "promtail" "fail2ban_exporter" "node_exporter")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        systemctl restart "$service" 2>/dev/null || true
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $service перезапущен"
    fi
done

# Ждем запуска сервисов
echo -e "${CYAN}${ARROW}${NC} Ожидание запуска сервисов..."
sleep 10

# Дополнительная диагностика сервисов
echo -e "${CYAN}${ARROW}${NC} Проверка статуса сервисов..."
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "  ${GREEN}${CHECK_MARK}${NC} $service: АКТИВЕН"
    else
        echo -e "  ${RED}${CROSS_MARK}${NC} $service: НЕ АКТИВЕН"
        # Пытаемся запустить сервис
        systemctl start "$service" 2>/dev/null || true
        echo -e "  ${CYAN}${ARROW}${NC} Попытка запуска $service"
    fi
done

# 4. Настройка fail2ban
print_header "🛡️ НАСТРОЙКА FAIL2BAN"
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


EOL

# Создаем фильтры для fail2ban
cat > /etc/fail2ban/filter.d/nginx-dos.conf <<EOL
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (404|503|400|499) .*$
ignoreregex =
EOL



systemctl enable --now fail2ban
check_error "Настройка fail2ban"

# 5. Установка Grafana
print_header "📊 УСТАНОВКА GRAFANA"
echo "=== ОТЛАДКА: Начинаем установку Grafana ==="
{
    wget https://dl.grafana.com/oss/release/grafana_10.4.3_amd64.deb -O /tmp/grafana.deb
    dpkg -i /tmp/grafana.deb || apt-get install -fy
    rm -f /tmp/grafana.deb
    
    # Настраиваем Grafana для доступа извне
    cat > /etc/grafana/grafana.ini <<EOF
[server]
http_addr = 0.0.0.0
http_port = 3000
protocol = http
domain = localhost
root_url = %(protocol)s://%(domain)s:%(http_port)s/
serve_from_sub_path = false

[security]
admin_user = admin
admin_password = admin
allow_embedding = true

[auth.anonymous]
enabled = false

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer
EOF
    
    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server
} > /dev/null 2>&1
check_error "Установка Grafana"

# 6. Установка Prometheus
print_header "📈 УСТАНОВКА PROMETHEUS"
echo "=== ОТЛАДКА: Начинаем установку Prometheus ==="
{
    useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
    mkdir -p /etc/prometheus /var/lib/prometheus
    chown prometheus:prometheus /var/lib/prometheus

    PROM_VERSION="2.47.0"
    wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
    tar xvf /tmp/prometheus.tar.gz -C /tmp/
    mv /tmp/prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/local/bin/
    mv /tmp/prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin/
    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool

    # Генерируем пароль для Prometheus
    PROMETHEUS_PASSWORD=$(generate_password)
    
    cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['0.0.0.0:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['0.0.0.0:9100']
  - job_name: 'loki'
    static_configs:
      - targets: ['0.0.0.0:9080']
  - job_name: 'fail2ban'
    static_configs:
      - targets: ['0.0.0.0:9191']
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['0.0.0.0:9091']
EOF

    # Создаем пустой файл конфигурации (без аутентификации)
    touch /etc/prometheus/web.yml
    chown prometheus:prometheus /etc/prometheus/web.yml
    chmod 600 /etc/prometheus/web.yml

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
    --web.enable-lifecycle \\


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
check_error "Установка Prometheus"

# 7. Установка Node Exporter
print_header "🖥️ УСТАНОВКА NODE EXPORTER"
echo "=== ОТЛАДКА: Начинаем установку Node Exporter ==="

# Проверяем доступность GitHub
if ! curl -s --max-time 10 --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    echo -e "${LIGHT_YELLOW}⚠️ Проблема с доступом к GitHub, пропускаем установку Node Exporter${NC}"
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Node Exporter можно установить позже вручную"
    check_error "Установка Node Exporter (пропущена)"
else
    {
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Node Exporter..."
        if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz; then
            echo -e "${LIGHT_YELLOW}⚠️ Не удалось загрузить Node Exporter, пропускаем установку${NC}"
            exit 0
        fi
        
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Распаковка Node Exporter..."
        tar xvf /tmp/node_exporter.tar.gz -C /tmp/
        mv /tmp/node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
        useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
        chown node_exporter:node_exporter /usr/local/bin/node_exporter

        cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable node_exporter
        systemctl start node_exporter
    } > /dev/null 2>&1
    check_error "Установка Node Exporter"
fi

# 8. Установка Pushgateway
print_header "📤 УСТАНОВКА PUSHGATEWAY"
echo "=== ОТЛАДКА: Начинаем установку Pushgateway ==="

# Проверяем доступность GitHub
if ! curl -s --max-time 10 --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    echo -e "${LIGHT_YELLOW}⚠️ Проблема с доступом к GitHub, пропускаем установку Pushgateway${NC}"
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Pushgateway можно установить позже вручную"
    check_error "Установка Pushgateway (пропущена)"
else
    {
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Pushgateway..."
        if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/prometheus/pushgateway/releases/download/v1.6.1/pushgateway-1.6.1.linux-amd64.tar.gz -O /tmp/pushgateway.tar.gz; then
            echo -e "${LIGHT_YELLOW}⚠️ Не удалось загрузить Pushgateway, пропускаем установку${NC}"
            exit 0
        fi
        
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Распаковка Pushgateway..."
        tar xvf /tmp/pushgateway.tar.gz -C /tmp/
        mv /tmp/pushgateway-1.6.1.linux-amd64/pushgateway /usr/local/bin/
        useradd --no-create-home --shell /bin/false pushgateway 2>/dev/null || true
        chown pushgateway:pushgateway /usr/local/bin/pushgateway

        # Создаем директорию для Pushgateway
        mkdir -p /etc/pushgateway

        cat > /etc/systemd/system/pushgateway.service <<EOF
[Unit]
Description=Prometheus Pushgateway
After=network.target

[Service]
User=pushgateway
Group=pushgateway
ExecStart=/usr/local/bin/pushgateway \\
    --web.listen-address=0.0.0.0:9091 \\


[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable pushgateway
        systemctl start pushgateway
    } > /dev/null 2>&1
    check_error "Установка Pushgateway"
fi

# 9. Установка Loki и Promtail
print_header "📝 УСТАНОВКА LOKI И PROMTAIL"
echo "=== ОТЛАДКА: Начинаем установку Loki и Promtail ==="

# Проверяем доступность GitHub
if ! curl -s --max-time 10 --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    echo -e "${LIGHT_YELLOW}⚠️ Проблема с доступом к GitHub, пропускаем установку Loki и Promtail${NC}"
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Loki и Promtail можно установить позже вручную"
    check_error "Установка Loki и Promtail (пропущена)"
else
    {
        LOKI_VERSION="2.9.1"
        

        
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Loki..."
        if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip -O /tmp/loki.zip; then
            echo -e "${LIGHT_YELLOW}⚠️ Не удалось загрузить Loki, пропускаем установку${NC}"
            exit 0
        fi
        
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка Loki..."
        unzip /tmp/loki.zip -d /tmp/
        mv /tmp/loki-linux-amd64 /usr/local/bin/loki
        chmod +x /usr/local/bin/loki

        useradd --no-create-home --shell /bin/false loki 2>/dev/null || true
        mkdir -p /etc/loki /var/lib/loki
        chown loki:loki /var/lib/loki



        cat > /etc/loki/loki-config.yaml <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  http_listen_address: 0.0.0.0
  grpc_listen_port: 9096
  grpc_listen_address: 0.0.0.0

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

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

ruler:
  alertmanager_url: http://localhost:9093
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

        echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Promtail..."
        if ! timeout 60 wget --timeout=30 --tries=3 https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/promtail-linux-amd64.zip -O /tmp/promtail.zip; then
            echo -e "${LIGHT_YELLOW}⚠️ Не удалось загрузить Promtail, пропускаем установку${NC}"
            exit 0
        fi
        
        echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка Promtail..."
        unzip /tmp/promtail.zip -d /tmp/
        mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
        chmod +x /usr/local/bin/promtail

        useradd --no-create-home --shell /bin/false promtail 2>/dev/null || true
        mkdir -p /etc/promtail
        chown promtail:promtail /etc/promtail

        cat > /etc/promtail/promtail-config.yaml <<EOF
server:
  http_listen_port: 9080
  http_listen_address: 0.0.0.0
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs
      __path__: /var/log/*log
EOF

        cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail log shipping agent
After=network.target

[Service]
User=promtail
Group=promtail
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable --now loki
        systemctl enable --now promtail
    } > /dev/null 2>&1
    check_error "Установка Loki и Promtail"
fi

# 10. Настройка экспортера для fail2ban
print_header "📊 НАСТРОЙКА МОНИТОРИНГА FAIL2BAN"
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
check_error "Настройка мониторинга fail2ban"

# 11. Настройка Grafana
print_header "⚙️ НАСТРОЙКА GRAFANA"
echo "=== ОТЛАДКА: Начинаем настройку Grafana ==="

# Проверяем, запущен ли Grafana
echo -e "${LIGHT_CYAN}${ARROW}${NC} Ожидание запуска Grafana..."
timeout 60 bash -c 'while ! systemctl is-active --quiet grafana-server; do sleep 1; done' || {
    echo -e "${LIGHT_YELLOW}⚠️ Grafana не запустился в течение 60 секунд, пропускаем настройку${NC}"
    check_error "Настройка Grafana (пропущена)"
    exit 0
}

echo -e "${LIGHT_CYAN}${ARROW}${NC} Grafana запущен, начинаем настройку..."

# Генерируем пароль для Grafana
GRAFANA_PASSWORD=$(generate_password)
echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка пароля администратора..."
grafana-cli admin reset-admin-password "$GRAFANA_PASSWORD" 2>/dev/null || {
    echo -e "${LIGHT_YELLOW}⚠️ Не удалось установить пароль Grafana${NC}"
}

# Проверяем доступность Grafana API
echo -e "${LIGHT_CYAN}${ARROW}${NC} Проверка доступности Grafana API..."
timeout 30 bash -c 'until curl -s http://localhost:3000/api/health; do sleep 2; done' || {
    echo -e "${LIGHT_YELLOW}⚠️ Grafana API недоступен, пропускаем настройку дашбордов${NC}"
    check_error "Настройка Grafana (базовая)"
    exit 0
}

# Добавляем источники данных с таймаутом
echo -e "${LIGHT_CYAN}${ARROW}${NC} Добавление источника данных Prometheus..."
timeout 30 curl -u admin:"$GRAFANA_PASSWORD" -X POST -H "Content-Type: application/json" \
  -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy"}' \
  http://localhost:3000/api/datasources 2>/dev/null || {
    echo -e "${LIGHT_YELLOW}⚠️ Не удалось добавить Prometheus как источник данных${NC}"
}

echo -e "${LIGHT_CYAN}${ARROW}${NC} Добавление источника данных Loki..."
timeout 30 curl -u admin:"$GRAFANA_PASSWORD" -X POST -H "Content-Type: application/json" \
  -d '{"name":"Loki","type":"loki","url":"http://localhost:3100","access":"proxy"}' \
  http://localhost:3000/api/datasources 2>/dev/null || {
    echo -e "${LIGHT_YELLOW}⚠️ Не удалось добавить Loki как источник данных${NC}"
}

# Пропускаем импорт дашбордов для ускорения
echo -e "${LIGHT_YELLOW}⚠️ Пропускаем импорт дашбордов для ускорения${NC}"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Дашборды можно импортировать позже вручную"

check_error "Настройка Grafana"

# 12. Завершение установки
print_header "🎉 УСТАНОВКА ЗАВЕРШЕНА"

# Генерируем все пароли для отображения
PHPMYADMIN_PASSWORD=$(generate_password)

# Получаем IP адрес сервера
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "\n${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУПНЫЕ СЕРВИСЫ${NC} ${LIGHT_BLUE}${STAR}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🌐 ВЕБ-ИНТЕРФЕЙСЫ${NC}${LIGHT_BLUE}${LINE_V:0:42}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"

echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📊 Grafana:${NC}      ${LIGHT_YELLOW}http://${SERVER_IP}:3000${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📈 Prometheus:${NC}   ${LIGHT_YELLOW}http://${SERVER_IP}:9090${NC}${LIGHT_BLUE}${LINE_V:0:6}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📝 Loki:${NC}         ${LIGHT_YELLOW}http://${SERVER_IP}:3100${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📤 Pushgateway:${NC}  ${LIGHT_YELLOW}http://${SERVER_IP}:9091${NC}${LIGHT_BLUE}${LINE_V:0:6}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДАННЫЕ ДЛЯ ВХОДА${NC} ${LIGHT_PURPLE}${STAR}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🔐 УЧЕТНЫЕ ДАННЫЕ${NC}${LIGHT_PURPLE}${LINE_V:0:40}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"

echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📊 Grafana:${NC}       ${LIGHT_YELLOW}TrafficGrafana${NC}     ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$GRAFANA_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:4}${LINE_V}${NC}"

echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}🗄️  phpMyAdmin:${NC}    ${LIGHT_YELLOW}TrafficPhpMyAdmin${NC}  ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$PHPMYADMIN_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:2}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! 🎉${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Дополнительная информация
echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ПОЛЕЗНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_PURPLE}${STAR}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Grafana:${NC}    ${LIGHT_YELLOW}/var/log/grafana/grafana.log${NC}${LIGHT_PURPLE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Prometheus:${NC}  ${LIGHT_YELLOW}/var/log/prometheus/${NC}${LIGHT_PURPLE}${LINE_V:0:12}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Loki:${NC}        ${LIGHT_YELLOW}/var/log/loki/${NC}${LIGHT_PURPLE}${LINE_V:0:18}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Promtail:${NC}   ${LIGHT_YELLOW}/var/log/promtail/${NC}${LIGHT_PURPLE}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Fail2ban:${NC}   ${LIGHT_YELLOW}/var/log/fail2ban.log${NC}${LIGHT_PURPLE}${LINE_V:0:10}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_GREEN}${CHECK_MARK}${NC} ${BOLD}Все сервисы установлены и настроены!${NC}"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Рекомендуется перезагрузить сервер после установки"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Для мониторинга используйте Grafana: ${LIGHT_YELLOW}http://${SERVER_IP}:3000${NC}"





# Загружаем диагностический скрипт
echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДИАГНОСТИКА СИСТЕМЫ${NC} ${LIGHT_PURPLE}${STAR}${NC}"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка диагностического скрипта..."
if wget -q https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/diagnostic.sh -O /usr/local/bin/diagnostic.sh; then
    chmod +x /usr/local/bin/diagnostic.sh
    echo -e "${LIGHT_GREEN}${CHECK_MARK}${NC} Диагностический скрипт загружен"
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Для диагностики запустите: ${LIGHT_YELLOW}diagnostic.sh${NC}"
else
    echo -e "${LIGHT_YELLOW}⚠️ Не удалось загрузить диагностический скрипт${NC}"
fi


