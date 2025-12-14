import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';

void main() {
  group('LocalDeltaQueue Pruning Tests', () {
    late Directory tempDir;
    late LocalDeltaQueue queue;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('delta_queue_prune_test');
      queue = LocalDeltaQueue(DeltaFilenameGenerator(), tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Squash INSERT + UPDATE = INSERT', () async {
      // 1. Insert
      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now(),
          deviceUuid: 'dev1',
          sequence: 1,
          action: SyncAction.insert,
          tableName: 't1',
          data: const {'id': '1', 'val': 'a'},
        ),
      );

      // 2. Update
      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now().add(const Duration(seconds: 1)),
          deviceUuid: 'dev1',
          sequence: 2,
          action: SyncAction.update,
          tableName: 't1',
          data: const {'id': '1', 'val': 'b'},
        ),
      );

      final count = await queue.pruneQueue();
      expect(count, equals(1)); // 1 file removed

      final pending = await queue.getPendingDeltas();
      expect(pending.length, equals(1));

      final delta = await queue.readDelta(pending.first);
      expect(delta.action, equals(SyncAction.insert));
      expect(delta.data!['val'], equals('b'));
      expect(delta.sequence, equals(2)); // Keeps latest sequence
    });

    test('Squash UPDATE + UPDATE = UPDATE', () async {
      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now(),
          deviceUuid: 'dev1',
          sequence: 1,
          action: SyncAction.update,
          tableName: 't1',
          data: const {'id': '1', 'val': 'a'},
        ),
      );

      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now().add(const Duration(seconds: 1)),
          deviceUuid: 'dev1',
          sequence: 2,
          action: SyncAction.update,
          tableName: 't1',
          data: const {'id': '1', 'val': 'b'},
        ),
      );

      final count = await queue.pruneQueue();
      expect(count, equals(1));

      final pending = await queue.getPendingDeltas();
      expect(pending.length, equals(1));

      final delta = await queue.readDelta(pending.first);
      expect(delta.action, equals(SyncAction.update));
      expect(delta.data!['val'], equals('b'));
    });

    test('Squash INSERT + DELETE = Remove All', () async {
      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now(),
          deviceUuid: 'dev1',
          sequence: 1,
          action: SyncAction.insert,
          tableName: 't1',
          data: const {'id': '1', 'val': 'a'},
        ),
      );

      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now().add(const Duration(seconds: 1)),
          deviceUuid: 'dev1',
          sequence: 2,
          action: SyncAction.delete,
          tableName: 't1',
          data: const {'id': '1'},
        ),
      );

      final count = await queue.pruneQueue();
      expect(count, equals(2)); // Both removed

      final pending = await queue.getPendingDeltas();
      expect(pending, isEmpty);
    });

    test('Squash UPDATE + DELETE = DELETE', () async {
      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now(),
          deviceUuid: 'dev1',
          sequence: 1,
          action: SyncAction.update,
          tableName: 't1',
          data: const {'id': '1', 'val': 'a'},
        ),
      );

      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now().add(const Duration(seconds: 1)),
          deviceUuid: 'dev1',
          sequence: 2,
          action: SyncAction.delete,
          tableName: 't1',
          data: const {'id': '1'},
        ),
      );

      final count = await queue.pruneQueue();
      expect(count, equals(1));

      final pending = await queue.getPendingDeltas();
      expect(pending.length, equals(1));

      final delta = await queue.readDelta(pending.first);
      expect(delta.action, equals(SyncAction.delete));
    });

    test('Export queue', () async {
      await queue.enqueue(
        SyncDelta(
          timestamp: DateTime.now(),
          deviceUuid: 'dev1',
          sequence: 1,
          action: SyncAction.insert,
          tableName: 't1',
          data: const {'id': '1', 'val': 'a'},
        ),
      );

      final exportFile = File('${tempDir.path}/export.json');
      await queue.exportQueue(exportFile);

      expect(await exportFile.exists(), isTrue);
      final content = await exportFile.readAsString();
      expect(content, contains('"action":"INSERT"'));
      expect(content, contains('"val":"a"'));
    });
  });
}
