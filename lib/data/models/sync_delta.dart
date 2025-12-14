import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

enum SyncAction {
  insert,
  update,
  delete;

  String toJson() => name.toUpperCase();
  static SyncAction fromJson(String json) => SyncAction.values.firstWhere(
    (e) => e.name.toUpperCase() == json.toUpperCase(),
    orElse: () => throw FormatException('Unknown SyncAction: $json'),
  );
}

class SyncDelta extends Equatable {
  final DateTime timestamp;
  final String deviceUuid;
  final int sequence;
  final SyncAction action;
  final String tableName;
  final Map<String, dynamic>? data;
  final int schemaVersion;
  final String appVersion;
  final String? checksum;

  const SyncDelta({
    required this.timestamp,
    required this.deviceUuid,
    required this.sequence,
    required this.action,
    required this.tableName,
    this.data,
    this.schemaVersion = 1, // Default to 1 for backward compatibility/initial
    this.appVersion = '0.0.0',
    this.checksum,
  });

  factory SyncDelta.fromJson(Map<String, dynamic> json) {
    return SyncDelta(
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceUuid: json['deviceUUID'] as String,
      sequence: json['sequence'] as int,
      action: SyncAction.fromJson(json['action'] as String),
      tableName: json['table'] as String,
      data: json['data'] as Map<String, dynamic>?,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      appVersion: json['appVersion'] as String? ?? '0.0.0',
      checksum: json['checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'deviceUUID': deviceUuid,
      'sequence': sequence,
      'action': action.toJson(),
      'table': tableName,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      if (data != null) 'data': data,
      if (checksum != null) 'checksum': checksum,
    };
  }

  SyncDelta copyWith({
    DateTime? timestamp,
    String? deviceUuid,
    int? sequence,
    SyncAction? action,
    String? tableName,
    Map<String, dynamic>? data,
    int? schemaVersion,
    String? appVersion,
    String? checksum,
  }) {
    return SyncDelta(
      timestamp: timestamp ?? this.timestamp,
      deviceUuid: deviceUuid ?? this.deviceUuid,
      sequence: sequence ?? this.sequence,
      action: action ?? this.action,
      tableName: tableName ?? this.tableName,
      data: data ?? this.data,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      appVersion: appVersion ?? this.appVersion,
      checksum: checksum ?? this.checksum,
    );
  }

  String calculateChecksum() {
    // Exclude checksum field from calculation
    final map = toJson();
    map.remove('checksum');

    final jsonString = jsonEncode(map);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool verifyChecksum() {
    if (checksum == null) {
      return false;
    }
    return checksum == calculateChecksum();
  }

  @override
  List<Object?> get props => [
    timestamp,
    deviceUuid,
    sequence,
    action,
    tableName,
    data,
    schemaVersion,
    appVersion,
    checksum,
  ];

  void validate() {
    if (tableName.isEmpty) {
      throw const FormatException(
        'SyncDelta validation failed: tableName is empty',
      );
    }
    if (deviceUuid.isEmpty) {
      throw const FormatException(
        'SyncDelta validation failed: deviceUuid is empty',
      );
    }
    // Allow for some clock skew (e.g. 5 minutes into the future), but generally future timestamps are bad.
    if (timestamp.isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    )) {
      throw FormatException(
        'SyncDelta validation failed: timestamp is in the future (${timestamp.toIso8601String()})',
      );
    }

    if (action == SyncAction.insert || action == SyncAction.update) {
      if (data == null || data!.isEmpty) {
        throw const FormatException(
          'SyncDelta validation failed: data is missing for INSERT/UPDATE',
        );
      }
    } else if (action == SyncAction.delete) {
      // For delete, we expect at least the ID in the data
      if (data == null || !data!.containsKey('id')) {
        throw const FormatException(
          'SyncDelta validation failed: ID is missing in data for DELETE',
        );
      }
    }
  }
}
