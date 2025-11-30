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
  });
}
