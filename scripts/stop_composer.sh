#!/bin/bash
# ============================================================================
# Экстренная остановка зависших процессов Composer
# ============================================================================

echo "🛑 ОСТАНОВКА ЗАВИСШИХ ПРОЦЕССОВ COMPOSER"
echo "================================================"

# Поиск процессов Composer
echo "Поиск процессов Composer..."
composer_pids=$(pgrep -f "composer\|v-add-user-composer\|hst-install" 2>/dev/null)

if [ -n "$composer_pids" ]; then
    echo "Найдены процессы:"
    ps aux | grep -E "(composer|v-add-user-composer|hst-install)" | grep -v grep
    
    echo ""
    echo "Останавливаем процессы..."
    
    # Graceful остановка
    for pid in $composer_pids; do
        echo "Отправка SIGTERM процессу $pid..."
        kill -TERM "$pid" 2>/dev/null
    done
    
    # Ждем 10 секунд
    echo "Ожидание graceful завершения (10 сек)..."
    sleep 10
    
    # Проверяем, остались ли процессы
    composer_pids=$(pgrep -f "composer\|v-add-user-composer\|hst-install" 2>/dev/null)
    
    if [ -n "$composer_pids" ]; then
        echo "Принудительная остановка оставшихся процессов..."
        
        for pid in $composer_pids; do
            echo "Отправка SIGKILL процессу $pid..."
            kill -KILL "$pid" 2>/dev/null
        done
        
        sleep 2
        
        # Финальная проверка
        composer_pids=$(pgrep -f "composer\|v-add-user-composer\|hst-install" 2>/dev/null)
        if [ -n "$composer_pids" ]; then
            echo "❌ Не удалось остановить процессы: $composer_pids"
        else
            echo "✅ Все процессы остановлены"
        fi
    else
        echo "✅ Все процессы остановлены gracefully"
    fi
else
    echo "✅ Процессы Composer не найдены"
fi

echo ""
echo "Проверка статуса HestiaCP..."
if systemctl is-active --quiet admin; then
    echo "✅ HestiaCP работает"
else
    echo "⚠️ HestiaCP не запущен"
fi

echo ""
echo "Для продолжения установки запустите:"
echo "bash traffic_manager_new.sh --install-hestia"
