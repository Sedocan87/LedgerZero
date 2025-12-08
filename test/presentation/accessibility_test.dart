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
import 'package:mockito/mockito.dart';

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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
             hasAccountsProvider.overrideWith((ref) => Future.value(true)),
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
