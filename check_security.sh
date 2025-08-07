#!/bin/bash
# ============================================================================
# Traffic Connect Server - Проверка безопасности
# ============================================================================

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции логирования
log_info() { echo -e "${BLUE}[Инфо] $1${NC}"; }
log_ok() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[ВНИМАНИЕ] $1${NC}"; }
log_err() { echo -e "${RED}[ОШИБКА] $1${NC}"; }

# Проверка root прав
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_err "Этот скрипт должен быть запущен от имени root"
        exit 1
    fi
}

# Проверка SSH безопасности согласно политике безопасности
check_ssh_security() {
    log_info "Проверка SSH безопасности согласно политике безопасности..."
    local score=0
    
    if [ -f /etc/ssh/sshd_config ]; then
        # Проверка root доступа (должен быть включен согласно политике)
        if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
            log_ok "SSH root доступ включен (согласно политике безопасности)"
            score=$((score + 15))
        else
            log_warn "SSH root доступ отключен (не соответствует политике)"
        fi
        
        # Проверка аутентификации по паролю (должна быть включена для root)
        if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
            log_ok "SSH аутентификация по паролю включена (для root)"
            score=$((score + 10))
        else
            log_warn "SSH аутентификация по паролю отключена"
        fi
        
        # Проверка аутентификации по ключам
        if grep -q "PubkeyAuthentication yes" /etc/ssh/sshd_config; then
            log_ok "SSH аутентификация по ключам включена"
            score=$((score + 15))
        else
            log_warn "SSH аутентификация по ключам отключена"
        fi
        
        # Проверка группы ssh-users
        if grep -q "Match Group ssh-users" /etc/ssh/sshd_config; then
            log_ok "Настроена группа ssh-users для пользователей"
            score=$((score + 10))
        else
            log_warn "Группа ssh-users не настроена"
        fi
        
        if grep -q "Port 22" /etc/ssh/sshd_config && ! grep -q "#Port 22" /etc/ssh/sshd_config; then
            log_warn "SSH использует стандартный порт 22"
        else
            log_ok "SSH использует нестандартный порт"
            score=$((score + 10))
        fi
    fi
    
    return $score
}

# Проверка файрвола
check_firewall() {
    log_info "Проверка файрвола..."
    local score=0
    
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        log_ok "UFW активен"
        score=$((score + 20))
    else
        log_warn "UFW не активен"
    fi
    
    if iptables -L | grep -q "DROP"; then
        log_ok "Правила блокировки настроены"
        score=$((score + 15))
    else
        log_warn "Правила блокировки не настроены"
    fi
    
    return $score
}

# Проверка fail2ban
check_fail2ban() {
    log_info "Проверка Fail2ban..."
    local score=0
    
    if systemctl is-active --quiet fail2ban; then
        log_ok "Fail2ban активен"
        score=$((score + 20))
        
        # Проверка активных банов
        local banned_ips=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
        if [ "$banned_ips" -gt 0 ] 2>/dev/null; then
            log_warn "Заблокировано IP адресов: $banned_ips"
        fi
    else
        log_warn "Fail2ban не активен"
    fi
    
    return $score
}

# Проверка обновлений системы
check_system_updates() {
    log_info "Проверка обновлений системы..."
    local score=0
    
    if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
        local last_update=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp)
        local current_time=$(date +%s)
        local days_since_update=$(((current_time - last_update) / 86400))
        
        if [ $days_since_update -le 7 ]; then
            log_ok "Система обновлена ($days_since_update дней назад)"
            score=$((score + 15))
        elif [ $days_since_update -le 30 ]; then
            log_warn "Система не обновлялась $days_since_update дней"
            score=$((score + 5))
        else
            log_err "Система не обновлялась $days_since_update дней"
        fi
    else
        log_warn "Не удалось проверить обновления системы"
    fi
    
    return $score
}

# Проверка открытых портов
check_open_ports() {
    log_info "Проверка открытых портов..."
    local score=0
    
    # Проверка критических портов
    local critical_ports=(22 23 21 3389 5900)
    local open_critical=0
    
    for port in "${critical_ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warn "Критический порт $port открыт"
            open_critical=$((open_critical + 1))
        fi
    done
    
    if [ $open_critical -eq 0 ]; then
        log_ok "Критические порты закрыты"
        score=$((score + 15))
    else
        score=$((score - $((open_critical * 5))))
    fi
    
    # Показываем все открытые порты
    log_info "Открытые порты:"
    netstat -tlnp 2>/dev/null | grep LISTEN | while read line; do
        echo "  $line"
    done
    
    return $score
}

