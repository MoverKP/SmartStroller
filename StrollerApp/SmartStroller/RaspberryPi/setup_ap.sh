#!/bin/bash
# Setup script for SmartStroller Access Point on Raspberry Pi
# Run with: sudo bash setup_ap.sh

# Don't exit on error - we'll handle errors manually
set +e

AP_SSID="SmartStroller"
AP_IP="192.168.4.1"
INTERFACE="wlan0"

echo "=========================================="
echo "SmartStroller AP Setup Script"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Update package list
echo "Updating package list..."
apt-get update

# Install required packages
echo "Installing hostapd and dnsmasq..."
apt-get install -y hostapd dnsmasq

# Stop services to configure them
echo "Stopping services..."
systemctl stop hostapd
systemctl stop dnsmasq

# Configure hostapd
echo "Configuring hostapd..."
cat > /etc/hostapd/hostapd.conf << EOF
interface=${INTERFACE}
driver=nl80211
ssid=${AP_SSID}
channel=7
hw_mode=g
# Open network (no password)
EOF

# Configure hostapd to use our config file
if [ -f /etc/default/hostapd ]; then
    sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
fi

# Backup original dnsmasq config
if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
fi

# Configure dnsmasq
echo "Configuring dnsmasq..."
# Create a minimal config that only handles wlan0
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

# Disable any conflicting dnsmasq config files
if [ -d /etc/dnsmasq.d ]; then
    echo "Disabling conflicting dnsmasq config files..."
    mkdir -p /etc/dnsmasq.d/disabled
    # Move any existing configs that might conflict
    for file in /etc/dnsmasq.d/*.conf; do
        if [ -f "$file" ]; then
            mv "$file" /etc/dnsmasq.d/disabled/ 2>/dev/null || true
        fi
    done
fi

# Configure static IP for wlan0
echo "Configuring static IP..."

# Check if dhcpcd is installed and configured
if [ -f /etc/dhcpcd.conf ]; then
    echo "Using dhcpcd for static IP configuration..."
    if ! grep -q "interface ${INTERFACE}" /etc/dhcpcd.conf; then
        cat >> /etc/dhcpcd.conf << EOF

# SmartStroller AP Configuration
interface ${INTERFACE}
static ip_address=${AP_IP}/24
nohook wpa_supplicant
EOF
    fi
    USE_DHCPCD=true
elif systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
    echo "NetworkManager detected. You may need to configure static IP manually."
    echo "Or disable NetworkManager for wlan0 interface."
    USE_DHCPCD=false
else
    echo "dhcpcd not found. Will configure IP manually using ip command."
    USE_DHCPCD=false
fi

# Enable services
echo "Enabling services..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq

# Restart networking
echo "Restarting networking services..."

# Restart dhcpcd if it exists
if [ "$USE_DHCPCD" = true ] && systemctl list-unit-files | grep -q dhcpcd.service; then
    echo "Restarting dhcpcd..."
    systemctl restart dhcpcd 2>/dev/null || echo "Note: dhcpcd restart skipped (may not be needed)"
    sleep 2
else
    echo "Configuring IP address manually..."
    # Bring down interface
    ip link set ${INTERFACE} down 2>/dev/null || true
    sleep 1
    # Configure IP address
    ip addr flush dev ${INTERFACE} 2>/dev/null || true
    ip addr add ${AP_IP}/24 dev ${INTERFACE} 2>/dev/null || true
    # Bring interface up
    ip link set ${INTERFACE} up 2>/dev/null || true
    sleep 1
fi

echo "Restarting dnsmasq..."
systemctl restart dnsmasq
sleep 2

echo "Restarting hostapd..."
systemctl restart hostapd

# Wait a moment for services to start
sleep 3

# Check status
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo "Checking service status..."
systemctl status hostapd --no-pager -l | head -10
echo ""
systemctl status dnsmasq --no-pager -l | head -10
echo ""

# Verify IP address
echo "Checking IP configuration..."
CURRENT_IP=$(ip addr show ${INTERFACE} 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
if [ "$CURRENT_IP" = "$AP_IP" ]; then
    echo "✓ IP address correctly set to ${AP_IP}"
else
    echo "⚠ IP address is ${CURRENT_IP:-'not set'}, expected ${AP_IP}"
    echo "  You may need to manually configure it:"
    echo "    sudo ip addr add ${AP_IP}/24 dev ${INTERFACE}"
    echo "    sudo ip link set ${INTERFACE} up"
fi

echo ""
echo "Access Point should be running!"
echo "SSID: ${AP_SSID}"
echo "IP: ${AP_IP}"
echo ""
echo "To check if AP is running:"
echo "  sudo systemctl status hostapd"
echo "  sudo systemctl status dnsmasq"
echo "  ip addr show ${INTERFACE}"
echo ""
echo "If the IP address is not set correctly, you can set it manually:"
echo "  sudo ip addr flush dev ${INTERFACE}"
echo "  sudo ip addr add ${AP_IP}/24 dev ${INTERFACE}"
echo "  sudo ip link set ${INTERFACE} up"
echo ""
