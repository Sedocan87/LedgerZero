import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late MockPayeeRepository mockPayeeRepository;
  late MockTransactionRepository mockTransactionRepository;

  setUp(() {
    mockPayeeRepository = MockPayeeRepository();
    mockTransactionRepository = MockTransactionRepository();
  });

  test('payeesProvider returns list of payees', () async {
    final payees = [
      Payee(id: '1', name: 'Payee A', createdAt: DateTime.now()),
      Payee(id: '2', name: 'Payee B', createdAt: DateTime.now()),
    ];

    when(mockPayeeRepository.watchAllPayees()).thenAnswer((_) => Stream.value(payees));

    final container = ProviderContainer(
      overrides: [
        payeeRepositoryProvider.overrideWithValue(mockPayeeRepository),
        transactionRepositoryProvider.overrideWithValue(mockTransactionRepository),
      ],
    );

    final result = await container.read(payeesProvider.future);
    expect(result, payees);
  });
}
