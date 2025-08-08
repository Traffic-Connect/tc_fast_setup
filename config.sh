#!/bin/bash

# Configuration file for TC Fast Setup
# This file contains all configurable parameters

# =============================================================================
# SYSTEM CONFIGURATION
# =============================================================================

# Timezone
TIMEZONE="Europe/Moscow"

# System locale
LOCALE="ru_RU.UTF-8"

# =============================================================================
# HESTIA CP CONFIGURATION
# =============================================================================

# Hestia CP installation parameters
HESTIA_LANG="ru"
HESTIA_HOSTNAME="hostname"
HESTIA_USERNAME="TrafficAdmin"
HESTIA_EMAIL="info@domain.tld"
HESTIA_PASSWORD="AdMiNiStRaToR"

# Hestia CP components to install
HESTIA_APACHE="no"
HESTIA_NAMED="no"
HESTIA_EXIM="no"
HESTIA_DOVECOT="no"
HESTIA_CLAMAV="no"
HESTIA_SPAMASSASSIN="no"

# =============================================================================
# FIREWALL CONFIGURATION
# =============================================================================

# Firewall type preference (nftables/iptables/auto)
FIREWALL_TYPE="auto"

# SSH brute force protection
SSH_RATE_LIMIT="5/minute"
SSH_BURST_LIMIT="10"

# ICMP rate limiting
ICMP_RATE_LIMIT="1/second"

# SYN flood protection
SYN_FLOOD_RATE="10/second"
SYN_FLOOD_BURST="25"

# Port scanner protection
PORT_SCAN_RATE="1/second"

# =============================================================================
# MONITORING CONFIGURATION
# =============================================================================

# Grafana configuration
GRAFANA_VERSION="10.4.3"
GRAFANA_ADMIN_PASSWORD="admin"

# Prometheus configuration
PROMETHEUS_VERSION="2.47.0"
PROMETHEUS_SCRAPE_INTERVAL="15s"

# Node Exporter configuration
NODE_EXPORTER_VERSION="1.6.1"

# Pushgateway configuration
PUSHGATEWAY_VERSION="1.6.1"

# Loki configuration
LOKI_VERSION="2.9.1"
LOKI_QUERY_TIMEOUT="5m"

# Promtail configuration
PROMTAIL_VERSION="2.9.2"

# =============================================================================
# FAIL2BAN CONFIGURATION
# =============================================================================

# Fail2ban general settings
FAIL2BAN_IGNORE_IP="127.0.0.1/8"
FAIL2BAN_BANTIME="1h"
FAIL2BAN_FINDTIME="600"
FAIL2BAN_MAXRETRY="5"

# SSH jail settings
SSH_MAXRETRY="5"
SSH_FINDTIME="600"
SSH_BANTIME="1h"

# Nginx jail settings
NGINX_HTTP_AUTH_MAXRETRY="3"
NGINX_BOTSEARCH_MAXRETRY="10"
NGINX_BOTSEARCH_FINDTIME="3600"
NGINX_BOTSEARCH_BANTIME="86400"
NGINX_DOS_MAXRETRY="100"
NGINX_DOS_FINDTIME="300"
NGINX_DOS_BANTIME="3600"

# Hestia jail settings
HESTIA_AUTH_MAXRETRY="5"
HESTIA_AUTH_FINDTIME="600"
HESTIA_AUTH_BANTIME="86400"

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

# Cloudflare integration
ENABLE_CLOUDFLARE="yes"
CLOUDFLARE_TIMEOUT="10"

# Monitoring ports (localhost only)
MONITORING_PORTS="9090 9100 3100 9080 9191 9091"

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

# Log levels
LOG_LEVEL="info"

# Log retention
LOG_RETENTION_DAYS="30"

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

# Password policy
MIN_PASSWORD_LENGTH="12"
REQUIRE_SPECIAL_CHARS="yes"
REQUIRE_NUMBERS="yes"
REQUIRE_UPPERCASE="yes"

# Session timeout
SESSION_TIMEOUT="3600"

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

# Backup settings
ENABLE_BACKUPS="yes"
BACKUP_RETENTION_DAYS="7"
BACKUP_TIME="02:00"

# =============================================================================
# UPDATE CONFIGURATION
# =============================================================================

# Auto-update settings
ENABLE_AUTO_UPDATES="yes"
UPDATE_CHECK_INTERVAL="daily"
SECURITY_UPDATES_ONLY="no"

# =============================================================================
# PERFORMANCE CONFIGURATION
# =============================================================================

