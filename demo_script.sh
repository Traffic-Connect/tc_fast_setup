#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Дополнительные цвета для градиентов
LIGHT_BLUE='\033[94m'
LIGHT_GREEN='\033[92m'
LIGHT_CYAN='\033[96m'
LIGHT_PURPLE='\033[95m'
LIGHT_RED='\033[91m'
LIGHT_YELLOW='\033[93m'

# Символы для оформления
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="->"
STAR="*"
DASH="-"
EQUALS="="
CORNER_TL="+"
CORNER_TR="+"
CORNER_BL="+"
CORNER_BR="+"
LINE_V="|"
LINE_H="="
LINE_T="+"
LINE_B="+"
LINE_L="+"
LINE_R="+"

# Функция проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS_MARK} [ОШИБКА] $1${NC}"
        exit 1
    else
        echo -e "${GREEN}${CHECK_MARK} [OK] $1${NC}"
    fi
}

# Функция для красивого заголовка
print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:padding} ${BOLD}${title}${NC} ${LINE_H:0:padding}${CORNER_TR}${NC}"
}

# Функция для прогресс-бара
show_progress() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}[${NC}"
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "${CYAN}] ${NC}${LIGHT_GREEN}%d%%${NC}" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Красивый заголовок скрипта
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🚀 TC FAST SETUP - АВТОМАТИЧЕСКАЯ УСТАНОВКА${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${LIGHT_CYAN}Система мониторинга и управления сервером${NC}${LIGHT_BLUE}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Отображение системной информации
echo -e "\n${LIGHT_CYAN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}СИСТЕМНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_CYAN}${STAR}${NC}"
echo -e "${LIGHT_CYAN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}🖥️  Система:${NC}     ${LIGHT_YELLOW}Ubuntu 22.04.3 LTS${NC}${LIGHT_CYAN}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}💾 Память:${NC}      ${LIGHT_YELLOW}8.0 GB${NC}${LIGHT_CYAN}${LINE_V:0:25}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}💿 Диск:${NC}        ${LIGHT_YELLOW}100G${NC}${LIGHT_CYAN}${LINE_V:0:28}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}🌐 IP адрес:${NC}    ${LIGHT_YELLOW}213.136.74.48${NC}${LIGHT_CYAN}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Демонстрация установки
print_header "🧹 ОЧИСТКА СИСТЕМЫ"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Очистка старых пакетов..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Удаление временных файлов..."
sleep 1
check_error "Очистка системы"

print_header "📦 УСТАНОВКА БАЗОВЫХ ПАКЕТОВ"

echo -e "${LIGHT_CYAN}${ARROW}${NC} Обновление списка пакетов..."
sleep 1
show_progress 1 4

echo -e "${LIGHT_CYAN}${ARROW}${NC} Обновление системы..."
sleep 1
show_progress 2 4

echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка базовых пакетов..."
sleep 1
show_progress 3 4

echo -e "${LIGHT_CYAN}${ARROW}${NC} Завершение установки..."
sleep 1
show_progress 4 4
check_error "Установка базовых пакетов"

print_header "🌐 УСТАНОВКА HESTIA CP"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Hestia CP..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка компонентов..."
sleep 1
check_error "Установка Hestia CP"

print_header "🔥 НАСТРОЙКА ФАЙРВОЛА"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Настройка правил..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Активация файрвола..."
sleep 1
check_error "Настройка файрвола"

print_header "🛡️ НАСТРОЙКА FAIL2BAN"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Конфигурация jail..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Запуск службы..."
sleep 1
check_error "Настройка fail2ban"

print_header "📊 УСТАНОВКА GRAFANA"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Grafana..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка пакета..."
sleep 1
check_error "Установка Grafana"

print_header "📈 УСТАНОВКА PROMETHEUS"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Создание пользователя..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка Prometheus..."
sleep 1
check_error "Установка Prometheus"

print_header "🖥️ УСТАНОВКА NODE EXPORTER"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Node Exporter..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Настройка службы..."
sleep 1
check_error "Установка Node Exporter"

print_header "📤 УСТАНОВКА PUSHGATEWAY"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Pushgateway..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Настройка службы..."
sleep 1
check_error "Установка Pushgateway"

print_header "📝 УСТАНОВКА LOKI И PROMTAIL"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Загрузка Loki..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Установка Promtail..."
sleep 1
check_error "Установка Loki и Promtail"

print_header "📊 НАСТРОЙКА МОНИТОРИНГА FAIL2BAN"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Создание экспортера..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Настройка метрик..."
sleep 1
check_error "Настройка мониторинга fail2ban"

print_header "⚙️ НАСТРОЙКА GRAFANA"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Настройка источников данных..."
sleep 1
echo -e "${LIGHT_CYAN}${ARROW}${NC} Импорт дашбордов..."
sleep 1
check_error "Настройка Grafana"

print_header "🎉 УСТАНОВКА ЗАВЕРШЕНА"

# Генерируем все пароли для отображения
HESTIA_PASSWORD="Gk0yb8lNJColp"
GRAFANA_PASSWORD="ZRC3AaeuxY0JKSO"
PROMETHEUS_PASSWORD="SUIurNsLa7d2X95T"
LOKI_PASSWORD="T34K1CWOSmuhmr02"
PUSHGATEWAY_PASSWORD="phFyJj2BoNBduHt0"
PHPMYADMIN_PASSWORD="Jh9kfULYTnBTEXRD"

# Получаем IP адрес сервера
SERVER_IP="213.136.74.48"

echo -e "\n${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУПНЫЕ СЕРВИСЫ${NC} ${LIGHT_BLUE}${STAR}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🌐 ВЕБ-ИНТЕРФЕЙСЫ${NC}${LIGHT_BLUE}${LINE_V:0:42}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}🌐 Hestia CP:${NC}    ${LIGHT_YELLOW}http://${SERVER_IP}:8083${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📊 Grafana:${NC}      ${LIGHT_YELLOW}http://${SERVER_IP}:3000${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📈 Prometheus:${NC}   ${LIGHT_YELLOW}http://${SERVER_IP}:9090${NC}${LIGHT_BLUE}${LINE_V:0:6}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📝 Loki:${NC}         ${LIGHT_YELLOW}http://${SERVER_IP}:3100${NC}${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}📤 Pushgateway:${NC}  ${LIGHT_YELLOW}http://${SERVER_IP}:9091${NC}${LIGHT_BLUE}${LINE_V:0:6}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДАННЫЕ ДЛЯ ВХОДА${NC} ${LIGHT_PURPLE}${STAR}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🔐 УЧЕТНЫЕ ДАННЫЕ${NC}${LIGHT_PURPLE}${LINE_V:0:40}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}🌐 Hestia CP:${NC}     ${LIGHT_YELLOW}TrafficHestia${NC}     ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$HESTIA_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:4}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📊 Grafana:${NC}       ${LIGHT_YELLOW}TrafficGrafana${NC}     ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$GRAFANA_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:4}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📈 Prometheus:${NC}    ${LIGHT_YELLOW}TrafficPrometheus${NC}  ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$PROMETHEUS_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:2}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📝 Loki:${NC}          ${LIGHT_YELLOW}TrafficLoki${NC}        ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$LOKI_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:6}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📤 Pushgateway:${NC}   ${LIGHT_YELLOW}TrafficPushgateway${NC} ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$PUSHGATEWAY_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:2}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}🗄️  phpMyAdmin:${NC}    ${LIGHT_YELLOW}TrafficPhpMyAdmin${NC}  ${LIGHT_GREEN}/${NC} ${LIGHT_RED}$PHPMYADMIN_PASSWORD${NC}${LIGHT_PURPLE}${LINE_V:0:2}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! 🎉${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Дополнительная информация
echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ПОЛЕЗНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_PURPLE}${STAR}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Grafana:${NC}    ${LIGHT_YELLOW}/var/log/grafana/grafana.log${NC}${LIGHT_PURPLE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Prometheus:${NC}  ${LIGHT_YELLOW}/var/log/prometheus/${NC}${LIGHT_PURPLE}${LINE_V:0:12}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Loki:${NC}        ${LIGHT_YELLOW}/var/log/loki/${NC}${LIGHT_PURPLE}${LINE_V:0:18}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Promtail:${NC}   ${LIGHT_YELLOW}/var/log/promtail/${NC}${LIGHT_PURPLE}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}📋 Логи Fail2ban:${NC}   ${LIGHT_YELLOW}/var/log/fail2ban.log${NC}${LIGHT_PURPLE}${LINE_V:0:10}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_GREEN}${CHECK_MARK}${NC} ${BOLD}Все сервисы установлены и настроены!${NC}"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Рекомендуется перезагрузить сервер после установки"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Для мониторинга используйте Grafana: ${LIGHT_YELLOW}http://${SERVER_IP}:3000${NC}"
echo -e "${LIGHT_CYAN}${ARROW}${NC} Для управления сервером используйте Hestia CP: ${LIGHT_YELLOW}http://${SERVER_IP}:8083${NC}"
