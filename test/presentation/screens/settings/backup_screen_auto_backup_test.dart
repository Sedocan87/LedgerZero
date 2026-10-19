import 'dart:io';

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
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/security_fakes.dart';
import '../../../helpers/test_database.dart';

/// The automatic backup section of the Backup screen with the real service
/// over an in-memory database and a temporary folder.
void main() {
  late TestDatabase t;
  late Directory dir;
  late SharedPreferences prefs;
  late InMemorySecureStore store;

  setUp(() async {
    t = TestDatabase();
    dir = Directory.systemTemp.createTempSync('lz_auto_backup_ui_');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = InMemorySecureStore();
  });

  tearDown(() async {
    await t.close();
    dir.deleteSync(recursive: true);
  });

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(t.db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(store),
      backupServiceProvider.overrideWith(
        (ref) => BackupService(
          t.db,
          files: ExportFileService(
            baseDirectory: () async => Directory(p.join(dir.path, 'tmp')),
            deferDeletion: false,
          ),
          kdf: fastKdf,
        ),
      ),
      autoBackupServiceProvider.overrideWith(
        (ref) => AutoBackupService(
          prefs,
          store,
          backupService: () => ref.read(backupServiceProvider),
          baseDirectory: () async => dir,
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

  /// Waits (real time; the test body runs in [WidgetTester.runAsync]) until
  /// [done] holds, pumping a frame in between.
  Future<void> waitUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  testWidgets(
    'turning automatic backups on asks for a password, writes the first '
    'backup and lists it for restore',
    (tester) => tester.runAsync(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final toggle = find.byKey(const Key('autoBackup.enabled'));
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(find.text('Off'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Password for automatic backups'), findsOneWidget);

      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      // Too short: refused.
      await tester.enterText(fields.at(0), 'short');
      await tester.enterText(fields.at(1), 'short');
      await tester.tap(find.byKey(const Key('autoBackup.confirmPassword')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(fields.at(0), 'correct horse battery');
      await tester.enterText(fields.at(1), 'correct horse battery');
      await tester.tap(find.byKey(const Key('autoBackup.confirmPassword')));
      await tester.pump();
      // The first backup runs (key derivation in an isolate).
      final backups = Directory(p.join(dir.path, 'backups'));
      await waitUntil(
        tester,
        () => prefs.getInt(AutoBackupService.lastSuccessKey) != null,
      );
      await tester.pumpAndSettle();
      expect(find.text('Backup saved'), findsOneWidget);

      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(find.textContaining('Last backup:'), findsOneWidget);
      expect(
        await store.read(AutoBackupService.passwordKey),
        'correct horse battery',
      );
      final files = backups.listSync();
      expect(files, hasLength(1));
      expect(p.basename(files.single.path), startsWith('ledgerzero_auto_'));
      expect(find.byKey(const Key('autoBackup.now')), findsOneWidget);
      await waitUntil(
        tester,
        () => find.text('Delete the automatic backups').evaluate().isNotEmpty,
      );

      // The restore picker lists the backup.
      await tester.ensureVisible(find.byKey(const Key('autoBackup.restore')));
      await tester.tap(find.byKey(const Key('autoBackup.restore')));
      await waitUntil(
        tester,
        () => find.text('Which backup?').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialogOption), findsOneWidget);
      Navigator.of(tester.element(find.byType(SimpleDialog))).pop();
      await tester.pumpAndSettle();

      // Off again: the password is forgotten, the file stays.
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(await store.read(AutoBackupService.passwordKey), isNull);
      expect(backups.listSync(), hasLength(1));
      await waitUntil(
        tester,
        () => find.text('Delete the automatic backups').evaluate().isNotEmpty,
      );
    }),
  );

  testWidgets('a failed run shows on the switch', (tester) async {
    await tester.runAsync(() async {
      await prefs.setBool(AutoBackupService.enabledKey, true);
      await prefs.setInt(
        AutoBackupService.lastAttemptKey,
        DateTime(2026, 10, 19, 9).millisecondsSinceEpoch,
      );
      await prefs.setString(AutoBackupService.lastErrorKey, 'disk full');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.textContaining('Last try failed'), findsOneWidget);
      expect(find.textContaining('disk full'), findsOneWidget);
      expect(
        find.text('There are no automatic backups on this phone.'),
        findsNothing,
      );

      await tester.ensureVisible(find.byKey(const Key('autoBackup.restore')));
      await tester.tap(find.byKey(const Key('autoBackup.restore')));
      await waitUntil(
        tester,
        () => find
            .text('There are no automatic backups on this phone.')
            .evaluate()
            .isNotEmpty,
      );
    });
  });
}
