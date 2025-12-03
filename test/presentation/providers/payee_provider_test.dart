import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late MockPayeeRepository mockPayeeRepository;

  setUp(() {
    mockPayeeRepository = MockPayeeRepository();
  });

  group('filteredPayeesProvider', () {
    final payees = [
      const Payee(id: '1', name: 'Alpha', isFavorite: false),
      const Payee(id: '2', name: 'Beta', isFavorite: true),
      const Payee(id: '3', name: 'Gamma', isFavorite: false),
    ];

    test('returns all payees sorted by favorite then name when query is empty', () async {
      when(mockPayeeRepository.watchAllPayees()).thenAnswer((_) => Stream.value(payees));

      final container = ProviderContainer(
        overrides: [
          payeeRepositoryProvider.overrideWithValue(mockPayeeRepository),
        ],
      );

      // Wait for the stream to emit
      await container.read(payeesProvider.future);

      final result = container.read(filteredPayeesProvider);

      expect(result.value, isNotNull);
      final list = result.value!;
      expect(list.length, 3);
      expect(list[0].name, 'Beta'); // Favorite first
      expect(list[1].name, 'Alpha'); // Then Alphabetical
      expect(list[2].name, 'Gamma');
    });

    test('returns filtered payees when query is provided', () async {
      when(mockPayeeRepository.watchAllPayees()).thenAnswer((_) => Stream.value(payees));

      final container = ProviderContainer(
        overrides: [
          payeeRepositoryProvider.overrideWithValue(mockPayeeRepository),
        ],
      );

      // Wait for the stream to emit
      await container.read(payeesProvider.future);

      // Set query
      container.read(payeeSearchQueryProvider.notifier).state = 'alp';

      final result = container.read(filteredPayeesProvider);

      expect(result.value, isNotNull);
      final list = result.value!;
      expect(list.length, 1);
      expect(list[0].name, 'Alpha');
    });

    test('is case insensitive', () async {
      when(mockPayeeRepository.watchAllPayees()).thenAnswer((_) => Stream.value(payees));

      final container = ProviderContainer(
        overrides: [
          payeeRepositoryProvider.overrideWithValue(mockPayeeRepository),
        ],
      );

      // Wait for the stream to emit
      await container.read(payeesProvider.future);

      container.read(payeeSearchQueryProvider.notifier).state = 'BETA';

      final result = container.read(filteredPayeesProvider);

      expect(listEquals(result.value, [payees[1]]), isTrue);
    });
  });
}

bool listEquals(List<Payee>? a, List<Payee>? b) {
  if (a == null || b == null) {
    return a == b;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) {
      return false;
    }
  }
  return true;
}
