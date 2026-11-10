import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/backup_screen.dart';
import 'package:ledger_zero/services/backup/auto_backup_service.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/security_fakes.dart';
import '../../../helpers/test_database.dart';

class _Saver implements FileSaver {
  bool result = true;
  int calls = 0;
  final saved = <String, Uint8List>{};

  @override
  Future<bool> save(String filename, Uint8List bytes) async {
    calls++;
    if (result) {
      saved[filename] = bytes;
    }
    return result;
  }
}

class _Sharer implements FileSharer {
  bool result = true;
  final shared = <String>[];

  @override
  Future<bool> share(
    List<String> paths, {
    String? text,
    String? subject,
  }) async {
    shared.addAll(paths);
    return result;
  }
}

class _Scheduler extends Fake implements BackupScheduler {
  int recorded = 0;

  @override
  DateTime? get lastBackup => null;

  @override
  Future<void> recordBackupSuccess() async => recorded++;
}

/// "Save to…" (system file picker) and "Share…" on the Backup screen, and
/// the Android backup section.
void main() {
  late TestDatabase t;
  late Directory dir;
  late SharedPreferences prefs;
  late _Saver saver;
  late _Sharer sharer;
  late _Scheduler scheduler;
  late ExportFileService files;

  setUp(() async {
    t = TestDatabase();
    dir = Directory.systemTemp.createTempSync('lz_backup_save_ui_');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    saver = _Saver();
    sharer = _Sharer();
    scheduler = _Scheduler();
    files = ExportFileService(
      saver: saver,
      sharer: sharer,
      baseDirectory: () async => dir,
      deferDeletion: false,
    );
  });

  tearDown(() async {
    await t.close();
    dir.deleteSync(recursive: true);
  });

  Widget app({int databaseSize = 1024 * 1024}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(t.db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      autoBackupServiceProvider.overrideWith(
        (ref) => AutoBackupService(
          prefs,
          InMemorySecureStore(),
          backupService: () => ref.read(backupServiceProvider),
          baseDirectory: () async => dir,
        ),
      ),
      exportFileServiceProvider.overrideWithValue(files),
      backupSchedulerProvider.overrideWithValue(scheduler),
      databaseFileSizeProvider.overrideWith((ref) async => databaseSize),
      backupServiceProvider.overrideWith(
        (ref) => BackupService(
          t.db,
          backupScheduler: scheduler,
          files: files,
          kdf: fastKdf,
        ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en', 'US')],
      home: BackupScreen(),
    ),
  );

  Future<void> waitUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  Future<void> createWith(WidgetTester tester, Key button) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.ensureVisible(fields.first);
    await tester.enterText(fields.at(0), 'a long backup password');
    await tester.enterText(fields.at(1), 'a long backup password');
    await tester.ensureVisible(find.byKey(button));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(button));
  }

  List<FileSystemEntity> leftovers() {
    final exports = Directory(
      p.join(dir.path, ExportFileService.directoryName),
    );
    return exports.existsSync() ? exports.listSync() : const [];
  }

  testWidgets('"Save to…" hands the encrypted file to the system file '
      'picker and counts as a backup that left the phone', (tester) async {
    await tester.runAsync(() async {
      await createWith(tester, const Key('backup.saveTo'));
      await waitUntil(tester, () => saver.saved.isNotEmpty);
      await waitUntil(tester, () => scheduler.recorded == 1);
      await tester.pump();

      final name = saver.saved.keys.single;
      expect(name, endsWith('.lzbk'));
      // The encrypted backup format, never the plain database.
      final bytes = saver.saved.values.single;
      expect(
        String.fromCharCodes(bytes.take(BackupFormat.magic.length)),
        String.fromCharCodes(BackupFormat.magic),
      );
      expect(sharer.shared, isEmpty);
      expect(find.text('Backup saved'), findsOneWidget);
      // The temporary file is gone.
      expect(leftovers(), isEmpty);
    });
  });

  testWidgets('a cancelled "Save to…" does not count as a backup', (
    tester,
  ) async {
    saver.result = false;
    await tester.runAsync(() async {
      await createWith(tester, const Key('backup.saveTo'));
      await waitUntil(tester, () => saver.calls == 1);
      await waitUntil(
        tester,
        () => tester
            .widget<ElevatedButton>(
              find.descendant(
                of: find.byKey(const Key('backup.saveTo')),
                matching: find.byType(ElevatedButton),
              ),
            )
            .enabled,
      );
      expect(scheduler.recorded, 0);
      expect(find.text('Backup saved'), findsNothing);
      expect(leftovers(), isEmpty);
    });
  });

  testWidgets('"Share…" still hands the file to the share sheet', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await createWith(tester, const Key('backup.share'));
      await waitUntil(tester, () => sharer.shared.isNotEmpty);
      await waitUntil(tester, () => scheduler.recorded == 1);
      expect(saver.saved, isEmpty);
    });
  });

  testWidgets('the Android backup section explains it; a database near '
      "Android's 25 MB gets a note", (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Android backup'), findsOneWidget);
    expect(find.textContaining('end-to-end encrypted'), findsWidgets);
    expect(find.byKey(const ValueKey('androidBackupTooLarge')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(databaseSize: 21 * 1024 * 1024));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('androidBackupTooLarge')), findsOneWidget);
    expect(find.textContaining('21 MB'), findsOneWidget);
  });
}