# Resource limits
MAX_CONNECTIONS="1000"
MAX_MEMORY_USAGE="80%"
MAX_CPU_USAGE="80%"

# Cache settings
ENABLE_CACHE="yes"
CACHE_SIZE="256M"
CACHE_TTL="3600"

# =============================================================================
# NOTIFICATION CONFIGURATION
# =============================================================================

# Email notifications
ENABLE_EMAIL_NOTIFICATIONS="no"
SMTP_SERVER=""
SMTP_PORT="587"
SMTP_USERNAME=""
SMTP_PASSWORD=""
NOTIFICATION_EMAIL=""

# =============================================================================
# ADVANCED CONFIGURATION
# =============================================================================

# Debug mode
DEBUG_MODE="no"

# Verbose output
VERBOSE_OUTPUT="no"

# Force installation
FORCE_INSTALLATION="no"

# Skip confirmation prompts
SKIP_CONFIRMATION="no"

# =============================================================================
# CUSTOM CONFIGURATION
# =============================================================================

# Custom packages to install
CUSTOM_PACKAGES=""

# Custom firewall rules
CUSTOM_FIREWALL_RULES=""

# Custom fail2ban rules
CUSTOM_FAIL2BAN_RULES=""

# Custom monitoring rules
CUSTOM_MONITORING_RULES=""

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate configuration
validate_config() {
    local errors=0
    
    # Check required fields
    if [ -z "$HESTIA_USERNAME" ]; then
        echo "ERROR: HESTIA_USERNAME is required"
        ((errors++))
    fi
    
    if [ -z "$HESTIA_PASSWORD" ]; then
        echo "ERROR: HESTIA_PASSWORD is required"
        ((errors++))
    fi
    
    if [ -z "$HESTIA_EMAIL" ]; then
        echo "ERROR: HESTIA_EMAIL is required"
        ((errors++))
    fi
    
    # Check password strength
    if [ ${#HESTIA_PASSWORD} -lt 8 ]; then
        echo "WARNING: HESTIA_PASSWORD is too short (minimum 8 characters)"
    fi
    
    # Check email format
    if [[ ! "$HESTIA_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "WARNING: HESTIA_EMAIL format may be invalid"
    fi
    
    # Check firewall type
    if [ "$FIREWALL_TYPE" != "auto" ] && [ "$FIREWALL_TYPE" != "nftables" ] && [ "$FIREWALL_TYPE" != "iptables" ]; then
        echo "ERROR: FIREWALL_TYPE must be 'auto', 'nftables', or 'iptables'"
        ((errors++))
    fi
    
    # Check versions
    if [ -z "$GRAFANA_VERSION" ] || [ -z "$PROMETHEUS_VERSION" ] || [ -z "$LOKI_VERSION" ]; then
        echo "ERROR: Version numbers are required"
        ((errors++))
    fi
    
    return $errors
}

# Load configuration from file
load_config() {
    if [ -f "$1" ]; then
        source "$1"
        echo "Configuration loaded from $1"
    else
        echo "Configuration file $1 not found, using defaults"
    fi
}

# Save configuration to file
save_config() {
    cat > "$1" <<EOF
# Generated configuration file
# Created: $(date)
# Version: 1.0

$(grep -E '^[A-Z_]+=' "$0" | grep -v '^#' | sort)
EOF
    echo "Configuration saved to $1"
}

# Export configuration for other scripts
export_config() {
    # Export all configuration variables
    export TIMEZONE HESTIA_LANG HESTIA_HOSTNAME HESTIA_USERNAME HESTIA_EMAIL HESTIA_PASSWORD
    export FIREWALL_TYPE SSH_RATE_LIMIT ICMP_RATE_LIMIT
    export GRAFANA_VERSION PROMETHEUS_VERSION LOKI_VERSION
    export FAIL2BAN_IGNORE_IP FAIL2BAN_BANTIME FAIL2BAN_FINDTIME FAIL2BAN_MAXRETRY
    export ENABLE_CLOUDFLARE MONITORING_PORTS
    export DEBUG_MODE VERBOSE_OUTPUT FORCE_INSTALLATION
}

# Main function
main() {
    case "$1" in
        "validate")
            validate_config
            ;;
        "load")
            load_config "$2"
            ;;
        "save")
            save_config "$2"
            ;;
        "export")
            export_config
            ;;
        "show")
            grep -E '^[A-Z_]+=' "$0" | grep -v '^#' | sort
            ;;
        *)
            echo "Usage: $0 {validate|load <file>|save <file>|export|show}"
            exit 1
            ;;
    esac
}

# If script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
