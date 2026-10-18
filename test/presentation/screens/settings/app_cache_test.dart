import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/settings/app_cache.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('deletes only the app\'s own temporary files', () async {
    final temp = Directory.systemTemp.createTempSync('lz_cache_');
    addTearDown(() => temp.deleteSync(recursive: true));
    File(
      p.join(temp.path, 'exports', 'Register.csv'),
    ).createSync(recursive: true);
    File(p.join(temp.path, 'restore_1', 'db')).createSync(recursive: true);
    File(p.join(temp.path, 'selective_2', 'db')).createSync(recursive: true);
    File(p.join(temp.path, 'picked_bank.csv')).createSync();
    // Not ours: another plugin's files.
    File(
      p.join(temp.path, 'image_picker', 'x.jpg'),
    ).createSync(recursive: true);
    File(p.join(temp.path, 'flutter_engine.log')).createSync();

    await clearAppCache(
      tempDir: temp,
      exports: ExportFileService(baseDirectory: () async => temp),
    );

    final left = temp.listSync().map((e) => p.basename(e.path)).toList()
      ..sort();
    expect(left, ['flutter_engine.log', 'image_picker']);
  });
}
