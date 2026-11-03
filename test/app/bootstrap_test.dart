import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/bootstrap.dart';
import 'package:ledger_zero/app/startup_error_app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a failing start-up shows the error screen; Retry starts '
      'again', (tester) async {
    var attempts = 0;
    final shown = <Widget>[];
    Future<SharedPreferences> failing() async {
      attempts++;
      throw StateError('preferences unreadable');
    }

    await bootstrap(
      AppEnvironment.production,
      loadPreferences: failing,
      run: shown.add,
    );
    expect(attempts, 1);
    expect(shown.single, isA<StartupErrorApp>());

    await tester.pumpWidget(shown.single);
    await tester.pumpAndSettle();
    expect(find.text('LedgerZero could not start'), findsOneWidget);

    await tester.tap(find.byKey(const Key('startup.retry')));
    await tester.pump();
    expect(attempts, 2);
    expect(shown, hasLength(2));
    expect(shown.last, isA<StartupErrorApp>());
  });

  test('every entry point starts through bootstrap (the error screen)', () {
    final entryPoints = Directory('lib')
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'main(_\w+)?\.dart$').hasMatch(f.path))
        .toList();
    expect(
      entryPoints.map((f) => f.uri.pathSegments.last),
      containsAll([
        'main.dart',
        'main_development.dart',
        'main_staging.dart',
        'main_production.dart',
      ]),
    );
    for (final file in entryPoints) {
      final source = file.readAsStringSync();
      expect(source, contains('bootstrap('), reason: file.path);
      expect(source, isNot(contains('runApp(')), reason: file.path);
    }
  });
}
