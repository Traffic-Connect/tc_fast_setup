#!/bin/bash
# ============================================================================
# Traffic Connect Server Installation - Конфигурация
# ============================================================================
# ВНИМАНИЕ: Все переменные должны быть определены только в этом файле!
# Другие файлы должны ссылаться на переменные из этого файла.
# Для пользовательских настроек используйте config.local.sh

# ============================================================================
# ВЕРСИИ КОМПОНЕНТОВ
# ============================================================================

PROMETHEUS_VERSION="2.47.0"
NODE_EXPORTER_VERSION="1.6.1"
PUSHGATEWAY_VERSION="1.6.1"
LOKI_VERSION="2.9.1"
GRAFANA_VERSION="10.4.3"

# ============================================================================
# СИСТЕМНЫЕ НАСТРОЙКИ ПО УМОЛЧАНИЮ
# ============================================================================

DEFAULT_HESTIA_USER="admin"
DEFAULT_EMAIL="info@domain.tld"
REQUIRED_DISK_SPACE=2048  # 2GB в MB
REQUIRED_MEMORY=1024      # 1GB в MB

# ============================================================================
# ЦВЕТА ДЛЯ ВЫВОДА
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# URL И РЕПОЗИТОРИИ
# ============================================================================

GEOIP_DB_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb"
SCHEMES_REPO="https://github.com/Traffic-Connect/schemes-scripts"
LINK_MANAGER_REPO="https://github.com/Traffic-Connect/tc-link-manager-installer"
BADBOT_REPO="https://github.com/Traffic-Connect/tc-nginx-badbot"

# ============================================================================
# ПУТИ И ФАЙЛЫ
# ============================================================================

LOG_DIR="/var/log/install"
CREDENTIALS_FILE="/root/credentials.txt"
PROGRESS_LOG="/var/log/install/progress.log"
BACKUP_DIR="/var/backup/install"
ROLLBACK_LOG="/var/log/install/rollback.log"

# ============================================================================
# ПОРТЫ СЕРВИСОВ
# ============================================================================

GRAFANA_PORT="3000"
PROMETHEUS_PORT="9090"
LOKI_PORT="3100"
PROMTAIL_PORT="9080"
NODE_EXPORTER_PORT="9100"
PUSHGATEWAY_PORT="9091"
FAIL2BAN_EXPORTER_PORT="9191"
HESTIA_PORT="8083"

# ============================================================================
# ТАЙМАУТЫ
# ============================================================================

SERVICE_CHECK_TIMEOUT=30
SERVICE_START_TIMEOUT=5
GEOIP_DOWNLOAD_TIMEOUT=60
INSTALLATION_TIMEOUT=3600  # 1 час

# ============================================================================
# БЕЗОПАСНОСТЬ И ПРОВЕРКИ
# ============================================================================

VERIFY_CHECKSUMS=true
SSL_VERIFY=true
GPG_VERIFY=true
ENABLE_ROLLBACK=true
ENABLE_METRICS=true
ENABLE_JSON_LOGGING=true

# Хеши для проверки целостности файлов (заглушки - нужно заменить на реальные)
GEOIP_DB_SHA256=""
PROMETHEUS_SHA256=""
NODE_EXPORTER_SHA256=""
PUSHGATEWAY_SHA256=""
LOKI_SHA256=""
GRAFANA_SHA256=""

# ============================================================================
# НАСТРОЙКИ ЗАГРУЗКИ И КЭШИРОВАНИЯ
# ============================================================================

CURL_TIMEOUT=300
CURL_RETRIES=3
CURL_RETRY_DELAY=5
CACHE_DIR="/var/cache/install"
CACHE_TTL=3600  # 1 час

# ============================================================================
# ОПТИМИЗАЦИЯ ПРОИЗВОДИТЕЛЬНОСТИ
# ============================================================================

MAX_PARALLEL_JOBS=4
DOWNLOAD_CHUNK_SIZE=8192
COMPRESSION_LEVEL=6

# ============================================================================
# МОНИТОРИНГ И МЕТРИКИ
# ============================================================================

METRICS_ENABLED=true
METRICS_PORT="9092"
METRICS_INTERVAL=15

