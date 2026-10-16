// Performance budget of the budget screen's calculations on a large ledger
// (10,000 transactions over a year, 50 categories). Generously bounded; the
// point is to catch an accidental N+1 query or full-table loop, not to
// benchmark. Tagged `perf`: skipped by default, run with
// `flutter test --tags perf --run-skipped`.
@Tags(['perf'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/data/database/database.dart';

import '../domain/services/ledger_test_helpers.dart';
import '../helpers/test_database.dart';

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  test(
    'budget month of a 10k-transaction ledger is computed in < 5 s',
    () async {
      final month = DateTime.utc(2024, 12);
      await t.addAccount(id: 'acc', startingBalance: 100000);
      final categoryIds = <String>[];
      await t.db.batch((b) {
        for (var i = 0; i < 50; i++) {
          final id = 'perf-cat-$i';
          categoryIds.add(id);
          b.insert(
            t.db.categories,
            CategoriesCompanion.insert(id: id, name: 'Category $i'),
          );
          for (var m = 1; m <= 12; m++) {
            b.insert(
              t.db.budgets,
              BudgetsCompanion.insert(
                id: 'perf-b-$i-$m',
                categoryId: id,
                month: '2024-${m.toString().padLeft(2, '0')}',
                budgeted: const Value(5000),
              ),
            );
          }
        }
        for (var j = 0; j < 10000; j++) {
          final income = j % 10 == 0;
          b.insert(
            t.db.transactions,
            TransactionsCompanion.insert(
              id: 'perf-tx-$j',
              accountId: 'acc',
              date: CalendarDate.normalize(
                DateTime.utc(2024, 1, 1).add(Duration(days: j % 366)),
              ),
              amount: income ? 100000 : -(500 + j % 3000),
              categoryId: Value(income ? null : categoryIds[j % 50]),
            ),
          );
        }
      });

      final stopwatch = Stopwatch()..start();
      final tbb = await t.budgeting.calculateTBB(month);
      final batch = await t.budgeting.calculateBatchCategoryPerformance(month);
      stopwatch.stop();

      expect(batch, isNotEmpty);
      expect(tbb, isA<int>());
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      // The numbers are right too, not only fast.
      await expectLedgerInvariant(t, month);
    },
  );
}
