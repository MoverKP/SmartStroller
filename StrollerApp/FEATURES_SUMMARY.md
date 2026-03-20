# Complete Features & Functions Summary

## 📱 Application Overview
A Flutter-based remote control application for drones/devices with Bluetooth connectivity, NFC scanning, GPS tracking, fan control, and offline record storage.

---

## 🏗️ Architecture & State Management

### Main Entry Point
- **File**: `lib/main.dart`
- **Home Page**: `DashboardPage` (changed from connection page)
- **State Management**: `Provider` with `MyAppState` as root state
- **Routes**:
  - `/dashboard` - Main dashboard (home)
  - `/connect` - WiFi/Bluetooth connection page
  - `/records` - Previous records page
  - `/gps` - GPS location with Google Maps
  - `/control` - Controller page with joystick
  - `/settings` - Settings page
  - `/select` - Selection page
  - `/device` - Device page

---

## 📄 Pages & Features

### 1. Dashboard Page (`lib/pages/dashboard_page.dart`)
**Purpose**: Main entry point showing data/information instead of connection page

#### Features:
- **Fan Status Display**
  - Shows fan ON/OFF status with icon
  - Displays current temperature
  - Shows threshold temperature
  - Shows lid status (Open/Closed) with reason
  - Button to adjust fan threshold temperature

- **Recent Records Section**
  - Shows 5 most recent NFC scan records
  - Displays drone ID, serial number, and timestamp
  - "View All" button to navigate to full records page
  - Pull-to-refresh functionality

- **Quick Actions**
  - Cards for quick navigation to Records and GPS Map

- **WiFi/Bluetooth Connection Button**
  - Located in top-right corner of AppBar
  - Shows connection status (connected/disconnected)
  - Navigates to connection page

#### Methods:
- `_loadRecentRecords()` - Loads 5 most recent records
- `_startTemperatureSimulation()` - Simulates temperature updates (for demo)
- `_formatDateTime(DateTime)` - Formats time as HH:MM
- `_buildStatusItem(String, String, Color)` - Builds status display item
- `_buildActionCard(...)` - Builds quick action card widget
- `_showThresholdDialog(BuildContext, MyAppState)` - Shows dialog to adjust fan threshold

---

### 2. Records Page (`lib/pages/records_page.dart`)
**Purpose**: Display all saved NFC scan records (works offline)

#### Features:
- **Record List**
  - Shows all saved records sorted by newest first
  - Displays: Drone ID, Serial Number, Timestamp, GPS coordinates, Device Name
  - Pull-to-refresh functionality
  - Delete individual records
  - Clear all records with confirmation dialog

- **Empty State**
  - Shows message when no records exist
  - Explains that records appear after NFC scans

#### Methods:
- `_loadRecords()` - Loads all records from storage
- `_deleteRecord(String id)` - Deletes a single record
- `_clearAllRecords()` - Clears all records with confirmation
- `_formatDateTime(DateTime)` - Formats full date and time

---

### 3. GPS Page (`lib/pages/gps_page.dart`)
**Purpose**: Display current GPS location on embedded Google Maps

#### Features:
- **Google Maps Integration**
  - Embedded Google Maps widget
  - Shows current location marker
  - Displays latitude, longitude, and accuracy
  - Refresh button to update location
  - Floating action button for quick location update

- **Permission Handling**
  - Checks location service status
  - Requests location permissions
  - Shows error messages for permission issues

#### Methods:
- `_getCurrentLocation()` - Gets current GPS position
  - Checks location service enabled
  - Requests permissions if needed
  - Gets position with high accuracy
  - Updates map camera to current location
  - Handles errors gracefully

---

### 4. Scan Page (`lib/pages/scan_page.dart`)
**Purpose**: Scan and display Bluetooth devices, highlight "BB car" devices

#### Features:
- **Device Scanning**
  - Scans for Bluetooth devices (15 second timeout)
  - Displays all scanned devices
  - Auto-refreshes scan results

