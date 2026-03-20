#!/usr/bin/env python3
"""
SmartStroller Raspberry Pi Server
This program creates a WiFi Access Point and receives sensor data from ESP32-S3

Requirements:
- Flask: pip3 install flask
- hostapd and dnsmasq (for AP setup)

Author: SmartStroller Project
"""

import json
import os
import sys
import time
from datetime import datetime
from flask import Flask, request, jsonify
import threading

# Configuration
AP_SSID = "SmartStroller"
AP_PASSWORD = ""  # Empty for open network
AP_IP = "192.168.4.1"
AP_SUBNET = "192.168.4.0/24"
PORT = 80

# Data storage
DATA_DIR = "sensor_data"
DATA_FILE = os.path.join(DATA_DIR, "sensor_readings.jsonl")  # JSON Lines format
CONFIG_FILE = os.path.join(DATA_DIR, "config.json")

# Default configuration to send to ESP32
DEFAULT_CONFIG = {
    "dataFormat": "json",
    "dataFields": "all",  # or comma-separated: "temperature,humidity,pressure,roll,pitch,yaw"
    "frequency": 500  # milliseconds
}

# Flask app
app = Flask(__name__)

# Store latest configuration
current_config = DEFAULT_CONFIG.copy()

# Statistics
stats = {
    "total_readings": 0,
    "last_received": None,
    "start_time": datetime.now().isoformat()
}

# Latest sensor reading (for clients like the mobile app)
latest_reading = None


def ensure_data_directory():
    """Create data directory if it doesn't exist"""
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)
        print(f"Created data directory: {DATA_DIR}")


def load_config():
    """Load configuration from file"""
    global current_config
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                current_config = json.load(f)
            print(f"Loaded configuration from {CONFIG_FILE}")
        except Exception as e:
            print(f"Error loading config: {e}")
            current_config = DEFAULT_CONFIG.copy()
    else:
        # Save default config
        save_config()
    return current_config


def save_config():
    """Save current configuration to file"""
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(current_config, f, indent=2)
        print(f"Configuration saved to {CONFIG_FILE}")
    except Exception as e:
        print(f"Error saving config: {e}")


def save_sensor_data(data):
    """Save sensor data to file (JSON Lines format)"""
    global latest_reading
    try:
        # Add server timestamp
        data['server_timestamp'] = datetime.now().isoformat()
        
        # Append to file (JSON Lines format - one JSON object per line)
        with open(DATA_FILE, 'a') as f:
            f.write(json.dumps(data) + '\n')
        
        # Update statistics
        stats["total_readings"] += 1
        stats["last_received"] = datetime.now().isoformat()
        # Cache latest reading (without file-specific fields)
        latest_reading = data
        
        print(f"Saved sensor data (Total: {stats['total_readings']})")
        return True
    except Exception as e:
        print(f"Error saving sensor data: {e}")
        return False


@app.route('/config', methods=['GET', 'POST'])
def handle_config():
    """Handle configuration requests from ESP32"""
    global current_config
    
    if request.method == 'POST':
        # ESP32 is requesting configuration
        try:
            # Return current configuration
            response = {
                "status": "ok",
                "dataFormat": current_config.get("dataFormat", "json"),
                "dataFields": current_config.get("dataFields", "all"),
                "frequency": current_config.get("frequency", 500)
            }
            print(f"Sent configuration to ESP32: {response}")
            return jsonify(response), 200
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 500
    
    elif request.method == 'GET':
        # Return current configuration (for web interface)
        return jsonify(current_config), 200


