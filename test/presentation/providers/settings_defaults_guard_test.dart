// The default account/category settings are cleared when the record no
// longer qualifies (deleted, closed, partner's; deleted, hidden).
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_defaults_guard.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late ProviderContainer c;

  setUp(() async {
    t = TestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(t.db),
      ],
    );
    // As MyApp does.
    c.listen(settingsDefaultsGuardProvider, (_, _) {});
  });

  tearDown(() async {
    c.dispose();
    await t.close();
  });

  /// Lets the streams emit and the guard's microtask run.
  Future<void> settle() async {
    await c.read(accountsProvider.future);
    await c.read(categoriesProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('a closed default account is cleared', () async {
    final account = await t.addAccount(id: 'a1');
    await c.read(settingsProvider.notifier).setDefaultAccountId('a1');
    await settle();
    expect(c.read(settingsProvider).defaultAccountId, 'a1');

    await t.accounts.updateAccount(account.copyWith(isClosed: true));
    await settle();
    expect(c.read(settingsProvider).defaultAccountId, isNull);
  });

  test('a deleted default account is cleared', () async {
    await t.addAccount(id: 'a1');
    await c.read(settingsProvider.notifier).setDefaultAccountId('a1');
    await settle();
    await t.accounts.deleteAccount('a1');
    await settle();
    expect(c.read(settingsProvider).defaultAccountId, isNull);
  });

  test("the partner's personal account is not a default", () async {
    await t.addAccount(id: 'p1');
    // Their phone shared it: owned by the partner's member id (the raw
    // update names the table so the accounts stream re-emits).
    await t.db.customUpdate(
      'UPDATE accounts SET owner_id = ?, on_budget = 0 WHERE id = ?',
      variables: const [Variable('partner-member'), Variable('p1')],
      updates: {t.db.accounts},
    );
    await c.read(settingsProvider.notifier).setDefaultAccountId('p1');
    await settle();
    expect(c.read(settingsProvider).defaultAccountId, isNull);
  });

  test('a hidden or deleted default category is cleared', () async {
    final groceries = await t.categoryId('Groceries');
    await c.read(settingsProvider.notifier).setDefaultCategoryId(groceries);
    await settle();
    expect(c.read(settingsProvider).defaultCategoryId, groceries);

    final category = (await t.categories.getCategoryById(groceries))!;
    await t.categories.updateCategory(category.copyWith(isHidden: true));
    await settle();
    expect(c.read(settingsProvider).defaultCategoryId, isNull);

    final dining = await t.categoryId('Dining Out');
    await c.read(settingsProvider.notifier).setDefaultCategoryId(dining);
    await settle();
    expect(c.read(settingsProvider).defaultCategoryId, dining);
    await t.categories.deleteCategory(dining);
    await settle();
    expect(c.read(settingsProvider).defaultCategoryId, isNull);
  });

  test('an eligible default survives unrelated changes', () async {
    await t.addAccount(id: 'a1');
    await t.addAccount(id: 'a2');
    await c.read(settingsProvider.notifier).setDefaultAccountId('a1');
    await settle();
    await t.accounts.deleteAccount('a2');
    await settle();
    expect(c.read(settingsProvider).defaultAccountId, 'a1');
  });
}
