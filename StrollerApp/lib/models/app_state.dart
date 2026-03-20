import 'package:flutter/foundation.dart';
import 'fan_state.dart';
import 'wifi_state.dart';
import 'gps_state.dart';

/// Root application state using Provider pattern
class MyAppState extends ChangeNotifier {
  int _selectedPage = 0;
  int _selectedModel = 0;
  
  final FanState _fanState = FanState();
  final WifiState _wifiState = WifiState();
  final GpsState _gpsState = GpsState();

  /// Get currently selected page index
  int get selectedPage => _selectedPage;

  /// Get selected 3D model index
  int get selectedModel => _selectedModel;

  /// Get fan state
  FanState get fanState => _fanState;

  /// Get WiFi state
  WifiState get wifiState => _wifiState;

  /// Get GPS state
  GpsState get gpsState => _gpsState;

  /// Set selected page
  void setSelectedPage(int page) {
    _selectedPage = page;
    notifyListeners();
  }

  /// Set selected model
  void setSelectedModel(int model) {
    _selectedModel = model;
    notifyListeners();
  }
}
