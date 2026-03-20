import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FanState model manages fan control logic and state
/// Handles temperature threshold, fan status, and lid status
class FanState extends ChangeNotifier {
  static const String _thresholdKey = 'fan_threshold_temperature';
  static const double _defaultThreshold = 26.0;

  double _thresholdTemperature = _defaultThreshold;
  bool _isFanOn = false;
  double _currentTemperature = 0.0;
  bool _isLidClosed = false;
  String _lidCloseReason = '';

  FanState() {
    _loadThreshold();
  }

  /// Get current threshold temperature
  double get thresholdTemperature => _thresholdTemperature;

  /// Get current fan status
  bool get isFanOn => _isFanOn;

  /// Get current temperature
  double get currentTemperature => _currentTemperature;

  /// Get lid status
  bool get isLidClosed => _isLidClosed;

  /// Get lid close reason
  String get lidCloseReason => _lidCloseReason;

  /// Load threshold temperature from SharedPreferences
  Future<void> _loadThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThreshold = prefs.getDouble(_thresholdKey);
      if (savedThreshold != null) {
        _thresholdTemperature = savedThreshold;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading threshold: $e');
      }
    }
  }

  /// Set and save threshold temperature
  Future<void> setThresholdTemperature(double temperature) async {
    _thresholdTemperature = temperature;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_thresholdKey, temperature);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving threshold: $e');
      }
    }
    notifyListeners();
  }

  /// Update current temperature (for display). Fan state does NOT auto-change.
  void updateTemperature(double temperature) {
    _currentTemperature = temperature;
    notifyListeners();
  }

  /// Set lid status (closed when UV too high or raining)
  void setLidClosed(bool closed, {String reason = ''}) {
    _isLidClosed = closed;
    _lidCloseReason = reason;
    // If lid closes, force fan OFF; if opens, keep current fan state
    if (_isLidClosed) {
      _isFanOn = false;
    }
    notifyListeners();
  }

  /// Manually set fan state from UI button
  void setFanOn(bool on) {
    if (_isLidClosed && on) {
      // Lid closed: fan cannot be turned on
      _isFanOn = false;
    } else {
      _isFanOn = on;
    }
    notifyListeners();
  }
}
