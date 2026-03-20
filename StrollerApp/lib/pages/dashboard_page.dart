import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/app_state.dart';
import '../services/records_service.dart';
import '../services/wifi_service.dart';
import '../services/temperature_history_service.dart';
import '../models/record.dart';
import 'connection_page.dart';
import 'records_page.dart';
import 'gps_page.dart';
import 'temperature_chart_page.dart';

/// Main dashboard page - entry point of the application
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final RecordsService _recordsService = RecordsService();
  final WifiService _wifiService = WifiService();
  final TemperatureHistoryService _tempHistoryService = TemperatureHistoryService();
  List<Record> _recentRecords = [];
  bool _isLoading = true;
  Timer? _sensorPollTimer;

  // Latest live sensor values from ESP32 via Raspberry Pi
  double? _latestTemperature;
  double? _latestHumidity;
  bool? _latestRainDetected;
  double? _latestSunshineMv;
  double? _latestRoll;
  double? _latestPitch;
  double? _latestYaw;
  DateTime? _lastSensorUpdate;

  @override
  void initState() {
    super.initState();
    _loadRecentRecords();
    _startSensorPolling();
  }

  @override
  void dispose() {
    _sensorPollTimer?.cancel();
    super.dispose();
  }

  /// Load 5 most recent records
  Future<void> _loadRecentRecords() async {
    setState(() => _isLoading = true);
    final allRecords = await _recordsService.getRecords();
    setState(() {
      _recentRecords = allRecords.take(5).toList();
      _isLoading = false;
    });
  }

  /// Start polling sensor data from ESP32
  void _startSensorPolling() {
    final appState = context.read<MyAppState>();
    
    // Update device IP if connected
    if (appState.wifiState.isConnected && appState.wifiState.deviceIp != null) {
      _wifiService.setDeviceIp(appState.wifiState.deviceIp!);
    }

    // Poll sensor data every 2 seconds
    _sensorPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchSensorData();
    });

    // Initial fetch
    _fetchSensorData();
  }

  /// Fetch sensor data from ESP32
  Future<void> _fetchSensorData() async {
    final appState = context.read<MyAppState>();
    
    // Only fetch if connected
    if (!appState.wifiState.isConnected) {
      if (kDebugMode) {
        print('WiFi not connected, skipping sensor data fetch');
      }
      return;
    }

    // Update device IP if changed
    if (appState.wifiState.deviceIp != null) {
      _wifiService.setDeviceIp(appState.wifiState.deviceIp!);
    }

    if (kDebugMode) {
      print('Fetching sensor data from: ${_wifiService.deviceIp}');
    }

    final sensorData = await _wifiService.fetchSensorData();
    
    if (sensorData != null && mounted) {
      if (kDebugMode) {
        print('Sensor data received: $sensorData');
      }

      // Parse temperature
      final temperatureRaw = sensorData['temperature'];
      double? temperature;
      if (temperatureRaw is num) {
        temperature = temperatureRaw.toDouble();
      } else if (temperatureRaw is String) {
        temperature = double.tryParse(temperatureRaw);
      }

      // Parse humidity
      final humidityRaw = sensorData['humidity'];
      double? humidity;
      if (humidityRaw is num) {
        humidity = humidityRaw.toDouble();
      } else if (humidityRaw is String) {
        humidity = double.tryParse(humidityRaw);
      }

      // Parse rain & sunshine (UV proxy)
      final rainDetected = sensorData['raindropDetected'] as bool? ?? false;
      final sunshineRaw = sensorData['sunshineVoltage'];
      double? sunshineMv;
      if (sunshineRaw is num) {
        sunshineMv = sunshineRaw.toDouble();
      } else if (sunshineRaw is String) {
        sunshineMv = double.tryParse(sunshineRaw);
      }

      // Parse orientation
      double? roll, pitch, yaw;
      final rollRaw = sensorData['roll'];
      final pitchRaw = sensorData['pitch'];
      final yawRaw = sensorData['yaw'];
      if (rollRaw is num) roll = rollRaw.toDouble();
      if (pitchRaw is num) pitch = pitchRaw.toDouble();
      if (yawRaw is num) yaw = yawRaw.toDouble();

      // Update local state for UI
      setState(() {
        _latestTemperature = temperature;
        _latestHumidity = humidity;
        _latestRainDetected = rainDetected;
        _latestSunshineMv = sunshineMv;
        _latestRoll = roll;
        _latestPitch = pitch;
        _latestYaw = yaw;
        _lastSensorUpdate = DateTime.now();
      });

      // Update fan state temperature & history
      if (temperature != null) {
        appState.fanState.updateTemperature(temperature);
        _tempHistoryService.saveReading(temperature, humidity);
        if (kDebugMode) {
          print('Temperature updated: $temperature°C');
        }
      } else {
        if (kDebugMode) {
          print('No temperature field in sensor data');
        }
      }

      // Derive simple UV index proxy from sunshine voltage (0-3300mV -> ~0-10)
      double uvIndex = 0.0;
      if (sunshineMv != null) {
        uvIndex = (sunshineMv / 330.0).clamp(0.0, 10.0);
      }

      // Lid control logic: rain or high UV closes lid
      if (rainDetected) {
        appState.fanState.setLidClosed(true, reason: 'Rain detected');
      } else if (uvIndex > 8.0) {
        appState.fanState.setLidClosed(true, reason: 'UV too high');
      } else {
        appState.fanState.setLidClosed(false);
      }

      // Update WiFi connection state
      appState.wifiState.setConnected(true, deviceIp: appState.wifiState.deviceIp);
    } else if (mounted) {
      // Connection failed, update state
      if (kDebugMode) {
        print('Failed to fetch sensor data or response was null');
      }
      appState.wifiState.setConnected(false);
    }
  }

  /// Format DateTime to HH:MM
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format DateTime to full date and time
  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// Show record details dialog
  void _showRecordDetails(Record record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Drone ID', record.droneId ?? 'N/A'),
              _buildDetailRow('Serial Number', record.serialNumber ?? 'N/A'),
              _buildDetailRow('Timestamp', _formatFullDateTime(record.timestamp)),
              if (record.latitude != null && record.longitude != null)
                _buildDetailRow('GPS', '${record.latitude!.toStringAsFixed(6)}, ${record.longitude!.toStringAsFixed(6)}')
              else
                _buildDetailRow('GPS', 'Not available'),
              _buildDetailRow('Device Name', record.deviceName ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/records');
            },
            child: const Text('View All Records'),
          ),
        ],
      ),
    );
  }

  /// Build detail row widget
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Build status display item
  Widget _buildStatusItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  /// Build quick action card
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show dialog to adjust fan threshold temperature
  Future<void> _showThresholdDialog(BuildContext context, MyAppState appState) async {
    final controller = TextEditingController(
      text: appState.fanState.thresholdTemperature.toStringAsFixed(1),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Fan Threshold'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Temperature (°C)',
            hintText: '26.0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await appState.fanState.setThresholdTemperature(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final fanState = appState.fanState;
    final wifiState = appState.wifiState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
              wifiState.isConnected ? Icons.wifi : Icons.wifi_off,
              color: wifiState.isConnected ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/connect');
            },
            tooltip: wifiState.isConnected
                ? 'Connected: ${wifiState.deviceIp ?? "Device"}'
                : 'Not Connected',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecentRecords,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Sensor Overview Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Live Sensors',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (_lastSensorUpdate != null)
                            Text(
                              'Updated ${_formatDateTime(_lastSensorUpdate!)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatusItem(
                                  'Temperature',
                                  _latestTemperature != null
                                      ? '${_latestTemperature!.toStringAsFixed(1)}°C'
                                      : '--',
                                  Colors.blue,
                                ),
                                _buildStatusItem(
                                  'Humidity',
                                  _latestHumidity != null
                                      ? '${_latestHumidity!.toStringAsFixed(1)}%'
                                      : '--',
                                  Colors.teal,
                                ),
                                _buildStatusItem(
                                  'Rain',
                                  _latestRainDetected == true ? 'Detected' : 'None',
                                  _latestRainDetected == true ? Colors.red : Colors.green,
                                ),
                                _buildStatusItem(
                                  'UV (sunlight)',
                                  _latestSunshineMv != null
                                      ? '${(_latestSunshineMv! / 1000).toStringAsFixed(2)} V'
                                      : '--',
                                  Colors.deepPurple,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatusItem(
                                  'Roll',
                                  _latestRoll != null
                                      ? '${_latestRoll!.toStringAsFixed(1)}°'
                                      : '--',
                                  Colors.orange,
                                ),
                                _buildStatusItem(
                                  'Pitch',
                                  _latestPitch != null
                                      ? '${_latestPitch!.toStringAsFixed(1)}°'
                                      : '--',
                                  Colors.orangeAccent,
                                ),
                                _buildStatusItem(
                                  'Yaw',
                                  _latestYaw != null
                                      ? '${_latestYaw!.toStringAsFixed(1)}°'
                                      : '--',
                                  Colors.brown,
                                ),
                                _buildStatusItem(
                                  'GPS',
                                  appState.gpsState.latitude != null &&
                                          appState.gpsState.longitude != null
                                      ? 'Lat ${appState.gpsState.latitude!.toStringAsFixed(4)}, '
                                          'Lon ${appState.gpsState.longitude!.toStringAsFixed(4)}'
                                      : (appState.gpsState.hasPermission
                                          ? 'Searching...'
                                          : 'Not available'),
                                  appState.gpsState.latitude != null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Fan Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Fan Status',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                              ],
                            ),
                            Icon(
                              fanState.isFanOn ? Icons.air : Icons.air_outlined,
                              color: fanState.isFanOn ? Colors.green : Colors.grey,
                              size: 32,
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildStatusItem(
                          'Status',
                          fanState.isFanOn ? 'ON' : 'OFF',
                          fanState.isFanOn ? Colors.green : Colors.grey,
                        ),
                        // Temperature & Humidity - Clickable to show chart
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TemperatureChartPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Temperature & Humidity',
                                      style: TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.show_chart, size: 14, color: Colors.grey[400]),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${fanState.currentTemperature.toStringAsFixed(1)}°C',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 16, color: Colors.blue),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Threshold with inline editing
                      InkWell(
                        onTap: () => _showThresholdDialog(context, appState),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Threshold',
                                    style: TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${fanState.thresholdTemperature.toStringAsFixed(1)}°C',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 16, color: Colors.orange),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildStatusItem(
                        'Lid Status',
                        fanState.isLidClosed ? 'Closed' : 'Open',
                        fanState.isLidClosed ? Colors.red : Colors.green,
                      ),
                      if (fanState.isLidClosed && fanState.lidCloseReason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Reason: ${fanState.lidCloseReason}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Fan control button (only changes when user taps)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            appState.fanState.setFanOn(!fanState.isFanOn);
                          },
                          icon: Icon(fanState.isFanOn ? Icons.air : Icons.air_outlined),
                          label: Text(fanState.isFanOn ? 'Turn Fan OFF' : 'Turn Fan ON'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: fanState.isFanOn ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recent Records Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Records',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/records'),
                    child: const Text('View All'),
                  ),
                ],
              ),

              ...([
                if (_isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )),
                if (!_isLoading && _recentRecords.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.nfc, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No records yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Records will appear after NFC scans',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_isLoading && _recentRecords.isNotEmpty)
                  ..._recentRecords.map((record) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.nfc, color: Colors.blue),
                      title: InkWell(
                        onTap: () => _showRecordDetails(record),
                        child: Text(
                          record.droneId ?? 'Unknown Drone',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      subtitle: Text(
                        'Serial: ${record.serialNumber ?? "N/A"} • ${_formatDateTime(record.timestamp)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showRecordDetails(record),
                    ),
                  )),
              ]),

              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildActionCard(
                    icon: Icons.history,
                    title: 'Records',
                    onTap: () => Navigator.pushNamed(context, '/records'),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildActionCard(
                    icon: Icons.map,
                    title: 'GPS Map',
                    onTap: () => Navigator.pushNamed(context, '/gps'),
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
