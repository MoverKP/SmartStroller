# SmartStroller Raspberry Pi Setup Guide

This guide will help you set up the Raspberry Pi to act as a WiFi Access Point and receive sensor data from the ESP32-S3.

## Prerequisites

- Raspberry Pi (any model with WiFi capability)
- Raspberry Pi OS (Raspbian) installed
- Internet connection (for initial setup)
- Python 3 installed (usually pre-installed)

## Step 1: Copy Files to Raspberry Pi

Copy the following files to your Raspberry Pi:
- `raspberry_pi_server.py` - Main server program
- `setup_ap.sh` - Access Point setup script (optional, for automated setup)
- `requirements.txt` - Python dependencies

You can use `scp`, USB drive, or any method you prefer.

## Step 2: Install Python Dependencies

**Important:** Modern Raspberry Pi OS uses an externally-managed Python environment. We'll use a virtual environment to avoid conflicts.

### Option A: Using Virtual Environment (Recommended)

1. Create a virtual environment:
   ```bash
   python3 -m venv venv
   ```

2. Activate the virtual environment:
   ```bash
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. **Important:** Always activate the virtual environment before running the server:
   ```bash
   source venv/bin/activate
   python3 raspberry_pi_server.py
   ```

### Option B: Install Flask via apt (Alternative)

If you prefer not to use a virtual environment, you can install Flask via apt:

```bash
sudo apt update
sudo apt install python3-flask
```

Note: This may install an older version of Flask, but it should work for basic functionality.

## Step 3: Set Up WiFi Access Point

You have two options:

### Option A: Automated Setup (Recommended)

1. Make the setup script executable:
   ```bash
   chmod +x setup_ap.sh
   ```

2. Run the setup script as root:
   ```bash
   sudo bash setup_ap.sh
   ```

This script will:
- Install `hostapd` and `dnsmasq`
- Configure the Access Point with SSID "SmartStroller"
- Set up DHCP server
- Configure static IP (192.168.4.1)

### Option B: Manual Setup

If you prefer to set up manually or the automated script doesn't work:

1. **Install required packages:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y hostapd dnsmasq
   ```

2. **Configure hostapd:**
   Create/edit `/etc/hostapd/hostapd.conf`:
   ```bash
   sudo nano /etc/hostapd/hostapd.conf
   ```
   
   Add the following:
   ```
   interface=wlan0
   driver=nl80211
   ssid=SmartStroller
   channel=7
   hw_mode=g
   ```

3. **Configure hostapd to use the config file:**
   ```bash
   sudo nano /etc/default/hostapd
   ```
   
   Find and uncomment/modify:
   ```
   DAEMON_CONF="/etc/hostapd/hostapd.conf"
   ```

4. **Configure dnsmasq:**
   Backup the original config:
   ```bash
   sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
   ```
   
   Create/edit `/etc/dnsmasq.conf`:
   ```bash
   sudo nano /etc/dnsmasq.conf
   ```
   
   Add:
   ```
   interface=wlan0
   dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
   address=/#/192.168.4.1
   ```

5. **Configure static IP:**
   Edit `/etc/dhcpcd.conf`:
   ```bash
   sudo nano /etc/dhcpcd.conf
   ```
   
   Add at the end:
   ```
   interface wlan0
   static ip_address=192.168.4.1/24
   nohook wpa_supplicant
   ```

6. **Enable and start services:**
   ```bash
   sudo systemctl unmask hostapd
   sudo systemctl enable hostapd
   sudo systemctl enable dnsmasq
   sudo systemctl restart dhcpcd
   sudo systemctl restart dnsmasq
   sudo systemctl restart hostapd
   ```

7. **Verify the Access Point is running:**
   ```bash
   sudo systemctl status hostapd
   ip addr show wlan0
   ```

   You should see the IP address `192.168.4.1` on `wlan0`.

## Step 4: Run the Server

1. **If using virtual environment, activate it first:**
   ```bash
   source venv/bin/activate
   ```

2. Make the Python script executable (optional):
   ```bash
   chmod +x raspberry_pi_server.py
   ```

3. Run the server:
   ```bash
   python3 raspberry_pi_server.py
   ```

   Or if you made it executable:
   ```bash
   ./raspberry_pi_server.py
   ```

