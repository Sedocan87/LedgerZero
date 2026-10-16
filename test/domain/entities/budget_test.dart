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
        budgeted: 10000,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.id, '1');
      expect(budget.categoryId, 'cat1');
      expect(budget.month, '2023-10');
      expect(budget.budgeted, 10000);
      expect(budget.createdAt, now);
      expect(budget.updatedAt, now);
    });

    test('should use default values', () {
      const budget = Budget(id: '1', month: '2023-10');

      expect(budget.id, '1');
      expect(budget.categoryId, isNull);
      expect(budget.month, '2023-10');
      expect(budget.budgeted, 0);
      expect(budget.createdAt, isNull);
      expect(budget.updatedAt, isNull);
    });

    test('should support serialization', () {
      final now = DateTime(2023, 10, 1);
      final budget = Budget(
        id: '1',
        categoryId: 'cat1',
        month: '2023-10',
        budgeted: 10000,
        createdAt: now,
        updatedAt: now,
      );

      final json = budget.toJson();
      expect(json['id'], '1');
      expect(json['category_id'], 'cat1');
      expect(json['month'], '2023-10');
      expect(json['budgeted'], 10000);
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());

      final fromJson = Budget.fromJson(json);
      expect(fromJson.id, budget.id);
      expect(fromJson.categoryId, budget.categoryId);
      expect(fromJson.month, budget.month);
      expect(fromJson.budgeted, budget.budgeted);
      expect(fromJson.createdAt, budget.createdAt);
      expect(fromJson.updatedAt, budget.updatedAt);
    });

    test('should handle missing optional fields during serialization', () {
      final json = {'id': '1', 'month': '2023-10'};

      final budget = Budget.fromJson(json);
      expect(budget.id, '1');
      expect(budget.categoryId, isNull);
      expect(budget.month, '2023-10');
      expect(budget.budgeted, 0); // Default
      expect(budget.createdAt, isNull);
      expect(budget.updatedAt, isNull);
    });

    test('should support equality', () {
      final now = DateTime(2023, 10, 1);
      final budget1 = Budget(
        id: '1',
        categoryId: 'cat1',
        month: '2023-10',
        budgeted: 10000,
        createdAt: now,
        updatedAt: now,
      );

      final budget2 = Budget(
        id: '1',
        categoryId: 'cat1',
        month: '2023-10',
        budgeted: 10000,
        createdAt: now,
        updatedAt: now,
      );

      const budget3 = Budget(id: '2', month: '2023-11');

      // Reflexive
      expect(budget1, equals(budget1));

      // Symmetric
      expect(budget1, equals(budget2));
      expect(budget2, equals(budget1));

      // HashCode
      expect(budget1.hashCode, equals(budget2.hashCode));

      // Not Equal
      expect(budget1, isNot(equals(budget3)));
      expect(budget1, isNot(equals('Not a Budget')));
      expect(budget1, isNot(equals(null)));
    });
  });
}
