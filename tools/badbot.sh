#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Установка BadBot
# ============================================================================

# Загрузка общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

install_badbot() {
    log_info "Установка и настройка BadBot..."
    if dir_exists "/root/tc-nginx-badbot"; then
        safe_rm "/root/tc-nginx-badbot"
    fi
    check_internet || exit 1
    if git clone https://github.com/Traffic-Connect/tc-nginx-badbot.git /root/tc-nginx-badbot; then
        log_ok "tc-nginx-badbot клонирован"
    else
        log_err "Ошибка клонирования badbot"
        exit 1
    fi
    if chmod 0755 /root/tc-nginx-badbot/badbot.sh; then
        log_ok "Права на badbot.sh установлены"
    fi
    if ! crontab -l 2>/dev/null | grep -q '/root/tc-nginx-badbot/badbot.sh'; then
        (crontab -l 2>/dev/null; echo "00 03 * * * /root/tc-nginx-badbot/badbot.sh") | crontab -
    fi
    if /root/tc-nginx-badbot/badbot.sh; then
        log_ok "badbot.sh выполнен"
    else
        log_err "Ошибка выполнения badbot.sh"
    fi
    if nginx -t && systemctl restart nginx; then
        log_ok "nginx успешно перезапущен"
    else
        log_err "Ошибка в конфиге или перезапуске nginx"
        exit 1
    fi
} 