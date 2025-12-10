import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/offline_indicator.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:mockito/mockito.dart';

import 'test_utils.dart';

// Mock ConnectivityService
class MockConnectivityService extends Mock implements ConnectivityService {
  final bool _isOffline;
  MockConnectivityService(this._isOffline);

  @override
  Stream<ConnectionStatus> get connectionStatusStream => Stream.value(
        _isOffline ? ConnectionStatus.offline : ConnectionStatus.online,
      );

  @override
  Future<bool> get isConnected async => !_isOffline;

  @override
  Future<bool> get isWifi async => !_isOffline;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test offline mode scenarios', (WidgetTester tester) async {
    // Override connectivity to be OFFLINE
    final mockConnectivity = MockConnectivityService(true);

    await setupIntegrationTest(
      tester,
      overrides: [
        connectivityServiceProvider.overrideWithValue(mockConnectivity),
      ],
    );

    await completeOnboarding(tester);
    await tester.pumpAndSettle();

    // 1. Verify Offline Indicator is visible
    expect(find.byType(OfflineIndicator), findsOneWidget);
    // Use a flexible finder for text in case it changes
    expect(find.textContaining('Offline'), findsOneWidget);

    // 2. Create a transaction while offline (UI check only)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Dismiss the form to clean up state
    if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
  });
}
