// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payees_dao.dart';

// ignore_for_file: type=lint
mixin _$PayeesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoryGroupsTable get categoryGroups => attachedDatabase.categoryGroups;
  $CategoriesTable get categories => attachedDatabase.categories;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $PayeesTable get payees => attachedDatabase.payees;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  PayeesDaoManager get managers => PayeesDaoManager(this);
}

class PayeesDaoManager {
  final _$PayeesDaoMixin _db;
  PayeesDaoManager(this._db);
  $$CategoryGroupsTableTableManager get categoryGroups =>
      $$CategoryGroupsTableTableManager(
        _db.attachedDatabase,
        _db.categoryGroups,
      );
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$PayeesTableTableManager get payees =>
      $$PayeesTableTableManager(_db.attachedDatabase, _db.payees);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
}
