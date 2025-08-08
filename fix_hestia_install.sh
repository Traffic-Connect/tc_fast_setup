#!/bin/bash
# ============================================================================
# Быстрое исправление установки HestiaCP
# ============================================================================

echo "🔧 БЫСТРОЕ ИСПРАВЛЕНИЕ УСТАНОВКИ HESTIACP"
echo "================================================"

# Остановка зависших процессов
echo "1. Остановка зависших процессов..."
pkill -f "hst-install\|composer\|v-add-user-composer" 2>/dev/null || true
sleep 3

# Проверка статуса установки
echo "2. Проверка статуса установки..."
if [ -f "/usr/local/admin/bin/admin" ]; then
    echo "✅ HestiaCP уже установлен"
else
    echo "❌ HestiaCP не установлен"
fi

# Отключение Composer
echo "3. Отключение Composer..."
if [ -f "/usr/local/hestia/bin/v-add-user-composer" ]; then
    mv "/usr/local/hestia/bin/v-add-user-composer" "/usr/local/hestia/bin/v-add-user-composer.disabled" 2>/dev/null || true
    echo "✅ Скрипт установки Composer отключен"
fi

# Удаление Composer файлов
echo "4. Очистка Composer файлов..."
if [ -d "/home/TrafficAdmin/.composer" ]; then
    rm -rf "/home/TrafficAdmin/.composer" 2>/dev/null || true
    echo "✅ Composer файлы удалены"
fi

# Проверка служб
echo "5. Проверка служб..."
if systemctl is-active --quiet admin; then
    echo "✅ HestiaCP служба работает"
else
    echo "⚠️ HestiaCP служба не работает"
    echo "Запуск службы..."
    systemctl start admin 2>/dev/null || true
fi

# Проверка веб-интерфейса
echo "6. Проверка веб-интерфейса..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8083 | grep -q "200\|302"; then
    echo "✅ Веб-интерфейс доступен"
else
    echo "⚠️ Веб-интерфейс недоступен"
fi

echo ""
echo "🎯 РЕЗУЛЬТАТ:"
echo "================================================"
echo "HestiaCP должен быть доступен по адресу:"
echo "https://$(hostname -f):8083"
echo ""
echo "Учетные данные:"
echo "Пользователь: TrafficAdmin"
echo "Пароль: (сгенерированный пароль)"
echo ""
echo "Для продолжения установки запустите:"
echo "bash traffic_manager_new.sh"
