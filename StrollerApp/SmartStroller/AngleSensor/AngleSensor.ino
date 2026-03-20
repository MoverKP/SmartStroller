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

HardwareSerial JY901S(2);  // hardware serial instance for JY901S sensor (UART2)
DHT dht(TEMP_HUMIDITY_PIN, DHT11);  // DHT11 temperature and humidity sensor

#define ACC_UPDATE    0x01
#define GYRO_UPDATE   0x02
#define ANGLE_UPDATE  0x04
#define MAG_UPDATE    0x08
#define READ_UPDATE   0x80

static volatile char s_cDataUpdate = 0, s_cCmd = 0xff;
const uint32_t c_uiBaud[8] = {0, 4800, 9600, 19200, 38400, 57600, 115200, 230400};

int i;
float fAcc[3], fGyro[3], fAngle[3];

// Environmental sensor variables
float temperature = 0.0;
float humidity = 0.0;
bool raindropDetected = false;
float sunshineVoltage = 0.0;  // in millivolts

// =================== Setup ===================
void setup() {
  Serial.begin(115200);
  JY901S.begin(9600, SERIAL_8N1, JY_RX, JY_TX);
  WitInit(WIT_PROTOCOL_NORMAL, 0x50);
  WitSerialWriteRegister(SensorUartSend);
  WitRegisterCallBack(SensorDataUpdata);
  WitDelayMsRegister(Delayms);

  // Initialize environmental sensor pins
  dht.begin();  // Initialize DHT sensor
  pinMode(RAINDROP_DO_PIN, INPUT_PULLUP);  // Use pullup for digital input
  // SUNSHINE_ANALOG_PIN is analog, no pinMode needed
  // ESP32-S3 ADC is 12-bit by default (0-4095)

  // Initial signal
  Serial.write("\r\n********************** wit-motion UART example ************************\r\n");
  AutoScanSensor();
}

// =================== Sensor Reading Functions ===================
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
  sunshineVoltage = (average * 3300.0) / 4095.0;
}

void readRaindropSensor() {
  // Try both logic - some modules use HIGH for rain, others use LOW
  int reading = digitalRead(RAINDROP_DO_PIN);
  // Most raindrop sensors: LOW = rain detected, HIGH = no rain
  // If this doesn't work, try: raindropDetected = (reading == HIGH);
  raindropDetected = (reading == LOW);
}

void readTempHumiditySensor() {
  // DHT11 sensor reading - needs at least 2 seconds between readings
  // Read humidity first (more reliable)
  humidity = dht.readHumidity();
  // Read temperature (in Celsius)
  temperature = dht.readTemperature();
  
  // Check if readings failed and retry
  if (isnan(humidity) || isnan(temperature)) {
    // Reading failed, try again
    humidity = dht.readHumidity();
    temperature = dht.readTemperature();
  }
}

// =================== Main Loop ===================
void loop() {
  // Read bytes from JY901S over hardware UART
  while (JY901S.available()) {
    uint8_t incomingByte = JY901S.read();
    WitSerialDataIn(incomingByte); // Feed sensor data into WIT library
  }

  // Handle commands from USB serial
  while (Serial.available()) {
    CopeCmdData(Serial.read());
  }

  CmdProcess();

  // Process updated sensor registers and output full motion data
  if (s_cDataUpdate) {
    for (i = 0; i < 3; i++) {
      fAcc[i]   = sReg[AX   + i] / 32768.0f * 16.0f;
      fGyro[i]  = sReg[GX   + i] / 32768.0f * 2000.0f;
      fAngle[i] = sReg[Roll + i] / 32768.0f * 180.0f;  // Roll, Pitch, Yaw in degrees
    }

    if (s_cDataUpdate & ANGLE_UPDATE) {
      float roll = fAngle[0];  // Rotation around X-axis (left/right tilt)
      float pitch = fAngle[1]; // Rotation around Y-axis (forward/backward tilt)
      float yaw = fAngle[2];   // Rotation around Z-axis (compass heading)
      
      Serial.print("angle:");
      Serial.print("Roll:");
      Serial.print(roll, 3);
      Serial.print(" Pitch:");
      Serial.print(pitch, 3);
      Serial.print(" Yaw:");
      Serial.print(yaw, 3);
      Serial.print("\r\n");
      s_cDataUpdate &= ~ANGLE_UPDATE;
    }

    s_cDataUpdate = 0;
  }

  // Read environmental sensors periodically
  // DHT11 needs at least 2 seconds between readings
  static unsigned long lastSensorRead = 0;
  unsigned long currentTime = millis();
  if (currentTime - lastSensorRead >= 2000) {  // Read every 2 seconds (DHT11 requirement)
    readSunshineSensor();
    readRaindropSensor();
    readTempHumiditySensor();
    
    // Output environmental sensor data
    // Debug: also show raw ADC reading for sunshine sensor
    int rawSunshine = analogRead(SUNSHINE_ANALOG_PIN);
    int rawRaindrop = digitalRead(RAINDROP_DO_PIN);
    
    Serial.print("environment:");
    Serial.print("Temp:");
    Serial.print(temperature, 2);
    Serial.print(" Humidity:");
    Serial.print(humidity, 2);
    Serial.print(" Raindrop:");
    Serial.print(raindropDetected ? "Yes" : "No");
    Serial.print("(raw:");
    Serial.print(rawRaindrop);
    Serial.print(") Sunshine:");
    Serial.print(sunshineVoltage, 2);
    Serial.print("mV");
    Serial.print("(raw:");
    Serial.print(rawSunshine);
    Serial.print(")");
    Serial.print("\r\n");
    
    lastSensorRead = currentTime;
  }
  delay(500);
}

// =================== Command Processing ===================
void CopeCmdData(unsigned char ucData) {
  static unsigned char s_ucData[50], s_ucRxCnt = 0;
  s_ucData[s_ucRxCnt++] = ucData;
  if (s_ucRxCnt < 3) return;
  if (s_ucRxCnt >= 50) s_ucRxCnt = 0;
  if ((s_ucData[1] == '\r') && (s_ucData[2] == '\n')) {
    s_cCmd = s_ucData[0];
    memset(s_ucData, 0, 50);
    s_ucRxCnt = 0;
  } else {
    s_ucData[0] = s_ucData[1];
    s_ucData[1] = s_ucData[2];
    s_ucRxCnt = 2;
  }
}

static void CmdProcess(void) {
  switch (s_cCmd) {
    case 'a': WitStartAccCali(); break;
    case 'm': WitStartMagCali(); break;
    case 'e': WitStopMagCali(); break;
    case 'u': WitSetBandwidth(BANDWIDTH_5HZ); break;
    case 'U': WitSetBandwidth(BANDWIDTH_256HZ); break;
    case 'B': JY901S.begin(c_uiBaud[WIT_BAUD_115200], SERIAL_8N1, JY_RX, JY_TX); break;
    case 'b': JY901S.begin(c_uiBaud[WIT_BAUD_9600], SERIAL_8N1, JY_RX, JY_TX); break;
    case 'r': WitSetOutputRate(RRATE_1HZ); break;
    case 'R': WitSetOutputRate(RRATE_10HZ); break;
    case 'C': WitSetContent(RSW_ACC | RSW_GYRO | RSW_ANGLE | RSW_MAG); break;
    case 'c': WitSetContent(RSW_ACC); break;
    default: break;
  }
  s_cCmd = 0xff;
}

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
