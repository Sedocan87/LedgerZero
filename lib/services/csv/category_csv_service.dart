import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/services/export/csv_sanitizer.dart';
import 'package:uuid/uuid.dart';

/// The CSV is empty or has fewer than two columns (group, category).
class CategoryCsvFormatException implements Exception {
  const CategoryCsvFormatException();
}

class CategoryCsvImportResult {
  const CategoryCsvImportResult({
    required this.groupsCreated,
    required this.categoriesCreated,
  });

  final int groupsCreated;
  final int categoriesCreated;
}

/// Category list export/import as CSV with the columns
/// `Group, Category, Hidden`.
class CategoryCsvService {
  CategoryCsvService({
    required this._categoryRepository,
    required this._unitOfWork,
    this._uuid = const Uuid(),
  });

  final CategoryRepository _categoryRepository;
  final UnitOfWork _unitOfWork;
  final Uuid _uuid;

  static const header = ['Group', 'Category', 'Hidden'];

  /// The CSV text for [groups] (in order) and their [categories]. Names are
  /// user text: quoted properly and neutralised against spreadsheet
  /// formulas.
  String buildCsv(List<CategoryGroup> groups, List<Category> categories) {
    final rows = <List<Object?>>[
      header,
      for (final group in groups)
        for (final category in categories.where(
          (c) => c.categoryGroupId == group.id,
        ))
          [group.name, category.name, CsvLiteral('${category.isHidden}')],
    ];
    return const ListToCsvConverter().convert(CsvSanitizer.rows(rows));
  }

  /// Creates the groups and categories of [content] that do not exist yet
  /// (matched by name, case-insensitively, categories within their group),
  /// in one unit of work. A header row is optional; without one the columns
  /// are group, category, hidden.
  Future<CategoryCsvImportResult> importCsv(String content) async {
    final normalized = content.replaceFirst('﻿', '').replaceAll('\r\n', '\n');
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(normalized).where((r) => r.any((c) => '$c'.trim().isNotEmpty));
    if (rows.isEmpty || rows.first.length < 2) {
      throw const CategoryCsvFormatException();
    }

    final first = [for (final c in rows.first) '$c'.trim().toLowerCase()];
    final hasHeader = first.contains('group') && first.contains('category');
    final groupIdx = hasHeader ? first.indexOf('group') : 0;
    final catIdx = hasHeader ? first.indexOf('category') : 1;
    final hiddenIdx = hasHeader ? first.indexOf('hidden') : 2;

    return _unitOfWork.run(() async {
      final groups = [...await _categoryRepository.getAllCategoryGroups()];
      final categories = [...await _categoryRepository.getAllCategories()];
      final now = DateTime.now().toUtc();
      var groupsCreated = 0;
      var categoriesCreated = 0;

      for (final row in rows.skip(hasHeader ? 1 : 0)) {
        if (row.length <= groupIdx || row.length <= catIdx) {
          continue;
        }
        final groupName = '${row[groupIdx]}'.trim();
        final categoryName = '${row[catIdx]}'.trim();
        if (groupName.isEmpty || categoryName.isEmpty) {
          continue;
        }
        final hiddenText = hiddenIdx >= 0 && row.length > hiddenIdx
            ? '${row[hiddenIdx]}'.trim().toLowerCase()
            : '';
        final hidden = const {'true', '1', 'yes'}.contains(hiddenText);

        var group = groups
            .where((g) => g.name.toLowerCase() == groupName.toLowerCase())
            .firstOrNull;
        if (group == null) {
          group = CategoryGroup(
            id: _uuid.v4(),
            name: groupName,
            sortOrder: groups.length,
            createdAt: now,
          );
          await _categoryRepository.createCategoryGroup(group);
          groups.add(group);
          groupsCreated++;
        }

        final groupId = group.id;
        final exists = categories.any(
          (c) =>
              c.categoryGroupId == groupId &&
              c.name.toLowerCase() == categoryName.toLowerCase(),
        );
        if (!exists) {
          final category = Category(
            id: _uuid.v4(),
            name: categoryName,
            categoryGroupId: groupId,
            isHidden: hidden,
            sortOrder: categories
                .where((c) => c.categoryGroupId == groupId)
                .length,
            createdAt: now,
          );
          await _categoryRepository.createCategory(category);
          categories.add(category);
          categoriesCreated++;
        }
      }
      return CategoryCsvImportResult(
        groupsCreated: groupsCreated,
        categoriesCreated: categoriesCreated,
      );
    });
  }
}

final categoryCsvServiceProvider = Provider<CategoryCsvService>((ref) {
  return CategoryCsvService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
  );
});
