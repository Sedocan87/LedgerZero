import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  test(
    'the provided parser sees payees created after its first parse',
    () async {
      SharedPreferences.setMockInitialValues({});
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

      final parser = container.read(transactionParserProvider);
      // Let the payees watch deliver its first (empty) list.
      await pumpEventQueue();
      expect((await parser.parse('Starbuks 4.50')).payeeId, isNull);

      await t.payees.createPayee(
        Payee(id: 'sb', name: 'Starbucks', createdAt: DateTime.utc(2024)),
      );
      await pumpEventQueue();

      expect((await parser.parse('Starbuks 4.50')).payeeId, 'sb');
    },
  );
}
