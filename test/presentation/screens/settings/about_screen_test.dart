// Settings > About (version, licences, support contact, legal pages) and
// the support contact's fallback when the phone has no mail app.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/licenses.dart';
import 'package:ledger_zero/core/constants/app_links.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/app_info_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/about_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/legal_document_screen.dart';
import 'package:ledger_zero/services/legal/legal_documents.dart';
import 'package:ledger_zero/presentation/providers/review_provider.dart';
import 'package:ledger_zero/services/review/review_service.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_zero/presentation/screens/settings/help_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../widget_test_helpers.dart';

void main() {
  final opened = <Uri>[];
  var canOpen = true;
  String? clipboard;

  List<Override> overrides() => [
    packageInfoProvider.overrideWith(
      (ref) async => PackageInfo(
        appName: 'LedgerZero Dev',
        packageName: 'com.ledgerzero.app.dev',
        version: '0.1.0-dev',
        buildNumber: '7',
      ),
    ),
    externalLinkOpenerProvider.overrideWithValue((uri) async {
      opened.add(uri);
      return canOpen;
    }),
  ];

  /// The bundled text is read from disk (real I/O, outside the fake
  /// clock): wait for the page.
  Future<void> waitForPage(WidgetTester tester, String document) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byKey(Key('legal.$document')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  setUp(() {
    opened.clear();
    canOpen = true;
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('the About entry in Settings opens the About screen', (
    tester,
  ) async {
    await pumpTestWidget(
      tester,
      child: ListView(children: const [AboutSettingsSection()]),
      overrides: overrides(),
    );

    expect(find.text('About LedgerZero'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings.about')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Version 0.1.0-dev (build 7)'), findsOneWidget);
  });

  testWidgets('About and its Settings entry fit 360 dp in German', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: Scaffold(
            body: ListView(children: const [AboutSettingsSection()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Über LedgerZero'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('settings.about')));
    await tester.pumpAndSettle();
    expect(find.text('Version 0.1.0-dev (Build 7)'), findsOneWidget);
    expect(find.text('Open-Source-Lizenzen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows app name, version and build number', (tester) async {
    await pumpTestWidget(
      tester,
      child: const AboutScreen(),
      overrides: overrides(),
    );

    expect(find.text('LedgerZero Dev'), findsOneWidget);
    expect(find.text('Version 0.1.0-dev (build 7)'), findsOneWidget);
    expect(find.text(AppLinks.supportEmail), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
  });

  testWidgets('privacy policy and terms of use open in the app, in its '
      'language', (tester) async {
    await pumpTestWidget(
      tester,
      child: const AboutScreen(),
      overrides: overrides(),
    );

    await tester.tap(find.byKey(const Key('about.privacy')));
    await waitForPage(tester, 'privacy');
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Who is responsible'), findsOneWidget);
    expect(opened, isEmpty, reason: 'bundled, no browser');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('about.terms')));
    await waitForPage(tester, 'terms');
    expect(find.text('No financial advice'), findsOneWidget);
  });

  testWidgets('the imprint is hidden while the publisher is not filled in', (
    tester,
  ) async {
    await pumpTestWidget(
      tester,
      child: const AboutScreen(),
      overrides: [
        ...overrides(),
        publisherProvider.overrideWith((ref) async => const Publisher()),
      ],
    );
    expect(find.byKey(const Key('about.imprint')), findsNothing);
  });

  testWidgets('the imprint is shown once the publisher is filled in', (
    tester,
  ) async {
    await pumpTestWidget(
      tester,
      child: const AboutScreen(),
      overrides: [
        ...overrides(),
        publisherProvider.overrideWith(
          (ref) async => const Publisher(
            name: 'Erika Mustermann',
            address: ['Musterstraße 1', '12345 Musterstadt'],
            email: 'support@ledgerzero.app',
          ),
        ),
      ],
    );
    expect(find.byKey(const Key('about.imprint')), findsOneWidget);
  });

  testWidgets('Settings lists About with the version, rating, the legal '
      'pages and the licences; rating opens the Play Store page', (
    tester,
  ) async {
    final review = _ListingOnly();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pumpTestWidget(
      tester,
      child: ListView(children: const [AboutSettingsSection()]),
      overrides: [
        ...overrides(),
        reviewClientProvider.overrideWithValue(review),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    expect(find.text('Version 0.1.0-dev (build 7)'), findsOneWidget);
    for (final key in [
      'settings.rate',
      'settings.privacy',
      'settings.terms',
      'settings.licenses',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    await tester.tap(find.byKey(const Key('settings.rate')));
    await tester.pumpAndSettle();
    expect(review.listings, 1);
  });

  testWidgets('the licence page lists the bundled Inter and Roboto fonts '
      'and the scanner\'s native libraries', (tester) async {
    LicenseRegistry.reset();
    resetBundledLicensesForTesting();
    addTearDown(() {
      LicenseRegistry.reset();
      resetBundledLicensesForTesting();
    });
    await pumpTestWidget(
      tester,
      child: const AboutScreen(),
      overrides: overrides(),
    );

    await tester.tap(find.byKey(const Key('about.licenses')));
    // The licence page collects its entries asynchronously (asset read).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('LedgerZero Dev'), findsWidgets);
    expect(find.text('Inter'), findsOneWidget);
    expect(find.text('Roboto'), findsOneWidget);
    expect(find.text('zxing-cpp'), findsOneWidget);
    expect(find.text('zint'), findsOneWidget);
  });

  // A plain test (real async): the licence stream reads an asset.
  test(
    'the Inter and Roboto entries carry the bundled licence texts',
    () async {
      // rootBundle caches the asset's future; one cached by a widget test
      // belongs to that test's fake-async zone and would never complete here.
      rootBundle.clear();
      LicenseRegistry.reset();
      resetBundledLicensesForTesting();
      addTearDown(() {
        LicenseRegistry.reset();
        resetBundledLicensesForTesting();
      });
      registerBundledLicenses();
      // A second call must not add the entries twice.
      registerBundledLicenses();

      final entries = await LicenseRegistry.licenses.toList();

      final roboto = entries.where((e) => e.packages.contains('Roboto'));
      expect(roboto, hasLength(1));
      expect(
        roboto.single.paragraphs.map((p) => p.text).join('\n'),
        contains('Apache License'),
      );
      final inter = entries.where((e) => e.packages.contains('Inter'));
      expect(inter, hasLength(1));
      expect(
        inter.single.paragraphs.map((p) => p.text).join('\n'),
        allOf(
          contains('The Inter Project Authors'),
          contains('SIL OPEN FONT LICENSE Version 1.1'),
        ),
      );
      expect(
        entries.where((e) => e.packages.contains('zxing-cpp')),
        hasLength(1),
      );
    },
  );

  group('Contact support', () {
    testWidgets('opens a mail to the support address', (tester) async {
      await pumpTestWidget(
        tester,
        child: const AboutScreen(),
        overrides: overrides(),
      );

      await tester.tap(find.byKey(const Key('about.support')));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('mailto:${AppLinks.supportEmail}')]);
      expect(clipboard, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('without a mail app the address is copied and the user is told '
        '(About)', (tester) async {
      canOpen = false;
      await pumpTestWidget(
        tester,
        child: const AboutScreen(),
        overrides: overrides(),
      );

      await tester.tap(find.byKey(const Key('about.support')));
      await tester.pumpAndSettle();

      expect(clipboard, AppLinks.supportEmail);
      expect(
        find.text(
          'No e-mail app was found. The address ${AppLinks.supportEmail} '
          'has been copied to the clipboard.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('without a mail app the address is copied and the user is told '
        '(Help)', (tester) async {
      canOpen = false;
      await pumpTestWidget(
        tester,
        child: const HelpScreen(),
        overrides: overrides(),
      );

      await tester.tap(find.byKey(const Key('help.contactSupport')));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('mailto:${AppLinks.supportEmail}')]);
      expect(clipboard, AppLinks.supportEmail);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

class _ListingOnly implements ReviewClient {
  int listings = 0;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStoreListing() async => listings++;
}
