import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/category_groups.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, CategoryGroups])
class CategoriesDao extends DatabaseAccessor<AppDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(super.db);
}
