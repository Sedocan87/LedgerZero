import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/domain/services/category_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late CategoryService service;
  const savings = DefaultCategories.savingsGroup;
  final groupId = DeterministicId.defaultGroup(savings);

  setUp(() {
    t = TestDatabase();
    service = CategoryService(
      categoryRepository: t.categories,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
    );
  });

  tearDown(() => t.close());

  Future<List<String>> savingsCategoryNames() async =>
      (await t.categories.getAllCategories())
          .where((c) => c.categoryGroupId == groupId)
          .map((c) => c.name)
          .toList();

  test('new databases are seeded with Savings & Investments', () async {
    expect(await t.categories.getCategoryGroupById(groupId), isNotNull);
    expect(await savingsCategoryNames(), [
      'Cash Reserve',
      'Stocks & ETFs',
      'Crypto',
      'Bonds',
      'Retirement',
    ]);
  });

  group('addDefaultGroup (budgets created before the group existed)', () {
    setUp(() async {
      for (final c in await t.categories.getAllCategories()) {
        if (c.categoryGroupId == groupId) {
          await t.categories.deleteCategory(c.id);
        }
      }
      await t.categories.deleteCategoryGroup(groupId);
    });

    test('adds the group last, with localised names', () async {
      await service.addDefaultGroup(savings, (n) => 'de:$n');

      final groups = await t.categories.getAllCategoryGroups();
      final added = groups.singleWhere((g) => g.id == groupId);
      expect(added.name, 'de:$savings');
      final others = groups.where((g) => g.id != groupId);
      expect(
        others.every((g) => (g.sortOrder ?? 0) < added.sortOrder!),
        isTrue,
      );
      expect((await savingsCategoryNames()).first, 'de:Cash Reserve');
      expect(
        await t.categories.getCategoryById(
          DeterministicId.defaultCategory(savings, 'Crypto'),
        ),
        isNotNull,
      );
    });

    test('is idempotent and keeps renamed rows', () async {
      await service.addDefaultGroup(savings, (n) => n);
      final crypto = DeterministicId.defaultCategory(savings, 'Crypto');
      final renamed = (await t.categories.getCategoryById(crypto))!;
      await t.categories.updateCategory(renamed.copyWith(name: 'Bitcoin'));

      await service.addDefaultGroup(savings, (n) => n);

      expect((await savingsCategoryNames()).length, 5);
      expect((await t.categories.getCategoryById(crypto))!.name, 'Bitcoin');
    });

    test('rejects an unknown group', () {
      expect(
        () => service.addDefaultGroup('Nope', (n) => n),
        throwsArgumentError,
      );
    });
  });
}
