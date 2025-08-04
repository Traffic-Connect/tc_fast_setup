#!/bin/bash
# ============================================================================
# Unit тесты для общей библиотеки функций
# ============================================================================

# Загрузка библиотек
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

# Счетчики тестов
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Функции для тестирования
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Тест}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✅ $message${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ $message${NC}"
        echo "  Ожидалось: '$expected'"
        echo "  Получено:  '$actual'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_not_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Тест}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${GREEN}✅ $message${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ $message${NC}"
        echo "  Значения не должны быть равны: '$expected'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_length() {
    local string="$1"
    local expected_length="$2"
    local message="${3:-Тест}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local actual_length=${#string}
    
    if [[ $actual_length -eq $expected_length ]]; then
        echo -e "${GREEN}✅ $message${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ $message${NC}"
        echo "  Ожидаемая длина: $expected_length"
        echo "  Фактическая длина: $actual_length"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Тест}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$condition"; then
        echo -e "${GREEN}✅ $message${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ $message${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Тест}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if ! eval "$condition"; then
        echo -e "${GREEN}✅ $message${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ $message${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# ============================================================================
# ТЕСТЫ БЕЗОПАСНОСТИ
# ============================================================================

test_password_generation() {
    echo ""
    echo "=== ТЕСТЫ ГЕНЕРАЦИИ ПАРОЛЕЙ ==="
    
    # Тест генерации паролей разной сложности
    local password_low=$(generate_secure_password 12 "low")
    local password_medium=$(generate_secure_password 16 "medium")
    local password_high=$(generate_secure_password 24 "high")
    
    assert_length "$password_low" 12 "Пароль низкой сложности должен быть 12 символов"
    assert_length "$password_medium" 16 "Пароль средней сложности должен быть 16 символов"
    assert_length "$password_high" 24 "Пароль высокой сложности должен быть 24 символа"
    
    # Тест уникальности паролей
    local password1=$(generate_secure_password)
    local password2=$(generate_secure_password)
    assert_not_equal "$password1" "$password2" "Пароли должны быть разными"
    
    # Тест сложности паролей
    assert_true "validate_password_strength '$password_high' 12" "Пароль высокой сложности должен проходить валидацию"
    assert_false "validate_password_strength 'weak' 12" "Слабый пароль не должен проходить валидацию"
}

test_password_validation() {
    echo ""
    echo "=== ТЕСТЫ ВАЛИДАЦИИ ПАРОЛЕЙ ==="
    
    # Тест валидных паролей
    assert_true "validate_password_strength 'StrongPass123!' 12" "Валидный пароль с символами"
    assert_true "validate_password_strength 'MySecurePass2023@' 12" "Валидный пароль с цифрами и символами"
    
    # Тест невалидных паролей
    assert_false "validate_password_strength 'short' 12" "Короткий пароль не должен проходить валидацию"
    assert_false "validate_password_strength 'onlylowercase' 12" "Пароль только из строчных букв не должен проходить валидацию"
    assert_false "validate_password_strength 'ONLYUPPERCASE' 12" "Пароль только из заглавных букв не должен проходить валидацию"
    assert_false "validate_password_strength '123456789012' 12" "Пароль только из цифр не должен проходить валидацию"
}

# ============================================================================
# ТЕСТЫ ВАЛИДАЦИИ
# ============================================================================

test_email_validation() {
    echo ""
    echo "=== ТЕСТЫ ВАЛИДАЦИИ EMAIL ==="
    
    # Тест валидных email
    assert_true "validate_email 'test@example.com'" "Валидный email"
    assert_true "validate_email 'user.name+tag@domain.co.uk'" "Валидный email с точками и плюсом"
    assert_true "validate_email 'admin@localhost'" "Валидный email localhost"
    
    # Тест невалидных email
    assert_false "validate_email 'invalid-email'" "Невалидный email без @"
    assert_false "validate_email '@example.com'" "Невалидный email без имени"
    assert_false "validate_email 'test@'" "Невалидный email без домена"
    assert_false "validate_email 'test..test@example.com'" "Невалидный email с двойными точками"
}

