#!/bin/bash

# Скрипт для исправления проблем с установкой Composer
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔧 ИСПРАВЛЕНИЕ УСТАНОВКИ COMPOSER${NC}"
echo "================================================"

# Проверка прав root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}❌ Этот скрипт должен быть запущен от имени root${NC}"
    exit 1
fi

# Функция проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ [ОШИБКА] $1${NC}"
        return 1
    else
        echo -e "${GREEN}✅ [OK] $1${NC}"
        return 0
    fi
}

# Функция выполнения команд с таймаутом
run_with_timeout() {
    local timeout=$1
    local description="$2"
    shift 2
    
    echo -e "${CYAN}Выполнение: $description (таймаут: ${timeout}с)${NC}"
    
    if timeout "$timeout" bash -c "$*"; then
        echo -e "${GREEN}✅ $description завершено успешно${NC}"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            echo -e "${RED}❌ $description превысил лимит времени ${timeout}с${NC}"
        else
            echo -e "${RED}❌ $description завершился с кодом $exit_code${NC}"
        fi
        return $exit_code
    fi
}

echo -e "\n${CYAN}1. Проверка текущего состояния Composer...${NC}"

# Проверяем, установлен ли уже Composer
if command -v composer >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Composer уже установлен${NC}"
    composer --version
    echo -e "${BLUE}Версия: $(composer --version | head -1)${NC}"
    exit 0
fi

echo -e "\n${CYAN}2. Проверка PHP...${NC}"

# Проверяем PHP
if ! command -v php >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ PHP не установлен. Устанавливаем...${NC}"
    
    # Останавливаем зависшие процессы APT
    pkill -f apt 2>/dev/null || true
    pkill -f dpkg 2>/dev/null || true
    sleep 3
    
    # Очищаем блокировки
    rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
    rm -f /var/lib/dpkg/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    
    # Восстанавливаем пакеты
    dpkg --configure -a 2>/dev/null || true
    
    # Устанавливаем PHP с таймаутом
    run_with_timeout 600 "Установка PHP" '
        export DEBIAN_FRONTEND=noninteractive
        apt update
        apt install -y php-cli php-mbstring php-xml php-zip php-curl php-gd php-mysql php-fpm
    '
    check_error "Установка PHP"
else
    echo -e "${GREEN}✅ PHP установлен${NC}"
    php --version | head -1
fi

echo -e "\n${CYAN}3. Альтернативная установка Composer...${NC}"

# Метод 1: Прямая загрузка с таймаутом
echo -e "${BLUE}Попытка 1: Прямая загрузка Composer...${NC}"
if run_with_timeout 300 "Загрузка Composer" '
    curl -sS --connect-timeout 30 --max-time 300 https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
'; then
    echo -e "${GREEN}✅ Composer установлен успешно${NC}"
else
    echo -e "${YELLOW}⚠️ Первый метод не сработал. Попытка 2...${NC}"
    
    # Метод 2: Загрузка через wget
    echo -e "${BLUE}Попытка 2: Загрузка через wget...${NC}"
    if run_with_timeout 300 "Загрузка Composer через wget" '
        wget --timeout=30 --tries=3 -O composer-setup.php https://getcomposer.org/installer
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm composer-setup.php
    '; then
        echo -e "${GREEN}✅ Composer установлен успешно${NC}"
    else
        echo -e "${YELLOW}⚠️ Второй метод не сработал. Попытка 3...${NC}"
        
        # Метод 3: Ручная установка
        echo -e "${BLUE}Попытка 3: Ручная установка...${NC}"
        if run_with_timeout 300 "Ручная установка Composer" '
            # Создаем временную директорию
            mkdir -p /tmp/composer_install
            cd /tmp/composer_install
            
            # Загружаем установщик
            wget --timeout=30 --tries=3 -O composer-setup.php https://getcomposer.org/installer
            
            # Проверяем загрузку
            if [ -f composer-setup.php ]; then
                php composer-setup.php --install-dir=/usr/local/bin --filename=composer
                rm composer-setup.php
            else
                echo "Ошибка загрузки composer-setup.php"
                exit 1
            fi
            
            cd /
            rm -rf /tmp/composer_install
        '; then
            echo -e "${GREEN}✅ Composer установлен успешно${NC}"
        else
            echo -e "${RED}❌ Все методы установки Composer не сработали${NC}"
            echo -e "${YELLOW}Рекомендации:${NC}"
            echo -e "  • Проверьте интернет соединение"
            echo -e "  • Попробуйте установить Composer вручную"
            echo -e "  • Проверьте настройки файрвола"
            exit 1
        fi
    fi
fi

echo -e "\n${CYAN}4. Проверка установки Composer...${NC}"

# Проверяем установку
if command -v composer >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Composer установлен и доступен${NC}"
    composer --version
    echo -e "${BLUE}Путь: $(which composer)${NC}"
    
    # Тестируем Composer
    echo -e "\n${CYAN}5. Тестирование Composer...${NC}"
    if run_with_timeout 60 "Тест Composer" 'composer --version'; then
        echo -e "${GREEN}✅ Composer работает корректно${NC}"
    else
        echo -e "${YELLOW}⚠️ Composer установлен, но есть проблемы с запуском${NC}"
    fi
else
    echo -e "${RED}❌ Composer не найден после установки${NC}"
    exit 1
fi

echo -e "\n${BLUE}================================================"
echo -e "${GREEN}🎉 УСТАНОВКА COMPOSER ЗАВЕРШЕНА${NC}"
echo -e "${CYAN}Теперь можно продолжить установку основного скрипта${NC}"
