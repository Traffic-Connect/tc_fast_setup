#!/bin/bash
set -e

# Отладочная информация
echo "=== ОТЛАДКА: Скрипт запущен ==="
echo "Время: $(date)"
echo "PID: $$"
echo "Пользователь: $(whoami)"
echo "Директория: $(pwd)"
echo "================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Символы
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="->"

# Функция восстановления состояния системы
restore_system_state() {
    echo "=== ОТЛАДКА: Функция restore_system_state() ==="
    echo -e "${CYAN}${ARROW}${NC} Восстановление состояния системы..."
    
    # Завершаем зависшие процессы apt/dpkg
    echo -e "${CYAN}${ARROW}${NC} Завершение зависших процессов..."
    pkill -f "apt" 2>/dev/null || true
    pkill -f "dpkg" 2>/dev/null || true
    pkill -f "apt-get" 2>/dev/null || true
    
    # Удаляем блокирующие файлы
    echo -e "${CYAN}${ARROW}${NC} Удаление блокирующих файлов..."
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/dpkg/lock* 2>/dev/null || true
    rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
    
    # Восстанавливаем состояние dpkg
    echo -e "${CYAN}${ARROW}${NC} Восстановление состояния dpkg..."
    dpkg --configure -a 2>/dev/null || true
    
    # Очищаем кэш apt
    echo -e "${CYAN}${ARROW}${NC} Очистка кэша apt..."
    apt clean 2>/dev/null || true
    apt autoclean 2>/dev/null || true
    
    # Обновляем список пакетов
    echo -e "${CYAN}${ARROW}${NC} Обновление списка пакетов..."
    apt update 2>/dev/null || true
    
    echo -e "${GREEN}${CHECK_MARK}${NC} Состояние системы восстановлено"
}

# Функция безопасной установки пакетов
safe_install() {
    local packages="$1"
    local description="$2"
    
    echo "=== ОТЛАДКА: safe_install() - $description ==="
    echo "Пакеты: $packages"
    echo -e "${CYAN}${ARROW}${NC} $description..."
    
    # Попытка установки
    if apt install -y $packages 2>/dev/null; then
        echo -e "${GREEN}${CHECK_MARK}${NC} $description завершена успешно"
        return 0
    else
        echo -e "${YELLOW}⚠️ Ошибка установки $description, восстанавливаем состояние...${NC}"
        restore_system_state
        
        # Повторная попытка
        if apt install -y $packages; then
            echo -e "${GREEN}${CHECK_MARK}${NC} $description завершена успешно после восстановления"
            return 0
        else
            echo -e "${RED}${CROSS_MARK}${NC} Критическая ошибка установки $description"
            return 1
        fi
    fi
}

# Функция установки пакетов по частям
install_packages_in_parts() {
    echo "=== ОТЛАДКА: Функция install_packages_in_parts() ==="
    echo -e "${CYAN}${ARROW}${NC} Установка базовых пакетов по частям..."
    
    # Часть 1: Основные утилиты
    safe_install "curl wget git nano htop" "Часть 1/5: Основные утилиты"
    
    # Часть 2: Сетевые утилиты
    safe_install "fail2ban iptables-persistent netfilter-persistent nftables" "Часть 2/5: Сетевые утилиты"
    
    # Часть 3: Python и связанные пакеты
    safe_install "software-properties-common apt-transport-https python3 python3-pip python3-venv" "Часть 3/5: Python и связанные пакеты"
    
    # Часть 4: Дополнительные утилиты
    safe_install "gnupg2 ca-certificates adduser libfontconfig1 unzip ncdu" "Часть 4/5: Дополнительные утилиты"
    
    # Часть 5: PHP зависимости (для Composer)
    safe_install "php-cli php-mbstring php-xml php-zip php-curl php-gd php-mysql php-fpm" "Часть 5/5: PHP зависимости"
    
    echo -e "${GREEN}${CHECK_MARK}${NC} Все базовые пакеты установлены успешно"
}

# Проверка root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}${CROSS_MARK} Этот скрипт должен быть запущен от имени root${NC}" 1>&2
    exit 1
fi

echo "=== ОТЛАДКА: Проверка root пройдена ==="

# 0. Восстановление состояния системы
echo "=== ОТЛАДКА: Начинаем восстановление состояния ==="
restore_system_state

# 1. Установка базовых пакетов
echo "=== ОТЛАДКА: Начинаем установку пакетов ==="
install_packages_in_parts

echo "=== ОТЛАДКА: Скрипт завершен успешно ==="
echo "Время завершения: $(date)"
