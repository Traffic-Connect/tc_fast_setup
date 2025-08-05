#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Дополнительные компоненты
# ============================================================================

# Загрузка общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/common.sh"

# Проверка root прав
check_root

# Настройка логирования
setup_logging

# Определение корневой директории проекта
PROJECT_ROOT="$SCRIPT_DIR"

# Проверка интернета
log_info "Проверка подключения к интернету..."
check_internet

# Проверка существования папки tools
if [ ! -d "$PROJECT_ROOT/tools" ]; then
    log_warn "Папка tools не найдена в $PROJECT_ROOT, пропускаем установку дополнительных компонентов"
    log_info "Дополнительные компоненты (шаблоны, BadBot, Link Manager) не будут установлены"
    exit 0
fi

log_info "Начинаем установку дополнительных компонентов..."

# ============================================================================
# 1. УСТАНОВКА ШАБЛОНОВ
# ============================================================================
echo -e "${YELLOW}=== Установка шаблонов HestiaCP ===${NC}"

# Проверка и установка шаблонов
[ -d "$PROJECT_ROOT/Components" ] || { log_err "Папка Components не найдена"; exit 1; }
[ -f "$PROJECT_ROOT/tools/templates.sh" ] || { log_err "Файл templates.sh не найден"; exit 1; }

source "$PROJECT_ROOT/tools/templates.sh"
install_templates
check_error "Установка шаблонов"

# ============================================================================
# 2. УСТАНОВКА SCHEMES SCRIPTS
# ============================================================================
echo -e "${YELLOW}=== Установка Schemes Scripts ===${NC}"

# Установка Schemes Scripts
[ -f "$PROJECT_ROOT/tools/schemes.sh" ] || { log_err "Файл schemes.sh не найден"; exit 1; }

source "$PROJECT_ROOT/tools/schemes.sh"
install_schemes
check_error "Установка Schemes Scripts"

# ============================================================================
# 3. УСТАНОВКА LINK MANAGER
# ============================================================================
echo -e "${YELLOW}=== Установка Link Manager ===${NC}"

# Установка Link Manager
[ -f "$PROJECT_ROOT/tools/link_manager.sh" ] || { log_err "Файл link_manager.sh не найден"; exit 1; }

source "$PROJECT_ROOT/tools/link_manager.sh"
install_link_manager
check_error "Установка Link Manager"

# ============================================================================
# 4. УСТАНОВКА BADBOT ЗАЩИТЫ
# ============================================================================
echo -e "${YELLOW}=== Установка BadBot защиты ===${NC}"

# Установка BadBot защиты
[ -f "$PROJECT_ROOT/tools/badbot.sh" ] || { log_err "Файл badbot.sh не найден"; exit 1; }

source "$PROJECT_ROOT/tools/badbot.sh"
install_badbot
check_error "Установка BadBot защиты"

# ============================================================================
# 5. ПРОВЕРКА УСТАНОВКИ
# ============================================================================
echo -e "${YELLOW}=== Проверка установки ===${NC}"

# Проверка установки шаблонов
log_info "Проверка установки шаблонов..."
if [ -d "/usr/local/hestia/data/templates/web/nginx" ]; then
    local template_count=$(ls /usr/local/hestia/data/templates/web/nginx/*.tpl 2>/dev/null | wc -l)
    if [ "$template_count" -gt 0 ]; then
        log_ok "Установлено $template_count Nginx шаблонов"
    else
        log_err "Nginx шаблоны не найдены"
    fi
else
    log_err "Директория Nginx шаблонов не найдена"
fi

# Проверка установки Schemes Scripts
log_info "Проверка установки Schemes Scripts..."
if [ -d "$HOME/schemas" ]; then
    log_ok "Schemes Scripts установлены в $HOME/schemas"
else
    log_err "Schemes Scripts не найдены"
fi

# Проверка установки Link Manager
log_info "Проверка установки Link Manager..."
if [ -d "$HOME/link-manager" ]; then
    log_ok "Link Manager установлен в $HOME/link-manager"
else
    log_err "Link Manager не найден"
fi

# Проверка установки BadBot
log_info "Проверка установки BadBot..."
if [ -d "/root/tc-nginx-badbot" ]; then
    log_ok "BadBot установлен в /root/tc-nginx-badbot"
    if crontab -l 2>/dev/null | grep -q '/root/tc-nginx-badbot/badbot.sh'; then
        log_ok "Cron-задача для BadBot настроена"
    else
        log_err "Cron-задача для BadBot не найдена"
    fi
else
    log_err "BadBot не найден"
fi

# ============================================================================
# 6. ЗАВЕРШЕНИЕ
# ============================================================================
echo -e "${YELLOW}=== Установка завершена ===${NC}"
echo -e "${GREEN}Установленные компоненты:${NC}"
echo -e "✅ Шаблоны HestiaCP (Nginx + PHP-FPM)"
echo -e "✅ Schemes Scripts"
echo -e "✅ Link Manager"
echo -e "✅ BadBot защита"
echo -e ""
echo -e "${BLUE}Дополнительная информация:${NC}"
echo -e "• Шаблоны: /usr/local/hestia/data/templates/web/"
echo -e "• Schemes: $HOME/schemas/"
echo -e "• Link Manager: $HOME/link-manager/"
echo -e "• BadBot: /root/tc-nginx-badbot/"
echo -e ""
echo -e "${YELLOW}Рекомендации:${NC}"
echo -e "• Проверьте конфигурацию Nginx: nginx -t"
echo -e "• Перезапустите Hestia CP: systemctl restart hestia"
echo -e "• Проверьте cron-задачи: crontab -l" 