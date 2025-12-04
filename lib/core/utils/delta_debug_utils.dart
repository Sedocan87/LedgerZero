// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:ledger_zero/data/models/sync_delta.dart';

class DeltaDebugUtils {
  static Future<SyncDelta> readAndVerifyDelta(File file) async {
    final bytes = await file.readAsBytes();

    // Check if Gzipped (gzip header starts with 0x1f 0x8b)
    final isGzipped = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

    List<int> decodedBytes;
    try {
      if (isGzipped) {
        decodedBytes = GZipCodec().decode(bytes);
      } else {
        decodedBytes = bytes;
      }
    } catch (e) {
      throw FormatException('Failed to decompress delta file: $e');
    }

    final jsonString = utf8.decode(decodedBytes);
    Map<String, dynamic> json;
    try {
      json = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse JSON: $e');
    }

    final delta = SyncDelta.fromJson(json);

    if (!delta.verifyChecksum()) {
      print('WARNING: Checksum verification failed for ${file.path}');
      print('Expected: ${delta.checksum}');
      print('Calculated: ${delta.calculateChecksum()}');
    } else {
        print('Checksum verified: OK');
    }

    return delta;
  }

  static Future<void> printDeltaDetails(File file) async {
    try {
      print('Processing file: ${file.path}');
      final delta = await readAndVerifyDelta(file);

      print('--- Delta Details ---');
      print('Timestamp: ${delta.timestamp.toIso8601String()}');
      print('Device UUID: ${delta.deviceUuid}');
      print('Sequence: ${delta.sequence}');
      print('Action: ${delta.action}');
      print('Table: ${delta.tableName}');
      print('Schema Version: ${delta.schemaVersion}');
      print('App Version: ${delta.appVersion}');
      print('Data: ${delta.data}');
      print('---------------------');
    } catch (e) {
      print('Error processing delta: $e');
    }
  }
}
