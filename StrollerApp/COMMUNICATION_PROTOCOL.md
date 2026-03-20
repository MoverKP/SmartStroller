# Communication Protocol: ESP32 S3 ↔ Raspberry Pi ↔ Flutter App

## Overview
This document defines the JSON communication format between:

- **ESP32 S3** and **Raspberry Pi SmartStroller server**
- **Flutter mobile app** and **Raspberry Pi SmartStroller server**

---

## Data Format

### ESP32 → Raspberry Pi (Sensor Data)

The ESP32 posts sensor data to the Raspberry Pi AP using HTTP:

- **URL**: `http://192.168.4.1/data`
- **Method**: `POST`
- **Body**: JSON with real sensor readings

#### JSON Structure:
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

#### Field Descriptions:
- `temperature` (float, required): Current temperature in Celsius (°C) from DHT11.
- `humidity` (float, required): Relative humidity percentage from DHT11. Range: 0.0 to 100.0.
- `roll` (float, optional): Rotation around X-axis (degrees) from JY901S.
- `pitch` (float, optional): Rotation around Y-axis (degrees) from JY901S.
- `yaw` (float, optional): Rotation around Z-axis (degrees) from JY901S.
- `raindropDetected` (boolean, optional): `true` if rain sensor detects rain, `false` otherwise.
- `sunshineVoltage` (float, optional): Sunshine sensor analog voltage in millivolts (0–3300 mV).
- `timestamp` (long, optional): Timestamp in milliseconds (from ESP32 `millis()`).

#### Example Messages:
```json
{"temperature":26.3,"humidity":65.2,"roll":1.5,"pitch":-0.3,"yaw":10.2,"raindropDetected":false,"sunshineVoltage":1500.0}
{"temperature":28.5,"humidity":70.0,"roll":2.0,"pitch":0.0,"yaw":15.0,"raindropDetected":false,"sunshineVoltage":2500.0}
{"temperature":24.0,"humidity":80.0,"roll":0.1,"pitch":0.2,"yaw":5.0,"raindropDetected":true,"sunshineVoltage":800.0}
```

---

### Phone App → Raspberry Pi (Configuration)

The Flutter app configures how often and what data the ESP32 sends, by calling Raspberry Pi’s `/update_config` endpoint.

#### Example POST Request:
```http
POST /update_config HTTP/1.1
Host: 192.168.4.1
Content-Type: application/json

{
  "dataFields": "temperature,humidity,roll,pitch,yaw,raindrop,sunshine",
  "frequency": 500
}
```

#### Configuration Fields:

- `dataFields` (string):
  - `"all"` (default) → send all available fields.
  - Or a comma-separated string of fields, e.g. `"temperature,humidity,roll,pitch,yaw,raindrop,sunshine"`.
  - ESP32 will only include those keys in the JSON.
- `frequency` (int): Delay in milliseconds between sensor transmissions.
  - Minimum allowed is 100 ms (server enforces).

---

## WiFi Configuration

### Raspberry Pi Access Point (AP)
- **SSID**: `SmartStroller`
- **Password**: _none_ (open network by default)
- **AP IP Address**: `192.168.4.1`
- **Port**: `80`

### ESP32 Station Mode
- ESP32 connects as a client (STA) to the Pi AP:
  - `ssid = "SmartStroller"`
  - `password = ""`

---

## Raspberry Pi HTTP API Endpoints

### 1. Root Endpoint
- **URL**: `http://192.168.4.1/`
- **Method**: GET
- **Response**: HTML status page for debugging.

### 2. Latest Sensor Data (for Phone App)
- **URL**: `http://192.168.4.1/latest`
- **Method**: GET
- **Response**: JSON with latest sensor data:
  ```json
  {
    "status": "ok",
    "data": {
      "temperature": 26.3,
      "humidity": 65.2,
      "roll": 1.5,
      "pitch": -0.3,
      "yaw": 10.2,
      "raindropDetected": false,
      "sunshineVoltage": 1500.0,
      "timestamp": 1234567890
    }
  }
  ```

### 3. Status (for Settings / Debug)
- **URL**: `http://192.168.4.1/status`
- **Method**: GET
- **Response**:
  ```json
  {
    "status": "running",
    "ap_ssid": "SmartStroller",
    "ap_ip": "192.168.4.1",
    "statistics": {
      "total_readings": 123,
      "last_received": "2026-01-09T12:34:56.789Z",
      "start_time": "2026-01-09T11:00:00.000Z"
    },
    "current_config": {
      "dataFormat": "json",
      "dataFields": "all",
      "frequency": 500
    }
  }
  ```

### 4. Update Configuration (from Phone App)
- **URL**: `http://192.168.4.1/update_config`
- **Method**: POST
- **Body**: JSON as described above (dataFields, frequency)
- **Response**:
  ```json
  {
    "status": "ok",
    "config": {
      "dataFormat": "json",
      "dataFields": "temperature,humidity,roll,pitch,yaw",
      "frequency": 500
    }
  }
  ```

---

## Data Flow

### Sensor Data Flow (ESP32 → Pi → Phone)
1. ESP32 reads all sensors (temperature, humidity, angles, rain, sunshine).
2. ESP32 builds JSON according to `dataFields` and posts to `http://192.168.4.1/data`.
3. Raspberry Pi saves the reading (file + `latest_reading` in memory).
4. Flutter app polls `http://192.168.4.1/latest` every 1–5 seconds.
5. App parses JSON, updates:
   - Temperature, humidity, rain, UV proxy (sunshineVoltage).
   - Orientation (roll, pitch, yaw).
   - Fan control logic via `FanState`.

### Lid & Fan Control Flow (on Phone)
1. App calculates a simple UV index proxy from `sunshineVoltage`:
   - `uvIndex ≈ sunshineVoltage / 330` (0–10 range).
2. If `raindropDetected == true` → lid **Closed** with reason `"Rain detected"`.
3. Else if `uvIndex > 8.0` → lid **Closed** with reason `"UV too high"`.
4. Else → lid **Open**.
5. Fan state:
   - **Auto mode**: fan ON if `temperature >= threshold` **and** lid open.
   - **Manual mode**: user can toggle fan ON/OFF from the app (still forced OFF if lid closed).

---

## Implementation Notes

1. **Polling Frequency**: Flutter app should poll `/api/sensor` every 1-5 seconds
2. **Error Handling**: If HTTP request fails, retry with exponential backoff
3. **Connection**: ESP32 creates WiFi Access Point "Stroller_Device" (password: "stroller123")
4. **IP Address**: Default AP IP is `192.168.4.1`, check Serial Monitor for actual IP
5. **CORS**: API includes CORS headers for web/Flutter web support
6. **Encoding**: All JSON strings are UTF-8 encoded

---

## Version
- **Protocol Version**: 2.0
- **Last Updated**: 2026-01-28
