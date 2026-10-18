import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/card_notification_log_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/card_notifications_screen.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_notification_capture_channel.dart';

/// Holds every queued notification as unreadable; no database needed. The
/// log is [history] as given.
class _FakeService implements NotificationCaptureService {
  _FakeService(this.channel);

  final FakeNotificationCaptureChannel channel;
  List<LoggedCapture> log = [];
  final List<String> addedAgain = [];
  final List<String> retried = [];
  final List<String> deleted = [];

  /// Thrown by [processPending] (a broken native store).
  Object? processError;

  @override
  Future<int> captureShowing(String packageName) =>
      channel.captureShowing(packageName);

  @override
  Future<List<LoggedCapture>> history({
    DateTime? from,
    DateTime? toExclusive,
    String? packageName,
  }) async => List.of(log);

  @override
  Future<int> addAgain(Iterable<String> ids) async {
    addedAgain.addAll(ids);
    return ids.length;
  }

  @override
  bool get isSupported => true;

  @override
  Future<CaptureRunResult> processPending() async {
    if (processError != null) {
      throw processError!;
    }
    return const CaptureRunResult();
  }

  @override
  Future<CaptureRunResult> retry(Iterable<String> ids) async {
    retried.addAll(ids);
    return const CaptureRunResult(added: 1);
  }

  @override
  Future<void> deleteHistory(Iterable<String> ids) async {
    deleted.addAll(ids);
  }

  @override
  Future<List<HeldCapture>> held() async => [
    for (final n in channel.queue)
      HeldCapture(
        n,
        const CardNotificationParse(CaptureKind.unreadable),
        CaptureHoldReason.unreadable,
      ),
  ];

  @override
  Future<void> dismiss(Iterable<String> ids) => channel.remove(ids);