# ============================================================================
# ЛОГИРОВАНИЕ
# ============================================================================

LOG_LEVEL="INFO"
LOG_FORMAT="TEXT"
LOG_RETENTION_DAYS=7

# ============================================================================
# КОНФИГУРАЦИЯ ПОЛЬЗОВАТЕЛЯ
# ============================================================================

# Файл пользовательской конфигурации (загружается если существует)
USER_CONFIG_FILE="config.local.sh"

# Настройки сложности паролей
PASSWORD_COMPLEXITY="high"  # low, medium, high

# ============================================================================
# НАСТРОЙКИ HESTIA CONTROL PANEL
# ============================================================================

# Базовые настройки системы
HESTIA_USER="${DEFAULT_HESTIA_USER}"
EMAIL="${DEFAULT_EMAIL}"
HOSTNAME="hostname.domain.tld"

# Настройки Hestia CP
HESTIA_HOSTNAME="${HOSTNAME}"
HESTIA_EMAIL="${EMAIL}"
HESTIA_USERNAME="Trafficadmin"

# Настройки установки Hestia CP
HESTIA_LANG="ru"                            # Язык интерфейса
HESTIA_APACHE="no"                          # Установка Apache (yes/no)
HESTIA_NAMED="no"                           # Установка BIND (yes/no)
HESTIA_EXIM="no"                            # Установка Exim (yes/no)
HESTIA_DOVECOT="no"                         # Установка Dovecot (yes/no)
HESTIA_CLAMAV="no"                          # Установка ClamAV (yes/no)
HESTIA_SPAMASSASSIN="no"                    # Установка SpamAssassin (yes/no)
HESTIA_FORCE="--force"                      # Принудительная установка

# Алиасы для совместимости (используются в скриптах)
LANG="${HESTIA_LANG}"
APACHE="${HESTIA_APACHE}"
NAMED="${HESTIA_NAMED}"
EXIM="${HESTIA_EXIM}"
DOVECOT="${HESTIA_DOVECOT}"
CLAMAV="${HESTIA_CLAMAV}"
SPAMASSASSIN="${HESTIA_SPAMASSASSIN}"
FORCE="${HESTIA_FORCE}"

# ============================================================================
# НАСТРОЙКИ ПАРОЛЕЙ
# ============================================================================
# ВНИМАНИЕ: Если пароли не указаны, они будут сгенерированы автоматически
# Для безопасности рекомендуется указать собственные пароли

# HESTIA_PASSWORD="your-secure-password"   # Пароль Hestia CP
# GRAFANA_PASSWORD="your-secure-password"  # Пароль Grafana

# ============================================================================
# ПРИМЕРЫ НАСТРОЕК
# ============================================================================
# Раскомментируйте и измените нужные строки для вашей конфигурации

# Для продакшена:
# HESTIA_HOSTNAME="server1.example.com"
# HESTIA_EMAIL="admin@example.com"
# HESTIA_USERNAME="admin"
# HESTIA_PASSWORD="your-very-secure-password"
# GRAFANA_PASSWORD="your-very-secure-password"

# Для тестирования:
# HESTIA_HOSTNAME="test.local"
# HESTIA_EMAIL="test@local.dev"
# HESTIA_USERNAME="testadmin"
# HESTIA_APACHE="yes"
# HESTIA_NAMED="yes"

# Для разработки:
# HESTIA_HOSTNAME="dev.example.com"
# HESTIA_EMAIL="dev@example.com"
# HESTIA_USERNAME="developer"
# HESTIA_LANG="en"
# HESTIA_APACHE="yes"
# HESTIA_NAMED="yes"
# HESTIA_EXIM="yes"
# HESTIA_DOVECOT="yes"

# ============================================================================
# ИНСТРУКЦИИ ПО НАСТРОЙКЕ
# ============================================================================
# 1. Скопируйте этот файл в config.local.sh для пользовательских настроек:
#    cp configuration.sh config.local.sh
#
# 2. Отредактируйте config.local.sh и измените нужные значения
#
# 3. Убедитесь, что пароли достаточно сложные (минимум 12 символов)
#
# 4. Проверьте, что все URL и домены корректны
#
# 5. Для продакшена обязательно измените пароли по умолчанию 