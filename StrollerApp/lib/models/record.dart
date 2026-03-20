/// Record model for NFC scan records
/// Stores drone ID, serial number, GPS coordinates, timestamp, and device name
class Record {
  final String id;
  final String? droneId;
  final String? serialNumber;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final String? deviceName;

  Record({
    required this.id,
    this.droneId,
    this.serialNumber,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.deviceName,
  });

  /// Convert Record to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'droneId': droneId,
      'serialNumber': serialNumber,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'deviceName': deviceName,
    };
  }

  /// Create Record from JSON
  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      id: json['id'] as String,
      droneId: json['droneId'] as String?,
      serialNumber: json['serialNumber'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceName: json['deviceName'] as String?,
    );
  }

  /// Create a copy of the record with optional field updates
  Record copyWith({
    String? id,
    String? droneId,
    String? serialNumber,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    String? deviceName,
  }) {
    return Record(
      id: id ?? this.id,
      droneId: droneId ?? this.droneId,
      serialNumber: serialNumber ?? this.serialNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      deviceName: deviceName ?? this.deviceName,
    );
  }
}
