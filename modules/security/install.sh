#!/bin/bash

# ============================================================================
# ЭТАП 2: НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/scripts/configuration.sh"
source "$PROJECT_ROOT/scripts/libraries/common.sh"

setup_security() {
    log_info "=== ЭТАП 2: Настройка безопасности ==="
    
    log_info "Настройка безопасности..."
    
    # Настройка firewall
    log_info "Настройка firewall..."
    iptables -F && iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Базовые правила
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Разрешение портов
    log_info "Настройка правил для портов..."
    for port in 22 80 443 $ADMIN_PORT $GRAFANA_PORT $PROMETHEUS_PORT $LOKI_PORT $NODE_EXPORTER_PORT $PROMTAIL_PORT $FAIL2BAN_EXPORTER_PORT $PUSHGATEWAY_PORT; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    done
    
    # Разрешение Cloudflare IPs
    log_info "Настройка правил для Cloudflare..."
    for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
        iptables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT
    done
    
    # Защита от атак
    log_info "Настройка защиты от атак..."
    iptables -N SYN_FLOOD
    iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    iptables -A SYN_FLOOD -m limit --limit 10/s --limit-burst 25 -j RETURN
    iptables -A SYN_FLOOD -j DROP
    
    # Сохранение правил iptables
    log_info "Сохранение правил iptables..."
    netfilter-persistent save
    
    # Настройка fail2ban
    log_info "Настройка Fail2ban..."
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 1h
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
EOF

    systemctl enable fail2ban
    systemctl start fail2ban
    
    # Проверка установки
    if systemctl is-active --quiet fail2ban; then
        log_ok "✅ Fail2ban запущен"
    else
        log_err "❌ Ошибка запуска Fail2ban"
        return 1
    fi
    
    log_ok "✅ Этап 2 завершен успешно"
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_security
fi 