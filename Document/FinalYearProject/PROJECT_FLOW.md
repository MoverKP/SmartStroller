# Smart Stroller — Project flow (Mermaid)

This folder holds flow diagrams for the FYP documentation. They are derived from the interim report (`Document/Midterm/Smart_BB_Car_Interim_Progress_Report.docx`), `StrollerApp/COMMUNICATION_PROTOCOL.md`, and the current repository layout (`Program/`, `Components/`, `StrollerApp/`).

**How to preview:** paste each `mermaid` block into [Mermaid Live Editor](https://mermaid.live) or use a Markdown viewer that renders Mermaid (VS Code extension, GitHub, etc.).

---

## 1. Target system architecture (interim report + design intent)

High-level roles: ESP32 as sensing/telemetry node; Raspberry Pi as gateway (plus GNSS for stroller position) and **motor control node**; Flutter app for monitoring, commands, and phone GPS (parent position). Dashed links are **planned or partially implemented** in code (lid servo on Pi, audio, proximity alert).

```mermaid
flowchart TB
  subgraph Physical["Physical stroller"]
    SENS["Sensors\n(DHT11 temp/humidity, IMU pitch/roll/yaw,\nrain, sunlight/UV proxy)"]
    GNSS["GNSS module\n(UART to Pi)\nstroller lat/lon"]
  end

  subgraph DriveSystem["Electric drive system"]
    WHEELS["Electric wheels\n(front module)"]
    MOTORCTRL["Motor controller\n(direction + speed input)"]
    RELAYS["Relay board\nPi GPIO → relays →\nmotor controller signals"]
    MANUAL["無極調速器\n(manual dial, not Pi-controlled)"]
  end

  subgraph OtherActuators["Other actuators"]
    LID["Lid servo\n(0°–40°, rain/UV auto)"]
    AUDIO["Speaker / mic\n(audio monitor, lullaby)"]
  end

  subgraph ESP32["ESP32-S3 (sensor node)"]
    FW["Firmware: read sensors,\nJSON telemetry,\nWi‑Fi STA to Pi AP"]
  end

  subgraph Pi["Raspberry Pi (control + gateway)"]
    AP["Wi‑Fi AP `SmartStroller`\n192.168.4.1"]
    SRV["HTTP server (Flask)\n/data, /config, /latest,\n/update_config, /status, /gps,\n/motor/forward, /motor/backward,\n/motor/speed, /motor/brake"]
    LOG["Log latest reading +\nJSONL history"]
    GPSPI["GNSS reader (serial)\nNMEA → lat/lon + fix"]
    MOTORLOGIC["Motor control logic\nIMU slope → auto speed/brake,\n3 speed levels, electric brake"]
  end

  subgraph Phone["Flutter mobile app"]
    UI["Dashboard, charts, records,\nconnection, settings"]
    MOTORUI["Motor controls\nForward / Backward buttons,\nSpeed 1/2/3 selector, Brake"]
    PHONEGPS["Phone GPS\nrequest user location"]
    ALERT["Proximity alert\n(distance > threshold\nor stroller GPS lost)"]
    RULES["Lid/fan rules from\nenv + UV proxy\n(app-side today)"]
  end

  SENS --> FW
  GNSS --> GPSPI
  FW -->|"HTTP POST JSON"| SRV
  GPSPI -->|"stroller position"| SRV
  SRV --> LOG
  AP --- SRV

  SRV --> MOTORLOGIC
  MOTORLOGIC -->|"GPIO high/low"| RELAYS
  RELAYS -->|"control signals"| MOTORCTRL
  MOTORCTRL -->|"drive power"| WHEELS
  MANUAL -.->|"manual adjustment"| WHEELS

  SRV -.->|"future"| LID
  SRV -.->|"future"| AUDIO

  Phone -->|"join same AP"| AP
  UI -->|"GET /latest\n(poll)"| SRV
  UI -->|"GET /gps\n(stroller position)"| SRV
  UI -->|"POST /update_config"| SRV
  SRV -->|"config to ESP32\n(GET/POST /config)"| FW
  LOG --> UI

  MOTORUI -->|"POST /motor/forward\n/motor/backward\n/motor/speed\n/motor/brake"| SRV
  SRV -->|"motor status"| MOTORUI

  PHONEGPS -->|"phone lat/lon"| UI
  UI -->|"phone + stroller coords"| ALERT
  SRV -->|"stroller coords + fix"| ALERT
  ALERT -->|"push notification\nif out of range or lost"| UI

  UI --> RULES
  RULES --> UI
```

---

## 2. Routine: telemetry, motor control, and app monitoring

Concrete loop matching `SmartStroller_ESP32S3.ino`, Pi server, and `WifiService` / dashboard polling. GNSS on Pi provides stroller position; phone GPS provides parent position for proximity alert. Motor control via Pi GPIO → relays → motor controller.

```mermaid
sequenceDiagram
  autonumber
  participant ESP as ESP32-S3
  participant Pi as Raspberry Pi Flask
  participant GPIO as Pi GPIO + Relays
  participant Motor as Motor Controller + Wheels
  participant GNSS as GNSS module (Pi UART)
  participant Store as sensor_data/*.jsonl + latest buffer
  participant App as Flutter app
  participant PhoneGPS as Phone GPS (Flutter)

  Note over Pi: AP up, SSID SmartStroller, IP 192.168.4.1
  ESP->>Pi: Wi‑Fi STA connect
  loop Config sync
    ESP->>Pi: GET or POST /config
    Pi-->>ESP: dataFields, frequency, dataFormat
  end

  loop Every frequency ms
    ESP->>ESP: Read DHT11, IMU, rain, sunshine ADC
    ESP->>Pi: POST /data JSON telemetry
    Pi->>Store: Append line + update latest reading
    Pi-->>ESP: 200 OK
  end

  par GNSS loop (stroller position)
    GNSS->>Pi: NMEA sentences (serial)
    Pi->>Pi: Parse lat/lon + fix status
    Pi->>Store: Store stroller GPS
  end

  App->>Pi: User connects phone to AP, set IP (default 192.168.4.1)
  App->>Pi: GET /latest (periodic, e.g. ~2 s)
  Pi-->>App: status + data object (includes IMU pitch for slope)
  App->>Pi: GET /gps (stroller position + fix)
  Pi-->>App: stroller lat/lon, fix status, timestamp

  App->>PhoneGPS: Request current location (Flutter permission)
  PhoneGPS-->>App: phone lat/lon, accuracy

  App->>App: Compute distance(phone, stroller)
  alt Distance > threshold OR stroller fix lost
    App->>App: Show proximity alert (notification)
  else Within range
    App->>App: Show "Stroller nearby" status
  end

  App->>App: Update UI, temperature history, fan/lid logic

  par Motor control
    App->>Pi: POST /motor/forward or /motor/backward
    Pi->>GPIO: Set direction relay(s)
    GPIO->>Motor: Direction signal
    Pi-->>App: Motor status
    
    App->>Pi: POST /motor/speed {level: 1|2|3}
    Pi->>GPIO: Set speed relay(s)
    GPIO->>Motor: Speed level signal
    Pi-->>App: Speed status

    Note over Pi: Slope safety logic (auto)
    Pi->>Pi: Read IMU pitch from latest telemetry
    alt Uphill detected (pitch > threshold)
      Pi->>GPIO: Increase speed or maintain
      Pi->>App: Event: uphill assist active
    else Downhill detected (pitch < -threshold)
      Pi->>GPIO: Reduce speed + apply brake if needed
      Pi->>App: Event: downhill brake active
    end

    App->>Pi: POST /motor/brake
    Pi->>GPIO: Activate brake relay
    GPIO->>Motor: Electric brake ON
    Pi-->>App: Brake applied
  end

  opt Settings
    App->>Pi: POST /update_config
    Pi-->>App: updated config
  end
```

---

## 3. End-to-end operational flow (user + system)

```mermaid
flowchart LR
  A([Power Pi AP + Flask]) --> B([ESP32 joins SmartStroller Wi‑Fi])
  B --> C([ESP32 pulls/pushes config])
  C --> D([Sensor read loop])
  D --> E([POST /data to Pi])
  E --> F([Pi stores + exposes latest])
  F --> G([Phone on same AP])

  subgraph GPSTrack["Dual GPS tracking"]
    H([Pi GNSS reads stroller lat/lon])
    I([App requests phone GPS])
    J([Compute distance])
    K{Distance > threshold?}
    L([Proximity alert])
    M([Stroller fix lost?])
    N([Alert: stroller GPS lost])
  end

  subgraph MotorControl["Motor control"]
    MC1([App: Forward/Backward])
    MC2([App: Speed 1/2/3])
    MC3([Pi GPIO → Relays → Motor])
    MC4([Electric wheels move])
    MC5([Slope safety logic])
    MC6([Uphill: assist speed])
    MC7([Downhill: reduce + brake])
    MC8([App: Brake button])
  end

  F --> H
  G --> I
  H --> J
  I --> J
  J --> K
  K -->|Yes| L
  K -->|No| O([Dashboard OK])
  H --> M
  M -->|Yes| N

  O --> P([Dashboard / charts / records])

  P --> MC1
  P --> MC2
  MC1 --> MC3
  MC2 --> MC3
  MC3 --> MC4
  E --> MC5
  MC5 --> MC6
  MC5 --> MC7
  MC6 --> MC3
  MC7 --> MC3

  P --> MC8
  MC8 --> MC3

  P --> Q{Need to change sampling?}
  Q -->|Yes| R([POST /update_config])
  R --> C
  Q -->|No| G

  subgraph Future["FYP completion (remaining)"]
    U([Pi: lid servo + rain/UV]) --> V([Hardware lid])
    W([Pi: audio I/O]) --> X([Monitor / lullaby])
  end
  E -.-> U
```

---

## 4. Motor control architecture (detail)

This section expands the motor control subsystem for FYP documentation.

```mermaid
flowchart TB
  subgraph Pi["Raspberry Pi"]
    SRV["Flask server\n/motor/* endpoints"]
    MOTORLOGIC["Motor logic:\n- Direction: forward/backward\n- Speed: 3 levels (relays)\n- Brake: electric brake ON\n- Slope safety: auto-adjust"]
    GPIO["GPIO pins\n(output to relays)"]
  end

  subgraph Relays["Relay board"]
    R1["Relay 1: Direction A"]
    R2["Relay 2: Direction B"]
    R3["Relay 3: Speed level 1"]
    R4["Relay 4: Speed level 2"]
    R5["Relay 5: Speed level 3"]
    R6["Relay 6: Electric brake"]
  end

  subgraph MotorSystem["Motor controller + wheels"]
    CTRL["Motor controller\n(receives relay signals)"]
    WHEELS["Electric wheels\n(front module)"]
    MANUAL["無極調速器\n(manual dial, independent)"]
  end

  subgraph App["Flutter app"]
    UI["Motor control UI:\n- Forward button\n- Backward button\n- Speed selector (1/2/3)\n- Brake button"]
  end

  App -->|"POST /motor/forward"| SRV
  App -->|"POST /motor/backward"| SRV
  App -->|"POST /motor/speed {level}"| SRV
  App -->|"POST /motor/brake"| SRV

  SRV --> MOTORLOGIC
  MOTORLOGIC --> GPIO

  GPIO --> R1
  GPIO --> R2
  GPIO --> R3
  GPIO --> R4
  GPIO --> R5
  GPIO --> R6

  R1 --> CTRL
  R2 --> CTRL
  R3 --> CTRL
  R4 --> CTRL
  R5 --> CTRL
  R6 --> CTRL

  CTRL --> WHEELS
  MANUAL -.->|"manual override"| WHEELS

  IMU["IMU pitch data\n(from ESP32 telemetry)"] -->|"slope detection"| MOTORLOGIC
```

**Motor control endpoints (proposed):**

| Endpoint | Method | Body | Description |
|----------|--------|------|-------------|
| `/motor/forward` | POST | `{}` | Set direction to forward |
| `/motor/backward` | POST | `{}` | Set direction to backward |
| `/motor/speed` | POST | `{"level": 1\|2\|3}` | Set speed level |
| `/motor/brake` | POST | `{}` | Apply electric brake |
| `/motor/status` | GET | — | Get current motor state |

---

## 5. Repository map (for documentation cross-reference)

```mermaid
flowchart TB
  ROOT["SmartStroller/"]
  ROOT --> P["Program/\nESP32 firmware, GPS Python tools"]
  ROOT --> C["Components/\nRaspberryPi server, AngleSensor sketch"]
  ROOT --> SA["StrollerApp/\nFlutter app + copy of Pi docs"]
  ROOT --> DOC["Document/\nhandbook, midterm, FinalYearProject"]

  P --> E32["SmartStroller_ESP32S3/SmartStroller_ESP32S3.ino"]
  P --> GPS["GPS/GPSDataReading.py\n(PC prototype, not used for Pi GNSS)"]
  C --> RPI["RaspberryPi/raspberry_pi_server.py\n(to add: /gps endpoint, GNSS serial)"]
  SA --> LIB["lib/ pages, services, models\n(to add: phone GPS, alert UI)"]
  SA --> PROTO["COMMUNICATION_PROTOCOL.md"]
```

---

## Notes for your review

1. **Motor control architecture:**
   - Pi GPIO → Relay board → Motor controller → Electric wheels
   - Functions: **Forward/Backward**, **3 speed levels**, **Electric brake**
   - **無極調速器** (stepless speed dial) is **manual-only**, not connected to Pi
   - Slope safety logic on Pi uses IMU pitch from ESP32 telemetry to auto-adjust speed/brake

2. **Motor API endpoints (to implement):**
   - `POST /motor/forward`, `/motor/backward` — direction control
   - `POST /motor/speed {"level": 1|2|3}` — speed selection
   - `POST /motor/brake` — electric brake
   - `GET /motor/status` — current state

3. **Dual GPS architecture:** GNSS module → Pi UART → `/gps` endpoint for **stroller position**; Flutter app → phone GPS permission for **parent position**. App computes distance and shows alert if **distance > threshold** or **stroller GPS fix lost**.

4. **Implementation gaps:**
   - Pi server needs `/gps` route and GNSS NMEA parsing (e.g., via `pyserial`).
   - Pi server needs `/motor/*` routes and GPIO control for relays.
   - Flutter app needs motor control UI and `geolocator` for phone GPS.

5. **IMU naming:** The interim report references MPU9250; the current ESP32 sketch uses **JY901S** over UART for roll/pitch/yaw. The flow is the same; update the diagram labels in your final report if you standardize on one module.

6. **Pi server variants:** A fuller `raspberry_pi_server.py` (with `/latest` and in-memory latest reading) exists under `StrollerApp/SmartStroller/RaspberryPi/`; `Components/RaspberryPi/` may differ slightly—align before demo.

7. **GPS prototype:** `Program/GPS/GPSDataReading.py` is a **standalone PC map viewer**; the FYP uses **GNSS on Pi** instead.

If any box or arrow does not match your demo setup, say which part to change and we can regenerate this file.
