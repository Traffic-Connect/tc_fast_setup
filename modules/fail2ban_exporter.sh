#!/bin/bash

# Подключаем утилиты
source "$(dirname "$0")/../core/utils.sh"

# Функция настройки экспортера для fail2ban
setup_fail2ban_exporter() {
    print_header "📊 НАСТРОЙКА МОНИТОРИНГА FAIL2BAN"
    log_message "INFO" "Настройка экспортера для fail2ban"
    
    {
        apt-get install -y python3-prometheus-client
        
        create_fail2ban_exporter_script
        create_fail2ban_exporter_service

        systemctl daemon-reload
        systemctl enable --now fail2ban_exporter
    } > /dev/null 2>&1
    
    check_error "Настройка мониторинга fail2ban"
}

# Функция создания скрипта экспортера fail2ban
create_fail2ban_exporter_script() {
    cat <<'EOF' | tee /usr/local/bin/fail2ban_exporter.py
from prometheus_client import start_http_server, Gauge
import subprocess
import time

banned_ips = Gauge('fail2ban_banned_ips', 'Number of banned IPs by fail2ban')

def collect():
    try:
        output = subprocess.check_output(["fail2ban-client", "status"])
        banned = 0
        for line in output.decode().splitlines():
            if "Total banned" in line:
                banned = int(line.split(":")[1].strip())
        banned_ips.set(banned)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    start_http_server(9191)
    while True:
        collect()
        time.sleep(15)
EOF

    chmod +x /usr/local/bin/fail2ban_exporter.py
}

# Функция создания systemd сервиса экспортера fail2ban
create_fail2ban_exporter_service() {
    cat <<EOF | tee /etc/systemd/system/fail2ban_exporter.service
[Unit]
Description=Fail2Ban Metrics Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/fail2ban_exporter.py

[Install]
WantedBy=multi-user.target
EOF
}
