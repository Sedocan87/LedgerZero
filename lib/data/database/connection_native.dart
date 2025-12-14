import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/constants/app_constants.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.databaseFilename));

    // Capture the session key. Ideally, this is set after login.
    final key = SecurityManager.sessionKey;

    // Use synchronous NativeDatabase for now to ensure FFI works correctly
    // and rely on global sqlite3 configuration in main.dart
    return NativeDatabase(
      file,
      setup: (db) {
        if (key != null) {
          db.execute("PRAGMA key = '$key'");
        }
      },
    );
  });
}
