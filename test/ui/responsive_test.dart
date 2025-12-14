import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/widgets/home/to_be_budgeted_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:mockito/mockito.dart';
import '../widget_test_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Create a mock for BackupScheduler
class MockBackupScheduler extends Mock implements BackupScheduler {
  @override
  Future<void> checkBackupDue() async {
    return Future.value();
  }
}

// Create a mock for SyncController
class MockSyncController extends StateNotifier<SyncState>
    implements SyncController {
  MockSyncController() : super(const SyncState());

  @override
  Future<void> syncNow() async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> setProvider(SyncProviderType provider) async {}

  @override
  Future<void> setSyncFrequency(SyncFrequency frequency) async {}

  @override
  Future<void> setWifiOnly(bool enabled) async {}
}

void main() {
  group('Responsive and Adaptive Tests', () {
    late MockBackupScheduler mockBackupScheduler;
    late MockSyncController mockSyncController;
    late DateTime currentMonth;

    setUp(() {
      mockBackupScheduler = MockBackupScheduler();
      mockSyncController = MockSyncController();
      final now = DateTime.now();
      currentMonth = DateTime(now.year, now.month);
    });

    testWidgets('HomeScreen handles orientation changes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;

      await pumpTestWidget(
        tester,
        child: const HomeScreen(),
        overrides: [
          hasAccountsProvider.overrideWith((ref) => Future.value(true)),
          backupSchedulerProvider.overrideWithValue(mockBackupScheduler),
          tbbProvider(currentMonth).overrideWith((ref) => Future.value(1000.0)),
          monthlyStatsProvider(currentMonth).overrideWith(
            (ref) => Future.value({'income': 5000.0, 'spending': 2000.0}),
          ),
          recentTransactionsProvider.overrideWith((ref) => Stream.value([])),
          syncControllerProvider.overrideWith((ref) => mockSyncController),
        ],
      );

      expect(find.byType(ToBeBudgetedWidget), findsOneWidget);

      // Landscape
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpAndSettle();
      expect(find.byType(ToBeBudgetedWidget), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('HomeScreen handles split-screen (tablet)', (
      WidgetTester tester,
    ) async {
      // Simulate 600px width (e.g. half of a tablet screen or a large phone)
      tester.view.physicalSize = const Size(600 * 3, 1000 * 3);
      tester.view.devicePixelRatio = 3.0;

      await pumpTestWidget(
        tester,
        child: const HomeScreen(),
        overrides: [
          hasAccountsProvider.overrideWith((ref) => Future.value(true)),
          backupSchedulerProvider.overrideWithValue(mockBackupScheduler),
          tbbProvider(currentMonth).overrideWith((ref) => Future.value(1000.0)),
          monthlyStatsProvider(currentMonth).overrideWith(
            (ref) => Future.value({'income': 5000.0, 'spending': 2000.0}),
          ),
          recentTransactionsProvider.overrideWith((ref) => Stream.value([])),
          syncControllerProvider.overrideWith((ref) => mockSyncController),
        ],
      );

      expect(find.byType(ToBeBudgetedWidget), findsOneWidget);
      // Ensure no overflow
      expect(tester.takeException(), isNull);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('HomeScreen handles large font scaling', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      // Set text scale factor to 2.0
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      await pumpTestWidget(
        tester,
        child: const HomeScreen(),
        overrides: [
          hasAccountsProvider.overrideWith((ref) => Future.value(true)),
          backupSchedulerProvider.overrideWithValue(mockBackupScheduler),
          tbbProvider(currentMonth).overrideWith((ref) => Future.value(1000.0)),
          monthlyStatsProvider(currentMonth).overrideWith(
            (ref) => Future.value({'income': 5000.0, 'spending': 2000.0}),
          ),
          recentTransactionsProvider.overrideWith((ref) => Stream.value([])),
          syncControllerProvider.overrideWith((ref) => mockSyncController),
        ],
      );

      expect(find.byType(ToBeBudgetedWidget), findsOneWidget);
      // Ensure no overflow errors
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
    });

    testWidgets('HomeScreen renders in Dark Mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      // Set platform brightness to dark
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

      await pumpTestWidget(
        tester,
        child: const HomeScreen(),
        overrides: [
          hasAccountsProvider.overrideWith((ref) => Future.value(true)),
          backupSchedulerProvider.overrideWithValue(mockBackupScheduler),
          tbbProvider(currentMonth).overrideWith((ref) => Future.value(1000.0)),
          monthlyStatsProvider(currentMonth).overrideWith(
            (ref) => Future.value({'income': 5000.0, 'spending': 2000.0}),
          ),
          recentTransactionsProvider.overrideWith((ref) => Stream.value([])),
          syncControllerProvider.overrideWith((ref) => mockSyncController),
        ],
      );

      expect(find.byType(ToBeBudgetedWidget), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
    });
  });
}
