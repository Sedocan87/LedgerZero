import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBackupScheduler extends Mock implements BackupScheduler {
  @override
  Future<void> checkBackupDue() async {}
}

class MockSyncController extends Mock implements SyncController {
  @override
  Future<void> syncNow({bool manual = false}) async {}
}

void main() {
  group('Accessibility', () {
    testWidgets('HomeScreen meets accessibility guidelines', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            hasAccountsProvider.overrideWithValue(const AsyncValue.data(true)),
            backupSchedulerProvider.overrideWithValue(MockBackupScheduler()),
            syncControllerProvider.overrideWith((ref) => MockSyncController()),
            // An off-budget account: the banner has all three pages.
            accountsProvider.overrideWith(
              (ref) => Stream.value(const [
                Account(id: 'c', name: 'Checking', type: AccountType.checking),
                Account(
                  id: 's',
                  name: 'Savings',
                  type: AccountType.savings,
                  onBudget: false,
                ),
              ]),
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

      // Avoid infinite pumps if there's a loading loop or animation
      await tester.pump(const Duration(seconds: 1));

      // Check for tap targets
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      // Check for text contrast
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // Check for labeled tap targets
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      semanticsHandle.dispose();
    });
  });
}