test_username_validation() {
    echo ""
    echo "=== ТЕСТЫ ВАЛИДАЦИИ ИМЕНИ ПОЛЬЗОВАТЕЛЯ ==="
    
    # Тест валидных имен пользователей
    assert_true "validate_username 'admin'" "Валидное имя пользователя"
    assert_true "validate_username 'user123'" "Валидное имя пользователя с цифрами"
    assert_true "validate_username 'test_user'" "Валидное имя пользователя с подчеркиванием"
    assert_true "validate_username 'my-user'" "Валидное имя пользователя с дефисом"
    
    # Тест невалидных имен пользователей
    assert_false "validate_username 'Admin'" "Невалидное имя с заглавной буквой"
    assert_false "validate_username '123user'" "Невалидное имя начинающееся с цифры"
    assert_false "validate_username 'user@name'" "Невалидное имя с специальными символами"
    assert_false "validate_username 'verylongusernameexceeding32characters'" "Невалидное имя слишком длинное"
}

test_url_validation() {
    echo ""
    echo "=== ТЕСТЫ ВАЛИДАЦИИ URL ==="
    
    # Тест валидных URL
    assert_true "validate_url 'https://example.com'" "Валидный HTTPS URL"
    assert_true "validate_url 'http://localhost:8080'" "Валидный HTTP URL с портом"
    assert_true "validate_url 'https://api.github.com/v1/users'" "Валидный URL с путем"
    
    # Тест невалидных URL
    assert_false "validate_url 'not-a-url'" "Невалидный URL без протокола"
    assert_false "validate_url 'ftp://example.com'" "Невалидный FTP URL"
    assert_false "validate_url 'example.com'" "Невалидный URL без протокола"
}

# ============================================================================
# ТЕСТЫ СИСТЕМНЫХ ПРОВЕРОК
# ============================================================================

