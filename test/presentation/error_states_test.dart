import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

// Reuse mocks from loading_states_test if possible or redefine
class MockBackupScheduler extends Mock implements BackupScheduler {
  @override
  Future<void> checkBackupDue() async {}
}

class MockSyncController extends Mock implements SyncController {
  @override
  Future<void> syncNow({bool manual = false}) async {}
}

void main() {
  group('Error States', () {
    testWidgets('HomeScreen shows error message when accounts check fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
             hasAccountsProvider.overrideWith((ref) => Future.error('Failed to load accounts')),
             backupSchedulerProvider.overrideWithValue(MockBackupScheduler()),
             syncControllerProvider.overrideWith((ref) => MockSyncController()),
             recentTransactionsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );

      // Wait for the future to complete (immediately errors out)
      await tester.pumpAndSettle();

      // Check for error text
      expect(find.textContaining('Error: Failed to load accounts'), findsOneWidget);
    });
  });
}
