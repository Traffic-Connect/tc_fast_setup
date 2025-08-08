#!/bin/bash
# ============================================================================
# Проверка синтаксиса всех bash файлов в проекте
# ============================================================================

echo "🔍 ПРОВЕРКА СИНТАКСИСА BASH ФАЙЛОВ"
echo "================================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Счетчики
total_files=0
valid_files=0
invalid_files=0

# Функция проверки файла
check_file() {
    local file="$1"
    local filename=$(basename "$file")
    
    if [ -f "$file" ] && [[ "$file" == *.sh ]]; then
        ((total_files++))
        
        if bash -n "$file" 2>/dev/null; then
            echo -e "${GREEN}✅ $filename${NC}"
            ((valid_files++))
        else
            echo -e "${RED}❌ $filename${NC}"
            echo -e "${YELLOW}   Ошибки:${NC}"
            bash -n "$file" 2>&1 | sed 's/^/     /'
            ((invalid_files++))
        fi
    fi
}

# Проверка основных файлов
echo "📁 Основные файлы:"
check_file "install.sh"
check_file "manager.sh"

# Проверка конфигураций
echo ""
echo "📁 Конфигурации:"
check_file "core/configs/main.conf"

# Проверка утилит
echo ""
echo "📁 Утилиты:"
check_file "core/utils/logger.sh"
check_file "core/utils/common.sh"
check_file "core/utils/system.sh"

# Проверка установщиков
echo ""
echo "📁 Установщики:"
check_file "core/installers/hestia_install.sh"
check_file "core/installers/system_install.sh"

# Проверка менеджеров
echo ""
echo "📁 Менеджеры:"
check_file "core/managers/service_manager.sh"
check_file "core/managers/config_manager.sh"

# Проверка модулей
echo ""
echo "📁 Модули:"
check_file "modules/core/system_check.sh"
check_file "modules/core/logging.sh"
check_file "modules/tools/check_hestia.sh"

# Проверка системных компонентов
echo ""
echo "📁 Системные компоненты:"
check_file "system/security/security_install.sh"
check_file "system/security/security_policy.sh"
check_file "system/monitoring/monitoring_install.sh"
check_file "system/admin/admin_install.sh"

# Проверка веб-компонентов
echo ""
echo "📁 Веб-компоненты:"
check_file "web/templates/templates_install.sh"

# Проверка скриптов
echo ""
echo "📁 Скрипты:"
check_file "scripts/fix_install.sh"
check_file "scripts/stop_composer.sh"

# Результаты
echo ""
echo "================================================"
echo "📊 РЕЗУЛЬТАТЫ ПРОВЕРКИ:"
echo "================================================"
echo "Всего файлов: $total_files"
echo -e "Валидных: ${GREEN}$valid_files${NC}"
echo -e "С ошибками: ${RED}$invalid_files${NC}"

if [ $invalid_files -eq 0 ]; then
    echo -e "${GREEN}🎉 Все файлы прошли проверку синтаксиса!${NC}"
    exit 0
else
    echo -e "${RED}❌ Обнаружены файлы с ошибками синтаксиса${NC}"
    exit 1
fi