# Проверка подозрительной активности
check_suspicious_activity() {
    log_info "Проверка подозрительной активности..."
    local score=0
    
    # Проверка неудачных попыток входа
    local failed_attempts=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    if [ "$failed_attempts" -gt 100 ]; then
        log_warn "Много неудачных попыток входа: $failed_attempts"
        score=$((score - 10))
    else
        log_ok "Неудачных попыток входа: $failed_attempts"
        score=$((score + 5))
    fi
    
    # Проверка подозрительных процессов
    local suspicious_processes=$(ps aux | grep -E "(crypto|miner|bot|scan)" | grep -v grep | wc -l)
    if [ "$suspicious_processes" -gt 0 ]; then
        log_err "Обнаружены подозрительные процессы: $suspicious_processes"
        score=$((score - 20))
    else
        log_ok "Подозрительные процессы не обнаружены"
        score=$((score + 10))
    fi
    
    return $score
}

    # Проверка файловой безопасности
    check_file_security() {
        log_info "Проверка файловой безопасности..."
        local score=0
        
        # Проверка прав на конфигурационные файлы
        local config_files=("/etc/ssh/sshd_config" "/etc/fail2ban/jail.local" "/etc/nginx/nginx.conf")
        for file in "${config_files[@]}"; do
            if [ -f "$file" ]; then
                local perms=$(stat -c %a "$file")
                if [ "$perms" = "600" ] || [ "$perms" = "644" ]; then
                    log_ok "Права на $file корректны: $perms"
                    score=$((score + 5))
                else
                    log_warn "Некорректные права на $file: $perms"
                fi
            fi
        done
        
        return $score
    }
    
    # Проверка пользователей согласно политике безопасности
    check_users_policy() {
        log_info "Проверка пользователей согласно политике безопасности..."
        local score=0
        
        # Загружаем политику безопасности
        if [ -f "$PROJECT_ROOT/system/security/security_policy.sh" ]; then
            source "$PROJECT_ROOT/system/security/security_policy.sh"
            
            # Проверяем наличие пользователей мониторинга
            local monitoring_users=("TrafficMetrics" "TrafficMonitor" "TrafficLogger" "TrafficNode" "TrafficPush" "TrafficFail2Ban")
            local found_users=0
            
            for username in "${monitoring_users[@]}"; do
                if id "$username" &>/dev/null; then
                    log_ok "Пользователь $username существует"
                    found_users=$((found_users + 1))
                else
                    log_warn "Пользователь $username не найден"
                fi
            done
            
            if [ $found_users -eq ${#monitoring_users[@]} ]; then
                log_ok "Все пользователи мониторинга созданы согласно политике"
                score=$((score + 15))
            else
                log_warn "Не все пользователи мониторинга созданы"
            fi
            
            # Проверяем группу ssh-users
            if getent group ssh-users >/dev/null 2>&1; then
                log_ok "Группа ssh-users существует"
                score=$((score + 5))
            else
                log_warn "Группа ssh-users не найдена"
            fi
        else
            log_warn "Файл политики безопасности не найден"
        fi
        
        return $score
    }

# Главная функция проверки
main_security_check() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              ПРОВЕРКА БЕЗОПАСНОСТИ 🔒                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    local total_score=0
    
    # Выполняем все проверки
    check_ssh_security
    total_score=$((total_score + $?))
    
    check_firewall
    total_score=$((total_score + $?))
    
    check_fail2ban
    total_score=$((total_score + $?))
    
    check_system_updates
    total_score=$((total_score + $?))
    
    check_open_ports
    total_score=$((total_score + $?))
    
    check_suspicious_activity
    total_score=$((total_score + $?))
    
    check_file_security
    total_score=$((total_score + $?))
    
    check_users_policy
    total_score=$((total_score + $?))
    
    # Вывод результатов
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    РЕЗУЛЬТАТЫ ПРОВЕРКИ                  ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║ Общий балл безопасности: $total_score/100"
    
    if [ $total_score -ge 80 ]; then
        echo "║ Статус: ОТЛИЧНО ✅"
        echo "║ Система хорошо защищена"
    elif [ $total_score -ge 60 ]; then
        echo "║ Статус: ХОРОШО ✅"
        echo "║ Система защищена, но есть возможности для улучшения"
    elif [ $total_score -ge 40 ]; then
        echo "║ Статус: СРЕДНЕ ⚠️"
        echo "║ Требуется улучшение безопасности"
    else
        echo "║ Статус: КРИТИЧНО ❌"
        echo "║ Требуется немедленное улучшение безопасности"
    fi
    
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # Рекомендации
    if [ $total_score -lt 80 ]; then
        echo "📋 РЕКОМЕНДАЦИИ ПО УЛУЧШЕНИЮ БЕЗОПАСНОСТИ:"
        echo "1. Отключите root доступ по SSH"
        echo "2. Настройте аутентификацию по ключам"
        echo "3. Активируйте UFW файрвол"
        echo "4. Настройте fail2ban"
        echo "5. Регулярно обновляйте систему"
        echo "6. Проверяйте логи безопасности"
        echo ""
        echo "📖 Подробные инструкции: cat PRODUCTION_SECURITY.md"
    fi
}

# Запуск проверки
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    main_security_check
fi
