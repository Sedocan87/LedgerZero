import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';

void main() {
  group('Category', () {
    test('should instantiate correctly', () {
      final now = DateTime.now();
      final category = Category(
        id: '1',
        name: 'Groceries',
        categoryGroupId: 'group1',
        isHidden: true,
        sortOrder: 1,
        createdAt: now,
      );

      expect(category.id, '1');
      expect(category.name, 'Groceries');
      expect(category.categoryGroupId, 'group1');
      expect(category.isHidden, true);
      expect(category.sortOrder, 1);
      expect(category.createdAt, now);
    });

    test('should use default values', () {
      const category = Category(
        id: '2',
        name: 'Salary',
      );

      expect(category.id, '2');
      expect(category.name, 'Salary');
      expect(category.categoryGroupId, isNull);
      expect(category.isHidden, false);
      expect(category.sortOrder, isNull);
      expect(category.createdAt, isNull);
    });

    test('should support serialization', () {
      final now = DateTime(2023, 10, 1);
      final category = Category(
        id: '1',
        name: 'Groceries',
        categoryGroupId: 'group1',
        isHidden: true,
        sortOrder: 1,
        createdAt: now,
      );

      final json = category.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'Groceries');
      expect(json['category_group_id'], 'group1');
      expect(json['is_hidden'], true);
      expect(json['sort_order'], 1);
      expect(json['created_at'], now.toIso8601String());

      final fromJson = Category.fromJson(json);
      expect(fromJson.id, category.id);
      expect(fromJson.name, category.name);
      expect(fromJson.categoryGroupId, category.categoryGroupId);
      expect(fromJson.isHidden, category.isHidden);
      expect(fromJson.sortOrder, category.sortOrder);
      expect(fromJson.createdAt, category.createdAt);
    });
  });
}
