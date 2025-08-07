#!/bin/bash

# ============================================================================
# Traffic Connect Fast Setup - Просмотр данных для входа
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Загрузка конфигурации и библиотек
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

echo "🔍 Traffic Connect Fast Setup - Данные для входа"
echo "================================================"

# Проверка, что мы в правильной папке
if [ ! -f "install.sh" ]; then
    echo "❌ Ошибка: файл install.sh не найден"
    echo "Убедитесь, что вы находитесь в папке tc_fast_setup"
    exit 1
fi

# Отображение данных для входа
show_access_credentials

echo ""
echo "💾 Сохранение данных в файл..."
save_credentials "$GRAFANA_ADMIN_PASSWORD" "$HESTIA_USERNAME" "$HESTIA_PASSWORD"

echo ""
echo "📄 Данные также сохранены в файл: $CREDENTIALS_FILE"
echo "🔒 Файл защищен правами 600 (только для root)"
