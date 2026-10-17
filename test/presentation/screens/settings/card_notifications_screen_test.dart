import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/card_notifications_screen.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_notification_capture_channel.dart';

/// Holds every queued notification as unreadable; no database needed.
class _FakeService implements NotificationCaptureService {
  _FakeService(this.channel);

  final FakeNotificationCaptureChannel channel;

  @override
  bool get isSupported => true;

  @override
  Future<CaptureRunResult> processPending() async => const CaptureRunResult();

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

  const visa = Account(
    id: 'acc-visa',
    name: 'Visa',
    type: AccountType.credit,
    currency: 'EUR',
    startingBalance: 0,
  );

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationCaptureChannelProvider.overrideWithValue(channel),
          notificationCaptureServiceProvider.overrideWithValue(
            _FakeService(channel),
          ),
          accountsProvider.overrideWith((ref) => Stream.value([visa])),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: CardNotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => channel = FakeNotificationCaptureChannel());

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
}
