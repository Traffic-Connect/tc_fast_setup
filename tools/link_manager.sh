#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Установка Link Manager
# ============================================================================

# Загрузка общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

install_link_manager() {
    log_info "Установка Link Manager..."
    local OLDDIR
    OLDDIR="$(pwd)"
    cd ~ || exit
    local LINK_MANAGER_DIR="link-manager"
    if dir_exists "$LINK_MANAGER_DIR"; then
        safe_rm "$LINK_MANAGER_DIR"
    fi
    mkdir -p "$LINK_MANAGER_DIR"
    cd "$LINK_MANAGER_DIR" || exit
    check_internet || exit 1
    if git clone https://github.com/Traffic-Connect/tc-link-manager-installer.git .; then
        log_ok "Link Manager клонирован"
    else
        log_err "Ошибка клонирования Link Manager"
        exit 1
    fi
    if [ -f setup.sh ]; then
        chmod +x setup.sh
        if ./setup.sh; then
            log_ok "TC Link Manager установлен"
        else
            log_err "Ошибка установки Link Manager"
        fi
    else
        log_err "setup.sh не найден в $LINK_MANAGER_DIR"
        exit 1
    fi
    cd "$OLDDIR" || exit
} 