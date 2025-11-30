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

    test('should support serialization', () {
      final now = DateTime(2023, 10, 1);
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

      final json = budget.toJson();
      expect(json['id'], '1');
      expect(json['category_id'], 'cat1');
      expect(json['month'], '2023-10');
      expect(json['budgeted'], 100.0);
      expect(json['activity'], 50.0);
      expect(json['available'], 50.0);
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());

      final fromJson = Budget.fromJson(json);
      expect(fromJson.id, budget.id);
      expect(fromJson.categoryId, budget.categoryId);
      expect(fromJson.month, budget.month);
      expect(fromJson.budgeted, budget.budgeted);
      expect(fromJson.activity, budget.activity);
      expect(fromJson.available, budget.available);
      expect(fromJson.createdAt, budget.createdAt);
      expect(fromJson.updatedAt, budget.updatedAt);
    });
  });
}
