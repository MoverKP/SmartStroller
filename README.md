# Smart Stroller

**Design & Implementation of an Intelligent Stroller System**

A sensor-equipped baby carriage platform with incline-sensitive motion assistance, environmental monitoring, dual GPS tracking, and mobile app control.

---

## Overview

The Smart Stroller project is a Final Year Project (Capstone Project) for the Bachelor of Engineering (Honours) in Electrical Engineering at The Hong Kong Polytechnic University. This system enhances traditional baby strollers with intelligent features including:

- **Motorised Assistance** — Electric wheel control with forward/backward movement and 3 speed levels
- **Slope Detection** — IMU-based incline detection for automatic speed adjustment and braking
- **Environmental Monitoring** — Real-time temperature, humidity, rain, and UV intensity sensing
- **Dual GPS Tracking** — Stroller GNSS + phone GPS with proximity alerts
- **Mobile App Control** — Flutter-based dashboard for monitoring and control

---

## System Architecture

```
┌─────────────────┐     Wi-Fi      ┌──────────────────┐     Wi-Fi      ┌─────────────────┐
│   ESP32-S3      │ ────────────── │  Raspberry Pi    │ ────────────── │  Flutter App    │
│  (Sensor Node)  │    HTTP/JSON   │ (Control Hub)    │    HTTP/JSON   │   (Mobile)      │
└─────────────────┘                └──────────────────┘                └─────────────────┘
        │                                   │
        ▼                                   ▼
┌─────────────────┐                ┌──────────────────┐
│    Sensors      │                │   Motor System   │
│ • DHT11         │                │ • Electric Wheels│
│ • JY901S IMU    │                │ • Relay Control  │
│ • Rain Sensor   │                │ • Electric Brake │
│ • UV Sensor     │                └──────────────────┘
└─────────────────┘                ┌──────────────────┐
                                     │   GNSS Module    │
                                     │ (Stroller GPS)   │
                                     └──────────────────┘
```

---

## Features

### 1. Motor Control System
- Forward/Backward direction control
- Three speed levels (1, 2, 3)
- Electric brake functionality
- Manual stepless speed dial (無極調速器)

### 2. Slope-Aware Safety
- IMU-based pitch angle detection
- Automatic speed increase on uphill slopes
- Automatic braking on downhill slopes
- Speed limit enforcement (< 4 km/h)

### 3. Environmental Monitoring
- Temperature monitoring (DHT11)
- Humidity monitoring (DHT11)
- Rain detection
- UV intensity measurement

### 4. Dual GPS Tracking
- Stroller position via GNSS module (on Raspberry Pi)
- Parent position via phone GPS
- Distance calculation using Haversine formula
- Proximity alert when distance exceeds threshold

### 5. Mobile Application (Flutter)
- Real-time sensor dashboard
- Motor control interface
- GPS map view
- Proximity alerts
- Configuration settings

---

## Hardware Components

| Component | Model | Purpose |
|-----------|-------|---------|
| Microcontroller | ESP32-S3 | Sensor data acquisition |
| Control Unit | Raspberry Pi 4 | Central control, Wi-Fi AP |
| IMU Sensor | JY901S | Orientation (roll, pitch, yaw) |
| Temp/Humidity | DHT11 | Environmental monitoring |
| UV Sensor | GUVA-S12SD | Sunlight/UV intensity |
| Rain Sensor | Resistive board | Rain detection |
| GNSS Module | GPS Module | Stroller location |
| Relay Board | 6-channel | Motor control signals |
| Motor System | Electric wheels | Propulsion |

---

## Software Components

### ESP32 Firmware
- Arduino framework
- FreeRTOS multitasking
- JSON telemetry via HTTP POST

### Raspberry Pi Server
- Python Flask HTTP server
- GPIO control for relays
- GNSS NMEA parsing

### Flutter Application
- Cross-platform mobile app (Android)
- Provider state management
- HTTP communication with Pi

---

## Repository Structure

```
SmartStroller/
├── Document/
│   ├── FinalYearProject/
│   │   ├── PROJECT_FLOW.md          # System architecture diagrams
│   │   ├── SMART_STROLLER_FYP_DRAFT.md  # FYP report draft
│   │   └── REFERENCES.txt           # Reference collection
│   ├── Midterm/                     # Interim report materials
│   └── Capstone Project Handbook 2526.pdf
├── Program/
│   ├── SmartStroller_ESP32S3/       # ESP32 firmware
│   └── GPS/                         # GPS Python tools
├── Components/
│   └── RaspberryPi/
│       └── raspberry_pi_server.py   # Flask server
├── StrollerApp/
│   └── lib/                         # Flutter app source
├── Photos/                          # Project photos
├── GIT_COMMANDS.md                  # Git cheat sheet
└── README.md                        # This file
```

---

## Getting Started

### Prerequisites
- ESP32-S3 development board
- Raspberry Pi 4
- Flutter SDK (for mobile app)
- Python 3.x (for Pi server)

### Setup

1. **ESP32 Firmware**
   ```bash
   cd Program/SmartStroller_ESP32S3
   # Open in Arduino IDE and upload to ESP32-S3
   ```

2. **Raspberry Pi Server**
   ```bash
   cd Components/RaspberryPi
   pip install -r requirements.txt
   sudo python3 raspberry_pi_server.py
   ```

3. **Flutter App**
   ```bash
   cd StrollerApp
   flutter pub get
   flutter run
   ```

4. **Connect to SmartStroller Wi-Fi**
   - SSID: `SmartStroller`
   - Password: (open network)
   - Default IP: `192.168.4.1`

---

## Communication Protocol

### HTTP Endpoints (Raspberry Pi)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/data` | POST | Receive sensor data |
| `/latest` | GET | Get latest sensor reading |
| `/config` | GET/POST | Get/set configuration |
| `/gps` | GET | Get stroller GPS position |
| `/status` | GET | Server status |
| `/motor/forward` | POST | Set forward direction |
| `/motor/backward` | POST | Set backward direction |
| `/motor/speed` | POST | Set speed level (1-3) |
| `/motor/brake` | POST | Apply brake |

### JSON Data Format

```json
{
  "temperature": 25.5,
  "humidity": 60.0,
  "roll": 1.2,
  "pitch": -0.5,
  "yaw": 35.0,
  "raindropDetected": false,
  "sunshineVoltage": 1234.0,
  "timestamp": 1234567890
}
```

---

## Project Objectives

| Objective | Target | Status |
|-----------|--------|--------|
| Slope Detection | 15°-25° pitch | ✅ |
| Speed Limit | < 4 km/h | ✅ |
| Dashboard Update | 1-2 seconds | ✅ |
| Motor Control | Forward/Back/Brake | ✅ |
| GPS Tracking | Dual GPS + Alerts | ✅ |
| Lid Automation | 0°-40° | 🔧 In Progress |
| Audio Monitoring | Mic + Speaker | 🔧 Planned |

---

## Author

**MoverKP**

**Supervisor:** Dr. Kenneth Lo

---

## License

This project is developed for academic purposes as part of the SEHS4654 Capstone Project.

---

## References

See [REFERENCES.txt](Document/FinalYearProject/REFERENCES.txt) for complete reference list.

---

## Last Updated

March 2026
