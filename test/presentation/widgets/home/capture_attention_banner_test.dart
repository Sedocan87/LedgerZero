import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/settings_screen.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_notification_capture_channel.dart';

class _FakeBackupScheduler extends Mock implements BackupScheduler {
  @override
  Future<void> checkBackupDue() async {}
}

class _FakeCapture implements NotificationCaptureService {
  _FakeCapture(this.attentionNow);

  CaptureAttention attentionNow;

  @override
  Future<CaptureAttention> attention() async => attentionNow;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  final opened = <String>[];

  Future<ProviderContainer> pump(
    WidgetTester tester,
    CaptureAttention attention, {
    Widget home = const HomeScreen(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    opened.clear();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => home),
        GoRoute(
          path: '/settings/card-notifications',
          builder: (context, state) {
            opened.add(state.uri.path);
            return const Scaffold(body: Text('card notifications'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupSchedulerProvider.overrideWithValue(_FakeBackupScheduler()),
          hasAccountsProvider.overrideWithValue(const AsyncValue.data(true)),
          tbbProvider.overrideWith((ref, month) => Future.value(10000)),
          monthlyStatsProvider.overrideWith(
            (ref, month) => Future.value({'income': 0, 'spending': 0}),
          ),
          accountsProvider.overrideWith((ref) => Stream.value([])),
          recentTransactionsProvider.overrideWith((ref) => Stream.value([])),
          notificationCaptureChannelProvider.overrideWithValue(
            FakeNotificationCaptureChannel(),
          ),
          notificationCaptureServiceProvider.overrideWithValue(
            _FakeCapture(attention),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    await container.read(captureAttentionProvider.notifier).refresh();
    await tester.pumpAndSettle();
    return container;
  }

  final banner = find.byKey(const Key('home.captureAttention'));

  testWidgets('Home says what card capture held back and leads to its '
      'settings', (tester) async {
    await pump(
      tester,
      const CaptureAttention(
        watching: true,
        waiting: ['w1', 'w2'],
        duplicates: ['d1'],
        failed: ['f1'],
      ),
    );

    expect(banner, findsOneWidget);
    expect(
      find.text('2 captured notifications are waiting for you'),
      findsOneWidget,
    );
    expect(
      find.text(
        '1 payment not added: it looks like a transaction you already have',
      ),
      findsOneWidget,
    );
    expect(find.text('1 payment could not be added'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home.captureAttention.review')));
    await tester.pumpAndSettle();
    expect(opened, ['/settings/card-notifications']);
  });

  testWidgets('Home says that capture stopped; the banner can be '
      'dismissed', (tester) async {
    final container = await pump(
      tester,
      const CaptureAttention(watching: true, listenerDisconnected: true),
    );

    expect(banner, findsOneWidget);
    expect(
      find.textContaining('has not connected the notification listener'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home.captureAttention.dismiss')));
    await tester.pumpAndSettle();
    expect(banner, findsNothing);

    // Still dismissed the next time the state is read.
    await container.read(captureAttentionProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
  });

  testWidgets('no banner when nothing needs attention or no app is '
      'watched', (tester) async {
    await pump(tester, const CaptureAttention(watching: true));
    expect(banner, findsNothing);

    await pump(tester, const CaptureAttention(accessMissing: true));
    expect(banner, findsNothing);
  });

  testWidgets('the Settings entry carries a badge', (tester) async {
    await pump(
      tester,
      const CaptureAttention(watching: true, waiting: ['w1'], failed: ['f1']),
      home: const SettingsScreen(),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.cardNotifications')),
      300,
    );
    final badge = find.byKey(const Key('settings.cardNotifications.badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsOneWidget,
    );
  });
}
