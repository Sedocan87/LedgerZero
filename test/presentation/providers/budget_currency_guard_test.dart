// The stored budget currency (per phone) follows the currency of the
// accounts in the budget: at start-up, and after a sync run applied the
// partner's changes, so both phones agree.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/services/account_service.dart';
import 'package:ledger_zero/presentation/providers/budget_currency_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/sync_simulation.dart';
import '../../helpers/test_database.dart';

void main() {
  /// A phone running the app on [db] with [setting] stored, the guard
  /// alive as in `MyApp`.
  Future<ProviderContainer> phone(AppDatabase db, String setting) async {
    SharedPreferences.setMockInitialValues({'settings_currency': setting});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(c.dispose);
    c.listen(budgetCurrencyGuardProvider, (_, _) {});
    return c;
  }

  /// Lets the accounts stream emit and the guard's microtask run.
  Future<void> settle(ProviderContainer c) async {
    await c.read(accountsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  String stored(ProviderContainer c) =>
      c.read(sharedPreferencesProvider).getString('settings_currency')!;

  group('at start-up', () {
    late TestDatabase t;
    setUp(() => t = TestDatabase());
    tearDown(() => t.close());

    test(
      'the setting becomes the currency of the accounts in the budget',
      () async {
        await t.addAccount(currency: 'CHF');
        await t.addAccount(currency: 'USD', onBudget: false);
        final c = await phone(t.db, 'EUR');
        await settle(c);
        expect(c.read(settingsProvider).currency, 'CHF');
        expect(stored(c), 'CHF');
      },
    );

    test('without an account in the budget the setting stays free', () async {
      await t.addAccount(currency: 'USD', onBudget: false);
      final c = await phone(t.db, 'EUR');
      await settle(c);
      expect(stored(c), 'EUR');
    });

    test('mixed accounts keep a setting that is one of theirs', () async {
      await t.addAccount(currency: 'EUR');
      await t.addAccount(currency: 'USD');
      final c = await phone(t.db, 'EUR');
      await settle(c);
      expect(stored(c), 'EUR');
      expect(c.read(budgetCurrencyProvider).isMixed, isTrue);
    });
  });

  test('after a sync run the partner phone follows a relabel', () async {
    const passphrase = 'correct horse battery staple';
    final folder = FakeSyncFolder();
    final a = await SimDevice.create(folder);
    final b = await SimDevice.create(folder);
    addTearDown(a.close);
    addTearDown(b.close);
    await a.engine.createSyncFolder(passphrase);
    await b.engine.joinSyncFolder(passphrase);
    await a.t!.addAccount(id: 'giro', currency: 'EUR');
    await a.t!.addAccount(id: 'usd', currency: 'USD', onBudget: false);
    await syncAll([a, b]);

    final partner = await phone(b.db, 'EUR');
    await settle(partner);
    expect(stored(partner), 'EUR');

    // A person's edit is never in the same millisecond as the version it
    // starts from.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await AccountService(
      accountRepository: a.t!.accounts,
      maintenance: a.t!.maintenance,
      ruleRepository: a.t!.rules,
      unitOfWork: a.t!.unitOfWork,
    ).relabelBudgetCurrency('CHF');
    await syncAll([a, b]);
    await settle(partner);

    expect(stored(partner), 'CHF');
    expect(partner.read(settingsProvider).currency, 'CHF');
    final usd = await b.rows("SELECT currency FROM accounts WHERE id = 'usd'");
    expect(usd.single['currency'], 'USD');
  });
}
