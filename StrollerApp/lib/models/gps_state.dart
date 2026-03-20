import 'package:flutter/foundation.dart';

/// GPS state management
class GpsState extends ChangeNotifier {
  bool _isEnabled = false;
  bool _hasPermission = false;
  double? _latitude;
  double? _longitude;
  double? _accuracy;

  /// Check if GPS is enabled
  bool get isEnabled => _isEnabled;

  /// Check if location permission is granted
  bool get hasPermission => _hasPermission;

  /// Get current latitude
  double? get latitude => _latitude;

  /// Get current longitude
  double? get longitude => _longitude;

  /// Get current accuracy
  double? get accuracy => _accuracy;

  /// Set GPS enabled status
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// Set permission status
  void setPermission(bool granted) {
    _hasPermission = granted;
    notifyListeners();
  }

  /// Update location
  void updateLocation(double latitude, double longitude, {double? accuracy}) {
    _latitude = latitude;
    _longitude = longitude;
    _accuracy = accuracy;
    notifyListeners();
  }

  /// Clear location data
  void clearLocation() {
    _latitude = null;
    _longitude = null;
    _accuracy = null;
    notifyListeners();
  }
}
