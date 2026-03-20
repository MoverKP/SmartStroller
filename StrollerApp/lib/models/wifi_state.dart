import 'package:flutter/foundation.dart';

/// WiFi connection state management
class WifiState extends ChangeNotifier {
  bool _isConnected = false;
  String? _deviceIp;
  String? _deviceName;

  /// Check if WiFi is connected to device
  bool get isConnected => _isConnected;

  /// Get connected device IP
  String? get deviceIp => _deviceIp;

  /// Get connected device name
  String? get deviceName => _deviceName;

  /// Set connection status
  void setConnected(bool connected, {String? deviceIp, String? deviceName}) {
    _isConnected = connected;
    _deviceIp = deviceIp;
    _deviceName = deviceName;
    notifyListeners();
  }

  /// Disconnect from current device
  void disconnect() {
    _isConnected = false;
    _deviceIp = null;
    _deviceName = null;
    notifyListeners();
  }
}
