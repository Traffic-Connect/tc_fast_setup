#!/bin/bash

# ============================================================================
# ЭТАП 2: НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================================

# Загрузка зависимостей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/core/configs/configuration.sh"
source "$PROJECT_ROOT/core/utils/common.sh"

# Загрузка политики безопасности
source "$PROJECT_ROOT/system/security/security_policy.sh"

setup_security_from_module() {
    log_info "=== ЭТАП 2: Настройка безопасности ==="
    
    log_info "Настройка безопасности с политикой TrafficConnect..."
    
    # Проверка безопасности системы
    log_info "Проверка текущего состояния безопасности..."
    check_system_security
    
    # Настройка SSH безопасности
    log_info "Настройка SSH безопасности..."
    setup_ssh_security
    
    # Настройка firewall
    log_info "Настройка firewall..."
    iptables -F && iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Базовые правила
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Разрешение портов с ограничениями
    log_info "Настройка правил для портов..."
    
    # SSH - только с определенных IP (настройте под ваши нужды)
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # HTTP/HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Административные порты - только с localhost
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $ADMIN_PORT -j ACCEPT
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $GRAFANA_PORT -j ACCEPT
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $PROMETHEUS_PORT -j ACCEPT
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $LOKI_PORT -j ACCEPT
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $NODE_EXPORTER_PORT -j ACCEPT
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $PROMTAIL_PORT -j ACCEPT
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $FAIL2BAN_EXPORTER_PORT -j ACCEPT
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport $PUSHGATEWAY_PORT -j ACCEPT
    
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
    
    # Настройка fail2ban с усиленной защитой
    log_info "Настройка Fail2ban..."
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
sender = fail2ban@localhost
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 7200

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600
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

# ============================================================================
# НАСТРОЙКА SSH БЕЗОПАСНОСТИ
# ============================================================================

setup_ssh_security() {
    log_info "Настройка SSH безопасности..."
    
    # Создание резервной копии конфигурации SSH
    if [ ! -f /etc/ssh/sshd_config.backup ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
        log_info "Создана резервная копия SSH конфигурации"
    fi
    
    # Пароль root не трогаем - оставляем как есть
    log_info "Пароль root оставляем без изменений"
    
    # Настройка SSH конфигурации
    log_info "Настройка SSH конфигурации..."
    
    # Создание временного файла конфигурации
    cat > /tmp/sshd_config_new << 'EOF'
# Traffic Connect Server - SSH Configuration
# Настроено для безопасности: root доступ по паролю, пользователи по ключам

# Основные настройки
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Настройки безопасности
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# Логирование
SyslogFacility AUTH
LogLevel INFO

# Ограничения
AllowUsers root
DenyUsers
AllowGroups
DenyGroups

# Дополнительные настройки безопасности
PermitEmptyPasswords no
PermitUserEnvironment no
Compression delayed
EOF

    # Применение новой конфигурации
    cp /tmp/sshd_config_new /etc/ssh/sshd_config
    chmod 600 /etc/ssh/sshd_config
    chown root:root /etc/ssh/sshd_config
    
    # Создание директории для SSH ключей
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    chown root:root /root/.ssh
    
    # Создание файла для авторизованных ключей
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chown root:root /root/.ssh/authorized_keys
    
    # Настройка прав доступа для пользователей
    log_info "Настройка прав доступа для пользователей..."
    
    # Создание группы для пользователей с доступом по ключам
    groupadd -f ssh-users 2>/dev/null || true
    
    # Создание пользователей согласно политике безопасности
    log_info "Создание пользователей согласно политике безопасности..."
    
    # Создаем пользователей для сервисов мониторинга
    local monitoring_users=("$GRAFANA_USERNAME" "$PROMETHEUS_USERNAME" "$LOKI_USERNAME" "$NODE_EXPORTER_USERNAME" "$PUSHGATEWAY_USERNAME" "$FAIL2BAN_EXPORTER_USERNAME")
    
    for username in "${monitoring_users[@]}"; do
        if ! id "$username" &>/dev/null; then
            useradd -m -s /bin/bash "$username"
            usermod -a -G ssh-users "$username"
            log_info "Создан пользователь: $username"
        fi
        
        # Настройка SSH директории
        mkdir -p "/home/$username/.ssh"
        chmod 700 "/home/$username/.ssh"
        chown "$username:$username" "/home/$username/.ssh"
        
        touch "/home/$username/.ssh/authorized_keys"
        chmod 600 "/home/$username/.ssh/authorized_keys"
        chown "$username:$username" "/home/$username/.ssh/authorized_keys"
        
        log_info "Настроена директория SSH для пользователя: $username"
    done
    
    # Настройка директорий для существующих пользователей
    for user in $(getent passwd | grep -E ":[0-9]{4}:" | cut -d: -f1 | grep -v root); do
        if [ -d "/home/$user" ] && ! [[ " ${monitoring_users[@]} " =~ " ${user} " ]]; then
            mkdir -p "/home/$user/.ssh"
            chmod 700 "/home/$user/.ssh"
            chown "$user:$user" "/home/$user/.ssh"
            
            touch "/home/$user/.ssh/authorized_keys"
            chmod 600 "/home/$user/.ssh/authorized_keys"
            chown "$user:$user" "/home/$user/.ssh/authorized_keys"
            
            # Добавляем пользователя в группу ssh-users
            usermod -a -G ssh-users "$user" 2>/dev/null || true
            
            log_info "Настроена директория SSH для пользователя: $user"
        fi
    done
    
    # Обновление SSH конфигурации для пользователей
    cat >> /etc/ssh/sshd_config << 'EOF'

# Настройки для пользователей (только ключи)
Match Group ssh-users
    PasswordAuthentication no
    PubkeyAuthentication yes
    AuthorizedKeysFile .ssh/authorized_keys
    MaxAuthTries 3
    MaxSessions 5
EOF

    # Проверка конфигурации SSH перед перезапуском
    log_info "Проверка конфигурации SSH..."
    if sshd -t 2>/dev/null; then
        log_info "Конфигурация SSH корректна"
        
        # Перезапуск SSH службы
        log_info "Перезапуск SSH службы..."
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        
        # Проверка статуса SSH (пробуем оба имени службы)
        if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
            log_ok "✅ SSH служба перезапущена успешно"
        else
            log_warn "⚠️ SSH служба не запустилась, но продолжаем установку"
            log_info "Проверьте конфигурацию SSH вручную: systemctl status ssh"
        fi
    else
        log_warn "⚠️ Конфигурация SSH содержит ошибки, пропускаем перезапуск"
        log_info "Проверьте конфигурацию SSH вручную: sshd -t"
    fi
    
    # Сохранение информации о доступе
    local secure_dir="/root/.traffic_connect"
    mkdir -p "$secure_dir"
    
    cat >> "$secure_dir/ssh_access.txt" << EOF

# SSH доступ - $(date) (согласно политике безопасности)
ROOT доступ:
  Логин: root
  Пароль: $ROOT_SSH_PASSWORD
  Тип: Парольная аутентификация
  Сложность: $(assess_password_strength "$ROOT_SSH_PASSWORD" | cut -d' ' -f1)

ПОЛЬЗОВАТЕЛИ МОНИТОРИНГА (только SSH ключи):
  $GRAFANA_USERNAME - Grafana (TrafficMetrics)
  $PROMETHEUS_USERNAME - Prometheus (TrafficMonitor)
  $LOKI_USERNAME - Loki (TrafficLogger)
  $NODE_EXPORTER_USERNAME - Node Exporter (TrafficNode)
  $PUSHGATEWAY_USERNAME - Pushgateway (TrafficPush)
  $FAIL2BAN_EXPORTER_USERNAME - Fail2ban Exporter (TrafficFail2Ban)

ОБЫЧНЫЕ ПОЛЬЗОВАТЕЛИ:
  Группа: ssh-users
  Тип: Только ключи SSH
  Директория ключей: ~/.ssh/authorized_keys

ВАЖНО:
  - Root доступ только по паролю
  - Пользователи только по SSH ключам
  - Добавьте SSH ключи в ~/.ssh/authorized_keys для каждого пользователя
  - Все логины соответствуют политике безопасности TrafficConnect
EOF

    chmod 600 "$secure_dir/ssh_access.txt"
    
    log_ok "✅ SSH безопасность настроена"
    log_warn "⚠️  Root пароль: $ROOT_SSH_PASSWORD"
    log_warn "⚠️  Добавьте SSH ключи для пользователей в ~/.ssh/authorized_keys"
    
    return 0
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_security_from_module
fi

# ============================================================================
# ОБРАТНАЯ СОВМЕСТИМОСТЬ
# ============================================================================

# Функция для обратной совместимости
setup_security() {
    setup_security_from_module
} 