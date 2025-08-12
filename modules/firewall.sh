#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция настройки файрвола
setup_firewall() {
    print_header "🔥 НАСТРОЙКА ФАЙРВОЛА"
    log_message "INFO" "Начинаем настройку файрвола"
    
    # Загружаем и запускаем скрипт настройки файрвола
    log_message "INFO" "Загрузка firewall_fixed.sh..."
    if wget -q https://raw.githubusercontent.com/Traffic-Connect/tc_fast_setup/main/firewall_fixed.sh -O /tmp/firewall_fixed.sh; then
        chmod +x /tmp/firewall_fixed.sh
        log_message "INFO" "Запуск firewall_fixed.sh..."
        bash /tmp/firewall_fixed.sh
        rm -f /tmp/firewall_fixed.sh
    else
        log_message "WARNING" "Не удалось загрузить firewall_fixed.sh, настраиваем базовый файрвол"
        setup_basic_firewall
    fi
}

# Функция базовой настройки файрвола
setup_basic_firewall() {
    log_message "INFO" "Базовая настройка файрвола..."
    
    # Определяем тип файрвола
    if command -v nft >/dev/null 2>&1; then
        log_message "INFO" "Using nftables (modern firewall)"
        setup_nftables
    else
        log_message "INFO" "Using iptables"
        setup_iptables
    fi
    
    log_message "SUCCESS" "Базовая настройка файрвола завершена"
}

# Функция настройки nftables
setup_nftables() {
    cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        tcp dport { 22, 80, 443, 3000, 9090, 9100, 3100, 9080, 9191, 9091 } accept
        udp dport 53 accept
        tcp dport 53 accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output { type filter hook output priority 0; policy accept; }
}
EOF
    nft -f /etc/nftables.conf
    systemctl enable nftables
    systemctl start nftables
}

# Функция настройки iptables
setup_iptables() {
    iptables -F
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    for port in 22 80 443 3000 9090 9100 3100 9080 9191 9091; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    done
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    netfilter-persistent save 2>/dev/null || true
}
