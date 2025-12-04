class DeltaFilenameGenerator {
  /// Generates a unique filename for a delta file.
  /// Format: timestamp_deviceUUID_sequence.json
  /// Timestamp is in milliseconds since epoch to ensure sortability and uniqueness combined with sequence.
  String generate({
    required DateTime timestamp,
    required String deviceUuid,
    required int sequence,
  }) {
    return '${timestamp.millisecondsSinceEpoch}_${deviceUuid}_$sequence.json';
  }
}