- **BB Car Highlighting**
  - Detects devices with "BB car" or "bbcar" in name (case insensitive)
  - Highlights with green border and background
  - Shows "BB Car" badge on highlighted devices

- **Navigation**
  - Back button stops scan and returns to dashboard
  - Refresh button to rescan

#### Methods:
- `buildScanResultTiles(BuildContext)` - Builds list of scan result widgets
  - Checks device name for "BB car" pattern
  - Applies special styling for BB car devices
  - Returns list of styled widgets

---

### 5. Connection Page (`lib/pages/connection_page.dart`)
**Purpose**: Entry point for WiFi/Bluetooth connection

#### Features:
- **Conditional Rendering**
  - Shows `ScanPage` if Bluetooth and GPS are enabled
  - Shows `BluetoothOffScreen` if services are disabled

---

### 6. Controller Page (`lib/views/controller_page.dart`)
**Purpose**: Main control interface with joystick, 3D model, and NFC scanning

#### Features:
- **NFC Scanning**
  - Continuous NFC tag polling
  - Parses DroneID and Serial Number from NFC tags
  - Pattern matching: `S####,UUID;` format
  - Auto-saves records when NFC data detected

- **3D Model Display**
  - Renders 3D drone model using O3D
  - Camera orbit controls

- **Joystick Control**
  - Left and right joysticks for control
  - Sends commands via Bluetooth

- **Record Saving**
  - Automatically saves NFC scan data
  - Captures GPS coordinates
  - Captures connected device name
  - Saves timestamp

#### Methods:
- `startNFC()` - Starts continuous NFC polling
  - Polls for NFC tags every 10 seconds
  - Reads NDEF records
  - Parses DroneID and Serial Number
  - Updates UI with NFC data
  - Calls `_saveRecord()` when data detected

- `_saveRecord(String? droneId, String? serialNumber)` - Saves NFC scan record
  - Gets current GPS location (if available)
  - Gets connected Bluetooth device name (if available)
  - Creates Record object with all data
  - Saves to local storage via RecordsService

---

## 🗄️ Data Models

### 1. Record Model (`lib/models/record.dart`)
**Purpose**: Data structure for NFC scan records

#### Properties:
- `id` (String) - Unique record identifier
- `droneId` (String?) - Drone ID from NFC tag
- `serialNumber` (String?) - Serial number from NFC tag
- `latitude` (double?) - GPS latitude
- `longitude` (double?) - GPS longitude
- `timestamp` (DateTime) - When record was created
- `deviceName` (String?) - Connected Bluetooth device name

#### Methods:
- `toJson()` - Converts to JSON for storage
- `fromJson(Map<String, dynamic>)` - Creates from JSON

---

### 2. FanState Model (`lib/models/fan_state.dart`)
**Purpose**: Manages fan control logic and state

#### Properties:
- `thresholdTemperature` (double) - Temperature threshold (default: 26.0°C)
- `isFanOn` (bool) - Current fan status
- `currentTemperature` (double) - Current temperature reading
- `isLidClosed` (bool) - Lid status
- `lidCloseReason` (String) - Reason lid is closed (UV/rain)

#### Methods:
- `_loadThreshold()` - Loads saved threshold from SharedPreferences
- `setThresholdTemperature(double)` - Sets and saves threshold
  - Saves to SharedPreferences
  - Re-evaluates fan state
- `updateTemperature(double)` - Updates current temperature
  - Automatically evaluates fan state
- `setLidClosed(bool, {String reason})` - Sets lid status
  - If closed, turns fan off
  - If opened, re-evaluates fan state
- `_evaluateFanState()` - Private method to determine fan state
  - Fan ON if: temperature >= threshold AND lid is not closed
  - Fan OFF otherwise

#### Fan Control Logic:
- **Default Behavior**: Lid closes when UV too high or raining (cannot be changed)
- **User Configurable**: Temperature threshold (default: 26°C)
- **Fan ON Condition**: Temperature >= threshold AND lid is open
- **Fan OFF Condition**: Temperature < threshold OR lid is closed

