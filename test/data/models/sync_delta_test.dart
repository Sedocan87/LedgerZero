import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';

void main() {
  group('SyncDelta Validation', () {
    final validDelta = SyncDelta(
      timestamp: DateTime.now().toUtc(),
      deviceUuid: 'device-123',
      sequence: 1,
      action: SyncAction.insert,
      tableName: 'transactions',
      data: const {'id': 'tx1', 'amount': 100},
    );

    test('valid delta passes validation', () {
      expect(() => validDelta.validate(), returnsNormally);
    });

    test('throws if tableName is empty', () {
      final invalid = SyncDelta(
        timestamp: DateTime.now().toUtc(),
        deviceUuid: 'device-123',
        sequence: 1,
        action: SyncAction.insert,
        tableName: '',
        data: const {'id': 'tx1'},
      );
      expect(() => invalid.validate(), throwsFormatException);
    });

    test('throws if deviceUuid is empty', () {
      final invalid = SyncDelta(
        timestamp: DateTime.now().toUtc(),
        deviceUuid: '',
        sequence: 1,
        action: SyncAction.insert,
        tableName: 'table',
        data: const {'id': 'tx1'},
      );
      expect(() => invalid.validate(), throwsFormatException);
    });

    test('throws if timestamp is in future', () {
      final invalid = SyncDelta(
        timestamp: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        deviceUuid: 'device-123',
        sequence: 1,
        action: SyncAction.insert,
        tableName: 'table',
        data: const {'id': 'tx1'},
      );
      expect(() => invalid.validate(), throwsFormatException);
    });

    test('throws if data is missing for INSERT', () {
      final invalid = SyncDelta(
        timestamp: DateTime.now().toUtc(),
        deviceUuid: 'device-123',
        sequence: 1,
        action: SyncAction.insert,
        tableName: 'table',
        data: null,
      );
      expect(() => invalid.validate(), throwsFormatException);
    });

    test('throws if data is missing for UPDATE', () {
      final invalid = SyncDelta(
        timestamp: DateTime.now().toUtc(),
        deviceUuid: 'device-123',
        sequence: 1,
        action: SyncAction.update,
        tableName: 'table',
        data: const {},
      );
      expect(() => invalid.validate(), throwsFormatException);
    });

    test('throws if ID is missing for DELETE', () {
      final invalid = SyncDelta(
        timestamp: DateTime.now().toUtc(),
        deviceUuid: 'device-123',
        sequence: 1,
        action: SyncAction.delete,
        tableName: 'table',
        data: const {'other': 'value'},
      );
      expect(() => invalid.validate(), throwsFormatException);
    });

    test('DELETE valid with ID', () {
      final valid = SyncDelta(
        timestamp: DateTime.now().toUtc(),
        deviceUuid: 'device-123',
        sequence: 1,
        action: SyncAction.delete,
        tableName: 'table',
        data: const {'id': 'tx1'},
      );
      expect(() => valid.validate(), returnsNormally);
    });
  });

  group('SyncDelta Checksum', () {
    test('calculateChecksum generates consistent hash', () {
      final delta = SyncDelta(
        timestamp: DateTime.utc(2025, 1, 1),
        deviceUuid: 'uuid',
        sequence: 1,
        action: SyncAction.insert,
        tableName: 'table',
        data: const {'key': 'value'},
      );

      final checksum1 = delta.calculateChecksum();
      final checksum2 = delta.calculateChecksum();
      expect(checksum1, isNotEmpty);
      expect(checksum1, checksum2);
    });

    test('verifyChecksum returns true for valid checksum', () {
      final delta = SyncDelta(
        timestamp: DateTime.utc(2025, 1, 1),
        deviceUuid: 'uuid',
        sequence: 1,
        action: SyncAction.insert,
        tableName: 'table',
        data: const {'key': 'value'},
      );
      final checksum = delta.calculateChecksum();
      final signedDelta = delta.copyWith(checksum: checksum);
      expect(signedDelta.verifyChecksum(), isTrue);
    });

    test('verifyChecksum returns false if data modified', () {
      final delta = SyncDelta(
        timestamp: DateTime.utc(2025, 1, 1),
        deviceUuid: 'uuid',
        sequence: 1,
        action: SyncAction.insert,
        tableName: 'table',
        data: const {'key': 'value'},
      );
      final checksum = delta.calculateChecksum();
      // Modify sequence but keep old checksum
      final corruptedDelta = SyncDelta(
        timestamp: delta.timestamp,
        deviceUuid: delta.deviceUuid,
        sequence: 2, // Changed
        action: delta.action,
        tableName: delta.tableName,
        data: delta.data,
        checksum: checksum,
      );
      expect(corruptedDelta.verifyChecksum(), isFalse);
    });
  });
}
