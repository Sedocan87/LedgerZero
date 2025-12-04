import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_settings_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mockito/mockito.dart';

import '../../../mocks/service_mocks.mocks.dart';

void main() {
  late MockGoogleAuthService mockAuthService;
  late MockGoogleDriveService mockDriveService;
  late MockICloudDriveService mockICloudService;
  late MockDeltaGenerationService mockDeltaService;
  late MockLocalDeltaQueue mockDeltaQueue;
  late MockSharedPreferences mockPrefs;
  late SyncController controller;

  setUp(() {
    mockAuthService = MockGoogleAuthService();
    mockDriveService = MockGoogleDriveService();
    mockICloudService = MockICloudDriveService();
    mockDeltaService = MockDeltaGenerationService();
    mockDeltaQueue = MockLocalDeltaQueue();
    mockPrefs = MockSharedPreferences();

    // Stub common calls
    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockAuthService.onCurrentUserChanged).thenAnswer((_) => const Stream.empty());
    when(mockAuthService.isSignedIn()).thenAnswer((_) async => false);

    controller = SyncController(
      mockAuthService,
      mockDriveService,
      mockICloudService,
      mockDeltaService,
      mockDeltaQueue,
      mockPrefs,
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
      mockDriveService,
      mockICloudService,
      mockDeltaService,
      mockDeltaQueue,
      mockPrefs,
    );

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Google Drive Sync'), findsOneWidget);
    expect(find.text('Connect to Google Drive'), findsOneWidget);
  });
}