---

### 3. AppState Model (`lib/models/app_state.dart`)
**Purpose**: Root application state

#### Properties:
- `selectedPage` (int) - Currently selected page
- `selectedModel` (int) - Selected 3D model
- `bleState` (BleState) - Bluetooth state
- `gpsState` (GpsState) - GPS state
- `fanState` (FanState) - Fan control state

---

## 🔧 Services

### RecordsService (`lib/services/records_service.dart`)
**Purpose**: Handles saving, loading, and deleting records using SharedPreferences

#### Methods:
- `getRecords()` - Returns all records sorted by newest first
  - Loads from SharedPreferences
  - Parses JSON strings
  - Returns sorted list

- `saveRecord(Record)` - Saves a new record
  - Loads existing records
  - Adds new record at beginning
  - Keeps only last 100 records (to prevent storage issues)
  - Saves to SharedPreferences

- `deleteRecord(String id)` - Deletes a record by ID
  - Loads records
  - Removes matching record
  - Saves updated list

- `clearAllRecords()` - Deletes all records
  - Removes records key from SharedPreferences

---

## 📦 Dependencies (pubspec.yaml)

### Core Packages:
- `flutter_blue_plus: ^1.32.2` - Bluetooth Low Energy
- `flutter_nfc_kit: ^3.0.0` - NFC tag reading
- `nfc_manager: ^3.0.0` - NFC management
- `geolocator: ^10.0.0` - GPS location services
- `location: ^6.0.2` - Location services
- `google_maps_flutter: ^2.5.0` - Google Maps integration
- `shared_preferences: ^2.2.2` - Local storage
- `provider: ^6.0.0` - State management
- `flutter_joystick: ^0.0.4` - Joystick controls
- `o3d: ^3.1.2` - 3D model rendering
- `permission_handler: ^11.3.1` - Permission handling

---

## 🎯 Key Features Implemented

### ✅ Completed Features:

1. **Main Dashboard**
   - ✅ Dashboard as main entry point (instead of connection page)
   - ✅ WiFi/Bluetooth button in top-right corner
   - ✅ Fan status display
   - ✅ Recent records preview
   - ✅ Quick action cards

2. **Offline Records**
   - ✅ View previous records without WiFi connection
   - ✅ Records stored locally using SharedPreferences
   - ✅ Full CRUD operations (Create, Read, Delete)
   - ✅ Records page accessible from multiple places

3. **Google Maps Integration**
   - ✅ Embedded Google Maps in GPS page
   - ✅ Current location marker
   - ✅ Location details display
   - ✅ Permission handling
   - ✅ Refresh functionality

4. **WiFi/Bluetooth Scanning**
   - ✅ Scan page shows all scanned devices
   - ✅ "BB car" devices highlighted with green border
   - ✅ "BB car" badge displayed on matching devices
   - ✅ Case-insensitive matching

5. **Fan Control**
   - ✅ Temperature threshold setting (default: 26°C)
   - ✅ Fan status display on main page
   - ✅ Automatic fan control logic
   - ✅ Lid status tracking
   - ✅ Threshold persistence (saved to SharedPreferences)

6. **NFC Integration**
   - ✅ Automatic NFC scanning in controller page
   - ✅ DroneID and Serial Number parsing
   - ✅ Auto-save records with GPS and device info
   - ✅ Pattern validation

---

## 🔄 Data Flow

### NFC Scan → Record Save Flow:
1. User scans NFC tag in Controller Page
2. `startNFC()` detects tag and parses data
3. `_saveRecord()` is called with DroneID and Serial Number
4. GPS location is fetched (if available)
5. Bluetooth device name is retrieved (if connected)
6. Record object is created with all data
7. `RecordsService.saveRecord()` saves to SharedPreferences
8. Dashboard and Records Page can display saved records

