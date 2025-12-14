import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Wraps the widget under test with a [ProviderScope] and [MaterialApp]
/// configured with localizations.
Future<void> pumpTestWidget(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
  NavigatorObserver? navigatorObserver,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Material(child: child),
        navigatorObservers: navigatorObserver != null
            ? [navigatorObserver]
            : [],
      ),
    ),
  );
  await tester.pumpAndSettle();
}
