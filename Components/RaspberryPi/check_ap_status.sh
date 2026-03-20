#!/bin/bash
# Check Access Point status and configuration
# Run with: bash check_ap_status.sh

echo "=========================================="
echo "SmartStroller AP Status Check"
echo "=========================================="

echo ""
echo "1. Checking wlan0 interface status:"
echo "-----------------------------------"
ip addr show wlan0 2>/dev/null || echo "wlan0 interface not found"

echo ""
echo "2. Checking hostapd service:"
echo "-----------------------------------"
systemctl is-active hostapd && echo "✓ hostapd is active" || echo "✗ hostapd is not active"
systemctl status hostapd --no-pager -l | head -10

echo ""
echo "3. Checking dnsmasq service:"
echo "-----------------------------------"
systemctl is-active dnsmasq && echo "✓ dnsmasq is active" || echo "✗ dnsmasq is not active"

echo ""
echo "4. Checking for active WiFi connections:"
echo "-----------------------------------"
if command -v nmcli &> /dev/null; then
    echo "NetworkManager connections:"
    nmcli connection show --active 2>/dev/null | grep -i wlan || echo "No active WiFi connections via NetworkManager"
fi

if command -v wpa_cli &> /dev/null; then
    echo ""
    echo "wpa_supplicant status:"
    wpa_cli status 2>/dev/null || echo "wpa_supplicant not running"
fi

echo ""
echo "5. Checking hostapd configuration:"
echo "-----------------------------------"
if [ -f /etc/hostapd/hostapd.conf ]; then
    echo "Configuration file exists:"
    cat /etc/hostapd/hostapd.conf
else
    echo "✗ /etc/hostapd/hostapd.conf not found"
fi

echo ""
echo "6. Checking if wlan0 is in AP mode:"
echo "-----------------------------------"
iw dev wlan0 info 2>/dev/null | grep -i "type\|mode" || echo "Could not get interface info"

echo ""
echo "=========================================="
echo "Recommendations:"
echo "=========================================="
echo "If wlan0 shows an IP from another network (like 192.168.3.x),"
echo "it means the Pi is connected to WiFi instead of acting as an AP."
echo ""
echo "To fix this:"
echo "1. Disconnect from WiFi network"
echo "2. Stop NetworkManager or wpa_supplicant on wlan0"
echo "3. Ensure hostapd is running"
echo "4. Verify wlan0 has IP 192.168.4.1"
echo ""
