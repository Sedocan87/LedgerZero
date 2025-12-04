import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';

final deltaFilenameGeneratorProvider = Provider<DeltaFilenameGenerator>((ref) {
  return DeltaFilenameGenerator();
});

final localDeltaQueueProvider = Provider<LocalDeltaQueue>((ref) {
  final filenameGenerator = ref.watch(deltaFilenameGeneratorProvider);
  return LocalDeltaQueue(filenameGenerator);
});

final deltaGenerationServiceProvider = Provider<DeltaGenerationService>((ref) {
  final db = ref.watch(databaseProvider);
  final localDeltaQueue = ref.watch(localDeltaQueueProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return DeltaGenerationService(db, localDeltaQueue, prefs);
});
