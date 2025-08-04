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

# Главная функция
main() {
    echo "🚀 ЗАПУСК ТЕСТИРОВАНИЯ ПРОЕКТА"
    echo "Дата: $(date)"
    echo ""
    
    # Запуск unit тестов
    run_test_suite "$SCRIPT_DIR/unit/test_common.sh" "UNIT ТЕСТЫ"
    
    # Запуск интеграционных тестов
    run_test_suite "$SCRIPT_DIR/integration/test_installation.sh" "ИНТЕГРАЦИОННЫЕ ТЕСТЫ"
    
    # Показ итоговых результатов
    echo ""
    echo "=========================================="
    echo "=== ИТОГОВЫЕ РЕЗУЛЬТАТЫ ==="
    echo "=========================================="
    echo "Всего тестовых наборов: $TOTAL_TESTS"
    echo -e "Пройдено успешно: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Провалено: ${RED}$FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}⚠️  ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ!${NC}"
        exit 1
    fi
}

# Запуск главной функции
main 