@app.route('/data', methods=['POST'])
def handle_data():
    """Receive sensor data from ESP32"""
    try:
        # Get JSON data from request
        if request.is_json:
            data = request.get_json()
        else:
            # Try to parse as raw JSON
            data = json.loads(request.data.decode('utf-8'))
        
        print(f"Received sensor data: {json.dumps(data, indent=2)}")
        
        # Save data
        if save_sensor_data(data):
            # Optionally return updated configuration in response
            response = {
                "status": "ok",
                "message": "Data received",
                "received_at": datetime.now().isoformat()
            }
            return jsonify(response), 200
        else:
            return jsonify({"status": "error", "message": "Failed to save data"}), 500
            
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        return jsonify({"status": "error", "message": "Invalid JSON"}), 400
    except Exception as e:
        print(f"Error processing data: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route('/update_config', methods=['POST'])
def update_config():
    """Update configuration (for web interface or API)"""
    global current_config
    
    try:
        if request.is_json:
            new_config = request.get_json()
        else:
            new_config = json.loads(request.data.decode('utf-8'))
        
        # Update configuration
        if "dataFormat" in new_config:
            current_config["dataFormat"] = new_config["dataFormat"]
        if "dataFields" in new_config:
            current_config["dataFields"] = new_config["dataFields"]
        if "frequency" in new_config:
            freq = int(new_config["frequency"])
            if freq >= 100:  # Minimum 100ms
                current_config["frequency"] = freq
            else:
                current_config["frequency"] = 100
        
        save_config()
        print(f"Configuration updated: {current_config}")
        
        return jsonify({"status": "ok", "config": current_config}), 200
        
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route('/status', methods=['GET'])
def get_status():
    """Get server status and statistics"""
    return jsonify({
        "status": "running",
        "ap_ssid": AP_SSID,
        "ap_ip": AP_IP,
        "statistics": stats,
        "current_config": current_config
    }), 200


@app.route('/latest', methods=['GET'])
def get_latest():
    """Get latest sensor reading for mobile app clients"""
    if latest_reading is None:
        return jsonify({
            "status": "error",
            "message": "No sensor data received yet"
        }), 404

    return jsonify({
        "status": "ok",
        "data": latest_reading
    }), 200


@app.route('/stats', methods=['GET'])
def get_stats():
    """Get detailed statistics"""
    file_size = 0
    if os.path.exists(DATA_FILE):
        file_size = os.path.getsize(DATA_FILE)
    
    return jsonify({
        "total_readings": stats["total_readings"],
        "last_received": stats["last_received"],
        "start_time": stats["start_time"],
        "data_file": DATA_FILE,
        "data_file_size_bytes": file_size
    }), 200


@app.route('/', methods=['GET'])
def index():
    """Simple web interface"""
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>SmartStroller Server</title>
        <meta charset="UTF-8">
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
            .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }}
            h1 {{ color: #333; }}
            .status {{ background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 10px 0; }}
            .config {{ background: #fff3e0; padding: 15px; border-radius: 5px; margin: 10px 0; }}
            button {{ background: #4CAF50; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }}
            button:hover {{ background: #45a049; }}
            input {{ padding: 8px; margin: 5px; border: 1px solid #ddd; border-radius: 4px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>SmartStroller Server</h1>
            <div class="status">
                <h2>Status</h2>
                <p><strong>AP SSID:</strong> {AP_SSID}</p>
                <p><strong>AP IP:</strong> {AP_IP}</p>
                <p><strong>Total Readings:</strong> <span id="total">{stats['total_readings']}</span></p>
                <p><strong>Last Received:</strong> <span id="last">{stats['last_received'] or 'Never'}</span></p>
            </div>
            <div class="config">
                <h2>Configuration</h2>
                <p><strong>Data Format:</strong> <span id="format">{current_config['dataFormat']}</span></p>
                <p><strong>Data Fields:</strong> <span id="fields">{current_config['dataFields']}</span></p>
                <p><strong>Frequency:</strong> <span id="freq">{current_config['frequency']}</span> ms</p>
                <h3>Update Configuration</h3>
                <input type="text" id="fields_input" placeholder="Data fields (e.g., temperature,humidity)" value="{current_config['dataFields']}">
                <input type="number" id="freq_input" placeholder="Frequency (ms)" value="{current_config['frequency']}" min="100">
                <button onclick="updateConfig()">Update Config</button>
            </div>
            <div style="margin-top: 20px;">
                <button onclick="refreshStatus()">Refresh Status</button>
                <button onclick="window.location.href='/stats'">View Statistics</button>
            </div>
        </div>
        <script>
            function refreshStatus() {{
                fetch('/status')
                    .then(r => r.json())
                    .then(data => {{
                        document.getElementById('total').textContent = data.statistics.total_readings;
                        document.getElementById('last').textContent = data.statistics.last_received || 'Never';
                        document.getElementById('format').textContent = data.current_config.dataFormat;
                        document.getElementById('fields').textContent = data.current_config.dataFields;
                        document.getElementById('freq').textContent = data.current_config.frequency;
                    }});
            }}
            function updateConfig() {{
                const fields = document.getElementById('fields_input').value;
                const freq = parseInt(document.getElementById('freq_input').value);
                fetch('/update_config', {{
                    method: 'POST',
                    headers: {{'Content-Type': 'application/json'}},
                    body: JSON.stringify({{dataFields: fields, frequency: freq}})
                }})
                .then(r => r.json())
                .then(data => {{
                    alert('Configuration updated!');
                    refreshStatus();
                }});
            }}
            setInterval(refreshStatus, 5000); // Auto-refresh every 5 seconds
        </script>
    </body>
    </html>
    """
    return html


def setup_access_point():
    """
    Setup WiFi Access Point on Raspberry Pi
    This function provides instructions and can attempt to configure the AP
    """
    print("\n" + "="*60)
    print("Setting up WiFi Access Point")
    print("="*60)
    print(f"SSID: {AP_SSID}")
    print(f"IP Address: {AP_IP}")
    print(f"Password: {'(Open - No password)' if not AP_PASSWORD else AP_PASSWORD}")
    print("\nTo set up the Access Point, you need to:")
    print("1. Install required packages:")
    print("   sudo apt-get update")
    print("   sudo apt-get install -y hostapd dnsmasq")
    print("\n2. Configure hostapd (create /etc/hostapd/hostapd.conf):")
    print(f"   interface=wlan0")
    print(f"   driver=nl80211")
    print(f"   ssid={AP_SSID}")
    if AP_PASSWORD:
        print(f"   wpa_passphrase={AP_PASSWORD}")
        print("   wpa=2")
        print("   wpa_key_mgmt=WPA-PSK")
    else:
        print("   # Open network (no password)")
    print("   channel=7")
    print("   hw_mode=g")
    print("\n3. Configure dnsmasq (create /etc/dnsmasq.conf or edit existing):")
    print(f"   interface=wlan0")
    print(f"   dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h")
    print(f"   address=/#/{AP_IP}")
    print("\n4. Configure static IP (edit /etc/dhcpcd.conf):")
    print(f"   interface wlan0")
    print(f"   static ip_address={AP_IP}/24")
    print("\n5. Enable and start services:")
    print("   sudo systemctl unmask hostapd")
    print("   sudo systemctl enable hostapd")
    print("   sudo systemctl enable dnsmasq")
    print("   sudo systemctl restart hostapd")
    print("   sudo systemctl restart dnsmasq")
    print("\nAlternatively, you can use the setup_ap.sh script (if provided)")
    print("="*60 + "\n")


def main():
    """Main function"""
    print("="*60)
    print("SmartStroller Raspberry Pi Server")
    print("="*60)
    
    # Ensure data directory exists
    ensure_data_directory()
    
    # Load configuration
    load_config()
    
    # Print setup instructions
    setup_access_point()
    
    print(f"Starting Flask server on {AP_IP}:{PORT}")
    print(f"Data will be saved to: {DATA_FILE}")
    print(f"Configuration file: {CONFIG_FILE}")
    print("\nEndpoints:")
    print(f"  - http://{AP_IP}/          - Web interface")
    print(f"  - http://{AP_IP}/config    - Configuration (GET/POST)")
    print(f"  - http://{AP_IP}/data      - Receive sensor data (POST)")
    print(f"  - http://{AP_IP}/status    - Server status (GET)")
    print(f"  - http://{AP_IP}/stats     - Statistics (GET)")
    print("\nPress Ctrl+C to stop the server")
    print("="*60 + "\n")
    
    # Run Flask server
    # Note: Use host='0.0.0.0' to listen on all interfaces
    # Port 80 requires root privileges
    try:
        app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)
    except PermissionError:
        print("\n" + "="*60)
        print("ERROR: Permission denied binding to port 80")
        print("="*60)
        print("Port 80 requires root privileges.")
        print("\nOptions:")
        print("1. Run with sudo (recommended):")
        print("   sudo python3 raspberry_pi_server.py")
        print("\n2. Or use a different port (requires ESP32 code update):")
        print("   Edit raspberry_pi_server.py and change PORT to 8080")
        print("   Then update ESP32 code to use http://192.168.4.1:8080")
        print("\n3. Or grant capability to bind to port 80:")
        print("   sudo setcap 'cap_net_bind_service=+ep' $(readlink -f $(which python3))")
        print("="*60)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nServer stopped by user")
    except Exception as e:
        print(f"\nError running server: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
