#!/bin/bash

# ============================================================================
# Traffic Connect - Исправление проблем с блокировкой dpkg
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

echo "🔧 Исправление проблем с блокировкой dpkg"
echo "================================================"

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
    echo "❌ Этот скрипт должен быть запущен с правами root"
    exit 1
fi

echo "🔍 Проверка блокировок dpkg..."

# Проверка активных процессов apt
echo "📋 Активные процессы apt:"
ps aux | grep -E "(apt|dpkg)" | grep -v grep

# Проверка файлов блокировок
echo ""
echo "🔒 Файлы блокировок:"
ls -la /var/lib/dpkg/lock* 2>/dev/null || echo "Файлы блокировок не найдены"
ls -la /var/cache/apt/archives/lock 2>/dev/null || echo "Кэш блокировка не найдена"

# Функция для безопасного удаления блокировок
remove_locks() {
    echo ""
    echo "🛠️ Удаление блокировок dpkg..."
    
    # Остановка процессов apt если они зависли
    echo "🛑 Остановка зависших процессов apt..."
    pkill -f "apt-get" 2>/dev/null || true
    pkill -f "apt" 2>/dev/null || true
    pkill -f "dpkg" 2>/dev/null || true
    
    # Ждем завершения процессов
    echo "⏳ Ожидание завершения процессов..."
    sleep 5
    
    # Удаление файлов блокировок
    echo "🗑️ Удаление файлов блокировок..."
    
    if [ -f "/var/lib/dpkg/lock" ]; then
        rm -f /var/lib/dpkg/lock
        echo "✅ Удален /var/lib/dpkg/lock"
    fi
    
    if [ -f "/var/lib/dpkg/lock-frontend" ]; then
        rm -f /var/lib/dpkg/lock-frontend
        echo "✅ Удален /var/lib/dpkg/lock-frontend"
    fi
    
    if [ -f "/var/lib/apt/lists/lock" ]; then
        rm -f /var/lib/apt/lists/lock
        echo "✅ Удален /var/lib/apt/lists/lock"
    fi
    
    if [ -f "/var/cache/apt/archives/lock" ]; then
        rm -f /var/cache/apt/archives/lock
        echo "✅ Удален /var/cache/apt/archives/lock"
    fi
    
    if [ -f "/var/lib/dpkg/info/format-new" ]; then
        rm -f /var/lib/dpkg/info/format-new
        echo "✅ Удален /var/lib/dpkg/info/format-new"
    fi
}

# Функция для исправления прерванной установки dpkg
fix_dpkg() {
    echo ""
    echo "🔧 Исправление прерванной установки dpkg..."
    
    # Проверка состояния dpkg
    echo "📊 Проверка состояния dpkg..."
    dpkg --audit 2>/dev/null || echo "dpkg --audit не выполнился"
    
    # Исправление прерванной установки
    echo "🛠️ Исправление прерванной установки..."
    dpkg --configure -a
    
    # Установка недостающих пакетов
    echo "📦 Установка недостающих пакетов..."
    apt-get install -f -y
    
    # Обновление списков пакетов
    echo "🔄 Обновление списков пакетов..."
    apt-get update
}

# Функция для проверки и исправления базы данных dpkg
fix_dpkg_database() {
    echo ""
    echo "🗄️ Проверка базы данных dpkg..."
    
    # Проверка целостности базы данных
    if dpkg -C 2>/dev/null; then
        echo "⚠️ Обнаружены проблемы в базе данных dpkg"
        echo "🛠️ Исправление базы данных..."
        
        # Резервное копирование
        echo "💾 Создание резервной копии..."
        cp -r /var/lib/dpkg /var/lib/dpkg.backup.$(date +%Y%m%d_%H%M%S)
        
        # Восстановление базы данных
        echo "🔧 Восстановление базы данных..."
        dpkg --clear-avail
        apt-get update
    else
        echo "✅ База данных dpkg в порядке"
    fi
}

# Основная логика
echo ""
echo "🤔 Выберите действие:"
echo "1) Автоматическое исправление (рекомендуется)"
echo "2) Только удаление блокировок"
echo "3) Только исправление dpkg"
echo "4) Проверка состояния"

read -p "Введите номер (1-4): " choice

case $choice in
    1)
        echo "🚀 Запуск автоматического исправления..."
        remove_locks
        fix_dpkg
        fix_dpkg_database
        ;;
    2)
        echo "🗑️ Удаление только блокировок..."
        remove_locks
        ;;
    3)
        echo "🔧 Исправление только dpkg..."
        fix_dpkg
        fix_dpkg_database
        ;;
    4)
        echo "📊 Проверка состояния..."
        echo "Активные процессы apt:"
        ps aux | grep -E "(apt|dpkg)" | grep -v grep
        echo ""
        echo "Файлы блокировок:"
        ls -la /var/lib/dpkg/lock* 2>/dev/null || echo "Файлы блокировок не найдены"
        ;;
    *)
        echo "❌ Неверный выбор. Запуск автоматического исправления..."
        remove_locks
        fix_dpkg
        fix_dpkg_database
        ;;
esac

# Финальная проверка
echo ""
echo "✅ Проверка результата..."

# Проверка, что блокировки удалены
if [ ! -f "/var/lib/dpkg/lock" ] && [ ! -f "/var/lib/dpkg/lock-frontend" ]; then
    echo "✅ Блокировки dpkg удалены"
else
    echo "❌ Блокировки dpkg все еще существуют"
fi

# Проверка состояния dpkg
if dpkg -l >/dev/null 2>&1; then
    echo "✅ dpkg работает корректно"
else
    echo "❌ Проблемы с dpkg остались"
fi

# Тест обновления
echo "🧪 Тест обновления списков пакетов..."
if apt-get update >/dev/null 2>&1; then
    echo "✅ apt-get update работает"
else
    echo "❌ apt-get update не работает"
fi

echo ""
echo "🎉 Исправление завершено!"
echo ""
echo "📋 Рекомендации:"
echo "  • Если проблемы остались, перезагрузите сервер: reboot"
echo "  • Для установки пакетов используйте: apt-get install -y <пакет>"
echo "  • Для обновления системы: apt-get update && apt-get upgrade -y"
echo ""
echo "🔧 Если нужно продолжить установку HestiaCP:"
echo "  cd ~/tc_fast_setup && ./install_hestia_only.sh"
