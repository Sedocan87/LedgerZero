import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the import currency starts at the default currency from Settings '
      'and can be changed before importing', () async {
    SharedPreferences.setMockInitialValues({'settings_currency': 'EUR'});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(t.db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(ynabImportViewModelProvider, (_, _) {});
    addTearDown(sub.close);

    expect(container.read(ynabImportViewModelProvider).currency, 'EUR');
    container.read(ynabImportViewModelProvider.notifier).setCurrency('CHF');
    expect(container.read(ynabImportViewModelProvider).currency, 'CHF');
  });
}
