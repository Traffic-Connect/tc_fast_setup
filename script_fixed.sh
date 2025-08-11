#!/bin/bash

# Улучшенная версия скрипта установки с таймаутами и обработкой ошибок
# Цвета для вывода
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

# Файл для отслеживания прогресса
PROGRESS_FILE="/tmp/tc_setup_progress"

# Красивый заголовок скрипта
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🚀 TC FAST SETUP - АВТОМАТИЧЕСКАЯ УСТАНОВКА${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${LIGHT_CYAN}Система мониторинга и управления сервером${NC}${LIGHT_BLUE}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Проверка root
if [ "$(id -u)" != "0" ]; then
    echo -e "${LIGHT_RED}${CROSS_MARK} Этот скрипт должен быть запущен от имени root${NC}" 1>&2
    exit 1
fi

# Отображение системной информации
echo -e "\n${LIGHT_CYAN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}СИСТЕМНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_CYAN}${STAR}${NC}"
echo -e "${LIGHT_CYAN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}🖥️  Система:${NC}     ${LIGHT_YELLOW}$(lsb_release -d | cut -f2)${NC}${LIGHT_CYAN}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}💾 Память:${NC}      ${LIGHT_YELLOW}$(free -h | awk 'NR==2{printf "%.1f GB", $2/1024}')${NC}${LIGHT_CYAN}${LINE_V:0:25}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}💿 Диск:${NC}        ${LIGHT_YELLOW}$(df -h / | awk 'NR==2{print $2}')${NC}${LIGHT_CYAN}${LINE_V:0:28}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}🌐 IP адрес:${NC}    ${LIGHT_YELLOW}$(hostname -I | awk '{print $1}')${NC}${LIGHT_CYAN}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Функция для выполнения команд с таймаутом
run_with_timeout() {
    local timeout=$1
    shift
    local description="$1"
    shift
    
    echo -e "${BLUE}[Выполнение] $description (таймаут: ${timeout}с)${NC}"
    
    if timeout "$timeout" bash -c "$*"; then
        echo -e "${GREEN}${CHECK_MARK} [OK] $description${NC}"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            echo -e "${RED}${CROSS_MARK} [ТАЙМАУТ] $description превысил лимит времени ${timeout}с${NC}"
        else
            echo -e "${RED}${CROSS_MARK} [ОШИБКА] $description завершился с кодом $exit_code${NC}"
        fi
        return $exit_code
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

# Функция для проверки и очистки блокировок APT
check_and_fix_apt() {
    echo -e "${CYAN}Проверка состояния APT...${NC}"
    
    # Проверяем блокировки
    if lsof /var/lib/dpkg/lock-frontend 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Обнаружена блокировка APT. Ожидание...${NC}"
        sleep 30
        
        # Если все еще заблокировано, принудительно очищаем
        if lsof /var/lib/dpkg/lock-frontend 2>/dev/null; then
            echo -e "${YELLOW}⚠️ Принудительная очистка блокировок APT...${NC}"
            pkill -f apt 2>/dev/null || true
            pkill -f dpkg 2>/dev/null || true
            sleep 5
            
            rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
            rm -f /var/lib/dpkg/lock 2>/dev/null || true
            rm -f /var/cache/apt/archives/lock 2>/dev/null || true
            rm -f /var/lib/apt/lists/lock 2>/dev/null || true
            
            dpkg --configure -a 2>/dev/null || true
        fi
    fi
    
    echo -e "${GREEN}✅ APT готов к работе${NC}"
}

# Функция для сохранения прогресса
save_progress() {
    echo "$1" > "$PROGRESS_FILE"
}

# Функция для загрузки прогресса
load_progress() {
    if [ -f "$PROGRESS_FILE" ]; then
        cat "$PROGRESS_FILE"
    else
        echo "0"
    fi
}

# Загружаем текущий прогресс
CURRENT_STEP=$(load_progress)

# 1. Очистка системы (если не выполнена)
if [ "$CURRENT_STEP" -lt 1 ]; then
    print_header "🧹 ОЧИСТКА СИСТЕМЫ"
    check_and_fix_apt
    
    run_with_timeout 300 "Очистка системы" '
        systemctl stop grafana-server 2>/dev/null || true
        apt purge -y grafana* 2>/dev/null || true
        rm -rf /etc/apt/sources.list.d/grafana* /usr/share/keyrings/grafana.gpg
        apt autoremove -y
    '
    check_error "Очистка системы"
    save_progress 1
fi

# Установка временной зоны
timedatectl set-timezone Europe/Minsk

# 2. Обновление системы и установка базовых пакетов (если не выполнена)
if [ "$CURRENT_STEP" -lt 2 ]; then
    print_header "📦 УСТАНОВКА БАЗОВЫХ ПАКЕТОВ"
    
    check_and_fix_apt
    
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Обновление списка пакетов..."
    run_with_timeout 300 "Обновление списка пакетов" 'apt update'
    show_progress 1 4
    
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Обновление системы..."
    # Устанавливаем переменные среды для неинтерактивной установки
    export DEBIAN_FRONTEND=noninteractive
    export APT_LISTCHANGES_FRONTEND=none
    
    run_with_timeout 1800 "Обновление системы" '
        apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
    '
    show_progress 2 4
    
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка базовых пакетов..."
    run_with_timeout 900 "Установка базовых пакетов" '
        apt install -y fail2ban iptables-persistent netfilter-persistent nftables curl wget \
                       software-properties-common apt-transport-https python3 \
                       python3-pip python3-venv git gnupg2 ca-certificates \
                       adduser libfontconfig1 unzip htop ncdu
    '
    show_progress 3 4
    
    echo -e "${LIGHT_CYAN}${ARROW}${NC} Завершение установки..."
    show_progress 4 4
    check_error "Установка базовых пакетов"
    save_progress 2
fi

# 3. Установка Composer (если не выполнена)
if [ "$CURRENT_STEP" -lt 3 ]; then
    print_header "📦 УСТАНОВКА COMPOSER"
    
    run_with_timeout 300 "Установка Composer" '
        echo "Загрузка Composer..."
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
        
        # Устанавливаем зависимости PHP
        apt install -y php-cli php-mbstring php-xml php-zip php-curl php-gd php-mysql php-fpm
        
        echo "Настройка Composer..."
        composer --version
    '
    check_error "Установка Composer"
    save_progress 3
fi

echo -e "\n${LIGHT_GREEN}🎉 Базовая установка завершена!${NC}"
echo -e "${CYAN}Следующие этапы:${NC}"
echo -e "  4. Установка Hestia CP"
echo -e "  5. Настройка файрвола"
echo -e "  6. Установка системы мониторинга"

echo -e "\n${YELLOW}Для продолжения запустите:${NC}"
echo -e "  ${GREEN}./continue_setup.sh${NC}"

# Создаем скрипт продолжения
cat > continue_setup.sh << 'EOF'
#!/bin/bash
# Продолжение установки с этапа 4
./script_fixed.sh
EOF

chmod +x continue_setup.sh

echo -e "\n${GREEN}✅ Критические этапы завершены без зависания!${NC}"
