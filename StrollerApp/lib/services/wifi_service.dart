import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for communicating with Raspberry Pi SmartStroller server via WiFi HTTP API
///
/// Network topology:
/// - Raspberry Pi runs an AP with SSID "SmartStroller" and IP 192.168.4.1
/// - ESP32 connects to this AP and POSTs sensor data to `http://192.168.4.1/data`
/// - Mobile app connects to the same AP and polls `http://192.168.4.1/latest`
///   to get the latest sensor reading, and can update configuration via `/update_config`.
class WifiService {
  static const String defaultIp = '192.168.4.1';
  static const String latestEndpoint = '/latest';
  static const String statusEndpoint = '/status';
  static const String updateConfigEndpoint = '/update_config';
  static const Duration requestTimeout = Duration(seconds: 5);

  String _deviceIp = defaultIp;
  bool _isConnected = false;

  /// Get current device IP
  String get deviceIp => _deviceIp;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Set device IP address
  void setDeviceIp(String ip) {
    _deviceIp = ip;
  }

  /// Test connection to Raspberry Pi server by hitting /latest
  Future<bool> testConnection({String? ip}) async {
    final testIp = ip ?? _deviceIp;
    try {
      final uri = Uri.parse('http://$testIp$latestEndpoint');
      final response = await http.get(uri).timeout(requestTimeout);
      
      if (response.statusCode == 200) {
        _deviceIp = testIp;
        _isConnected = true;
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Connection test failed: $e');
      }
    }
    _isConnected = false;
    return false;
  }

  /// Fetch latest sensor data from Raspberry Pi (/latest)
  Future<Map<String, dynamic>?> fetchSensorData() async {
    try {
      final uri = Uri.parse('http://$_deviceIp$latestEndpoint');
      if (kDebugMode) {
        print('Requesting latest data: $uri');
      }
      
      final response = await http.get(uri).timeout(requestTimeout);

      if (kDebugMode) {
        print('Latest data status: ${response.statusCode}');
        print('Latest data body: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          _isConnected = true;
          if (kDebugMode) {
            print('Parsed latest JSON: $jsonData');
          }
          // Raspberry Pi /latest returns: { "status": "ok", "data": { ... } }
          if (jsonData.containsKey('data') && jsonData['data'] is Map<String, dynamic>) {
            return jsonData['data'] as Map<String, dynamic>;
          }
          return jsonData;
        } catch (e) {
          _isConnected = false;
          if (kDebugMode) {
            print('Latest JSON parse error: $e');
            print('Response body: ${response.body}');
          }
        }
      } else {
        _isConnected = false;
        if (kDebugMode) {
          print('Failed to fetch latest data: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }
    } catch (e) {
      _isConnected = false;
      if (kDebugMode) {
        print('Error fetching latest data: $e');
      }
    }
    return null;
  }

  /// Fetch server status (includes current_config and statistics)
  Future<Map<String, dynamic>?> fetchServerStatus() async {
    try {
      final uri = Uri.parse('http://$_deviceIp$statusEndpoint');
      if (kDebugMode) {
        print('Requesting status: $uri');
      }

      final response = await http.get(uri).timeout(requestTimeout);

      if (kDebugMode) {
        print('Status response: ${response.statusCode}');
        print('Status body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonData;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching server status: $e');
      }
    }
    return null;
  }

  /// Update configuration on Raspberry Pi (dataFields, frequency)
  Future<bool> updateServerConfig({String? dataFields, int? frequency}) async {
    try {
      final uri = Uri.parse('http://$_deviceIp$updateConfigEndpoint');
      final body = <String, dynamic>{};
      if (dataFields != null) {
        body['dataFields'] = dataFields;
      }
      if (frequency != null) {
        body['frequency'] = frequency;
      }
      if (kDebugMode) {
        print('Updating config at $uri with body: $body');
      }
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(requestTimeout);

      if (kDebugMode) {
        print('Update config response: ${response.statusCode}');
        print('Update config body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonData['status'] == 'ok';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating server config: $e');
      }
    }
    return false;
  }

  /// Disconnect (reset connection state)
  void disconnect() {
    _isConnected = false;
  }
}
