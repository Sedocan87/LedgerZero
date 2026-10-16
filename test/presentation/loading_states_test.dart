import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';

// Mocks would be here if we needed complex repository mocks,
// but for loading states we can often just override the provider to return AsyncValue.loading()

// Mock for BackupScheduler to avoid timer issues in HomeScreen
class MockBackupScheduler extends Mock implements BackupScheduler {
  @override
  Future<void> checkBackupDue() async {}
}

class MockSyncController extends Mock implements SyncController {
  @override
  Future<void> syncNow({bool manual = false}) async {}
}

void main() {
  group('Loading States', () {
    testWidgets('HomeScreen shows loading indicator when checking accounts', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock backup scheduler to avoid NPE or timer issues
            backupSchedulerProvider.overrideWithValue(MockBackupScheduler()),
            // Mock sync controller to avoid background tasks
            syncControllerProvider.overrideWith((ref) => MockSyncController()),
            accountsProvider.overrideWith(
              (ref) => Stream.fromFuture(
                Future.delayed(const Duration(seconds: 1), () => const []),
              ),
            ),
            recentTransactionsProvider.overrideWith((ref) => Stream.value([])),
            tbbProvider.overrideWith((ref, month) => Future.value(10000)),
            monthlyStatsProvider.overrideWith(
              (ref, month) =>
                  Future.value({'income': 200000, 'spending': -50000}),
            ),
            appFormatterProvider.overrideWithValue(
              AppFormatter(
                locale: 'en',
                currency: 'USD',
                decimalSeparator: '.',
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(),
          ),
        ),
      );

      // Should find CircularProgressIndicator immediately
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // We don't need pumpAndSettle here if we just want to verify loading state.
      // If we want to verify it goes away, we need to make sure the Future completes.
      await tester.pump(const Duration(seconds: 2));

      // If we want to test content loading, we would need to mock all downstream providers (TBB, monthlyStats, etc)
      // For now, testing the initial loading state is sufficient for this task.
    });
  });
}
