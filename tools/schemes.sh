#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Установка Schemes Scripts
# ============================================================================

# Загрузка общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

install_schemes() {
    log_info "Установка Schemes Scripts..."
    local OLDDIR
    OLDDIR="$(pwd)"
    cd ~ || exit
    local SCHEMAS_DIR="schemas"
    if dir_exists "$SCHEMAS_DIR"; then
        safe_rm "$SCHEMAS_DIR"
    fi
    mkdir -p "$SCHEMAS_DIR"
    cd "$SCHEMAS_DIR" || exit
    check_internet || exit 1
    if git clone https://github.com/Traffic-Connect/schemes-scripts .; then
        log_ok "Schemes Scripts клонированы"
    else
        log_err "Ошибка клонирования Schemes Scripts"
        exit 1
    fi
    if [ -f setup.sh ]; then
        chmod +x setup.sh
        if ./setup.sh; then
            log_ok "Traffic Connect Schemes Scripts установлены"
        else
            log_err "Ошибка установки Schemes Scripts"
        fi
    else
        log_err "setup.sh не найден в $SCHEMAS_DIR"
        exit 1
    fi
    cd "$OLDDIR" || exit
} 