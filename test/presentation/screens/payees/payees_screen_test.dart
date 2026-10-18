import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/payees/payees_screen.dart';
import 'package:mockito/mockito.dart';

import '../../../mocks/repository_mocks.mocks.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Payee> payees) async {
    final repo = MockPayeeRepository();
    when(repo.watchAllPayees()).thenAnswer((_) => Stream.value(payees));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [payeeRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: PayeesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  IconButton exportButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const Key('payees.export')));

  testWidgets('export is disabled while there is nothing to export', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(find.text('No Payees'), findsOneWidget);
    expect(exportButton(tester).onPressed, isNull);
  });

  testWidgets('export is enabled with payees', (tester) async {
    await pump(tester, const [Payee(id: '1', name: 'Alpha')]);
    expect(exportButton(tester).onPressed, isNotNull);
  });
}
