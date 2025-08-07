#!/bin/bash

# ============================================================================
# Traffic Connect - Установка с нуля с автоматическим исправлением dpkg
# ============================================================================

echo "🚀 Установка Traffic Connect Server с нуля"
echo "================================================"

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Функция для исправления блокировок dpkg
fix_dpkg_locks() {
    echo "🔧 Проверка и исправление блокировок dpkg..."
    
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

# Функция для проверки и исправления dpkg
check_and_fix_dpkg() {
    echo "🔍 Проверка состояния dpkg..."
    
    # Проверка, работает ли dpkg
    if ! dpkg -l >/dev/null 2>&1; then
        echo "❌ Проблемы с dpkg, исправляем..."
        fix_dpkg_locks
        
        # Повторная проверка
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
    fix_dpkg_locks
    apt update
fi

if ! apt upgrade -y; then
    echo "❌ Ошибка обновления системы, исправляем..."
    fix_dpkg_locks
    apt upgrade -y
fi

# 3. Установка базовых пакетов
echo "📦 Шаг 3: Установка базовых пакетов..."
if ! apt install -y git curl wget; then
    echo "❌ Ошибка установки базовых пакетов, исправляем..."
    fix_dpkg_locks
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

if [ ! -f "install.sh" ]; then
    echo "❌ Файл install.sh не найден"
    exit 1
fi

echo "✅ Проект успешно клонирован"

# 6. Настройка прав
echo "🔐 Шаг 6: Настройка прав доступа..."
chmod +x install.sh install_monitoring_only.sh fix_ssl_timeout.sh show_credentials.sh fix_hestia_composer.sh fix_dpkg_lock.sh install_hestia_only.sh 2>/dev/null || true

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

# Запуск основного скрипта установки
if ./install.sh; then
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
    echo "📚 Дополнительные команды:"
    echo "  • Просмотр паролей: ./show_credentials.sh"
    echo "  • Исправление SSL: ./fix_ssl_timeout.sh"
    echo "  • Исправление Composer: ./fix_hestia_composer.sh"
    echo "  • Исправление dpkg: ./fix_dpkg_lock.sh"
else
    echo ""
    echo "❌ УСТАНОВКА ЗАВЕРШИЛАСЬ С ОШИБКАМИ"
    echo "================================================"
    echo ""
    echo "🔧 Рекомендации по исправлению:"
    echo "  • Проверьте логи установки выше"
    echo "  • Запустите исправление dpkg: ./fix_dpkg_lock.sh"
    echo "  • Запустите исправление Composer: ./fix_hestia_composer.sh"
    echo "  • Попробуйте установку только HestiaCP: ./install_hestia_only.sh"
    echo "  • Перезагрузите сервер: reboot"
    exit 1
fi
