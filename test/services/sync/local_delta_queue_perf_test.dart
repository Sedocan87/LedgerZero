
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';

void main() {
  group('LocalDeltaQueue Performance Tests', () {
    late Directory tempDir;
    late LocalDeltaQueue queue;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('delta_queue_perf_test');
      queue = LocalDeltaQueue(DeltaFilenameGenerator(), tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Handle 1000+ pending operations', () async {
      const int operationCount = 1000;
      final stopwatch = Stopwatch()..start();

      // 1. Enqueue 1000 operations
      for (int i = 0; i < operationCount; i++) {
        final delta = SyncDelta(
          timestamp: DateTime.now().add(Duration(milliseconds: i)),
          deviceUuid: 'test-device-uuid',
          sequence: i,
          action: SyncAction.insert,
          tableName: 'transactions',
          data: {'id': 'tx_$i', 'amount': 100.0},
          schemaVersion: 1,
          appVersion: '1.0.0',
        );
        await queue.enqueue(delta);
      }

      final enqueueTime = stopwatch.elapsedMilliseconds;
      print('Enqueued $operationCount items in ${enqueueTime}ms');

      expect(enqueueTime, lessThan(10000), reason: 'Enqueueing should be reasonably fast');

      // 2. List pending deltas
      stopwatch.reset();
      final pendingFiles = await queue.getPendingDeltas();
      final listTime = stopwatch.elapsedMilliseconds;
      print('Listed $operationCount items in ${listTime}ms');

      expect(pendingFiles.length, equals(operationCount));
      expect(listTime, lessThan(2000), reason: 'Listing should be fast');

      // 3. Process (read and mark as uploaded)
      stopwatch.reset();
      for (final file in pendingFiles) {
        final delta = await queue.readDelta(file);
        expect(delta.tableName, equals('transactions'));
        await queue.markAsUploaded(file);
      }
      final processTime = stopwatch.elapsedMilliseconds;
      print('Processed $operationCount items in ${processTime}ms');

      expect(processTime, lessThan(15000), reason: 'Processing should be reasonably fast');

      // 4. Verify queue is empty
      final remainingFiles = await queue.getPendingDeltas();
      expect(remainingFiles, isEmpty);
    });
  });
}