  @override
  Future<void> removeSource(String packageName) async {
    channel.sources.removeWhere((s) => s.packageName == packageName);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeNotificationCaptureChannel channel;
  late _FakeService service;

  const visa = Account(
    id: 'acc-visa',
    name: 'Visa',
    type: AccountType.credit,
    currency: 'EUR',
    startingBalance: 0,
  );

  Future<void> pump(
    WidgetTester tester, {
    Widget home = const CardNotificationsScreen(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationCaptureChannelProvider.overrideWithValue(channel),
          notificationCaptureServiceProvider.overrideWithValue(service),
          accountsProvider.overrideWith((ref) => Stream.value([visa])),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    channel = FakeNotificationCaptureChannel();
    service = _FakeService(channel);
  });

  testWidgets('access is requested only after the disclosure', (tester) async {
    channel.accessGranted = false;
    await pump(tester);

    expect(find.text('Not granted: nothing is captured'), findsOneWidget);
    await tester.tap(find.text('Grant access'));
    await tester.pumpAndSettle();
    expect(
      find.text('Allow LedgerZero to read notifications?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(channel.accessSettingsOpened, 0);

    await tester.tap(find.text('Grant access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(channel.accessSettingsOpened, 1);
  });

  testWidgets('adding an app asks for its account', (tester) async {
    channel.candidates = [
      const CandidateApp(
        packageName: 'de.bank.app',
        label: 'My Bank',
        origin: CandidateAppOrigin.known,
      ),
    ];
    await pump(tester);
    expect(find.text('No apps chosen yet.'), findsOneWidget);

    await tester.tap(find.text('Add app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Add payments from My Bank to'), findsOneWidget);
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(channel.sources.single.packageName, 'de.bank.app');
    expect(channel.sources.single.accountId, 'acc-visa');
    expect(find.text('My Bank'), findsOneWidget);
    expect(find.text('Visa'), findsOneWidget);
  });

  testWidgets('held notifications can be dismissed', (tester) async {
    channel.sources = [
      const CaptureSource(
        packageName: 'de.bank.app',
        label: 'My Bank',
        accountId: 'acc-visa',
      ),
    ];
    channel.queue.add(
      CapturedNotification(
        id: 'n1',
        packageName: 'de.bank.app',
        appLabel: 'My Bank',
        text: 'You have a new message',
        postedAt: DateTime(2026, 10, 14),
      ),
    );
    await pump(tester);

    expect(find.text('Waiting for you'), findsOneWidget);
    expect(find.text('No amount found'), findsOneWidget);

    await tester.ensureVisible(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(channel.queue, isEmpty);
    expect(find.text('Waiting for you'), findsNothing);
  });

  testWidgets('notifications already showing are offered for review', (
    tester,
  ) async {
    channel.candidates = [
      const CandidateApp(
        packageName: 'de.bank.app',
        label: 'My Bank',
        origin: CandidateAppOrigin.active,
      ),
    ];
    channel.showing['de.bank.app'] = [
      CapturedNotification(
        id: 'n1',
        packageName: 'de.bank.app',
        appLabel: 'My Bank',
        text: 'You spent €4.20 at Kiosk',
        postedAt: DateTime(2026, 10, 14),
      ),
    ];
    await pump(tester);

    await tester.tap(find.text('Add app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(
      find.text('1 notification from My Bank was already showing.'),
      findsOneWidget,
    );
    expect(channel.queue.single.status, CaptureStatus.found);
    await tester.scrollUntilVisible(
      find.byKey(const Key('cardNotifications.log')),
      200,
    );
    expect(find.byKey(const Key('cardNotifications.log')), findsOneWidget);
  });

  testWidgets('a failing booking run still shows the settings, with the '
      'error', (tester) async {
    channel.sources = [
      const CaptureSource(
        packageName: 'de.bank.app',
        label: 'My Bank',
        accountId: 'acc-visa',
      ),
    ];
    service.processError = StateError('disk full');
    await pump(tester);

    expect(find.byKey(const Key('cardNotifications.errorBanner')), findsOneWidget);
    expect(
      find.textContaining('StateError: Bad state: disk full'),
      findsOneWidget,
    );
    expect(find.text('My Bank'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);
  });

  testWidgets('a listener that is not connected is pointed out', (
    tester,
  ) async {
    channel.listenerConnected = false;
    await pump(tester);
    expect(
      find.byKey(const Key('cardNotifications.disconnected')),
      findsOneWidget,
    );

    channel.listenerConnected = true;
    await pump(tester, home: const CardNotificationsScreen(key: Key('again')));
    expect(find.byKey(const Key('cardNotifications.disconnected')), findsNothing);
  });

  testWidgets('a storage reset is shown once, with its date', (tester) async {
    channel.storageReset = DateTime(2026, 10, 18, 9, 30);
    await pump(tester);

    expect(find.textContaining('reset on'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(channel.storageReset, isNull);
    expect(find.textContaining('reset on'), findsNothing);
  });

  testWidgets('the log shows the error of a failing run and still lists '
      'the entries', (tester) async {
    service.processError = StateError('disk full');
    service.log = [
      LoggedCapture(
        CapturedNotification(
          id: 'n1',
          packageName: 'de.bank.app',
          appLabel: 'My Bank',
          text: 'You spent €3.55 at Kiosk',
          postedAt: DateTime(2026, 10, 14, 9, 28),
          status: CaptureStatus.added,
          transactionId: 'tx1',
        ),
        const CardNotificationParse(
          CaptureKind.outflow,
          amount: 355,
          currency: 'EUR',
          merchant: 'Kiosk',
        ),
      ),
    ];
    await pump(tester, home: const CardNotificationLogScreen());

    expect(
      find.textContaining('StateError: Bad state: disk full'),
      findsOneWidget,
    );
    expect(find.textContaining('Kiosk'), findsWidgets);
    expect(find.text('Nothing captured in this period.'), findsNothing);
  });

  testWidgets('failed entries show their error and can be retried; '
      'duplicates can be added anyway; listed entries can be deleted', (
    tester,
  ) async {
    LoggedCapture entry(String id, CaptureStatus status, {String? error}) =>
        LoggedCapture(
          CapturedNotification(
            id: id,
            packageName: 'de.bank.app',
            appLabel: 'My Bank',
            text: 'You spent €3.55 at Kiosk',
            postedAt: DateTime(2026, 10, 14, 9, 28),
            status: status,
            error: error,
          ),
          const CardNotificationParse(
            CaptureKind.outflow,
            amount: 355,
            currency: 'EUR',
            merchant: 'Kiosk',
          ),
          likelyDuplicate: status == CaptureStatus.duplicate,
        );
    service.log = [
      entry('failed', CaptureStatus.failed, error: 'StateError: disk full'),
      entry('dup', CaptureStatus.duplicate),
    ];
    await pump(tester, home: const CardNotificationLogScreen());

    expect(find.textContaining('Not added: StateError: disk full'), findsOneWidget);
    expect(
      find.textContaining('a transaction with this amount already exists'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.retried, ['failed']);

    await tester.tap(find.text('Add anyway'));
    await tester.pumpAndSettle();
    expect(service.addedAgain, ['dup']);

    await tester.tap(find.byKey(const Key('cardNotificationLog.delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete the 2 listed entries'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cardNotificationLog.deleteConfirm')));
    await tester.pumpAndSettle();
    expect(service.deleted, ['failed', 'dup']);
  });

  testWidgets('the log adds the selected payments', (tester) async {
    channel.sources = [
      const CaptureSource(
        packageName: 'de.bank.app',
        label: 'My Bank',
        accountId: 'acc-visa',
      ),
    ];
    LoggedCapture entry(
      String id,
      CaptureStatus status, {
      bool duplicate = false,
    }) => LoggedCapture(
      CapturedNotification(
        id: id,
        packageName: 'de.bank.app',
        appLabel: 'My Bank',
        text: 'Your payment of €3.55 at Kiosk was declined',
        postedAt: DateTime(2026, 10, 14, 9, 28),
        status: status,
      ),
      const CardNotificationParse(
        CaptureKind.ignored,
        amount: 355,
        currency: 'EUR',
        merchant: 'Kiosk',
        ignoredPhrase: 'declined',
      ),
      likelyDuplicate: duplicate,
    );
    service.log = [
      entry('skipped', CaptureStatus.skipped),
      entry('found', CaptureStatus.found),
      entry('dup', CaptureStatus.found, duplicate: true),
    ];
    await pump(tester, home: const CardNotificationLogScreen());

    expect(find.textContaining('Skipped: contains “declined”'), findsOneWidget);
    expect(
      find.text('A transaction with this amount already exists'),
      findsOneWidget,
    );

    // Select all leaves out skipped notifications and likely duplicates.
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('Add 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cardNotificationLog.add')));
    await tester.pumpAndSettle();

    expect(service.addedAgain, ['found']);
    expect(find.text('1 card payment added'), findsOneWidget);
  });
}
