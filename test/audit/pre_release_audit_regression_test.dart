import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
import 'package:ledger_zero/presentation/widgets/security/lock_overlay.dart';
import 'package:ledger_zero/services/backup/transferred_install.dart';
import 'package:ledger_zero/services/error/log_scrubber.dart';
import 'package:ledger_zero/services/export/csv_sanitizer.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _IdleAuthenticator implements AppLockAuthenticator {
  @override
  String? get lastFailure => null;

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<AppLockResult> authenticate({
    required String title,
    String? subtitle,
  }) async => AppLockResult.cancelled;
}

void main() {
  group('MoneyParser & Money safety', () {
    test('tryParse returns null on 18+ digit numbers instead of throwing', () {
      const parser = MoneyParser();
      expect(parser.tryParse('12345678901234567890'), isNull);
      expect(parser.tryParse('999999999999999999999999'), isNull);
      expect(() => parser.parse('12345678901234567890'), throwsFormatException);
    });

    test('fromDecimalString guards huge exponents without OOM or hang', () {
      expect(() => Money.fromDecimalString('1e99999999'), throwsArgumentError);
      expect(
        () => Money.fromDecimalString('1e999999999999999999999'),
        throwsArgumentError,
      );
      expect(Money.fromDecimalString('1e-99999999'), 0);
      expect(Money.fromDecimalString('0e99999999'), 0);
    });

    test('MoneyFormatter never outputs +¥0 for sub-unit JPY amounts', () {
      final fmt = MoneyFormatter(locale: 'en_US', defaultCurrency: 'JPY');
      expect(fmt.format(40, currency: 'JPY', signed: true), '¥0');
      expect(fmt.format(100, currency: 'JPY', signed: true), '+¥1');
    });
  });

  group('RuleMatchingService ReDoS guard', () {
    test('rejects nested quantifiers and oversized regex patterns', () {
      expect(RuleMatchingService.isSafeRegex(r'(a+)+$'), isFalse);
      expect(RuleMatchingService.isSafeRegex(r'(a*)*b'), isFalse);
      expect(RuleMatchingService.isSafeRegex(r'([a-z]+)+'), isFalse);
      expect(RuleMatchingService.isSafeRegex('a' * 300), isFalse);
      expect(RuleMatchingService.isSafeRegex(r'[unclosed'), isFalse);
    });

    test('accepts and caches ordinary regex patterns', () {
      expect(RuleMatchingService.isSafeRegex(r'REWE|EDEKA'), isTrue);
      final r1 = RuleMatchingService.compileSafeRegex(r'^SEPA\s+\d+');
      final r2 = RuleMatchingService.compileSafeRegex(r'^SEPA\s+\d+');
      expect(r1, isNotNull);
      expect(identical(r1, r2), isTrue);
      expect(r1!.hasMatch('SEPA 12345'), isTrue);
    });
  });

  group('LogScrubber & CsvSanitizer', () {
    test('LogScrubber scrubs multiline SQL, IBANs, pairing codes & amounts', () {
      final scrubbed = LogScrubber.scrub(
        'Causing statement: SELECT *\nFROM transactions WHERE memo = "Rent"\n'
        'IBAN DE89370400440532013000 code lzpair1:abcDEF_123-456 paid €5 or 99 EUR',
      );
      expect(scrubbed, isNot(contains('FROM transactions')));
      expect(scrubbed, isNot(contains('Rent')));

      final scrubbed2 = LogScrubber.scrub(
        'IBAN DE89370400440532013000 code lzpair1:abcDEF_123-456 paid €5 or 99 EUR',
      );
      expect(scrubbed2, isNot(contains('DE89370400440532013000')));
      expect(scrubbed2, isNot(contains('lzpair1:')));
      expect(scrubbed2, isNot(contains('€5')));
      expect(scrubbed2, isNot(contains('99 EUR')));
    });

    test('CsvSanitizer neutralises leading newline & padded formulas', () {
      expect(CsvSanitizer.cell('\n=SUM(1,2)'), "'\n=SUM(1,2)");
      expect(CsvSanitizer.cell('  =SUM(1,2)'), "'  =SUM(1,2)");
      expect(CsvSanitizer.unquote("'  =SUM(1,2)"), '  =SUM(1,2)');
      expect(CsvSanitizer.unquote("'\n=SUM(1,2)"), '\n=SUM(1,2)');
    });
  });

  group('YNAB import date bounds', () {
    test('rejects 2-digit years and out-of-range years like 0026', () {
      expect(YnabImportService.fittingRegisterDateFormats(['01/02/26']), isEmpty);
      expect(
        YnabImportService.fittingRegisterDateFormats(['01/02/0026']),
        isEmpty,
      );
      expect(
        YnabImportService.fittingRegisterDateFormats(['01/02/2026']),
        isNotEmpty,
      );
    });
  });

  group('Database safety & TransferredInstall', () {
    test('checkDatabaseFile reports tooNew and handles unopenable paths', () async {
      final dir = Directory.systemTemp.createTempSync('lz_conn_audit_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final newer = File(p.join(dir.path, 'newer.sqlite'));
      final db = sqlite.sqlite3.open(newer.path);
      db.execute('PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}');
      db.close();
      expect(await checkDatabaseFile(newer), DatabaseFileState.tooNew);

      final corrupt = File(p.join(dir.path, 'corrupt.sqlite'));
      corrupt.writeAsStringSync('not a sqlite file');
      expect(await checkDatabaseFile(corrupt), DatabaseFileState.damaged);
    });

    test('TransferredInstall does not commit marker if databaseFile fails', () async {
      final dir = Directory.systemTemp.createTempSync('lz_transfer_audit_');
      addTearDown(() => dir.deleteSync(recursive: true));
      SharedPreferences.setMockInitialValues({
        TransferredInstall.prefsKey: 'old-phone-install-id',
      });
      final prefs = await SharedPreferences.getInstance();

      await TransferredInstall.checkAtStartup(
        prefs,
        noBackupDirectory: () async => dir,
        databaseFile: () => Future.error(StateError('transient I/O failure')),
      );

      // Marker was NOT committed, so a subsequent startup still detects move.
      expect(
        prefs.getString(TransferredInstall.prefsKey),
        'old-phone-install-id',
      );
      expect(await File(p.join(dir.path, TransferredInstall.markerName)).exists(), isFalse);
    });
  });

  group('Android release config guardrails', () {
    test('camera features stay optional after manifest merge', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains(
          'android:name="android.hardware.camera.any" android:required="false" tools:replace="android:required"',
        ),
      );
      expect(
        manifest,
        contains(
          'android:name="android.hardware.camera" android:required="false"',
        ),
      );
      expect(
        manifest,
        contains(
          'android:name="android.hardware.camera.autofocus" android:required="false"',
        ),
      );
    });

    test('Android styles inherit Theme.AppCompat for API 24-27 BiometricPrompt', () {
      for (final path in [
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
      ]) {
        final content = File(path).readAsStringSync();
        expect(content, contains('Theme.AppCompat'));
        expect(content, isNot(contains('@android:style/Theme.')));
      }
    });

    test('proguard-rules.pro has no stale GMS keep rule', () {
      final rules = File('android/app/proguard-rules.pro').readAsStringSync();
      expect(rules, isNot(contains('com.google.android.gms')));
    });
  });

  group('UI & LockOverlay', () {
    test('high-contrast themes produce distinct high-contrast AppSemanticColors', () {
      final normalDark = AppTheme.darkTheme.extension<AppSemanticColors>()!;
      final hcDark = AppTheme.highContrastDarkTheme
          .extension<AppSemanticColors>()!;
      expect(hcDark.success, isNot(normalDark.success));
      expect(hcDark.error, isNot(normalDark.error));
    });

    testWidgets('LockOverlay intercepts system back while relocked', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'user_onboarded': true,
        kAppLockEnabledKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appLockAuthenticatorProvider.overrideWithValue(_IdleAuthenticator()),
        ],
      );
      addTearDown(container.dispose);

      // Unlock once so session is open and router can push /detail.
      container.read(sessionProvider.notifier).open();
      container.read(authProvider.notifier).setAuthenticated(true);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (_, _) => const Scaffold(body: Text('Detail')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            builder: (context, child) => LockOverlay(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/detail');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/detail');

      // Relock -> LockOverlay covers the offstage router.
      container.read(authProvider.notifier).setAuthenticated(false);
      await tester.pump();
      expect(container.read(authProvider).isRelocked, isTrue);
      expect(find.byType(LockScreen), findsOneWidget);

      // System back while relocked must be consumed and not pop /detail.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/detail');
      expect(find.byType(LockScreen), findsOneWidget);

      // Once unlocked, system back pops /detail back to /.
      container.read(authProvider.notifier).setAuthenticated(true);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    });
  });
}
