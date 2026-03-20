import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/record.dart';

/// Service for managing NFC scan records with offline storage
class RecordsService {
  static const String _recordsKey = 'nfc_scan_records';
  static const int _maxRecords = 100; // Keep only last 100 records

  /// Get all records sorted by newest first
  Future<List<Record>> getRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList(_recordsKey);

      if (recordsJson == null || recordsJson.isEmpty) {
        return [];
      }

      final records = recordsJson
          .map((jsonString) {
            try {
              final json = jsonDecode(jsonString) as Map<String, dynamic>;
              return Record.fromJson(json);
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing record: $e');
              }
              return null;
            }
          })
          .whereType<Record>()
          .toList();

      // Sort by timestamp (newest first)
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return records;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading records: $e');
      }
      return [];
    }
  }

  /// Save a new record
  /// Keeps only the last 100 records to prevent storage issues
  Future<bool> saveRecord(Record record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRecords = await getRecords();

      // Add new record at the beginning
      existingRecords.insert(0, record);

      // Keep only last 100 records
      final recordsToKeep = existingRecords.take(_maxRecords).toList();

      // Convert to JSON strings
      final recordsJson = recordsToKeep
          .map((record) => jsonEncode(record.toJson()))
          .toList();

      return await prefs.setStringList(_recordsKey, recordsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving record: $e');
      }
      return false;
    }
  }

  /// Delete a record by ID
  Future<bool> deleteRecord(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await getRecords();

      // Remove record with matching ID
      records.removeWhere((record) => record.id == id);

      // Convert to JSON strings
      final recordsJson = records
          .map((record) => jsonEncode(record.toJson()))
          .toList();

      return await prefs.setStringList(_recordsKey, recordsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting record: $e');
      }
      return false;
    }
  }

  /// Clear all records
  Future<bool> clearAllRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_recordsKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing records: $e');
      }
      return false;
    }
  }

  /// Get record count
  Future<int> getRecordCount() async {
    final records = await getRecords();
    return records.length;
  }
}
