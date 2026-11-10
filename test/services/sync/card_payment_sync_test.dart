import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';

import '../../helpers/sync_simulation.dart';

/// Payment categories are ordinary category rows with ids derived from the
/// card: both phones end up with identical rows, however they got them.
void main() {
  const passphrase = 'correct horse battery staple';
  late FakeSyncFolder folder;
  late SimDevice a;
  late SimDevice b;

  setUp(() async {
    folder = FakeSyncFolder();
    a = await SimDevice.create(folder);
    b = await SimDevice.create(folder);
    await a.engine.createSyncFolder(passphrase);
    await b.engine.joinSyncFolder(passphrase);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<List<Map<String, Object?>>> paymentRows(SimDevice d) => d.rows(
    'SELECT id, name, category_group_id, is_hidden, sort_order, icon, '
    'created_at, updated_at FROM categories '
    "WHERE category_group_id = '${CardPayments.groupId}' ORDER BY id",
  );

  Future<List<Map<String, Object?>>> groupRows(SimDevice d) => d.rows(
    'SELECT * FROM category_groups '
    "WHERE id = '${CardPayments.groupId}'",
  );

  test(
    'a card created on one phone gets its payment category on both',
    () async {
      await a.t!.addAccount(id: 'visa', name: 'Visa', type: AccountType.credit);
      await syncAll([a, b]);

      final onA = await paymentRows(a);
      expect(onA.single['id'], CardPayments.categoryId('visa'));
      expect(onA.single['name'], 'Visa');
      expect(await paymentRows(b), onA);
      expect(await groupRows(b), await groupRows(a));

      // Renamed and closed on B: follows on A.
      final card = (await b.t!.accounts.getAccountById('visa'))!;
      await b.t!.accounts.updateAccount(
        card.copyWith(name: 'Visa Gold', isClosed: true),
      );
      await syncAll([a, b]);
      final renamed = await paymentRows(a);
      expect(renamed.single['name'], 'Visa Gold');
      expect(renamed.single['is_hidden'], 1);
      expect(await paymentRows(b), renamed);
    },
  );

  test('both phones healing the same card at the same time end up '
      'identical', () async {
    // The account reached both phones without its category (e.g. data
    // from before payment categories): both heal it.
    await a.t!.addAccount(id: 'visa', name: 'Visa', type: AccountType.credit);
    await syncAll([a, b]);
    for (final d in [a, b]) {
      await d.exec('DELETE FROM categories WHERE id = ?', [
        CardPayments.categoryId('visa'),
      ]);
    }
    await syncAll([a, b]);
    for (final d in [a, b]) {
      await d.t!.categories.syncCardPaymentCategories(
        stampedAt: cardPaymentHealStamp,
      );
    }
    final healedA = await paymentRows(a);
    expect(healedA.single['name'], 'Visa');
    expect(await paymentRows(b), healedA);

    await syncAll([a, b]);
    expect(await paymentRows(a), healedA);
    expect(await paymentRows(b), healedA);
    expect(await a.count('SELECT COUNT(*) FROM sync_conflicts'), 0);
  });

  test('a rename on one phone beats the other phone\'s stale heal', () async {
    await a.t!.addAccount(id: 'visa', name: 'Visa', type: AccountType.credit);
    await syncAll([a, b]);
    final card = (await a.t!.accounts.getAccountById('visa'))!;
    await a.t!.accounts.updateAccount(card.copyWith(name: 'Visa Gold'));
    // B heals before it has the rename: nothing to do (its rows match).
    await b.t!.categories.syncCardPaymentCategories(
      stampedAt: cardPaymentHealStamp,
    );
    await syncAll([a, b]);
    expect((await paymentRows(b)).single['name'], 'Visa Gold');
    expect(await paymentRows(a), await paymentRows(b));
  });
}
