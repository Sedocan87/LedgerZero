// The rule editor's account sheet lists open accounts only, like the
// transaction form's picker.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/widgets/pickers/account_selector.dart';

void main() {
  testWidgets('closed accounts are not offered', (tester) async {
    const accounts = [
      Account(id: 'open', name: 'Giro', type: AccountType.checking),
      Account(
        id: 'closed',
        name: 'Old card',
        type: AccountType.credit,
        isClosed: true,
      ),
    ];
    Account? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          writableAccountsProvider.overrideWithValue(
            const AsyncValue.data(accounts),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: AccountSelector(onSelected: (a) => picked = a)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Giro'), findsOneWidget);
    expect(find.text('Old card'), findsNothing);
    await tester.tap(find.text('Giro'));
    await tester.pump();
    expect(picked?.id, 'open');
  });
}
