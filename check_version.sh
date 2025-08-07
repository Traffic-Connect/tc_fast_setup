#!/bin/bash

echo "🔍 Проверка версии Traffic Connect Fast Setup"
echo "=============================================="

# Проверка, что мы в правильной папке
if [ ! -f "install.sh" ]; then
    echo "❌ Ошибка: файл install.sh не найден"
    echo "Убедитесь, что вы находитесь в папке tc_fast_setup"
    exit 1
fi

echo "📋 Текущая версия:"
git log --oneline -1

echo ""
echo "📥 Последняя версия на GitHub:"
git fetch origin 2>/dev/null
git log --oneline -1 origin/main

echo ""
echo "🔄 Статус обновлений:"
if git status --porcelain | grep -q .; then
    echo "⚠️  Есть локальные изменения"
    echo "   Рекомендуется: ./force_update.sh"
else
    echo "✅ Нет локальных изменений"
fi

echo ""
echo "📊 Разница с GitHub:"
local_commit=$(git rev-parse HEAD)
remote_commit=$(git rev-parse origin/main 2>/dev/null || echo "unknown")

if [ "$local_commit" = "$remote_commit" ]; then
    echo "✅ Версия актуальна"
else
    echo "⚠️  Версия устарела"
    echo "   Рекомендуется: ./force_update.sh"
fi

echo ""
echo "🚀 Для обновления выполните:"
echo "   ./force_update.sh"