### Fan Control Flow:
1. Temperature is updated via `FanState.updateTemperature()`
2. `_evaluateFanState()` checks conditions:
   - If temperature >= threshold AND lid is open → Fan ON
   - Otherwise → Fan OFF
3. If lid is closed (UV/rain), fan is forced OFF
4. State changes notify listeners (UI updates)

---

## 📁 File Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   ├── app_state.dart                # Root state management
│   ├── args.dart                     # Screen arguments
│   ├── bluetooth.dart                # Bluetooth model
│   ├── fan_state.dart                # Fan control state
│   ├── plane.dart                    # Plane model
│   └── record.dart                   # Record data model
├── pages/
│   ├── connection_page.dart          # Connection entry
│   ├── dashboard_page.dart           # Main dashboard (HOME)
│   ├── device_page.dart              # Device page
│   ├── gps_page.dart                # GPS with Google Maps
│   ├── records_page.dart            # All records view
│   └── scan_page.dart               # Bluetooth scan
├── services/
│   └── records_service.dart          # Records storage service
├── views/
│   ├── controller_page.dart          # Main controller
│   ├── connection_page.dart          # (legacy)
│   ├── selection_page.dart           # Model selection
│   └── settings_page.dart            # Settings
└── [other folders for bluetooth, states, widgets, etc.]
```

---

## 🚀 Usage Examples

### Accessing Records (Offline):
```dart
final recordsService = RecordsService();
final records = await recordsService.getRecords(); // Works offline!
```

### Adjusting Fan Threshold:
```dart
final appState = context.read<MyAppState>();
appState.fanState.setThresholdTemperature(28.0); // Set to 28°C
```

### Updating Temperature (from device):
```dart
final appState = context.read<MyAppState>();
appState.fanState.updateTemperature(27.5); // Fan will turn on if >= threshold
```

### Saving NFC Record:
```dart
final record = Record(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  droneId: 'S1234',
  serialNumber: 'uuid-here',
  latitude: 37.7749,
  longitude: -122.4194,
  timestamp: DateTime.now(),
  deviceName: 'BB car Device',
);
await RecordsService().saveRecord(record);
```

---

## ⚙️ Configuration Files

### Android Configuration:
- `android/app/src/main/AndroidManifest.xml` - Google Maps API key
- `android/build.gradle` - Java 17, Kotlin 2.1.0
- `android/settings.gradle` - Gradle plugin versions
- `android/gradle.properties` - Build settings

### iOS Configuration:
- `ios/Runner/Info.plist` - Google Maps API key (if needed)

---

## 📝 Notes for Rebuilding

1. **Google Maps API Key**: 
   - Android: Set in `AndroidManifest.xml` under `com.google.android.geo.API_KEY`
   - iOS: Set in `Info.plist` under `com.google.maps.API_KEY`

2. **Gradle Configuration**:
   - Java 17 required
   - Kotlin JVM target: 17
   - Gradle 8.7
   - Android Gradle Plugin 8.6.0

3. **Permissions Required**:
   - Location (for GPS)
   - Bluetooth (for device connection)
   - NFC (for tag scanning)

4. **Storage**:
   - Records stored in SharedPreferences
   - Maximum 100 records kept (oldest deleted automatically)
   - Fan threshold persisted in SharedPreferences

---

## 🐛 Known Issues / Future Improvements

1. Temperature simulation in dashboard (should come from actual device)
2. Gradle build issues with plugin compatibility (resolved with Java 17 config)
3. Google Maps API key needs to be configured for production

---

## 📊 Summary Statistics

- **Total Pages**: 6 main pages
- **Data Models**: 3 (Record, FanState, AppState)
- **Services**: 1 (RecordsService)
- **State Management**: Provider pattern
- **Storage**: SharedPreferences (offline-capable)
- **External APIs**: Google Maps, Bluetooth, NFC, GPS

---

*Last Updated: Based on current codebase state*
*Version: 0.0.1+1*