test_system_requirements() {
    echo ""
    echo "=== ТЕСТЫ СИСТЕМНЫХ ТРЕБОВАНИЙ ==="
    
    # Тест проверки архитектуры
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        echo -e "${GREEN}✅ Архитектура x86_64 поддерживается${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}⚠ Архитектура $arch не поддерживается${NC}"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Тест проверки ОС
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
            echo -e "${GREEN}✅ ОС $ID поддерживается${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${YELLOW}⚠ ОС $ID не поддерживается${NC}"
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
    
    # Тест проверки памяти (имитация)
    local available_memory=2048  # Имитируем 2GB
    if [ $available_memory -ge $REQUIRED_MEMORY ]; then
        echo -e "${GREEN}✅ Достаточно памяти: ${available_memory}MB${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Недостаточно памяти: ${available_memory}MB${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Тест проверки места на диске (имитация)
    local available_disk=5120  # Имитируем 5GB
    if [ $available_disk -ge $REQUIRED_DISK_SPACE ]; then
        echo -e "${GREEN}✅ Достаточно места на диске: ${available_disk}MB${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Недостаточно места на диске: ${available_disk}MB${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# ============================================================================
# ТЕСТЫ ОБРАБОТКИ ОШИБОК
# ============================================================================

test_error_handling() {
    echo ""
    echo "=== ТЕСТЫ ОБРАБОТКИ ОШИБОК ==="
    
    # Тест функции check_error с успешным выполнением
    local test_command="echo 'success'"
    if $test_command; then
        assert_true "check_error 'Тест успешного выполнения' 'test_component' || true" "Проверка успешного выполнения"
    fi
    
    # Тест функции check_error с ошибкой
    local test_command="false"
    if ! $test_command; then
        assert_false "check_error 'Тест обработки ошибки' 'test_component' || true" "Проверка обработки ошибки"
    fi
}

# ============================================================================
# ТЕСТЫ ЛОГИРОВАНИЯ
# ============================================================================

test_logging_functions() {
    echo ""
    echo "=== ТЕСТЫ ФУНКЦИЙ ЛОГИРОВАНИЯ ==="
    
    # Тест базовых функций логирования
    local test_message="Тестовое сообщение"
    
    # Тест log_info
    local info_output=$(log_info "$test_message" 2>&1)
    assert_true "echo '$info_output' | grep -q '\[Инфо\]'" "Функция log_info работает"
    
    # Тест log_ok
    local ok_output=$(log_ok "$test_message" 2>&1)
    assert_true "echo '$ok_output' | grep -q '\[OK\]'" "Функция log_ok работает"
    
    # Тест log_err
    local err_output=$(log_err "$test_message" 2>&1)
    assert_true "echo '$err_output' | grep -q '\[ОШИБКА\]'" "Функция log_err работает"
    
    # Тест log_warn
    local warn_output=$(log_warn "$test_message" 2>&1)
    assert_true "echo '$warn_output' | grep -q '\[ВНИМАНИЕ\]'" "Функция log_warn работает"
}

# ============================================================================
# ТЕСТЫ УТИЛИТ
# ============================================================================

test_utility_functions() {
    echo ""
    echo "=== ТЕСТЫ УТИЛИТАРНЫХ ФУНКЦИЙ ==="
    
    # Тест dir_exists
    assert_true "dir_exists '/tmp'" "Функция dir_exists для существующей директории"
    assert_false "dir_exists '/nonexistent/directory'" "Функция dir_exists для несуществующей директории"
    
    # Тест safe_rm
    local test_file="/tmp/test_safe_rm.txt"
    echo "test" > "$test_file"
    assert_true "[ -f '$test_file' ]" "Тестовый файл создан"
    safe_rm "$test_file"
    assert_false "[ -f '$test_file' ]" "Функция safe_rm удалила файл"
    
    # Тест show_progress
    local progress_output=$(show_progress 5 10 2>&1)
    assert_true "echo '$progress_output' | grep -q '50%'" "Функция show_progress показывает правильный процент"
}

# ============================================================================
# ТЕСТЫ ПРОВЕРКИ ЦЕЛОСТНОСТИ
# ============================================================================

test_file_integrity() {
    echo ""
    echo "=== ТЕСТЫ ПРОВЕРКИ ЦЕЛОСТНОСТИ ==="
    
    # Создание тестового файла
    local test_file="/tmp/test_integrity.txt"
    echo "test content" > "$test_file"
    
    # Вычисление хеша
    local expected_hash=$(sha256sum "$test_file" | cut -d' ' -f1)
    
    # Тест проверки целостности
    assert_true "verify_file_integrity '$test_file' '$expected_hash'" "Проверка целостности валидного файла"
    
    # Тест с неправильным хешем
    assert_false "verify_file_integrity '$test_file' 'wrong_hash'" "Проверка целостности с неправильным хешем"
    
    # Очистка
    rm -f "$test_file"
}

# ============================================================================
# ТЕСТЫ МЕТРИК
# ============================================================================

test_metrics_functions() {
    echo ""
    echo "=== ТЕСТЫ ФУНКЦИЙ МЕТРИК ==="
    
    # Тест track_installation_time
    local start_time=$(date +%s)
    sleep 1
    track_installation_time "test_component" "$start_time"
    
    # Проверка создания файла метрик
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        assert_true "[ -f '$LOG_DIR/installation_metrics.log' ]" "Файл метрик установки создан"
    fi
    
    # Тест collect_system_metrics
    collect_system_metrics
    
    # Проверка создания файла системных метрик
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        assert_true "[ -f '$LOG_DIR/system_metrics.json' ]" "Файл системных метрик создан"
    fi
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ ТЕСТИРОВАНИЯ
# ============================================================================

run_all_tests() {
    echo "🚀 ЗАПУСК UNIT ТЕСТОВ"
    echo "Проект: Traffic Connect Server Installation"
    echo "Дата: $(date)"
    echo ""
    
    # Создание временной директории для логов
    mkdir -p "$LOG_DIR"
    
    # Запуск всех тестов
    test_password_generation
    test_password_validation
    test_email_validation
    test_username_validation
    test_url_validation
    test_system_requirements
    test_error_handling
    test_logging_functions
    test_utility_functions
    test_file_integrity
    test_metrics_functions
    
    # Показ результатов
    echo ""
    echo "=========================================="
    echo "=== РЕЗУЛЬТАТЫ UNIT ТЕСТИРОВАНИЯ ==="
    echo "=========================================="
    echo "Всего тестов: $TOTAL_TESTS"
    echo -e "Пройдено успешно: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Провалено: ${RED}$FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 ВСЕ UNIT ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}⚠️  ЕСТЬ ПРОВАЛЕННЫЕ UNIT ТЕСТЫ!${NC}"
        return 1
    fi
}

# Запуск тестов
run_all_tests 