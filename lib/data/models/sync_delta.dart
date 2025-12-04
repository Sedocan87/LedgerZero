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

  const SyncDelta({
    required this.timestamp,
    required this.deviceUuid,
    required this.sequence,
    required this.action,
    required this.tableName,
    this.data,
    this.schemaVersion = 1, // Default to 1 for backward compatibility/initial
    this.appVersion = '0.0.0',
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
    };
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
      ];
}
