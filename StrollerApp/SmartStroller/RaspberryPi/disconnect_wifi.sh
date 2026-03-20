#!/bin/bash
# Disconnect from WiFi and prepare for AP mode
# Run with: sudo bash disconnect_wifi.sh

set -e

INTERFACE="wlan0"

echo "=========================================="
echo "Disconnecting WiFi and Preparing for AP Mode"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Stop NetworkManager if it's managing wlan0
if systemctl is-active --quiet NetworkManager; then
    echo "Stopping NetworkManager..."
    systemctl stop NetworkManager
    # Disable it from managing wlan0
    if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
        if ! grep -q "unmanaged-devices" /etc/NetworkManager/NetworkManager.conf; then
            echo "Configuring NetworkManager to ignore wlan0..."
            sed -i '/\[keyfile\]/a unmanaged-devices=interface-name:wlan0' /etc/NetworkManager/NetworkManager.conf
        fi
    fi
fi

# Stop wpa_supplicant if running
if systemctl is-active --quiet wpa_supplicant 2>/dev/null; then
    echo "Stopping wpa_supplicant..."
    systemctl stop wpa_supplicant
    systemctl disable wpa_supplicant 2>/dev/null || true
fi

# Kill any wpa_supplicant processes on wlan0
pkill -f "wpa_supplicant.*wlan0" 2>/dev/null || true

# Bring down the interface
echo "Bringing down ${INTERFACE}..."
ip link set ${INTERFACE} down 2>/dev/null || true
sleep 1

# Flush any existing IP addresses
echo "Flushing IP addresses..."
ip addr flush dev ${INTERFACE} 2>/dev/null || true

# Configure static IP for AP
echo "Setting static IP 192.168.4.1..."
ip addr add 192.168.4.1/24 dev ${INTERFACE} 2>/dev/null || true

# Bring interface up
echo "Bringing up ${INTERFACE}..."
ip link set ${INTERFACE} up 2>/dev/null || true
sleep 1

# Restart hostapd
echo "Restarting hostapd..."
systemctl restart hostapd
sleep 2

# Restart dnsmasq
echo "Restarting dnsmasq..."
systemctl restart dnsmasq
sleep 2

# Verify
echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="
echo "Current IP on ${INTERFACE}:"
ip addr show ${INTERFACE} | grep "inet " || echo "No IP configured"

echo ""
echo "hostapd status:"
systemctl is-active hostapd && echo "✓ hostapd is running" || echo "✗ hostapd is not running"

echo ""
echo "dnsmasq status:"
systemctl is-active dnsmasq && echo "✓ dnsmasq is running" || echo "✗ dnsmasq is not running"

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
echo "You should now see 'SmartStroller' network in WiFi scan."
echo "If not, check:"
echo "  sudo systemctl status hostapd"
echo "  ip addr show wlan0"
echo ""
