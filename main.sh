#!/bin/bash
set -e

# Подключаем основные модули
source "$(dirname "$0")/core/colors.sh"
source "$(dirname "$0")/core/utils.sh"
source "$(dirname "$0")/core/installer.sh"

# Красивый заголовок скрипта
echo -e "${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🚀 TC FAST SETUP - АВТОМАТИЧЕСКАЯ УСТАНОВКА${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${LIGHT_CYAN}Система мониторинга и управления сервером${NC}${LIGHT_BLUE}${LINE_V:0:20}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"

# Инициализация установки
initialize_installation

# Отображение информации перед установкой
display_login_info
display_components
display_important_info

# Ожидание подтверждения
wait_for_confirmation

# Основной процесс установки
main_installation_process

# Отображение результатов
source "$(dirname "$0")/output/display.sh"
display_results

echo -e "\n${LIGHT_BLUE}${CORNER_TL}${LINE_H:0:58}${CORNER_TR}${NC}"
echo -e "${LIGHT_BLUE}${LINE_V}${NC} ${BOLD}${LIGHT_GREEN}🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! 🎉${NC} ${LIGHT_BLUE}${LINE_V:0:8}${LINE_V}${NC}"
echo -e "${LIGHT_BLUE}${CORNER_BL}${LINE_H:0:58}${CORNER_BR}${NC}"
