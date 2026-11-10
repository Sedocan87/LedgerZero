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

  testWidgets('privacy policy and imprint are hidden while they have no URL', (
    tester,
  ) async {
    // Today's constants: the owner has no hosted texts yet.
    expect(AppLinks.privacyPolicyUrl, isNull);
    expect(AppLinks.imprintUrl, isNull);

    await pumpTestWidget(
      tester,
      child: const AboutScreen(),
      overrides: overrides(),
    );

    expect(find.byKey(const Key('about.privacyPolicy')), findsNothing);
    expect(find.byKey(const Key('about.imprint')), findsNothing);
  });

  testWidgets('privacy policy and imprint open their URL once it is set', (
    tester,
  ) async {
    await pumpTestWidget(
      tester,
      child: const AboutScreen(
        privacyPolicyUrl: 'https://example.com/privacy',
        imprintUrl: 'https://example.com/imprint',
      ),
      overrides: overrides(),
    );

    await tester.tap(find.byKey(const Key('about.privacyPolicy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about.imprint')));
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.parse('https://example.com/privacy'),
      Uri.parse('https://example.com/imprint'),
    ]);
    expect(clipboard, isNull);
  });

  testWidgets('a web page that cannot be opened is copied to the clipboard', (
    tester,
  ) async {
    canOpen = false;
    await pumpTestWidget(
      tester,
      child: const AboutScreen(privacyPolicyUrl: 'https://example.com/privacy'),
      overrides: overrides(),
    );

    await tester.tap(find.byKey(const Key('about.privacyPolicy')));
    await tester.pumpAndSettle();

    expect(clipboard, 'https://example.com/privacy');
    expect(
      find.text(
        'The page could not be opened. Its address has been copied to the '
        'clipboard.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the licence page lists the bundled Roboto font and the '
      'scanner\'s native libraries', (tester) async {
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
    expect(find.text('Roboto'), findsOneWidget);
    expect(find.text('zxing-cpp'), findsOneWidget);
    expect(find.text('zint'), findsOneWidget);
  });

  // A plain test (real async): the licence stream reads an asset.
  test('the Roboto entry carries the bundled licence text', () async {
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
    expect(
      entries.where((e) => e.packages.contains('zxing-cpp')),
      hasLength(1),
    );
  });

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
