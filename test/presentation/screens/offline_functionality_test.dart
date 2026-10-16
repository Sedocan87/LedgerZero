import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/offline_indicator.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'offline_functionality_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ConnectivityService>()])
void main() {
  late MockConnectivityService mockConnectivityService;
  late StreamController<ConnectionStatus> statusController;

  setUp(() {
    mockConnectivityService = MockConnectivityService();
    statusController = StreamController<ConnectionStatus>.broadcast();

    when(
      mockConnectivityService.connectionStatusStream,
    ).thenAnswer((_) => statusController.stream);
    when(mockConnectivityService.isConnected).thenAnswer((_) async => true);
  });

  tearDown(() {
    statusController.close();
  });

  testWidgets('OfflineIndicator shows when offline', (tester) async {
    // Override stream to emit offline
    when(
      mockConnectivityService.connectionStatusStream,
    ).thenAnswer((_) => Stream.value(ConnectionStatus.offline));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityServiceProvider.overrideWithValue(
            mockConnectivityService,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: Scaffold(body: Column(children: [OfflineIndicator()])),
        ),
      ),
    );

    await tester.pump(); // Process stream

    expect(find.text('Offline Mode'), findsOneWidget);
  });

  testWidgets('OfflineIndicator hides when online', (tester) async {
    when(
      mockConnectivityService.connectionStatusStream,
    ).thenAnswer((_) => Stream.value(ConnectionStatus.online));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityServiceProvider.overrideWithValue(
            mockConnectivityService,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: Scaffold(body: Column(children: [OfflineIndicator()])),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Offline Mode'), findsNothing);
  });
}
