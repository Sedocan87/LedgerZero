import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';

void main() {
  group('Category', () {
    final testDate = DateTime(2023, 1, 1);

    final category = Category(
      id: 'cat_1',
      name: 'Groceries',
      categoryGroupId: 'group_1',
      isHidden: false,
      sortOrder: 1,
      goalType: GoalType.monthlyFunding,
      targetAmount: 500.0,
      targetDate: testDate,
      color: 0xFF00FF00,
      icon: 'cart',
      createdAt: testDate,
    );

    test('supports value equality', () {
      final c1 = Category(
        id: 'cat_1',
        name: 'Groceries',
        categoryGroupId: 'group_1',
        isHidden: false,
        sortOrder: 1,
        goalType: GoalType.monthlyFunding,
        targetAmount: 500.0,
        targetDate: testDate,
        color: 0xFF00FF00,
        icon: 'cart',
        createdAt: testDate,
      );
      final c2 = Category(
        id: 'cat_1',
        name: 'Groceries',
        categoryGroupId: 'group_1',
        isHidden: false,
        sortOrder: 1,
        goalType: GoalType.monthlyFunding,
        targetAmount: 500.0,
        targetDate: testDate,
        color: 0xFF00FF00,
        icon: 'cart',
        createdAt: testDate,
      );

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
    });

    test('copyWith returns new instance with updated fields', () {
      final updated = category.copyWith(
        name: 'Food',
        targetAmount: 600.0,
      );

      expect(updated.name, equals('Food'));
      expect(updated.targetAmount, equals(600.0));
      expect(updated.id, equals(category.id));
      expect(updated.goalType, equals(category.goalType));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'id': 'cat_1',
        'name': 'Groceries',
        'category_group_id': 'group_1',
        'is_hidden': false,
        'sort_order': 1,
        'goal_type': 'monthlyFunding', // Assuming string representation
        'target_amount': 500.0,
        'target_date': testDate.toIso8601String(),
        'color': 0xFF00FF00,
        'icon': 'cart',
        'created_at': testDate.toIso8601String(),
      };

      final c = Category.fromJson(json);
      expect(c, equals(category));
    });

    test('toJson returns correct map', () {
      final json = category.toJson();
      expect(json, {
        'id': 'cat_1',
        'name': 'Groceries',
        'category_group_id': 'group_1',
        'is_hidden': false,
        'sort_order': 1,
        'goal_type': 'monthlyFunding',
        'target_amount': 500.0,
        'target_date': testDate.toIso8601String(),
        'color': 0xFF00FF00,
        'icon': 'cart',
        'created_at': testDate.toIso8601String(),
      });
    });

    test('validate returns error for empty name', () {
      final invalidCat = category.copyWith(name: '');
      final errors = invalidCat.validate();
      expect(errors, contains('Category name cannot be empty'));
    });

    test('defaults are set correctly', () {
       const defaultCat = Category(id: '1', name: 'Test');
       expect(defaultCat.isHidden, false);
       expect(defaultCat.goalType, null);
    });
  });
}
