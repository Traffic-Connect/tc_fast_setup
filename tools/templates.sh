#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Установка шаблонов
# ============================================================================

# Загрузка общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

install_templates() {
    log_info "Установка шаблонов HestiaCP..."
    local COMPONENTS_DIR="$PROJECT_ROOT/Components"
    local NGINX_TEMPL_DIR="/usr/local/hestia/data/templates/web/nginx"
    local PHPFPM_TEMPL_DIR="/usr/local/hestia/data/templates/web/php-fpm"
    local files=(
        "tc-nginx-apache.stpl"
        "tc-nginx-apache.tpl"
        "tc-custom.tpl"
        "tc-nginx-only.stpl"
        "tc-nginx-only.tpl"
        "tc-nginx-only-mu.stpl"
        "tc-nginx-only-mu.tpl"
    )
    local missing=()
    echo "[DEBUG] Содержимое папки Components ($COMPONENTS_DIR):"
    ls -l "$COMPONENTS_DIR"
    for f in "${files[@]}"; do
        if [ ! -f "$COMPONENTS_DIR/$f" ]; then
            missing+=("$f")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_err "Не найдены необходимые шаблоны: ${missing[*]}"
        echo -e "${RED}Добавьте отсутствующие файлы в папку Components и повторите установку.${NC}"
        exit 1
    fi
    [ -d "$NGINX_TEMPL_DIR" ] || mkdir -p "$NGINX_TEMPL_DIR"
    [ -d "$PHPFPM_TEMPL_DIR" ] || mkdir -p "$PHPFPM_TEMPL_DIR"
    for f in "${files[@]}"; do
        if [ -f "$COMPONENTS_DIR/$f" ]; then
            if [[ "$f" == *.tpl ]]; then
                cp "$COMPONENTS_DIR/$f" "$NGINX_TEMPL_DIR/" 2>/dev/null || cp "$COMPONENTS_DIR/$f" "$PHPFPM_TEMPL_DIR/"
            else
                cp "$COMPONENTS_DIR/$f" "$NGINX_TEMPL_DIR/"
            fi
        fi
    done
    chown www-data:www-data $NGINX_TEMPL_DIR/*.tpl 2>/dev/null || true
    chown www-data:www-data $NGINX_TEMPL_DIR/*.stpl 2>/dev/null || true
    chown www-data:www-data $PHPFPM_TEMPL_DIR/*.tpl 2>/dev/null || true
    log_ok "Права на шаблоны установлены."
    echo "[DEBUG] Файлы в $NGINX_TEMPL_DIR:" && ls -l "$NGINX_TEMPL_DIR"
    echo "[DEBUG] Файлы в $PHPFPM_TEMPL_DIR:" && ls -l "$PHPFPM_TEMPL_DIR"
    local HESTIA_CONF="/usr/local/hestia/conf/hestia.conf"
    if [ -f "$HESTIA_CONF" ]; then
        if grep -q '^PHP_TEMPLATE=' "$HESTIA_CONF"; then
            sed -i.bak 's/^PHP_TEMPLATE=.*/PHP_TEMPLATE=custom/' "$HESTIA_CONF"
        else
            echo 'PHP_TEMPLATE=custom' >> "$HESTIA_CONF"
        fi
        log_ok "PHP_TEMPLATE=custom установлен в hestia.conf"
        if systemctl restart hestia; then
            log_ok "HestiaCP перезапущена"
        else
            log_err "Ошибка перезапуска HestiaCP"
        fi
    else
        log_warn "Файл $HESTIA_CONF не найден, создаю базовую конфигурацию..."
        mkdir -p "$(dirname "$HESTIA_CONF")"
        cat > "$HESTIA_CONF" << 'EOF'
# Hestia CP Configuration
PHP_TEMPLATE=custom
WEB_TEMPLATE=custom
PROXY_TEMPLATE=custom
EOF
        log_ok "Создана базовая конфигурация Hestia CP"
        if systemctl list-unit-files | grep -q hestia.service; then
            if systemctl restart hestia; then
                log_ok "HestiaCP перезапущена"
            else
                log_warn "Не удалось перезапустить HestiaCP"
            fi
        else
            log_warn "Служба Hestia CP не найдена, пропускаем перезапуск"
        fi
    fi
} 