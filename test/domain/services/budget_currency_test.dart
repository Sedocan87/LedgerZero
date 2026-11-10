// The budget currency is the currency of the open accounts in the budget;
// "Change the budget currency" relabels exactly those, in one unit of work
// (docs/BUDGETING_RULES.md, "Budget currency").
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/services/account_service.dart';
import 'package:ledger_zero/domain/services/budget_currency.dart';

import '../../helpers/test_database.dart';

/// The real repository, failing on the [failOn]th update (a write error
/// or the app killed in the middle of the relabel).
class _FailingUpdates implements AccountRepository {
  _FailingUpdates(this._inner, {required this.failOn});

  final AccountRepository _inner;
  final int failOn;
  var _updates = 0;

  @override
  Future<List<Account>> getAllAccounts() => _inner.getAllAccounts();

  @override
  Future<void> updateAccount(Account account) async {
    if (++_updates == failOn) {
      throw StateError('write failed');
    }
    await _inner.updateAccount(account);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BudgetCurrency.of', () {
    Account account(
      String currency, {
      bool onBudget = true,
      bool closed = false,
    }) => Account(
      id: '$currency-$onBudget-$closed',
      name: currency,
      type: AccountType.checking,
      currency: currency,
      onBudget: onBudget,
      isClosed: closed,
    );

    test('without an open account in the budget it is the setting', () {
      final b = BudgetCurrency.of([
        account('USD', onBudget: false),
        account('GBP', closed: true),
      ], setting: 'EUR');
      expect(b.currency, 'EUR');
      expect(b.isFixed, isFalse);
    });

    test('with accounts in the budget it is theirs', () {
      final b = BudgetCurrency.of([
        account('CHF'),
        account('USD', onBudget: false),
      ], setting: 'EUR');
      expect(b.currency, 'CHF');
      expect(b.isFixed, isTrue);
      expect(b.isMixed, isFalse);
    });

    test('mixed: the setting if one of them, else the most used', () {
      final accounts = [
        account('EUR'),
        account('USD'),
        account('USD', closed: false).copyWith(id: 'usd2'),
      ];
      final kept = BudgetCurrency.of(accounts, setting: 'EUR');
      expect(kept.currency, 'EUR');
      expect(kept.isMixed, isTrue);
      expect(kept.onBudgetCurrencies, ['EUR', 'USD']);
      expect(kept.oddAccounts(accounts).map((a) => a.currency), ['USD', 'USD']);
      expect(BudgetCurrency.of(accounts, setting: 'CHF').currency, 'USD');
    });
  });

  group('relabelBudgetCurrency', () {
    late TestDatabase t;

    AccountService service([AccountRepository? accounts]) => AccountService(
      accountRepository: accounts ?? t.accounts,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
    );

    setUp(() async {
      t = TestDatabase();
      await t.addAccount(id: 'giro', currency: 'EUR', startingBalance: 1000);
      await t.addAccount(id: 'card', currency: 'EUR', startingBalance: -200);
      await t.addAccount(id: 'usd', currency: 'USD', onBudget: false);
      await t.addAccount(id: 'depot', currency: 'EUR', onBudget: false);
      await t.addAccount(id: 'mine', currency: 'EUR', owner: AccountOwner.me);
      final old = await t.addAccount(id: 'old', currency: 'EUR');
      await t.accounts.updateAccount(old.copyWith(isClosed: true));
    });

    tearDown(() => t.close());

    Future<Map<String, String>> currencies() async => {
      for (final a in await t.accounts.getAllAccounts()) a.id: a.currency,
    };

    test('relabels every open account in the budget and none outside it; '
        'amounts are not converted', () async {
      final count = await service().relabelBudgetCurrency('CHF');

      expect(count, 2);
      expect(await currencies(), {
        'giro': 'CHF',
        'card': 'CHF',
        'usd': 'USD',
        'depot': 'EUR',
        'mine': 'EUR',
        'old': 'EUR',
      });
      final giro = (await t.accounts.getAccountById('giro'))!;
      expect(giro.startingBalance, 1000);
      // An ordinary account edit: queued for the partner's phone.
      final queued = await t.db
          .customSelect(
            'SELECT COUNT(*) AS n FROM pending_sync_changes '
            "WHERE table_name = 'accounts' AND record_id IN ('giro', 'card')",
          )
          .getSingle();
      expect(queued.data['n'], greaterThanOrEqualTo(2));
    });

    test('in one unit of work: a failure relabels none', () async {
      final failing = _FailingUpdates(t.accounts, failOn: 2);
      await expectLater(
        service(failing).relabelBudgetCurrency('CHF'),
        throwsStateError,
      );
      final after = await currencies();
      expect(after['giro'], 'EUR');
      expect(after['card'], 'EUR');
    });

    test(
      'relabelling to the budget currency fixes only the odd ones',
      () async {
        await t.addAccount(id: 'travel', currency: 'USD');
        expect(await service().relabelBudgetCurrency('EUR'), 1);
        final after = await currencies();
        expect(after['travel'], 'EUR');
        expect(after['usd'], 'USD');
      },
    );
  });
}
