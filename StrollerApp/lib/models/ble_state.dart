import 'package:flutter/foundation.dart';

/// Bluetooth Low Energy state management
class BleState extends ChangeNotifier {
  bool _isEnabled = false;
  bool _isConnected = false;
  String? _connectedDeviceName;
  String? _connectedDeviceId;

  /// Check if Bluetooth is enabled
  bool get isEnabled => _isEnabled;

  /// Check if device is connected
  bool get isConnected => _isConnected;

  /// Get connected device name
  String? get connectedDeviceName => _connectedDeviceName;

  /// Get connected device ID
  String? get connectedDeviceId => _connectedDeviceId;

  /// Set Bluetooth enabled status
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// Set connection status
  void setConnected(bool connected, {String? deviceName, String? deviceId}) {
    _isConnected = connected;
    _connectedDeviceName = deviceName;
    _connectedDeviceId = deviceId;
    notifyListeners();
  }

  /// Disconnect from current device
  void disconnect() {
    _isConnected = false;
    _connectedDeviceName = null;
    _connectedDeviceId = null;
    notifyListeners();
  }
}
