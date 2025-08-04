#!/bin/bash
# ============================================================================
# Интеграционные тесты для процесса установки
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
# ТЕСТЫ ПРОВЕРКИ СИСТЕМЫ
# ============================================================================

test_system_compatibility() {
    echo ""
    echo "=== ТЕСТЫ СОВМЕСТИМОСТИ СИСТЕМЫ ==="
    
    # Проверка root прав
    if [ "$(id -u)" = "0" ]; then
        echo -e "${GREEN}✅ Запуск от root${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Не запущено от root${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Проверка интернета
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Интернет доступен${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Интернет недоступен${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Проверка системных требований
    if check_system_requirements; then
        echo -e "${GREEN}✅ Системные требования выполнены${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Системные требования не выполнены${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# ============================================================================
# ТЕСТЫ КОНФИГУРАЦИИ
# ============================================================================

test_configuration_loading() {
    echo ""
    echo "=== ТЕСТЫ ЗАГРУЗКИ КОНФИГУРАЦИИ ==="
    
    # Проверка загрузки основного конфига
    assert_true "[ -f '$PROJECT_ROOT/config.sh' ]" "Основной конфиг существует"
    
    # Проверка загрузки общей библиотеки
    assert_true "[ -f '$PROJECT_ROOT/lib/common.sh' ]" "Общая библиотека существует"
    
    # Проверка загрузки интерактивной библиотеки
    assert_true "[ -f '$PROJECT_ROOT/lib/interactive.sh' ]" "Интерактивная библиотека существует"
    
    # Проверка переменных конфигурации
    assert_true "[ -n '$GRAFANA_PORT' ]" "Порт Grafana настроен"
    assert_true "[ -n '$PROMETHEUS_PORT' ]" "Порт Prometheus настроен"
    assert_true "[ -n '$LOKI_PORT' ]" "Порт Loki настроен"
    assert_true "[ -n '$HESTIA_PORT' ]" "Порт Hestia настроен"
    
    # Проверка версий компонентов
    assert_true "[ -n '$GRAFANA_VERSION' ]" "Версия Grafana настроена"
    assert_true "[ -n '$PROMETHEUS_VERSION' ]" "Версия Prometheus настроена"
    assert_true "[ -n '$LOKI_VERSION' ]" "Версия Loki настроена"
}

# ============================================================================
# ТЕСТЫ ЗАВИСИМОСТЕЙ
# ============================================================================

test_dependencies() {
    echo ""
    echo "=== ТЕСТЫ ЗАВИСИМОСТЕЙ ==="
    
    # Проверка основных команд
    local required_commands=("curl" "wget" "apt" "systemctl" "netstat")
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Команда $cmd доступна${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}❌ Команда $cmd недоступна${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    done
    
    # Проверка Python для GUI
    if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Python доступен для GUI${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}⚠ Python недоступен для GUI${NC}"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# ============================================================================
# ТЕСТЫ СТРУКТУРЫ ПРОЕКТА
# ============================================================================

test_project_structure() {
    echo ""
    echo "=== ТЕСТЫ СТРУКТУРЫ ПРОЕКТА ==="
    
    # Проверка основных директорий
    local required_dirs=("lib" "tools" "Components" "tests" "web")
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            echo -e "${GREEN}✅ Директория $dir существует${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}❌ Директория $dir отсутствует${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    done
    
    # Проверка основных скриптов
    local required_scripts=("install.sh" "install_complete.sh" "install_tools.sh")
    
    for script in "${required_scripts[@]}"; do
        if [ -f "$PROJECT_ROOT/$script" ]; then
            if [ -x "$PROJECT_ROOT/$script" ]; then
                echo -e "${GREEN}✅ Скрипт $script существует и исполняемый${NC}"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                echo -e "${YELLOW}⚠ Скрипт $script существует, но не исполняемый${NC}"
            fi
        else
            echo -e "${RED}❌ Скрипт $script отсутствует${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    done
}

# ============================================================================
# ТЕСТЫ ПОРТОВ И СЕТИ
# ============================================================================

test_network_connectivity() {
    echo ""
    echo "=== ТЕСТЫ СЕТЕВОЙ СВЯЗНОСТИ ==="
    
    # Проверка внешних ресурсов
    local external_urls=(
        "https://github.com"
        "https://dl.grafana.com"
        "https://github.com/prometheus"
        "https://github.com/grafana/loki"
    )
    
    for url in "${external_urls[@]}"; do
        if curl -s --head "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $url доступен${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}❌ $url недоступен${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    done
    
    # Проверка локальных портов
    local local_ports=("22" "80" "443")
    
    for port in "${local_ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}✅ Порт $port занят${NC}"
        else
            echo -e "${YELLOW}⚠ Порт $port свободен${NC}"
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    done
}

# ============================================================================
# ТЕСТЫ БЕЗОПАСНОСТИ
# ============================================================================

test_security_features() {
    echo ""
    echo "=== ТЕСТЫ БЕЗОПАСНОСТИ ==="
    
    # Проверка настроек безопасности
    assert_true "[ '$VERIFY_CHECKSUMS' = 'true' ]" "Проверка целостности файлов включена"
    assert_true "[ '$SSL_VERIFY' = 'true' ]" "SSL проверка включена"
    assert_true "[ '$GPG_VERIFY' = 'true' ]" "GPG проверка включена"
    assert_true "[ '$ENABLE_ROLLBACK' = 'true' ]" "Автоматический rollback включен"
    
    # Проверка генерации паролей
    local password1=$(generate_secure_password)
    local password2=$(generate_secure_password)
    
    assert_not_equal "$password1" "$password2" "Пароли генерируются уникальными"
    assert_length "$password1" 24 "Пароль имеет правильную длину"
    assert_true "validate_password_strength '$password1' 12" "Пароль проходит валидацию сложности"
}

# ============================================================================
# ТЕСТЫ ЛОГИРОВАНИЯ
# ============================================================================

test_logging_system() {
    echo ""
    echo "=== ТЕСТЫ СИСТЕМЫ ЛОГИРОВАНИЯ ==="
    
    # Создание тестовой директории логов
    mkdir -p "$LOG_DIR"
    
    # Тест функций логирования
    local test_message="Тестовое сообщение интеграционного теста"
    
    log_info "$test_message" >/dev/null 2>&1
    assert_true "[ $? -eq 0 ]" "Функция log_info работает"
    
    log_ok "$test_message" >/dev/null 2>&1
    assert_true "[ $? -eq 0 ]" "Функция log_ok работает"
    
    log_err "$test_message" >/dev/null 2>&1
    assert_true "[ $? -eq 0 ]" "Функция log_err работает"
    
    log_warn "$test_message" >/dev/null 2>&1
    assert_true "[ $? -eq 0 ]" "Функция log_warn работает"
    
    # Проверка создания JSON логов
    if [[ "$ENABLE_JSON_LOGGING" == "true" ]]; then
        assert_true "[ -f '$LOG_DIR/install.json' ]" "JSON лог создается"
    fi
}

# ============================================================================
# ТЕСТЫ МЕТРИК И МОНИТОРИНГА
# ============================================================================

test_metrics_system() {
    echo ""
    echo "=== ТЕСТЫ СИСТЕМЫ МЕТРИК ==="
    
    # Тест отслеживания времени установки
    local start_time=$(date +%s)
    sleep 1
    track_installation_time "test_component" "$start_time"
    
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        assert_true "[ -f '$LOG_DIR/installation_metrics.log' ]" "Файл метрик установки создается"
    fi
    
    # Тест сбора системных метрик
    collect_system_metrics
    
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        assert_true "[ -f '$LOG_DIR/system_metrics.json' ]" "Файл системных метрик создается"
    fi
}

# ============================================================================
# ТЕСТЫ ВАЛИДАЦИИ
# ============================================================================

test_validation_functions() {
    echo ""
    echo "=== ТЕСТЫ ФУНКЦИЙ ВАЛИДАЦИИ ==="
    
    # Тест валидации email
    assert_true "validate_email 'test@example.com'" "Валидный email проходит проверку"
    assert_false "validate_email 'invalid-email'" "Невалидный email не проходит проверку"
    
    # Тест валидации имени пользователя
    assert_true "validate_username 'admin'" "Валидное имя пользователя проходит проверку"
    assert_false "validate_username 'Admin'" "Невалидное имя пользователя не проходит проверку"
    
    # Тест валидации URL
    assert_true "validate_url 'https://example.com'" "Валидный URL проходит проверку"
    assert_false "validate_url 'not-a-url'" "Невалидный URL не проходит проверку"
}

# ============================================================================
# ТЕСТЫ ОБРАБОТКИ ОШИБОК
# ============================================================================

test_error_handling() {
    echo ""
    echo "=== ТЕСТЫ ОБРАБОТКИ ОШИБОК ==="
    
    # Тест функции check_error с успешным выполнением
    echo "success" >/dev/null 2>&1
    if check_error "Тест успешного выполнения" "test_component" 2>/dev/null; then
        echo -e "${GREEN}✅ Обработка успешного выполнения работает${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Обработка успешного выполнения не работает${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Тест функции check_error с ошибкой
    false >/dev/null 2>&1
    if ! check_error "Тест обработки ошибки" "test_component" 2>/dev/null; then
        echo -e "${GREEN}✅ Обработка ошибок работает${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Обработка ошибок не работает${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# ============================================================================
# ТЕСТЫ ПРОИЗВОДИТЕЛЬНОСТИ
# ============================================================================

test_performance_features() {
    echo ""
    echo "=== ТЕСТЫ ПРОИЗВОДИТЕЛЬНОСТИ ==="
    
    # Проверка настроек производительности
    assert_true "[ -n '$MAX_PARALLEL_JOBS' ]" "Максимальное количество параллельных процессов настроено"
    assert_true "[ -n '$DOWNLOAD_CHUNK_SIZE' ]" "Размер блока загрузки настроен"
    assert_true "[ -n '$COMPRESSION_LEVEL' ]" "Уровень сжатия настроен"
    
    # Проверка кэширования
    assert_true "[ -n '$CACHE_DIR' ]" "Директория кэша настроена"
    assert_true "[ -n '$CACHE_TTL' ]" "Время жизни кэша настроено"
    
    # Тест создания кэш директории
    mkdir -p "$CACHE_DIR"
    assert_true "[ -d '$CACHE_DIR' ]" "Кэш директория создается"
}

# ============================================================================
# ТЕСТЫ ИНТЕРАКТИВНОГО РЕЖИМА
# ============================================================================

test_interactive_mode() {
    echo ""
    echo "=== ТЕСТЫ ИНТЕРАКТИВНОГО РЕЖИМА ==="
    
    # Проверка наличия интерактивных функций
    assert_true "[ -f '$PROJECT_ROOT/lib/interactive.sh' ]" "Интерактивная библиотека существует"
    
    # Проверка функций интерактивного режима (без запуска)
    if grep -q "interactive_setup" "$PROJECT_ROOT/lib/interactive.sh"; then
        echo -e "${GREEN}✅ Функция interactive_setup найдена${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Функция interactive_setup не найдена${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if grep -q "interactive_input" "$PROJECT_ROOT/lib/interactive.sh"; then
        echo -e "${GREEN}✅ Функция interactive_input найдена${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ Функция interactive_input не найдена${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}



# ============================================================================
# ТЕСТЫ ДОПОЛНИТЕЛЬНЫХ КОМПОНЕНТОВ
# ============================================================================

test_additional_components() {
    echo ""
    echo "=== ТЕСТЫ ДОПОЛНИТЕЛЬНЫХ КОМПОНЕНТОВ ==="
    
    # Проверка скриптов дополнительных компонентов
    local component_scripts=("templates.sh" "schemes.sh" "link_manager.sh" "badbot.sh")
    
    for script in "${component_scripts[@]}"; do
        if [ -f "$PROJECT_ROOT/tools/$script" ]; then
            echo -e "${GREEN}✅ Скрипт $script существует${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}❌ Скрипт $script отсутствует${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    done
    
    # Проверка шаблонов
    if [ -d "$PROJECT_ROOT/Components" ]; then
        local template_count=$(ls "$PROJECT_ROOT/Components"/*.tpl 2>/dev/null | wc -l)
        if [ "$template_count" -gt 0 ]; then
            echo -e "${GREEN}✅ Найдено $template_count шаблонов${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${YELLOW}⚠ Шаблоны не найдены${NC}"
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ ТЕСТИРОВАНИЯ
# ============================================================================

run_all_integration_tests() {
    echo "🚀 ЗАПУСК ИНТЕГРАЦИОННЫХ ТЕСТОВ"
    echo "Проект: Traffic Connect Server Installation"
    echo "Дата: $(date)"
    echo ""
    
    # Создание временной директории для логов
    mkdir -p "$LOG_DIR"
    
    # Запуск всех тестов
    test_system_compatibility
    test_configuration_loading
    test_dependencies
    test_project_structure
    test_network_connectivity
    test_security_features
    test_logging_system
    test_metrics_system
    test_validation_functions
    test_error_handling
    test_performance_features
    test_interactive_mode
    test_additional_components
    
    # Показ результатов
    echo ""
    echo "=========================================="
    echo "=== РЕЗУЛЬТАТЫ ИНТЕГРАЦИОННЫХ ТЕСТОВ ==="
    echo "=========================================="
    echo "Всего тестов: $TOTAL_TESTS"
    echo -e "Пройдено успешно: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Провалено: ${RED}$FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 ВСЕ ИНТЕГРАЦИОННЫЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!${NC}"
        echo "Проект готов к установке."
        return 0
    else
        echo ""
        echo -e "${RED}⚠️  ЕСТЬ ПРОВАЛЕННЫЕ ИНТЕГРАЦИОННЫЕ ТЕСТЫ!${NC}"
        echo "Необходимо исправить ошибки перед установкой."
        return 1
    fi
}

# Запуск тестов
run_all_integration_tests 