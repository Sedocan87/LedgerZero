import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';

import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late ProviderContainer container;
  late PayeeController controller;

  setUp(() async {
    t = TestDatabase();
    await seedPayeeReferences(t);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(t.db)],
    );
    controller = container.read(payeeControllerProvider);
  });

  tearDown(() async {
    container.dispose();
    await t.close();
  });

  group('PayeeController (real database)', () {
    test('updatePayee persists changes', () async {
      final payee = (await t.payees.getPayeeById('target'))!;
      await controller.updatePayee(
        payee.copyWith(name: 'Corner Shop', isFavorite: true),
      );
      final updated = (await t.payees.getPayeeById('target'))!;
      expect(updated.name, 'Corner Shop');
      expect(updated.isFavorite, isTrue);
    });

    test('deletePayee clears all references, also soft-deleted rows and '
        'scheduled transactions', () async {
      await controller.deletePayee('source');

      await expectPayeeReferences(t, null);
      expect(await t.payees.getPayeeById('target'), isNotNull);
    });

    test('mergePayees moves all references to the target', () async {
      await controller.mergePayees('source', 'target');

      await expectPayeeReferences(t, 'target');
      expect(await countRows(t, 'transactions', 'payee_id = ?', ['target']), 4);
    });
  });
}
