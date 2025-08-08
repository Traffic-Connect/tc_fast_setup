#!/bin/bash
# ============================================================================
# Проверка статуса HestiaCP
# ============================================================================

echo "🔍 ПРОВЕРКА СТАТУСА HESTIACP"
echo "================================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция проверки
check_component() {
    local name="$1"
    local check_cmd="$2"
    local success_msg="$3"
    local fail_msg="$4"
    
    if eval "$check_cmd" 2>/dev/null; then
        echo -e "${GREEN}✅ $success_msg${NC}"
        return 0
    else
        echo -e "${RED}❌ $fail_msg${NC}"
        return 1
    fi
}

# Счетчики
total_checks=0
passed_checks=0

echo "1. Проверка основных компонентов:"
echo "--------------------------------"

# Проверка бинарного файла
if check_component "Binary" "[ -f '/usr/local/admin/bin/admin' ]" "Основной бинарный файл найден" "Основной бинарный файл не найден"; then
    ((passed_checks++))
fi
((total_checks++))

# Проверка директории admin
if check_component "Admin Dir" "[ -d '/usr/local/admin' ]" "Директория admin найдена" "Директория admin не найдена"; then
    ((passed_checks++))
fi
((total_checks++))

# Проверка директории hestia
if check_component "Hestia Dir" "[ -d '/usr/local/hestia' ]" "Директория конфигурации найдена" "Директория конфигурации не найдена"; then
    ((passed_checks++))
fi
((total_checks++))

echo ""
echo "2. Проверка служб:"
echo "----------------"

# Проверка службы admin
if check_component "Service" "systemctl is-active --quiet admin" "Служба admin работает" "Служба admin не работает"; then
    ((passed_checks++))
fi
((total_checks++))

# Проверка автозапуска службы
if check_component "Auto-start" "systemctl is-enabled --quiet admin" "Служба настроена на автозапуск" "Служба не настроена на автозапуск"; then
    ((passed_checks++))
fi
((total_checks++))

echo ""
echo "3. Проверка веб-интерфейса:"
echo "-------------------------"

# Проверка доступности веб-интерфейса
if check_component "Web Interface" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8083 | grep -q '200\|302'" "Веб-интерфейс доступен" "Веб-интерфейс недоступен"; then
    ((passed_checks++))
fi
((total_checks++))

# Проверка SSL сертификата
if check_component "SSL" "curl -s -o /dev/null -w '%{http_code}' https://localhost:8083 | grep -q '200\|302'" "SSL сертификат работает" "SSL сертификат не работает"; then
    ((passed_checks++))
fi
((total_checks++))

echo ""
echo "4. Проверка пользователей:"
echo "------------------------"

# Проверка пользователя TrafficAdmin
if check_component "User" "id 'TrafficAdmin' &>/dev/null" "Пользователь TrafficAdmin существует" "Пользователь TrafficAdmin не найден"; then
    ((passed_checks++))
fi
((total_checks++))

# Проверка системных пользователей
if check_component "System Users" "id 'hestiaweb' &>/dev/null && id 'hestiamail' &>/dev/null" "Системные пользователи существуют" "Системные пользователи не найдены"; then
    ((passed_checks++))
fi
((total_checks++))

echo ""
echo "5. Проверка конфигурации:"
echo "-----------------------"

# Проверка файла конфигурации
if check_component "Config" "[ -f '/usr/local/hestia/conf/hestia.conf' ]" "Файл конфигурации найден" "Файл конфигурации не найден"; then
    ((passed_checks++))
fi
((total_checks++))

# Проверка лога установки
if check_component "Install Log" "[ -f '/usr/local/hestia/install.log' ]" "Лог установки найден" "Лог установки не найден"; then
    ((passed_checks++))
fi
((total_checks++))

echo ""
echo "6. Проверка портов:"
echo "-----------------"

# Проверка порта 8083
if check_component "Port 8083" "netstat -tlnp | grep -q ':8083'" "Порт 8083 открыт" "Порт 8083 не открыт"; then
    ((passed_checks++))
fi
((total_checks++))

echo ""
echo "================================================"
echo "📊 РЕЗУЛЬТАТЫ ПРОВЕРКИ:"
echo "================================================"

# Вычисление процента успешных проверок
percentage=$((passed_checks * 100 / total_checks))

echo "Пройдено проверок: $passed_checks из $total_checks ($percentage%)"

if [ $percentage -ge 80 ]; then
    echo -e "${GREEN}🎉 HestiaCP работает отлично!${NC}"
elif [ $percentage -ge 60 ]; then
    echo -e "${YELLOW}⚠️ HestiaCP работает с предупреждениями${NC}"
else
    echo -e "${RED}❌ HestiaCP имеет серьезные проблемы${NC}"
fi

echo ""
echo "🌐 Доступ к панели управления:"
echo "   URL: https://$(hostname -f):8083"
echo "   Пользователь: TrafficAdmin"
echo ""

# Дополнительная информация
if [ -f "/usr/local/hestia/install.log" ]; then
    echo "📋 Последние записи из лога установки:"
    tail -n 5 /usr/local/hestia/install.log
fi
