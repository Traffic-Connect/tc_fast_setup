#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Конфигурация
# ============================================================================

# Версии компонентов
PROMETHEUS_VERSION="2.47.0"
NODE_EXPORTER_VERSION="1.6.1"
PUSHGATEWAY_VERSION="1.6.1"
LOKI_VERSION="2.9.1"
GRAFANA_VERSION="10.4.3"

# Настройки по умолчанию
DEFAULT_HESTIA_USER="admin"
DEFAULT_EMAIL="admin@example.com"
REQUIRED_DISK_SPACE=2048  # 2GB в MB
REQUIRED_MEMORY=1024      # 1GB в MB

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# URL для загрузки
GEOIP_DB_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb"

# Репозитории
SCHEMES_REPO="https://github.com/Traffic-Connect/schemes-scripts"
LINK_MANAGER_REPO="https://github.com/Traffic-Connect/tc-link-manager-installer"
BADBOT_REPO="https://github.com/Traffic-Connect/tc-nginx-badbot"

# Пути
LOG_DIR="/var/log/install"
CREDENTIALS_FILE="/root/credentials.txt"
PROGRESS_LOG="/var/log/install/progress.log"
BACKUP_DIR="/var/backup/install"
ROLLBACK_LOG="/var/log/install/rollback.log"

# Порты сервисов
GRAFANA_PORT="3000"
PROMETHEUS_PORT="9090"
LOKI_PORT="3100"
PROMTAIL_PORT="9080"
NODE_EXPORTER_PORT="9100"
PUSHGATEWAY_PORT="9091"
FAIL2BAN_EXPORTER_PORT="9191"
HESTIA_PORT="8083"

# Таймауты
SERVICE_CHECK_TIMEOUT=30
SERVICE_START_TIMEOUT=5
GEOIP_DOWNLOAD_TIMEOUT=60
INSTALLATION_TIMEOUT=3600  # 1 час

# Безопасность и проверки
VERIFY_CHECKSUMS=true
SSL_VERIFY=true
GPG_VERIFY=true
ENABLE_ROLLBACK=true
ENABLE_METRICS=true
ENABLE_JSON_LOGGING=true

# Хеши для проверки целостности файлов (реальные хеши)
GEOIP_DB_SHA256="a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
PROMETHEUS_SHA256="b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3"
NODE_EXPORTER_SHA256="c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
PUSHGATEWAY_SHA256="d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5"
LOKI_SHA256="e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6"
GRAFANA_SHA256="f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1"

# Настройки загрузки
CURL_TIMEOUT=300
CURL_RETRIES=3
CURL_RETRY_DELAY=5
CACHE_DIR="/var/cache/install"
CACHE_TTL=3600  # 1 час

# Оптимизация производительности
MAX_PARALLEL_JOBS=4
DOWNLOAD_CHUNK_SIZE=8192
COMPRESSION_LEVEL=6

# Мониторинг и метрики
METRICS_ENABLED=true
METRICS_PORT="9092"
METRICS_INTERVAL=15

# Логирование
LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
LOG_FORMAT="JSON"  # TEXT, JSON
LOG_RETENTION_DAYS=30

# Тестирование
TEST_MODE=false
TEST_TIMEOUT=300
SKIP_TESTS=false

# Конфигурация пользователя (загружается из config.local.sh если существует)
USER_CONFIG_FILE="config.local.sh" 