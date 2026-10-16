// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounts_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoryGroupsTable get categoryGroups => attachedDatabase.categoryGroups;
  $CategoriesTable get categories => attachedDatabase.categories;
  $PayeesTable get payees => attachedDatabase.payees;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  AccountsDaoManager get managers => AccountsDaoManager(this);
}

class AccountsDaoManager {
  final _$AccountsDaoMixin _db;
  AccountsDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoryGroupsTableTableManager get categoryGroups =>
      $$CategoryGroupsTableTableManager(
        _db.attachedDatabase,
        _db.categoryGroups,
      );
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$PayeesTableTableManager get payees =>
      $$PayeesTableTableManager(_db.attachedDatabase, _db.payees);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
}
