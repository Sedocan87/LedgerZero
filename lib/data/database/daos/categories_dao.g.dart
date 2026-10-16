// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_dao.dart';

// ignore_for_file: type=lint
mixin _$CategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoryGroupsTable get categoryGroups => attachedDatabase.categoryGroups;
  $CategoriesTable get categories => attachedDatabase.categories;
  CategoriesDaoManager get managers => CategoriesDaoManager(this);
}

class CategoriesDaoManager {
  final _$CategoriesDaoMixin _db;
  CategoriesDaoManager(this._db);
  $$CategoryGroupsTableTableManager get categoryGroups =>
      $$CategoryGroupsTableTableManager(
        _db.attachedDatabase,
        _db.categoryGroups,
      );
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
}
