import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Temperature & humidity reading with timestamp
class TemperatureReading {
  final double temperature;
  final double? humidity;
  final DateTime timestamp;

  TemperatureReading({
    required this.temperature,
    this.humidity,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TemperatureReading.fromJson(Map<String, dynamic> json) {
    return TemperatureReading(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: json['humidity'] != null ? (json['humidity'] as num).toDouble() : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Service for storing and retrieving temperature history
class TemperatureHistoryService {
  static const String _historyKey = 'temperature_history';
  static const int _maxReadings = 1000; // Keep last 1000 readings

  /// Save a temperature & humidity reading
  Future<void> saveReading(double temperature, [double? humidity]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readings = await getReadings();

      // Add new reading at the beginning
      readings.insert(0, TemperatureReading(
        temperature: temperature,
        timestamp: DateTime.now(),
      ));

      // Keep only last N readings
      final readingsToKeep = readings.take(_maxReadings).toList();

      // Convert to JSON strings
      final readingsJson = readingsToKeep
          .map((reading) => jsonEncode(reading.toJson()))
          .toList();

      await prefs.setStringList(_historyKey, readingsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving temperature reading: $e');
      }
    }
  }

  /// Get all temperature readings
  Future<List<TemperatureReading>> getReadings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readingsJson = prefs.getStringList(_historyKey);

      if (readingsJson == null || readingsJson.isEmpty) {
        return [];
      }

      final readings = readingsJson
          .map((jsonString) {
            try {
              final json = jsonDecode(jsonString) as Map<String, dynamic>;
              return TemperatureReading.fromJson(json);
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing temperature reading: $e');
              }
              return null;
            }
          })
          .whereType<TemperatureReading>()
          .toList();

      return readings;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading temperature readings: $e');
      }
      return [];
    }
  }

  /// Get readings for the last N hours
  Future<List<TemperatureReading>> getReadingsForHours(int hours) async {
    final allReadings = await getReadings();
    final cutoffTime = DateTime.now().subtract(Duration(hours: hours));
    return allReadings.where((r) => r.timestamp.isAfter(cutoffTime)).toList();
  }

  /// Clear all readings
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing temperature history: $e');
      }
    }
  }
}
