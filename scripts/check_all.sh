#!/bin/bash
# ============================================================================
# Traffic Connect Server - Проверка синтаксиса всех bash файлов
# ============================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Счетчики
TOTAL_FILES=0
VALID_FILES=0
INVALID_FILES=0

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка синтаксиса файла
check_file() {
    local file="$1"
    local filename=$(basename "$file")
    
    if [ -f "$file" ] && [ -r "$file" ]; then
        # Проверяем, что это bash файл
        if head -n 1 "$file" | grep -q "#!/bin/bash"; then
            ((TOTAL_FILES++))
            
            if bash -n "$file" 2>/dev/null; then
                log_ok "✅ $filename"
                ((VALID_FILES++))
            else
                log_err "❌ $filename"
                ((INVALID_FILES++))
                # Показываем ошибку
                bash -n "$file" 2>&1 | sed 's/^/    /'
            fi
        fi
    fi
}

# Рекурсивный поиск bash файлов
find_bash_files() {
    local dir="$1"
    
    # Проверяем файлы в текущей директории
    for file in "$dir"/*.sh; do
        if [ -f "$file" ]; then
            check_file "$file"
        fi
    done
    
    # Рекурсивно проверяем поддиректории
    for subdir in "$dir"/*/; do
        if [ -d "$subdir" ]; then
            find_bash_files "$subdir"
        fi
    done
}

# Главная функция
main() {
    echo ""
    echo "🔍 ПРОВЕРКА СИНТАКСИСА BASH ФАЙЛОВ"
    echo "================================================"
    echo ""
    
    # Определяем корневую директорию проекта
    local project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    log_info "Проверка файлов в: $project_root"
    echo ""
    
    # Проверяем все bash файлы
    find_bash_files "$project_root"
    
    echo ""
    echo "📊 РЕЗУЛЬТАТЫ ПРОВЕРКИ:"
    echo "================================================"
    echo "Всего bash файлов: $TOTAL_FILES"
    echo "Валидных файлов: $VALID_FILES"
    echo "Файлов с ошибками: $INVALID_FILES"
    echo ""
    
    if [ $INVALID_FILES -eq 0 ]; then
        log_ok "🎉 Все bash файлы имеют корректный синтаксис!"
        exit 0
    else
        log_err "❌ Найдены файлы с ошибками синтаксиса"
        exit 1
    fi
}

# Запуск
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