**Note:** If you're using a virtual environment, you must activate it (`source venv/bin/activate`) every time you open a new terminal before running the server.

3. The server will start and display:
   - Access Point information
   - Server endpoints
   - Data storage location

## Step 5: Test the Setup

1. **Check if ESP32 can connect:**
   - Power on your ESP32-S3
   - It should automatically connect to "SmartStroller" network
   - Check the serial monitor to see if connection is successful

2. **Access the web interface:**
   - Connect another device (phone/laptop) to "SmartStroller" network
   - Open browser and go to: `http://192.168.4.1`
   - You should see the SmartStroller Server web interface

3. **Check data reception:**
   - The server will save all received data to `sensor_data/sensor_readings.jsonl`
   - Check the terminal output for incoming data messages
   - View statistics at: `http://192.168.4.1/stats`

## Running as a Service (Optional)

To run the server automatically on boot:

1. Create a systemd service file:
   ```bash
   sudo nano /etc/systemd/system/smartstroller.service
   ```

2. Add the following (adjust paths as needed):

   **If using virtual environment:**
   ```ini
   [Unit]
   Description=SmartStroller Server
   After=network.target

   [Service]
   Type=simple
   User=smartstroller
   WorkingDirectory=/home/smartstroller/Desktop/SmartStroller
   ExecStart=/home/smartstroller/Desktop/SmartStroller/venv/bin/python3 /home/smartstroller/Desktop/SmartStroller/raspberry_pi_server.py
   Restart=always
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

   **If NOT using virtual environment:**
   ```ini
   [Unit]
   Description=SmartStroller Server
   After=network.target

   [Service]
   Type=simple
   User=smartstroller
   WorkingDirectory=/home/smartstroller/Desktop/SmartStroller
   ExecStart=/usr/bin/python3 /home/smartstroller/Desktop/SmartStroller/raspberry_pi_server.py
   Restart=always
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

3. Enable and start the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable smartstroller.service
   sudo systemctl start smartstroller.service
   ```

4. Check status:
   ```bash
   sudo systemctl status smartstroller.service
   ```

## Data Storage

- **Sensor Data:** Saved to `sensor_data/sensor_readings.jsonl` (JSON Lines format)
- **Configuration:** Saved to `sensor_data/config.json`
- Each line in the JSONL file is a complete JSON object with sensor readings

## API Endpoints

- `GET /` - Web interface
- `GET /status` - Server status and statistics
- `GET /stats` - Detailed statistics
- `GET /config` - Get current configuration
- `POST /config` - ESP32 requests configuration
- `POST /data` - ESP32 sends sensor data
- `POST /update_config` - Update configuration

## Troubleshooting

### Access Point not starting
- Check if `wlan0` interface exists: `ip addr show`
- Check hostapd logs: `sudo journalctl -u hostapd -n 50`
- Verify configuration: `sudo hostapd -dd /etc/hostapd/hostapd.conf`

### ESP32 cannot connect
- Verify AP is running: `sudo systemctl status hostapd`
- Check if ESP32 can see the network (check serial output)
- Verify IP range: `ip addr show wlan0` should show 192.168.4.1

### Server not receiving data
- Check if server is running: `ps aux | grep raspberry_pi_server`
- Check firewall: `sudo ufw status` (disable if blocking)
- Verify ESP32 is posting to correct URL: `http://192.168.4.1/data`

### Permission errors
- Make sure you have write permissions in the directory
- The script will create `sensor_data/` directory automatically

### "externally-managed-environment" error when installing packages
If you see this error when running `pip3 install`:
```
error: externally-managed-environment
```

**Solution:** Use a virtual environment (recommended):
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Or install Flask via apt instead:
```bash
sudo apt install python3-flask
```

**Note:** The `--break-system-packages` flag is NOT recommended as it can break your system Python installation.

## Stopping the Server

Press `Ctrl+C` in the terminal where the server is running.

If running as a service:
```bash
sudo systemctl stop smartstroller.service
```

## Notes

- The Access Point uses an open network (no password) by default
- To add a password, modify `/etc/hostapd/hostapd.conf` and add:
  ```
  wpa_passphrase=your_password
  wpa=2
  wpa_key_mgmt=WPA-PSK
  ```
  Then update the ESP32 code with the password.
