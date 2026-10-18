import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/common/settings_action.dart';

void main() {
  testWidgets('opens Settings from any app bar', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(actions: const [SettingsAction()])),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('appbar.settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });
}
