import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';

void main() {
  group('CategoryGroup', () {
    test('should instantiate correctly', () {
      final now = DateTime.now();
      final categoryGroup = CategoryGroup(
        id: '1',
        name: 'Monthly Bills',
        sortOrder: 1,
        createdAt: now,
      );

      expect(categoryGroup.id, '1');
      expect(categoryGroup.name, 'Monthly Bills');
      expect(categoryGroup.sortOrder, 1);
      expect(categoryGroup.createdAt, now);
    });

    test('should use default values', () {
      const categoryGroup = CategoryGroup(
        id: '2',
        name: 'Everyday Expenses',
      );

      expect(categoryGroup.id, '2');
      expect(categoryGroup.name, 'Everyday Expenses');
      expect(categoryGroup.sortOrder, isNull);
      expect(categoryGroup.createdAt, isNull);
    });

    test('should support serialization', () {
      final now = DateTime(2023, 10, 1);
      final categoryGroup = CategoryGroup(
        id: '1',
        name: 'Monthly Bills',
        sortOrder: 1,
        createdAt: now,
      );

      final json = categoryGroup.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'Monthly Bills');
      expect(json['sort_order'], 1);
      expect(json['created_at'], now.toIso8601String());

      final fromJson = CategoryGroup.fromJson(json);
      expect(fromJson.id, categoryGroup.id);
      expect(fromJson.name, categoryGroup.name);
      expect(fromJson.sortOrder, categoryGroup.sortOrder);
      expect(fromJson.createdAt, categoryGroup.createdAt);
    });

    test('should handle missing optional fields during serialization', () {
      final json = {
        'id': '1',
        'name': 'Monthly Bills',
      };

      final categoryGroup = CategoryGroup.fromJson(json);
      expect(categoryGroup.id, '1');
      expect(categoryGroup.name, 'Monthly Bills');
      expect(categoryGroup.sortOrder, isNull);
      expect(categoryGroup.createdAt, isNull);
    });

    test('should support equality', () {
      final now = DateTime(2023, 10, 1);
      final categoryGroup1 = CategoryGroup(
        id: '1',
        name: 'Monthly Bills',
        sortOrder: 1,
        createdAt: now,
      );

      final categoryGroup2 = CategoryGroup(
        id: '1',
        name: 'Monthly Bills',
        sortOrder: 1,
        createdAt: now,
      );

      const categoryGroup3 = CategoryGroup(
        id: '2',
        name: 'Everyday Expenses',
      );

      // Reflexive
      expect(categoryGroup1, equals(categoryGroup1));

      // Symmetric
      expect(categoryGroup1, equals(categoryGroup2));
      expect(categoryGroup2, equals(categoryGroup1));

      // HashCode
      expect(categoryGroup1.hashCode, equals(categoryGroup2.hashCode));

      // Not Equal
      expect(categoryGroup1, isNot(equals(categoryGroup3)));
      expect(categoryGroup1, isNot(equals('Not a CategoryGroup')));
      expect(categoryGroup1, isNot(equals(null)));
    });
  });
}
