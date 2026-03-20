/*
 * SmartStroller ESP32-S3 WiFi Client
 * 
 * This program:
 * 1. Connects to WiFi network named "SmartStroller"
 * 2. Receives configuration from AP via POST (data format, data field, frequency)
 * 3. Collects sensor data and groups it into JSON format
 * 4. Posts data back to the SmartStroller AP
 * 5. Uses frequency from AP to control data transmission delay
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <HardwareSerial.h>
#include <REG.h>
#include <wit_c_sdk.h>
#include <DHT.h>

// =================== Pin Definitions ===================
// JY901S Angle Sensor (Hardware Serial)
#define JY_RX 16   // JY901S RX pin
#define JY_TX 17   // JY901S TX pin

// Environmental Sensors
#define TEMP_HUMIDITY_PIN 41  // HS-S26A Temperature and Humidity module data pin
#define RAINDROP_DO_PIN 40    // Raindrops module digital output (DO)
#define SUNSHINE_ANALOG_PIN 4 // Sunshine detection module analog input

// Hardware Serial for JY901S sensor
HardwareSerial JY901S(2);  // hardware serial instance for JY901S sensor (UART2)
DHT dht(TEMP_HUMIDITY_PIN, DHT11);  // DHT11 temperature and humidity sensor

// JY901S sensor update flags
#define ACC_UPDATE    0x01
#define GYRO_UPDATE   0x02
#define ANGLE_UPDATE  0x04
#define MAG_UPDATE    0x08
#define READ_UPDATE   0x80

static volatile char s_cDataUpdate = 0, s_cCmd = 0xff;
int i;
float fAcc[3], fGyro[3], fAngle[3];

// WiFi credentials
const char* ssid = "SmartStroller";
const char* password = "";  // Add password if needed

// Server configuration
String serverURL = "http://192.168.4.1";  // Default AP IP, adjust if needed
String configEndpoint = "/config";
String dataEndpoint = "/data";

// Configuration received from AP
struct Config {
  String dataFormat;      // e.g., "json"
  String dataFields;      // Comma-separated list of fields to send
  int frequency;          // Delay in milliseconds
  bool configured;        // Flag to check if config is received
} apConfig;

// Sensor data structure - only real sensors
struct SensorData {
  float temperature;      // From DHT11
  float humidity;        // From DHT11
  float roll;            // Rotation around X-axis (degrees) from JY901S
  float pitch;           // Rotation around Y-axis (degrees) from JY901S
  float yaw;             // Rotation around Z-axis (degrees) from JY901S
  bool raindropDetected; // From raindrop sensor
  float sunshineVoltage; // From sunshine sensor (millivolts)
  unsigned long timestamp;
} sensorData;

// Track sensor reading statistics
static unsigned int dht11_read_count = 0;
static unsigned int dht11_same_value_count = 0;

// FreeRTOS task handle for DHT11 sensor reading
TaskHandle_t dht11TaskHandle = NULL;

// Mutex for thread-safe sensor data access
SemaphoreHandle_t sensorDataMutex = NULL;

// WiFi and HTTP clients
WiFiClient client;
HTTPClient http;
WebServer server(80);  // Web server on port 80 to receive POST from AP

// Timing variables
unsigned long lastDataSend = 0;
unsigned long lastConfigCheck = 0;
const unsigned long configCheckInterval = 30000;  // Check for config every 30 seconds

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("SmartStroller ESP32-S3 Client Starting...");
  
  // Initialize JY901S sensor
  JY901S.begin(9600, SERIAL_8N1, JY_RX, JY_TX);
  WitInit(WIT_PROTOCOL_NORMAL, 0x50);
  WitSerialWriteRegister(SensorUartSend);
  WitRegisterCallBack(SensorDataUpdata);
  WitDelayMsRegister(Delayms);
  
  // Initialize environmental sensors
  dht.begin();  // Initialize DHT sensor
  pinMode(RAINDROP_DO_PIN, INPUT_PULLUP);  // Use pullup for digital input
  // SUNSHINE_ANALOG_PIN is analog, no pinMode needed
  
  // Create mutex for thread-safe sensor data access
  sensorDataMutex = xSemaphoreCreateMutex();
  if (sensorDataMutex == NULL) {
    Serial.println("Failed to create mutex!");
  }
  
  // Auto-scan for JY901S sensor
  Serial.println("Scanning for JY901S sensor...");
  AutoScanSensor();
  
  // Create FreeRTOS task for DHT11 sensor reading
  xTaskCreate(
    dht11Task,           // Task function
    "DHT11_Task",        // Task name
    4096,                // Stack size (bytes)
    NULL,                // Parameters
    1,                   // Priority (0-25, higher = higher priority)
    &dht11TaskHandle     // Task handle
  );
  
  if (dht11TaskHandle == NULL) {
    Serial.println("Failed to create DHT11 task!");
  } else {
    Serial.println("DHT11 reading task created successfully");
  }
  
  // Initialize default configuration
  apConfig.dataFormat = "json";
  apConfig.dataFields = "all";
  apConfig.frequency = 500;  // Default 500ms
  apConfig.configured = false;
  
  // Initialize sensor data
  initializeSensorData();
  
  // Connect to WiFi
  connectToWiFi();
  
  // Setup web server to receive POST requests from AP
  setupWebServer();
  
  // Request initial configuration from AP
  requestConfiguration();
}

void loop() {
  // Read bytes from JY901S over hardware UART
  while (JY901S.available()) {
    uint8_t incomingByte = JY901S.read();
    WitSerialDataIn(incomingByte); // Feed sensor data into WIT library
  }
  
  // Process JY901S sensor data (thread-safe update)
  if (s_cDataUpdate) {
    for (i = 0; i < 3; i++) {
      fAcc[i]   = sReg[AX   + i] / 32768.0f * 16.0f;
      fGyro[i]  = sReg[GX   + i] / 32768.0f * 2000.0f;
      fAngle[i] = sReg[Roll + i] / 32768.0f * 180.0f;  // Roll, Pitch, Yaw in degrees
    }
    
    if (s_cDataUpdate & ANGLE_UPDATE) {
      // Thread-safe update of angle data
      if (xSemaphoreTake(sensorDataMutex, portMAX_DELAY) == pdTRUE) {
        sensorData.roll = fAngle[0];   // Rotation around X-axis (left/right tilt)
        sensorData.pitch = fAngle[1];  // Rotation around Y-axis (forward/backward tilt)
        sensorData.yaw = fAngle[2];    // Rotation around Z-axis (compass heading)
        xSemaphoreGive(sensorDataMutex);
      }
      s_cDataUpdate &= ~ANGLE_UPDATE;
    }
    
    s_cDataUpdate = 0;
  }
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    connectToWiFi();
  }
  
  // Handle incoming web server requests (for POST from AP)
  server.handleClient();
  
  // Periodically check for configuration updates
  if (millis() - lastConfigCheck > configCheckInterval) {
    requestConfiguration();
    lastConfigCheck = millis();
  }
  
  // Collect sensor data (environmental sensors)
  collectSensorData();
  
  // Send data at configured frequency
  if (millis() - lastDataSend >= apConfig.frequency) {
    sendDataToAP();
    lastDataSend = millis();
  }
  
  // Small delay to prevent watchdog issues
  delay(10);
}

void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFailed to connect to WiFi");
  }
}

void requestConfiguration() {
  Serial.println("Requesting configuration from AP...");
  
  http.begin(client, serverURL + configEndpoint);
  http.addHeader("Content-Type", "application/json");
  
  // Send request for configuration
  String requestBody = "{\"request\":\"config\"}";
  int httpResponseCode = http.POST(requestBody);
  
  if (httpResponseCode > 0) {
    Serial.print("HTTP Response code: ");
    Serial.println(httpResponseCode);
    
    String response = http.getString();
    Serial.println("Response: " + response);
    
    // Parse configuration from response
    parseConfiguration(response);
  } else {
    Serial.print("Error on sending POST: ");
    Serial.println(httpResponseCode);
  }
  
  http.end();
}

void setupWebServer() {
  // Handle POST request from AP for configuration
  server.on("/config", HTTP_POST, handleConfigPost);
  
  // Handle GET request for status
  server.on("/status", HTTP_GET, handleStatusGet);
  
  // Start server
  server.begin();
  Serial.println("Web server started on port 80");
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());
}

void handleConfigPost() {
  if (server.hasArg("plain")) {
    String body = server.arg("plain");
    Serial.println("Received POST from AP:");
    Serial.println(body);
    
    // Parse configuration from POST body
    parseConfiguration(body);
    
    // Send acknowledgment
    server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Configuration received\"}");
  } else {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No data received\"}");
  }
}

void handleStatusGet() {
  StaticJsonDocument<256> doc;
  doc["status"] = "online";
  doc["configured"] = apConfig.configured;
  doc["frequency"] = apConfig.frequency;
  doc["dataFormat"] = apConfig.dataFormat;
  doc["ip"] = WiFi.localIP().toString();
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void parseConfiguration(String jsonString) {
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, jsonString);
  
  if (error) {
    Serial.print("JSON parsing failed: ");
    Serial.println(error.c_str());
    return;
  }
  
  // Extract configuration
  if (doc.containsKey("dataFormat")) {
    apConfig.dataFormat = doc["dataFormat"].as<String>();
  }
  
  if (doc.containsKey("dataFields")) {
    apConfig.dataFields = doc["dataFields"].as<String>();
  }
  
  if (doc.containsKey("frequency")) {
    apConfig.frequency = doc["frequency"].as<int>();
    // Ensure minimum delay of 100ms
    if (apConfig.frequency < 100) {
      apConfig.frequency = 100;
    }
  }
  
  apConfig.configured = true;
  
  Serial.println("Configuration updated:");
  Serial.print("  Data Format: ");
  Serial.println(apConfig.dataFormat);
  Serial.print("  Data Fields: ");
  Serial.println(apConfig.dataFields);
  Serial.print("  Frequency: ");
  Serial.print(apConfig.frequency);
  Serial.println(" ms");
}

void initializeSensorData() {
  sensorData.temperature = 0.0;
  sensorData.humidity = 0.0;
  sensorData.roll = 0.0;
  sensorData.pitch = 0.0;
  sensorData.yaw = 0.0;
  sensorData.raindropDetected = false;
  sensorData.sunshineVoltage = 0.0;
  sensorData.timestamp = 0;
}

void collectSensorData() {
  // Update timestamp (thread-safe)
  if (xSemaphoreTake(sensorDataMutex, portMAX_DELAY) == pdTRUE) {
    sensorData.timestamp = millis();
    xSemaphoreGive(sensorDataMutex);
  }
  
  // Read other environmental sensors (DHT11 is handled in separate task)
  static unsigned long lastEnvSensorRead = 0;
  unsigned long currentTime = millis();
  
  // Read other environmental sensors more frequently (every 500ms)
  if (currentTime - lastEnvSensorRead >= 500) {
    readRaindropSensor();
    readSunshineSensor();
    lastEnvSensorRead = currentTime;
  }
  
  // Note: Roll, Pitch, Yaw are updated in loop() when JY901S data is received
  // Note: Temperature and Humidity are updated in DHT11 task
}

void readSunshineSensor() {
  long sum = 0;
  // ESP32-S3 uses 12-bit ADC (0-4095), sample 512 times for faster reading
  for (int i = 0; i < 512; i++) {
    int sensorValue = analogRead(SUNSHINE_ANALOG_PIN);
    sum = sensorValue + sum;
    delayMicroseconds(100);  // Much faster than delay(2)
  }
  int average = sum / 512;  // Average value
  // ESP32-S3 ADC: 0-4095 maps to 0-3.3V, convert to millivolts
  // Formula: voltage = (reading / 4095) * 3300mV
  float voltage = (average * 3300.0) / 4095.0;
  
  // Thread-safe update
  if (xSemaphoreTake(sensorDataMutex, portMAX_DELAY) == pdTRUE) {
    sensorData.sunshineVoltage = voltage;
    xSemaphoreGive(sensorDataMutex);
  }
}

void readRaindropSensor() {
  // Most raindrop sensors: LOW = rain detected, HIGH = no rain
  int reading = digitalRead(RAINDROP_DO_PIN);
  // Thread-safe update
  if (xSemaphoreTake(sensorDataMutex, portMAX_DELAY) == pdTRUE) {
    sensorData.raindropDetected = (reading == LOW);
    xSemaphoreGive(sensorDataMutex);
  }
}

// FreeRTOS task for reading DHT11 sensor (runs in separate thread)
void dht11Task(void *parameter) {
  const TickType_t xDelay = pdMS_TO_TICKS(2000);  // 2 seconds delay (DHT11 requirement)
  
  Serial.println("DHT11 task started");
  
  // Initial delay to let other systems initialize
  vTaskDelay(pdMS_TO_TICKS(1000));
  
  while (1) {
    // DHT11 sensor reading - needs at least 2 seconds between readings
    // Read humidity first (triggers a sensor reading)
    float h = dht.readHumidity();
    
    // Small delay to ensure sensor has time to respond
    vTaskDelay(pdMS_TO_TICKS(50));
    
    // Read temperature (this will use the same sensor reading as humidity)
    float t = dht.readTemperature();
    
    // Check if readings failed
    if (isnan(h) || isnan(t)) {
      // Reading failed, wait longer and try again
      vTaskDelay(pdMS_TO_TICKS(500));  // DHT11 needs time between failed reads
      h = dht.readHumidity();
      vTaskDelay(pdMS_TO_TICKS(50));
      t = dht.readTemperature();
      
      // If still failed, log error and skip update
      if (isnan(h) || isnan(t)) {
        Serial.println("[DHT11] Read failed! Keeping previous values.");
        vTaskDelay(xDelay);  // Wait before next attempt
        continue;
      }
    }
    
    // Thread-safe update of sensor data
    if (xSemaphoreTake(sensorDataMutex, portMAX_DELAY) == pdTRUE) {
      // Get old values for comparison
      float oldTemp = sensorData.temperature;
      float oldHumid = sensorData.humidity;
      
      // Check if values changed
      bool tempChanged = (abs(t - oldTemp) > 0.1);  // Changed by more than 0.1°C
      bool humidChanged = (abs(h - oldHumid) > 0.5); // Changed by more than 0.5%
      
      if (!tempChanged && !humidChanged && dht11_read_count > 0) {
        dht11_same_value_count++;
      } else {
        dht11_same_value_count = 0;  // Reset counter if values changed
      }
      
      // Update sensor data
      sensorData.humidity = h;
      sensorData.temperature = t;
      dht11_read_count++;
      
      // Release mutex
      xSemaphoreGive(sensorDataMutex);
      
      // Debug output
      Serial.print("[DHT11 #");
      Serial.print(dht11_read_count);
      Serial.print("] Temp=");
      Serial.print(t, 2);
      Serial.print("°C, Humidity=");
      Serial.print(h, 1);
      Serial.print("%");
      if (dht11_same_value_count > 0) {
        Serial.print(" (unchanged for ");
        Serial.print(dht11_same_value_count);
        Serial.print(" reads)");
      }
      Serial.println();
    }
    
    // Wait 2 seconds before next reading (DHT11 requirement)
    vTaskDelay(xDelay);
  }
}

String createJSONData() {
  StaticJsonDocument<1024> doc;
  
  // Thread-safe read of sensor data
  float temp, humid, roll, pitch, yaw;
  bool raindrop;
  float sunshine;
  unsigned long ts;
  
  if (xSemaphoreTake(sensorDataMutex, portMAX_DELAY) == pdTRUE) {
    temp = sensorData.temperature;
    humid = sensorData.humidity;
    roll = sensorData.roll;
    pitch = sensorData.pitch;
    yaw = sensorData.yaw;
    raindrop = sensorData.raindropDetected;
    sunshine = sensorData.sunshineVoltage;
    ts = sensorData.timestamp;
    xSemaphoreGive(sensorDataMutex);
  } else {
    // If mutex fails, use default values
    temp = 0.0;
    humid = 0.0;
    roll = 0.0;
    pitch = 0.0;
    yaw = 0.0;
    raindrop = false;
    sunshine = 0.0;
    ts = millis();
  }
  
  // Add timestamp
  doc["timestamp"] = ts;
  
  // Check which fields to include based on configuration
  String fields = apConfig.dataFields;
  bool sendAll = (fields == "all" || fields == "");
  
  // Temperature and Humidity (from DHT11)
  if (sendAll || fields.indexOf("temperature") >= 0) {
    doc["temperature"] = temp;
  }
  
  if (sendAll || fields.indexOf("humidity") >= 0) {
    doc["humidity"] = humid;
  }
  
  // Orientation data (from JY901S)
  if (sendAll || fields.indexOf("roll") >= 0 || fields.indexOf("orientation") >= 0) {
    doc["roll"] = roll;
  }
  
  if (sendAll || fields.indexOf("pitch") >= 0 || fields.indexOf("orientation") >= 0) {
    doc["pitch"] = pitch;
  }
  
  if (sendAll || fields.indexOf("yaw") >= 0 || fields.indexOf("orientation") >= 0) {
    doc["yaw"] = yaw;
  }
  
  // Environmental sensors (optional)
  if (sendAll || fields.indexOf("raindrop") >= 0) {
    doc["raindropDetected"] = raindrop;
  }
  
  if (sendAll || fields.indexOf("sunshine") >= 0) {
    doc["sunshineVoltage"] = sunshine;
  }
  
  // Convert to JSON string
  String jsonString;
  serializeJson(doc, jsonString);
  
  return jsonString;
}

void sendDataToAP() {
  if (!apConfig.configured) {
    Serial.println("Configuration not received yet. Skipping data send.");
    return;
  }
  
  // Create JSON data based on configuration
  String jsonData = createJSONData();
  
  Serial.println("Sending data to AP:");
  Serial.println(jsonData);
  
  http.begin(client, serverURL + dataEndpoint);
  http.addHeader("Content-Type", "application/json");
  
  int httpResponseCode = http.POST(jsonData);
  
  if (httpResponseCode > 0) {
    Serial.print("HTTP Response code: ");
    Serial.println(httpResponseCode);
    
    if (httpResponseCode == 200) {
      String response = http.getString();
      Serial.println("Response: " + response);
      
      // Check if AP sent new configuration in response
      if (response.length() > 0 && response.startsWith("{")) {
        parseConfiguration(response);
      }
    }
  } else {
    Serial.print("Error on sending POST: ");
    Serial.println(httpResponseCode);
  }
  
  http.end();
}

// =================== JY901S Sensor Callback Functions ===================
static void SensorUartSend(uint8_t *p_data, uint32_t uiSize) {
  JY901S.write(p_data, uiSize);
  JY901S.flush();
}

static void Delayms(uint16_t ucMs) {
  delay(ucMs);
}

static void SensorDataUpdata(uint32_t uiReg, uint32_t uiRegNum) {
  for (int i = 0; i < uiRegNum; i++) {
    switch (uiReg) {
      case AZ: s_cDataUpdate |= ACC_UPDATE; break;
      case GZ: s_cDataUpdate |= GYRO_UPDATE; break;
      case HZ: s_cDataUpdate |= MAG_UPDATE; break;
      case Yaw: s_cDataUpdate |= ANGLE_UPDATE; break;
      default: s_cDataUpdate |= READ_UPDATE; break;
    }
    uiReg++;
  }
}

static void AutoScanSensor(void) {
  const uint32_t c_uiBaud[8] = {0, 4800, 9600, 19200, 38400, 57600, 115200, 230400};
  // Skip index 0 (invalid baud = 0) and always configure pins / format
  for (int i = 1; i < (int)(sizeof(c_uiBaud) / sizeof(c_uiBaud[0])); i++) {
    JY901S.begin(c_uiBaud[i], SERIAL_8N1, JY_RX, JY_TX);
    JY901S.flush();
    int iRetry = 2;
    s_cDataUpdate = 0;
    do {
      WitReadReg(AX, 3);
      delay(200);
      while (JY901S.available()) {
        WitSerialDataIn(JY901S.read());
      }
      if (s_cDataUpdate != 0) {
        Serial.print(c_uiBaud[i]);
        Serial.println(" baud sensor found!");
        return;
      }
      iRetry--;
    } while (iRetry);
  }
  Serial.println("Sensor not found. Check connection and power.");
}
