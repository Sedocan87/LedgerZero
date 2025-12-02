import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';

void main() {
  const tCategory = Category(
    id: '1',
    name: 'Test Category',
    categoryGroupId: 'group1',
    isHidden: false,
    sortOrder: 1,
    goalType: GoalType.targetBalance,
    targetAmount: 100.0,
    color: 0xFF000000,
    icon: 'home',
  );

  test('should support value equality', () {
    expect(tCategory, equals(tCategory.copyWith()));
  });

  test('copyWith should update fields correctly', () {
    final updated = tCategory.copyWith(name: 'New Name', color: 0xFFFFFFFF);
    expect(updated.name, 'New Name');
    expect(updated.color, 0xFFFFFFFF);
    expect(updated.icon, tCategory.icon);
    expect(updated.goalType, tCategory.goalType);
  });

  test('should store color and icon correctly', () {
    expect(tCategory.color, 0xFF000000);
    expect(tCategory.icon, 'home');
  });

  test('fromJson should return a valid model', () {
    final Map<String, dynamic> jsonMap = {
      'id': '1',
      'name': 'Test Category',
      'category_group_id': 'group1',
      'is_hidden': false,
      'sort_order': 1,
      'goal_type': 'targetBalance',
      'target_amount': 100.0,
      'target_date': null,
      'color': 0xFF000000,
      'icon': 'home',
      'created_at': null,
    };
    final result = Category.fromJson(jsonMap);
    expect(result, tCategory);
  });

  test('toJson should return a JSON map containing the proper data', () {
    final result = tCategory.toJson();
    final expectedMap = {
      'id': '1',
      'name': 'Test Category',
      'category_group_id': 'group1',
      'is_hidden': false,
      'sort_order': 1,
      'goal_type': 'targetBalance',
      'target_amount': 100.0,
      'target_date': null,
      'color': 0xFF000000,
      'icon': 'home',
      'created_at': null,
    };
    expect(result, expectedMap);
  });

  test('validate should return error when name is empty', () {
    final invalidCategory = tCategory.copyWith(name: '');
    final result = invalidCategory.validate();
    expect(result, contains('Category name cannot be empty'));
  });
}
