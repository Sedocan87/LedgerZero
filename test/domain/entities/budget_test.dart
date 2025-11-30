import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/budget.dart';

void main() {
  group('Budget', () {
    test('should instantiate correctly', () {
      final now = DateTime.now();
      final budget = Budget(
        id: '1',
        categoryId: 'cat1',
        month: '2023-10',
        budgeted: 100.0,
        activity: 50.0,
        available: 50.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.id, '1');
      expect(budget.categoryId, 'cat1');
      expect(budget.month, '2023-10');
      expect(budget.budgeted, 100.0);
      expect(budget.activity, 50.0);
      expect(budget.available, 50.0);
      expect(budget.createdAt, now);
      expect(budget.updatedAt, now);
    });

    test('should use default values', () {
      const budget = Budget(
        id: '1',
        month: '2023-10',
      );

      expect(budget.id, '1');
      expect(budget.categoryId, isNull);
      expect(budget.month, '2023-10');
      expect(budget.budgeted, 0.0);
      expect(budget.activity, 0.0);
      expect(budget.available, 0.0);
      expect(budget.createdAt, isNull);
      expect(budget.updatedAt, isNull);
    });
  });
}
