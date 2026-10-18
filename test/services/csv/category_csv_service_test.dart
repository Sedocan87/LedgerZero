import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/csv/category_csv_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late CategoryCsvService service;

  setUp(() {
    t = TestDatabase();
    service = CategoryCsvService(
      categoryRepository: t.categories,
      unitOfWork: t.unitOfWork,
    );
  });

  tearDown(() => t.close());

  test('export then import round-trips without duplicates', () async {
    final groups = await t.categories.getAllCategoryGroups();
    final categories = await t.categories.getAllCategories();
    final csv = service.buildCsv(groups, categories);
    expect(csv.split('\n').first.trim(), 'Group,Category,Hidden');

    final result = await service.importCsv(csv);
    expect(result.categoriesCreated, 0);
    expect(result.groupsCreated, 0);
    expect(await t.categories.getAllCategories(), hasLength(categories.length));
  });

  test('imports new groups and categories (CRLF, BOM, hidden flag)', () async {
    const csv =
        '﻿Group,Category,Hidden\r\nHobbies,Climbing,false\r\n'
        'Hobbies,Old gear,true\r\n';
    final result = await service.importCsv(csv);
    expect(result.groupsCreated, 1);
    expect(result.categoriesCreated, 2);
    final hobbies = (await t.categories.getAllCategoryGroups()).firstWhere(
      (g) => g.name == 'Hobbies',
    );
    final created = (await t.categories.getAllCategories())
        .where((c) => c.categoryGroupId == hobbies.id)
        .toList();
    expect(created.map((c) => c.name), containsAll(['Climbing', 'Old gear']));
    expect(created.firstWhere((c) => c.name == 'Old gear').isHidden, isTrue);
  });

  test('neutralises spreadsheet formulas in names', () async {
    await service.importCsv('Group,Category\nTricks,=SUM(A1)\n');
    final groups = await t.categories.getAllCategoryGroups();
    final categories = await t.categories.getAllCategories();
    final csv = service.buildCsv(groups, categories);
    expect(csv, isNot(contains(',=SUM')));
  });

  test('rejects a file that is not a category list', () async {
    expect(
      () => service.importCsv(''),
      throwsA(isA<CategoryCsvFormatException>()),
    );
    expect(
      () => service.importCsv('just one column\n'),
      throwsA(isA<CategoryCsvFormatException>()),
    );
  });

  test(
    'semicolon-separated files and Windows-1252 bytes are read (I13)',
    () async {
      // "Gruppe;Kategorie" as a German spreadsheet saves it, with an umlaut
      // in Windows-1252 (0xE4 = ä).
      final bytes = [
        ...'Group;Category;Hidden\nFreizeit;B'.codeUnits,
        0xE4,
        ...'der;false\nFreizeit;Kino;true\n'.codeUnits,
      ];
      final result = await service.importCsvBytes(bytes);
      expect(result.groupsCreated, 1);
      expect(result.categoriesCreated, 2);
      final names = (await t.categories.getAllCategories()).map((c) => c.name);
      expect(names, containsAll(['Bäder', 'Kino']));
    },
  );
}
