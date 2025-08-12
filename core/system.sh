#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/utils.sh"

# Функция восстановления состояния системы
restore_system_state() {
    log_message "INFO" "Восстановление состояния системы..."
    
    # Завершаем зависшие процессы apt/dpkg
    log_message "INFO" "Завершение зависших процессов..."
    pkill -f "apt" 2>/dev/null || true
    pkill -f "dpkg" 2>/dev/null || true
    pkill -f "apt-get" 2>/dev/null || true
    
    # Удаляем блокирующие файлы
    log_message "INFO" "Удаление блокирующих файлов..."
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/dpkg/lock* 2>/dev/null || true
    rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
    
    # Восстанавливаем состояние dpkg
    log_message "INFO" "Восстановление состояния dpkg..."
    dpkg --configure -a 2>/dev/null || true
    
    # Очищаем кэш apt
    log_message "INFO" "Очистка кэша apt..."
    apt clean 2>/dev/null || true
    apt autoclean 2>/dev/null || true
    
    # Обновляем список пакетов
    log_message "INFO" "Обновление списка пакетов..."
    apt update 2>/dev/null || true
    
    log_message "SUCCESS" "Состояние системы восстановлено"
}

# Функция установки пакетов по частям
install_packages_in_parts() {
    log_message "INFO" "Установка базовых пакетов по частям..."
    
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
    
    log_message "SUCCESS" "Все базовые пакеты установлены успешно"
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
        log_message "WARNING" "Отсутствуют зависимости: ${missing[*]}"
        log_message "INFO" "Устанавливаем недостающие зависимости..."
        
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
                    log_message "WARNING" "systemctl не найден - проверьте установку systemd"
                    ;;
                "apt")
                    log_message "ERROR" "apt не найден - это критическая ошибка"
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
            log_message "ERROR" "Не удалось установить: ${still_missing[*]}"
            log_message "INFO" "Попробуйте установить вручную: apt install ${still_missing[*]}"
            exit 1
        else
            log_message "SUCCESS" "Все зависимости установлены успешно"
        fi
    else
        log_message "SUCCESS" "Все необходимые зависимости найдены"
    fi
}

# Функция безопасной установки пакетов
safe_install() {
    local packages="$1"
    local description="$2"
    
    log_message "INFO" "safe_install() - $description"
    log_message "INFO" "Пакеты: $packages"
    
    # Попытка установки
    if apt install -y $packages 2>/dev/null; then
        log_message "SUCCESS" "$description завершена успешно"
        return 0
    else
        log_message "WARNING" "Ошибка установки $description, восстанавливаем состояние..."
        restore_system_state
        
        # Повторная попытка
        if apt install -y $packages; then
            log_message "SUCCESS" "$description завершена успешно после восстановления"
            return 0
        else
            log_message "ERROR" "Критическая ошибка установки $description"
            return 1
        fi
    fi
}

# Функция очистки системы
cleanup_system() {
    print_header "🧹 ОЧИСТКА СИСТЕМЫ"
    
    log_message "INFO" "Остановка и удаление старых сервисов..."
    {
        systemctl stop grafana-server 2>/dev/null || true
        apt purge -y grafana* 2>/dev/null || true
        rm -rf /etc/apt/sources.list.d/grafana* /usr/share/keyrings/grafana.gpg
        apt autoremove -y
        apt update
    } > /dev/null 2>&1
    
    # Установка временной зоны
    timedatectl set-timezone Europe/Minsk
    
    log_message "SUCCESS" "Система очищена"
}

# Функция обновления системы
update_system() {
    print_header "📦 ОБНОВЛЕНИЕ СИСТЕМЫ"
    
    log_message "INFO" "Обновление системы..."
    apt upgrade -y > /dev/null 2>&1
    
    # Установка пакетов по частям
    install_packages_in_parts
    
    check_error "Обновление системы"
}

# Функция проверки и настройки сервисов
check_and_restart_services() {
    local services=("grafana-server" "prometheus" "pushgateway" "loki" "promtail" "fail2ban_exporter" "node_exporter")
    
    log_message "INFO" "Перезапуск сервисов для применения настроек..."
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl restart "$service" 2>/dev/null || true
            log_message "SUCCESS" "$service перезапущен"
        fi
    done
    
    # Ждем запуска сервисов
    log_message "INFO" "Ожидание запуска сервисов..."
    sleep 10
    
    # Дополнительная диагностика сервисов
    log_message "INFO" "Проверка статуса сервисов..."
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "SUCCESS" "$service: АКТИВЕН"
        else
            log_message "WARNING" "$service: НЕ АКТИВЕН"
            # Пытаемся запустить сервис
            systemctl start "$service" 2>/dev/null || true
            log_message "INFO" "Попытка запуска $service"
        fi
    done
}
