#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция настройки fail2ban
setup_fail2ban() {
    print_header "🛡️ НАСТРОЙКА FAIL2BAN"
    
    # Создаем конфигурацию fail2ban
    create_fail2ban_config
    
    # Создаем фильтры
    create_fail2ban_filters
    
    # Запускаем fail2ban
    systemctl enable --now fail2ban
    
    check_error "Настройка fail2ban"
}

# Функция создания конфигурации fail2ban
create_fail2ban_config() {
    cat > /etc/fail2ban/jail.local <<EOL
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

[nginx-botsearch]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 10
findtime = 3600
bantime = 86400

[nginx-dos]
enabled = true
port = http,https
filter = nginx-dos
logpath = /var/log/nginx/access.log
maxretry = 100
findtime = 300
bantime = 3600
EOL
}

# Функция создания фильтров fail2ban
create_fail2ban_filters() {
    cat > /etc/fail2ban/filter.d/nginx-dos.conf <<EOL
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" (404|503|400|499) .*$
ignoreregex =
EOL
}
