import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_settings_screen.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:mockito/mockito.dart';

import '../../../mocks/service_mocks.mocks.dart';

class FakeSyncEngine extends Fake implements SyncEngine {
  final _controller = StreamController<SyncState>.broadcast();

  @override
  Stream<SyncState> get statusStream => _controller.stream;

  @override
  Future<void> sync({bool background = false, bool forceFullSync = false}) async {}
}

void main() {
  late MockGoogleAuthService mockAuthService;
  late MockICloudDriveService mockICloudService;
  late MockSharedPreferences mockPrefs;
  late FakeSyncEngine fakeSyncEngine;
  late SyncController controller;

  setUp(() {
    mockAuthService = MockGoogleAuthService();
    mockICloudService = MockICloudDriveService();
    mockPrefs = MockSharedPreferences();
    fakeSyncEngine = FakeSyncEngine();

    // Stub common calls
    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockAuthService.onCurrentUserChanged)
        .thenAnswer((_) => const Stream.empty());
    when(mockAuthService.isSignedIn()).thenAnswer((_) async => false);

    controller = SyncController(
      mockAuthService,
      mockICloudService,
      mockPrefs,
      fakeSyncEngine,
    );
  });

  Widget createWidget() {
    return ProviderScope(
      overrides: [
        syncControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en', 'US'),
        ],
        home: SyncSettingsScreen(),
      ),
    );
  }

  testWidgets('Shows provider selector', (WidgetTester tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Sync Provider'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('Shows Google Drive UI when selected', (WidgetTester tester) async {
    // Manually set state or simulate selection
    // Since we use real controller, we can simulate selection by setting prefs/init or calling setProvider

    // We can't call setProvider inside test easily before pump, but we can set up the controller
    // to initialize with Google Drive

    when(mockPrefs.getString('sync_provider')).thenReturn('googleDrive');
    // Re-create controller to pick up pref
    controller = SyncController(
      mockAuthService,
      mockICloudService,
      mockPrefs,
      fakeSyncEngine,
    );

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Google Drive Sync'), findsOneWidget);
    expect(find.text('Connect to Google Drive'), findsOneWidget);
  });
}
