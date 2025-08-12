#!/bin/bash

# Подключаем модули
source "$(dirname "$0")/core/colors.sh"
source "$(dirname "$0")/core/utils.sh"

# Красивый заголовок скрипта
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🌐 HESTIA CP - УСТАНОВКА ПАНЕЛИ УПРАВЛЕНИЯ${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${LIGHT_CYAN}Автоматическая установка Hestia Control Panel${NC}${LIGHT_BLUE}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Проверяем root права
check_root

# Генерируем данные для входа
HESTIA_USERNAME="admin"
HESTIA_PASSWORD=$(generate_password)
HESTIA_EMAIL="admin@$(hostname)"

# Получаем IP адрес сервера
SERVER_IP=$(get_server_ip)

print_header "🔧 ПОДГОТОВКА К УСТАНОВКЕ"

log_message "INFO" "Проверка системы..."
log_message "INFO" "ОС: $(lsb_release -d | cut -f2 2>/dev/null || echo 'Ubuntu')"
log_message "INFO" "Ядро: $(uname -r)"
log_message "INFO" "IP адрес: ${SERVER_IP}"

# Показываем данные для входа ДО установки
print_header "🔐 ДАННЫЕ ДЛЯ ВХОДА"

echo -e "\n${LIGHT_PURPLE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДОСТУП К HESTIA CP${NC} ${LIGHT_PURPLE}${STAR}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🌐 ВЕБ-ИНТЕРФЕЙС${NC}${LIGHT_PURPLE}${LINE_V:0:40}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}URL:${NC}         ${LIGHT_YELLOW}https://${SERVER_IP}:8083${NC}${LIGHT_PURPLE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${LINE_V}${NC} ${CYAN}Альтернативный:${NC} ${LIGHT_YELLOW}https://$(hostname):8083${NC}${LIGHT_PURPLE}${LINE_V:0:2}${LINE_V}${NC}"
echo -e "${LIGHT_PURPLE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_BLUE}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ДАННЫЕ ДЛЯ ВХОДА${NC} ${LIGHT_BLUE}${STAR}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🔐 УЧЕТНЫЕ ДАННЫЕ${NC}${LIGHT_BLUE}${LINE_V:0:40}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Логин:${NC}       ${LIGHT_YELLOW}${HESTIA_USERNAME}${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Пароль:${NC}      ${LIGHT_RED}${HESTIA_PASSWORD}${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${CYAN}Email:${NC}       ${LIGHT_YELLOW}${HESTIA_EMAIL}${NC}${LIGHT_BLUE}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_GREEN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ЧТО БУДЕТ УСТАНОВЛЕНО${NC} ${LIGHT_GREEN}${STAR}${NC}"
echo -e "${LIGHT_GREEN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}🚀 КОМПОНЕНТЫ${NC}${LIGHT_GREEN}${LINE_V:0:45}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ NGINX Web/Proxy Server${NC}${LIGHT_GREEN}${LINE_V:0:25}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ PHP-FPM 8.3${NC}${LIGHT_GREEN}${LINE_V:0:35}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ MariaDB 11.4${NC}${LIGHT_GREEN}${LINE_V:0:35}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ Vsftpd FTP Server${NC}${LIGHT_GREEN}${LINE_V:0:30}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ Firewall (iptables) + Fail2Ban${NC}${LIGHT_GREEN}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ phpMyAdmin v5.2.2${NC}${LIGHT_GREEN}${LINE_V:0:25}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ File Manager${NC}${LIGHT_GREEN}${LINE_V:0:35}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${LINE_V}${NC} ${CYAN}✅ Rclone & Restic${NC}${LIGHT_GREEN}${LINE_V:0:30}${LINE_V}${NC}"
echo -e "${LIGHT_GREEN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_YELLOW}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ВАЖНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_YELLOW}${STAR}${NC}"
echo -e "${LIGHT_YELLOW}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}⚠️ ВНИМАНИЕ${NC}${LIGHT_YELLOW}${LINE_V:0:45}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}•${NC} Установка займет 5-10 минут${LIGHT_YELLOW}${LINE_V:0:25}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}•${NC} После установки сервер перезагрузится${LIGHT_YELLOW}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}•${NC} Сохраните пароль: ${LIGHT_RED}${HESTIA_PASSWORD}${NC}${LIGHT_YELLOW}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_RED}${STAR}${NC} ${BOLD}${LIGHT_GREEN}СОХРАНИТЕ ПАРОЛЬ: ${LIGHT_RED}${HESTIA_PASSWORD}${NC} ${LIGHT_RED}${STAR}${NC}"

echo -e "\n${LIGHT_CYAN}${ARROW}${NC} Нажмите любую клавишу для начала установки..."
read -n 1 -s

print_header "📦 УСТАНОВКА HESTIA CP"

log_message "INFO" "Загрузка установщика Hestia CP..."
if wget -q https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh -O /tmp/hst-install.sh; then
    log_message "SUCCESS" "Установщик загружен"
    chmod +x /tmp/hst-install.sh
else
    log_message "ERROR" "Ошибка загрузки установщика"
    exit 1
fi

log_message "INFO" "Запуск установки Hestia CP..."
log_message "WARNING" "Установка может занять 5-10 минут"

# Запускаем установку Hestia CP
/tmp/hst-install.sh \
    --lang 'ru' \
    --hostname "$(hostname)" \
    --username "$HESTIA_USERNAME" \
    --email "$HESTIA_EMAIL" \
    --password "$HESTIA_PASSWORD" \
    --apache no \
    --named no \
    --exim no \
    --dovecot no \
    --clamav no \
    --spamassassin no \
    --force

check_error "Установка Hestia CP"

# Очищаем временные файлы
rm -f /tmp/hst-install.sh

print_header "🎉 УСТАНОВКА ЗАВЕРШЕНА"

log_message "SUCCESS" "Hestia CP успешно установлен!"
log_message "INFO" "Для входа используйте: https://${SERVER_IP}:8083"
log_message "INFO" "Логин: ${HESTIA_USERNAME} | Пароль: ${HESTIA_PASSWORD}"

echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🎉 УСТАНОВКА HESTIA CP ЗАВЕРШЕНА УСПЕШНО! 🎉${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_YELLOW}${STAR}${NC} ${BOLD}${LIGHT_GREEN}СЛЕДУЮЩИЕ ШАГИ${NC} ${LIGHT_YELLOW}${STAR}${NC}"
echo -e "${LIGHT_YELLOW}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${BOLD}${LIGHT_CYAN}📋 РЕКОМЕНДАЦИИ${NC}${LIGHT_YELLOW}${LINE_V:0:40}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}1.${NC} Перезагрузите сервер: ${LIGHT_CYAN}reboot${NC}${LIGHT_YELLOW}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}2.${NC} Войдите в Hestia CP по ссылке выше${LIGHT_YELLOW}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}3.${NC} Настройте домены и сайты${LIGHT_YELLOW}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${LINE_V}${NC} ${CYAN}4.${NC} Измените пароль администратора${LIGHT_YELLOW}${LINE_V:0:10}${LINE_V}${NC}"
echo -e "${LIGHT_YELLOW}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

echo -e "\n${LIGHT_CYAN}${STAR}${NC} ${BOLD}${LIGHT_GREEN}ПОЛЕЗНАЯ ИНФОРМАЦИЯ${NC} ${LIGHT_CYAN}${STAR}${NC}"
echo -e "${LIGHT_CYAN}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}📁 ФАЙЛЫ И ЛОГИ${NC}${LIGHT_CYAN}${LINE_V:0:35}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_L}${LINE_H:0:58}${LINE_R}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}Конфигурация:${NC} ${LIGHT_YELLOW}/usr/local/hestia/data/templates/${NC}${LIGHT_CYAN}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}Логи:${NC}         ${LIGHT_YELLOW}/var/log/hestia/${NC}${LIGHT_CYAN}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}Веб-сайты:${NC}    ${LIGHT_YELLOW}/home/admin/web/${NC}${LIGHT_CYAN}${LINE_V:0:15}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${LINE_V}${NC} ${CYAN}База данных:${NC}  ${LIGHT_YELLOW}/var/lib/mysql/${NC}${LIGHT_CYAN}${LINE_V:0:12}${LINE_V}${NC}"
echo -e "${LIGHT_CYAN}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
