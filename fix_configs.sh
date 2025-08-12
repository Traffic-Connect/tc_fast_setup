#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Символы
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="->"

echo -e "${BLUE}${BOLD}🔧 ИСПРАВЛЕНИЕ КОНФИГУРАЦИЙ СЕРВИСОВ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Функция создания правильного web.yml для Prometheus
fix_prometheus_config() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ PROMETHEUS${NC}"
    echo -e "${PURPLE}========================${NC}"
    
    # Создаем правильный web.yml
    cat > /etc/prometheus/web.yml << 'EOF'
basic_auth_users:
    TrafficPrometheus: $2y$10$EL8YcD649BB80rZM
EOF
    
    # Устанавливаем правильные права
    chown prometheus:prometheus /etc/prometheus/web.yml
    chmod 600 /etc/prometheus/web.yml
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурация Prometheus исправлена"
    echo ""
}

# Функция создания правильного web.yml для Pushgateway
fix_pushgateway_config() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ PUSHGATEWAY${NC}"
    echo -e "${PURPLE}==========================${NC}"
    
    # Создаем правильный web.yml
    cat > /etc/pushgateway/web.yml << 'EOF'
basic_auth_users:
    TrafficPushgateway: $2y$10$9MBikpzCHrDeey3
EOF
    
    # Устанавливаем правильные права
    chown pushgateway:pushgateway /etc/pushgateway/web.yml
    chmod 600 /etc/pushgateway/web.yml
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурация Pushgateway исправлена"
    echo ""
}

# Функция исправления конфигурации Loki
fix_loki_config() {
    echo -e "${PURPLE}${BOLD}🔧 ИСПРАВЛЕНИЕ LOKI${NC}"
    echo -e "${PURPLE}==================${NC}"
    
    # Создаем правильную конфигурацию Loki
    cat > /etc/loki/loki-config.yaml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  http_listen_address: 0.0.0.0
  grpc_listen_port: 9096
  grpc_listen_address: 0.0.0.0

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

ruler:
  alertmanager_url: http://localhost:9093
EOF
    
    # Устанавливаем правильные права
    chown loki:loki /etc/loki/loki-config.yaml
    chmod 644 /etc/loki/loki-config.yaml
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Конфигурация Loki исправлена"
    echo ""
}

# Функция создания пользователей для Loki
create_loki_users() {
    echo -e "${CYAN}${ARROW}${NC} Создание пользователей Loki..."
    
    # Создаем файл пользователей
    cat > /etc/loki/users.yaml << 'EOF'
users:
  TrafficLoki:
    password: 6wnakjz8nvEV1YAf
EOF
    
    chown loki:loki /etc/loki/users.yaml
    chmod 600 /etc/loki/users.yaml
    
    echo -e "  ${GREEN}${CHECK_MARK}${NC} Пользователи Loki созданы"
    echo ""
}

# Функция перезапуска сервисов
restart_services() {
    echo -e "${PURPLE}${BOLD}🔄 ПЕРЕЗАПУСК СЕРВИСОВ${NC}"
    echo -e "${PURPLE}======================${NC}"
    
    # Перезапускаем сервисы
    for service in prometheus pushgateway loki; do
        echo -e "${CYAN}${ARROW}${NC} Перезапуск $service..."
        systemctl restart $service
        sleep 3
        
        if systemctl is-active --quiet $service; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $service: АКТИВЕН"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $service: НЕ АКТИВЕН"
        fi
    done
    
    echo ""
}

# Функция проверки портов
check_ports() {
    echo -e "${PURPLE}${BOLD}🌐 ПРОВЕРКА ПОРТОВ${NC}"
    echo -e "${PURPLE}================${NC}"
    
    # Ждем немного для запуска сервисов
    echo -e "${CYAN}${ARROW}${NC} Ожидание запуска сервисов..."
    sleep 5
    
    # Проверяем порты
    for port in 9090 9091 3100; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} Порт $port: ОТКРЫТ"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} Порт $port: ЗАКРЫТ"
        fi
    done
    
    echo ""
}

# Основная логика
echo -e "${CYAN}${ARROW}${NC} Начинаем исправление конфигураций..."

# Исправляем конфигурации
fix_prometheus_config
fix_pushgateway_config
fix_loki_config
create_loki_users

# Перезапускаем сервисы
restart_services

# Проверяем порты
check_ports

echo -e "${GREEN}${BOLD}✅ ИСПРАВЛЕНИЕ ЗАВЕРШЕНО${NC}"
echo -e "${GREEN}========================${NC}"
echo ""
echo -e "${YELLOW}💡 Результат:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: http://$(hostname -I | awk '{print $1}'):9091"
echo -e "  ${CYAN}${ARROW}${NC} Loki: http://$(hostname -I | awk '{print $1}'):3100"
echo ""
echo -e "${YELLOW}🔐 Данные для входа:${NC}"
echo -e "  ${CYAN}${ARROW}${NC} Prometheus: TrafficPrometheus / EL8YcD649BB80rZM"
echo -e "  ${CYAN}${ARROW}${NC} Pushgateway: TrafficPushgateway / 9MBikpzCHrDeey3"
echo -e "  ${CYAN}${ARROW}${NC} Loki: TrafficLoki / 6wnakjz8nvEV1YAf"
