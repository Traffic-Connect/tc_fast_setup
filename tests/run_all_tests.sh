#!/bin/bash
# ============================================================================
# Запуск всех тестов проекта
# ============================================================================

# Загрузка библиотек
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/config.sh"

# Счетчики результатов
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Функция запуска тестов
run_test_suite() {
    local test_file="$1"
    local test_name="$2"
    
    echo ""
    echo "=== ЗАПУСК $test_name ==="
    
    if bash "$test_file"; then
        echo -e "${GREEN}✅ $test_name пройден успешно${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ $test_name провален${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Функция показа итоговых результатов
show_final_results() {
    echo ""
    echo "=========================================="
    echo "=== ИТОГОВЫЕ РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ==="
    echo "=========================================="
    echo "Всего тестовых наборов: $TOTAL_TESTS"
    echo -e "Пройдено успешно: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Провалено: ${RED}$FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!${NC}"
        echo "Проект готов к использованию."
        exit 0
    else
        echo ""
        echo -e "${RED}⚠️  ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ!${NC}"
        echo "Необходимо исправить ошибки перед использованием."
        exit 1
    fi
}

# Проверка наличия тестовых файлов
check_test_files() {
    local missing_files=()
    
    [[ -f "$SCRIPT_DIR/unit/test_common.sh" ]] || missing_files+=("unit/test_common.sh")
    [[ -f "$SCRIPT_DIR/integration/test_installation.sh" ]] || missing_files+=("integration/test_installation.sh")
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}Ошибка: Отсутствуют тестовые файлы:${NC}"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
}

# Главная функция
main() {
    echo "🚀 ЗАПУСК ПОЛНОГО ТЕСТИРОВАНИЯ ПРОЕКТА"
    echo "Проект: Traffic Connect Server Installation"
    echo "Дата: $(date)"
    echo ""
    
    # Проверка наличия тестовых файлов
    check_test_files
    
    # Запуск unit тестов
    run_test_suite "$SCRIPT_DIR/unit/test_common.sh" "UNIT ТЕСТЫ"
    
    # Запуск интеграционных тестов
    run_test_suite "$SCRIPT_DIR/integration/test_installation.sh" "ИНТЕГРАЦИОННЫЕ ТЕСТЫ"
    
    # Показ итоговых результатов
    show_final_results
}

# Запуск главной функции
main 