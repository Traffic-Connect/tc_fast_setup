#!/bin/bash

echo "🔄 Принудительное обновление Traffic Connect Fast Setup..."

# Проверка, что мы в правильной папке
if [ ! -f "install.sh" ]; then
    echo "❌ Ошибка: файл install.sh не найден"
    echo "Убедитесь, что вы находитесь в папке tc_fast_setup"
    exit 1
fi

echo "📥 Получение последних изменений..."
git fetch origin

echo "🔄 Принудительное обновление..."
git reset --hard origin/main

echo "🧹 Очистка кэша..."
git clean -fd

echo "✅ Обновление завершено!"
echo ""
echo "📋 Проверка изменений:"
git log --oneline -3
echo ""
echo "🚀 Теперь можно запускать установку:"
echo "   ./install.sh"
