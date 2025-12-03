import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/settings/settings_screen.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  testWidgets('SettingsScreen shows Scheduled Transactions option', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en', 'US'),
        ],
        home: SettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Scheduled Transactions'), findsOneWidget);
    expect(find.byIcon(AppIcons.calendar), findsOneWidget);
  });
}
