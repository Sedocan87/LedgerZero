import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/services/payee_service.dart';

import '../../helpers/test_database.dart';
import 'ledger_test_helpers.dart';

void main() {
  late TestDatabase t;
  late PayeeService service;

  setUp(() async {
    t = TestDatabase();
    service = PayeeService(
      payeeRepository: t.payees,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
    );
    await seedPayeeReferences(t);
  });

  tearDown(() => t.close());

  test('mergePayees moves every reference and deletes the source', () async {
    await service.mergePayees('source', 'target');

    await expectPayeeReferences(t, 'target');
    expect(await t.payees.getPayeeById('target'), isNotNull);
    await expectLedgerInvariant(t, DateTime.utc(2026, 5));
  });

  test('deletePayee clears every reference', () async {
    await service.deletePayee('source');

    await expectPayeeReferences(t, null);
    await expectLedgerInvariant(t, DateTime.utc(2026, 5));
  });

  test('merging into itself or from a missing payee is a no-op', () async {
    await service.mergePayees('source', 'source');
    await service.mergePayees('missing', 'target');
    expect(await t.payees.getPayeeById('source'), isNotNull);
    expect(await column(t, 'transactions', 'live', 'payee_id'), 'source');
  });
}
