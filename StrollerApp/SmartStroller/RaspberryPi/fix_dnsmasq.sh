#!/bin/bash
# Fix dnsmasq configuration for SmartStroller AP
# Run with: sudo bash fix_dnsmasq.sh

set -e

INTERFACE="wlan0"
AP_IP="192.168.4.1"

echo "=========================================="
echo "Fixing dnsmasq Configuration"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Stop dnsmasq
echo "Stopping dnsmasq..."
systemctl stop dnsmasq

# Backup current config
if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create proper config
echo "Creating dnsmasq configuration..."
cat > /etc/dnsmasq.conf << EOF
# SmartStroller AP Configuration
# Only listen on wlan0
interface=${INTERFACE}
bind-interfaces

# DHCP range for wlan0
dhcp-range=${INTERFACE},192.168.4.2,192.168.4.20,255.255.255.0,24h

# Redirect all DNS queries to AP IP
address=/#/${AP_IP}

# Don't read other config files that might interfere
no-resolv
no-hosts
EOF

# Disable conflicting config files
if [ -d /etc/dnsmasq.d ]; then
    echo "Checking for conflicting config files..."
    mkdir -p /etc/dnsmasq.d/disabled
    for file in /etc/dnsmasq.d/*.conf; do
        if [ -f "$file" ] && ! grep -q "SmartStroller" "$file"; then
            echo "Disabling: $file"
            mv "$file" /etc/dnsmasq.d/disabled/ 2>/dev/null || true
        fi
    done
fi

# Restart dnsmasq
echo "Restarting dnsmasq..."
systemctl restart dnsmasq

sleep 2

# Check status
echo ""
echo "=========================================="
echo "dnsmasq Status"
echo "=========================================="
systemctl status dnsmasq --no-pager -l | head -15

echo ""
echo "If you still see 'no address range available' errors,"
echo "check the dnsmasq logs:"
echo "  sudo journalctl -u dnsmasq -n 50"
echo ""
