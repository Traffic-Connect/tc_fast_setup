#!/bin/bash
# ============================================================================
# Тест политики безопасности TrafficConnect
# ============================================================================

echo "🧪 Тестирование политики безопасности TrafficConnect"
echo "=================================================="
echo ""

# Загружаем политику безопасности
if [ -f "$(dirname "$(dirname "$(dirname "$0")")")/system/security/security_policy.sh" ]; then
    source "$(dirname "$(dirname "$(dirname "$0")")")/system/security/security_policy.sh"
    echo "✅ Политика безопасности загружена"
else
    echo "❌ Файл политики безопасности не найден"
    exit 1
fi

echo ""
echo "🔑 Тест генерации паролей:"
echo "-------------------------"

# Тест 1: Базовый пароль
echo "1. Базовый пароль (16 символов):"
basic_pass=$(generate_compliant_password 16 "low")
echo "   Пароль: $basic_pass"
echo "   Оценка: $(assess_password_strength "$basic_pass")"
echo ""

# Тест 2: Средний пароль
echo "2. Средний пароль (20 символов):"
medium_pass=$(generate_compliant_password 20 "medium")
echo "   Пароль: $medium_pass"
echo "   Оценка: $(assess_password_strength "$medium_pass")"
echo ""

# Тест 3: Высокий пароль
echo "3. Высокий пароль (24 символа):"
high_pass=$(generate_compliant_password 24 "high")
echo "   Пароль: $high_pass"
echo "   Оценка: $(assess_password_strength "$high_pass")"
echo ""

echo "👤 Тест генерации логинов:"
echo "-------------------------"

# Тест логинов для разных модулей
modules=("grafana" "prometheus" "loki" "api" "admin_panel" "node_exporter")
for module in "${modules[@]}"; do
    login=$(generate_traffic_login "$module")
    echo "   $module: $login"
done
echo ""

echo "🔍 Тест проверки паролей:"
echo "------------------------"

# Тест хорошего пароля
good_password="Kj9#mN2\$pQ7@vX5&hL8"
echo "1. Хороший пароль: $good_password"
echo "   Результат: $(validate_password_policy "$good_password")"
echo "   Оценка: $(assess_password_strength "$good_password")"
echo ""

# Тест слабого пароля
weak_password="password123"
echo "2. Слабый пароль: $weak_password"
echo "   Результат: $(validate_password_policy "$weak_password")"
echo "   Оценка: $(assess_password_strength "$weak_password")"
echo ""

echo "📊 Тест создания учетных данных:"
echo "-------------------------------"

# Создаем временный файл для тестирования
TEST_CREDS_FILE="/tmp/test_credentials.txt"
rm -f "$TEST_CREDS_FILE"

# Тест создания учетных данных для Grafana
echo "1. Создание учетных данных для Grafana:"
grafana_creds=$(generate_and_save_module_credentials "grafana" 24 "high" "$TEST_CREDS_FILE")
grafana_username=$(echo "$grafana_creds" | cut -d: -f1)
grafana_password=$(echo "$grafana_creds" | cut -d: -f2)
echo "   Логин: $grafana_username"
echo "   Пароль: $grafana_password"
echo "   Оценка: $(assess_password_strength "$grafana_password")"
echo ""

# Показываем содержимое файла с учетными данными
if [ -f "$TEST_CREDS_FILE" ]; then
    echo "📄 Содержимое файла с учетными данными:"
    echo "----------------------------------------"
    cat "$TEST_CREDS_FILE"
    echo ""
    rm -f "$TEST_CREDS_FILE"
fi

echo "✅ Тестирование завершено успешно!"
echo ""
echo "💡 Для использования в своих скриптах:"
echo "   source 'system/security/security_policy.sh'"
echo "   password=\$(generate_compliant_password 24 'high')"
echo "   login=\$(generate_traffic_login 'my_module')"
