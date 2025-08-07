#!/bin/bash

# ============================================================================
# ЭТАП 5: УСТАНОВКА ШАБЛОНОВ
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

install_templates() {
    log_info "=== ЭТАП 5: Установка шаблонов ==="
    
    log_info "Установка шаблонов..."
    
    if [ ! -f "/usr/local/admin/bin/admin" ]; then
        log_warn "Административная панель не установлена, пропускаем шаблоны"
        return 0
    fi
    
    local NGINX_TEMPL_DIR="/usr/local/admin/data/templates/web/nginx"
    local PHPFPM_TEMPL_DIR="/usr/local/admin/data/templates/web/php-fpm"
    local TEMPLATES_DIR="$PROJECT_ROOT/web/templates"
    
    log_info "Создание директорий для шаблонов..."
    mkdir -p "$NGINX_TEMPL_DIR" "$PHPFPM_TEMPL_DIR"
    
    # Копирование шаблонов
    log_info "Копирование шаблонов..."
    local template_count=0
    
    # Копирование nginx шаблонов (.stpl и .tpl файлы)
    log_info "Копирование nginx шаблонов..."
    for file in "$TEMPLATES_DIR"/tc-nginx-*.stpl "$TEMPLATES_DIR"/tc-nginx-*.tpl; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$NGINX_TEMPL_DIR/" 2>/dev/null || true
            ((template_count++))
            log_info "Скопирован nginx шаблон: $filename"
        fi
    done
    
    # Копирование php-fpm шаблонов (только .tpl файлы)
    log_info "Копирование php-fpm шаблонов..."
    for file in "$TEMPLATES_DIR"/tc-*.tpl; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$PHPFPM_TEMPL_DIR/" 2>/dev/null || true
            log_info "Скопирован php-fpm шаблон: $filename"
        fi
    done
    
    chown -R www-data:www-data "$NGINX_TEMPL_DIR" "$PHPFPM_TEMPL_DIR"
    
    # Проверка скопированных файлов
    log_info "Проверка скопированных файлов..."
    local nginx_files=$(ls "$NGINX_TEMPL_DIR"/tc-* 2>/dev/null | wc -l)
    local php_fpm_files=$(ls "$PHPFPM_TEMPL_DIR"/tc-* 2>/dev/null | wc -l)
    
    log_info "Nginx шаблонов: $nginx_files"
    log_info "PHP-FPM шаблонов: $php_fpm_files"
    
    # Вывод списка скопированных файлов
    if [ "$nginx_files" -gt 0 ]; then
        log_info "Nginx шаблоны:"
        ls -la "$NGINX_TEMPL_DIR"/tc-* 2>/dev/null | while read line; do
            log_info "  $line"
        done
    fi
    
    if [ "$php_fpm_files" -gt 0 ]; then
        log_info "PHP-FPM шаблоны:"
        ls -la "$PHPFPM_TEMPL_DIR"/tc-* 2>/dev/null | while read line; do
            log_info "  $line"
        done
    fi
    
    # Настройка конфигурации административной панели
    log_info "Настройка конфигурации административной панели..."
    local ADMIN_CONF="/usr/local/admin/conf/admin.conf"
    if [ -f "$ADMIN_CONF" ]; then
        sed -i.bak 's/^PHP_TEMPLATE=.*/PHP_TEMPLATE=custom/' "$ADMIN_CONF"
        sed -i.bak 's/^WEB_TEMPLATE=.*/WEB_TEMPLATE=custom/' "$ADMIN_CONF"
    else
        echo 'PHP_TEMPLATE=custom' >> "$ADMIN_CONF"
        echo 'WEB_TEMPLATE=custom' >> "$ADMIN_CONF"
    fi
    
    systemctl restart admin
    
    # Проверка установки
    log_info "Проверка установки шаблонов..."
    
    # Список ожидаемых файлов
    local expected_nginx_files=(
        "tc-nginx-apache.stpl"
        "tc-nginx-apache.tpl"
        "tc-nginx-only.stpl"
        "tc-nginx-only.tpl"
        "tc-nginx-only-mu.stpl"
        "tc-nginx-only-mu.tpl"
    )
    
    local expected_php_fpm_files=(
        "tc-custom.tpl"
        "tc-nginx-apache.tpl"
        "tc-nginx-only.tpl"
        "tc-nginx-only-mu.tpl"
    )
    
    # Проверка nginx файлов
    local missing_nginx=()
    for file in "${expected_nginx_files[@]}"; do
        if [ ! -f "$NGINX_TEMPL_DIR/$file" ]; then
            missing_nginx+=("$file")
        fi
    done
    
    # Проверка php-fpm файлов
    local missing_php_fpm=()
    for file in "${expected_php_fpm_files[@]}"; do
        if [ ! -f "$PHPFPM_TEMPL_DIR/$file" ]; then
            missing_php_fpm+=("$file")
        fi
    done
    
    # Отчет
    if [ ${#missing_nginx[@]} -eq 0 ] && [ ${#missing_php_fpm[@]} -eq 0 ]; then
        log_ok "✅ Все шаблоны установлены корректно"
        log_ok "✅ Nginx шаблонов: ${#expected_nginx_files[@]}"
        log_ok "✅ PHP-FPM шаблонов: ${#expected_php_fpm_files[@]}"
    else
        if [ ${#missing_nginx[@]} -gt 0 ]; then
            log_warn "⚠️  Отсутствуют nginx шаблоны: ${missing_nginx[*]}"
        fi
        if [ ${#missing_php_fpm[@]} -gt 0 ]; then
            log_warn "⚠️  Отсутствуют php-fpm шаблоны: ${missing_php_fpm[*]}"
        fi
    fi
    
    # Информация о шаблонах
    log_info "Информация о шаблонах:"
    log_info "  Nginx шаблоны: /usr/local/admin/data/templates/web/nginx/"
    log_info "  PHP-FPM шаблоны: /usr/local/admin/data/templates/web/php-fpm/"
    log_info "  Шаблоны будут доступны в веб-интерфейсе административной панели"
    log_info "  Префикс шаблонов: tc- (Traffic Connect)"
    
    log_ok "✅ Этап 5 завершен"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_templates
fi 