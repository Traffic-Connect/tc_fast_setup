#!/bin/bash

# Firewall management script
# Usage: ./fw.sh [command]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Root check
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This script must be run as root${NC}" 1>&2
    exit 1
fi

# Check firewall availability
check_firewall() {
    if command -v nft >/dev/null 2>&1 && nft list ruleset >/dev/null 2>&1; then
        echo "nftables"
        return 0
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
        return 0
    else
        echo -e "${RED}No firewall found. Please install nftables or iptables${NC}"
        return 1
    fi
}

# Error checking function
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] $1${NC}"
        return 1
    else
        echo -e "${GREEN}[OK] $1${NC}"
        return 0
    fi
}

# Status display function
show_status() {
    echo -e "${YELLOW}=== Firewall Status ===${NC}"
    
    FIREWALL_TYPE=$(check_firewall)
    if [ $? -eq 0 ]; then
        echo -e "${BLUE}Using: $FIREWALL_TYPE${NC}"
        echo -e "${GREEN}Rules are active${NC}"
        
        if [ "$FIREWALL_TYPE" = "nftables" ]; then
            echo -e "\n${YELLOW}Current rules:${NC}"
            nft list ruleset | head -20
            echo -e "\n${BLUE}... (showing first 20 lines)${NC}"
        else
            echo -e "\n${YELLOW}Current INPUT rules:${NC}"
            iptables -L INPUT -n --line-numbers
        fi
    else
        echo -e "${RED}Firewall not configured${NC}"
        exit 1
    fi
}

# IP blocking function
block_ip() {
    if [ -z "$1" ]; then
        echo -e "${RED}Please specify IP address to block${NC}"
        echo "Usage: $0 block <IP>"
        exit 1
    fi
    
    IP=$1
    echo -e "${YELLOW}Blocking IP: $IP${NC}"
    
    FIREWALL_TYPE=$(check_firewall)
    if [ $? -eq 0 ]; then
        if [ "$FIREWALL_TYPE" = "nftables" ]; then
            nft add rule inet filter input ip saddr $IP drop
            echo -e "${GREEN}IP $IP blocked in nftables${NC}"
        else
            iptables -A INPUT -s $IP -j DROP
            echo -e "${GREEN}IP $IP blocked in iptables${NC}"
        fi
    else
        exit 1
    fi
}

# IP unblocking function
unblock_ip() {
    if [ -z "$1" ]; then
        echo -e "${RED}Please specify IP address to unblock${NC}"
        echo "Usage: $0 unblock <IP>"
        exit 1
    fi
    
    IP=$1
    echo -e "${YELLOW}Unblocking IP: $IP${NC}"
    
    FIREWALL_TYPE=$(check_firewall)
    if [ $? -eq 0 ]; then
        if [ "$FIREWALL_TYPE" = "nftables" ]; then
            nft delete rule inet filter input ip saddr $IP drop 2>/dev/null
            echo -e "${GREEN}IP $IP unblocked in nftables${NC}"
        else
            iptables -D INPUT -s $IP -j DROP 2>/dev/null
            echo -e "${GREEN}IP $IP unblocked in iptables${NC}"
        fi
    else
        exit 1
    fi
}

# Statistics display function
show_stats() {
    echo -e "${YELLOW}=== Firewall Statistics ===${NC}"
    
    FIREWALL_TYPE=$(check_firewall)
    if [ $? -eq 0 ]; then
        if [ "$FIREWALL_TYPE" = "nftables" ]; then
            echo -e "${BLUE}nftables statistics:${NC}"
            nft list ruleset -a | grep -E "(packets|bytes)" | head -10
        else
            echo -e "${BLUE}iptables statistics:${NC}"
            iptables -L INPUT -n -v | head -10
        fi
        
        echo -e "\n${YELLOW}Firewall logs (last 10 entries):${NC}"
        if [ -f /var/log/syslog ]; then
            grep -E "(nftables-dropped|iptables-dropped)" /var/log/syslog | tail -10
        else
            echo "Logs not found"
        fi
    else
        exit 1
    fi
}

# Cloudflare IP update function
update_cloudflare() {
    echo -e "${YELLOW}Updating Cloudflare IP addresses...${NC}"
    
    FIREWALL_TYPE=$(check_firewall)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    CLOUDFLARE_IPS=$(curl -s --max-time 10 https://www.cloudflare.com/ips-v4 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$CLOUDFLARE_IPS" ]; then
        if [ "$FIREWALL_TYPE" = "nftables" ]; then
            # Remove old Cloudflare rules
            nft list ruleset | grep "cloudflare" | awk '{print $NF}' | xargs -I {} nft delete rule inet filter input handle {} 2>/dev/null || true
            
            # Add new ones
            for ip in $CLOUDFLARE_IPS; do
                nft add rule inet filter input tcp saddr $ip dport { 80, 443 } accept comment "cloudflare"
            done
        else
            # Remove old Cloudflare rules
            iptables -L INPUT -n --line-numbers | grep "cloudflare" | awk '{print $1}' | tac | xargs -I {} iptables -D INPUT {} 2>/dev/null || true
            
            # Add new ones
            for ip in $CLOUDFLARE_IPS; do
                iptables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT -m comment --comment "cloudflare"
                iptables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT -m comment --comment "cloudflare"
            done
        fi
        echo -e "${GREEN}Updated $(echo "$CLOUDFLARE_IPS" | wc -w) Cloudflare IP addresses${NC}"
    else
        echo -e "${RED}Failed to load Cloudflare IP addresses${NC}"
    fi
}

# Help display function
show_help() {
    echo -e "${YELLOW}Firewall Management Script${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status     - Show firewall status"
    echo "  stats      - Show statistics"
    echo "  block IP   - Block IP address"
    echo "  unblock IP - Unblock IP address"
    echo "  cloudflare - Update Cloudflare IP addresses"
    echo "  help       - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 block 192.168.1.100"
    echo "  $0 unblock 192.168.1.100"
    echo "  $0 cloudflare"
}

# Main logic
case "$1" in
    "status")
        show_status
        ;;
    "stats")
        show_stats
        ;;
    "block")
        block_ip "$2"
        ;;
    "unblock")
        unblock_ip "$2"
        ;;
    "cloudflare")
        update_cloudflare
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac