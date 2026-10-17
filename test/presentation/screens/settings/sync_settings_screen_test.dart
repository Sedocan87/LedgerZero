import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_view_models.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_settings_screen.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';
import '../../providers/sync_controller_lifecycle_test.dart'
    show DummyTransport, FakeAuth, FakeConnectivity;

class _SetupEngine implements SyncEngine {
  String? created;
  SyncSetupStatus status = SyncSetupStatus.noFolder;

  @override
  Future<SyncSetupStatus> setupStatus() async => status;

  @override
  Future<void> createSyncFolder(String passphrase) async {
    created = passphrase;
    status = SyncSetupStatus.ready;
  }

  @override
  Future<SyncRunReport> sync({SyncCancellation? cancellation}) async =>
      SyncRunReport(setup: status);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestController extends SyncController {
  _TestController({
    required super.prefs,
    required super.dependencies,
    required super.connectivity,
  }) : super(
         authService: FakeAuth(),
         transportFor: (p) =>
             p == SyncProviderType.none ? null : DummyTransport(),
       );

  void emit(SyncState next) => state = next;
}

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  late _SetupEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_sync_setup_intro': true,
    });
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    engine = _SetupEngine();
  });

  tearDown(() => t.close());

  Future<_TestController> pump(WidgetTester tester, {String? provider}) async {
    if (provider != null) {
      await prefs.setString('sync_provider', provider);
    }
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _TestController(
      prefs: prefs,
      connectivity: FakeConnectivity(),
      dependencies: () => SyncDependencies(
        engineFor: (_) => engine,
        dao: t.db.syncDao,
        resolver: SyncConflictResolver(t.db),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en', 'US')],
          home: SyncSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('shows the provider selector', (tester) async {
    await pump(tester);
    expect(find.text('Sync Provider'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('shows the Google Drive section when selected', (tester) async {
    await pump(tester, provider: 'googleDrive');
    expect(find.text('Google Drive Sync'), findsOneWidget);
    expect(find.text('Connect to Google Drive'), findsOneWidget);
  });

  testWidgets('an iCloud provider from an older version shows no sync', (
    tester,
  ) async {
    await pump(tester, provider: 'iCloud');
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Google Drive Sync'), findsNothing);
  });

  testWidgets('first device sets a passphrase that meets the rules', (
    tester,
  ) async {
    final controller = await pump(tester, provider: 'googleDrive');
    await tester.runAsync(
      () => controller.onLockStateChanged(AppLockState.unlocked),
    );
    controller.emit(
      controller.state.copyWith(
        status: SyncStatus.connected,
        setup: SyncSetupState.needsNewPassphrase,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set a sync passphrase'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('syncPassphraseButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('syncPassphraseField')),
      'short',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Set passphrase').last);
    await tester.pumpAndSettle();
    expect(find.text('Use at least 10 characters'), findsWidgets);
    expect(engine.created, isNull);

    const good = 'purple elephant dances quietly';
    await tester.enterText(
      find.byKey(const ValueKey('syncPassphraseField')),
      good,
    );
    await tester.enterText(
      find.byKey(const ValueKey('syncPassphraseConfirmField')),
      good,
    );
    await tester.runAsync(() async {
      await tester.tap(
        find.widgetWithText(FilledButton, 'Set passphrase').last,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(engine.created, good);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(
      () => controller.onLockStateChanged(AppLockState.locked),
    );
  });

  testWidgets('shows conflicts, failed files and update notices', (
    tester,
  ) async {
    final controller = await pump(tester, provider: 'googleDrive');
    final now = DateTime.utc(2030);
    controller.emit(
      controller.state.copyWith(
        status: SyncStatus.connected,
        setup: SyncSetupState.ready,
        newerSchemaPending: true,
        legacyFilesFound: true,
        conflicts: [
          SyncConflictItem(
            id: 1,
            syncTable: 'payees',
            rowId: 'p',
            localSnapshot: '{"id":"p","name":"Mine"}',
            remoteSnapshot: '{"id":"p","name":"Theirs"}',
            remoteDeviceId: 'x',
            resolvedAt: now,
          ),
        ],
        quarantine: [
          SyncQuarantineItem(
            filename: 'bad.lzsync',
            deviceId: 'd',
            sequence: 1,
            reason: 'failed',
            error: 'auth',
            attempts: 1,
            firstSeen: now,
            lastAttempt: now,
            nextAttempt: now,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('newer version of LedgerZero'), findsOneWidget);
    expect(find.textContaining('.json.gz'), findsOneWidget);
    expect(find.text('1 change file could not be applied'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('syncConflictsTile')));
    await tester.pumpAndSettle();
    expect(find.text('Payee: Mine'), findsOneWidget);
    expect(find.text('Keep mine'), findsOneWidget);
  });
}
