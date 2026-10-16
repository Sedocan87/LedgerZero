// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_transactions_dao.dart';

// ignore_for_file: type=lint
mixin _$ScheduledTransactionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoryGroupsTable get categoryGroups => attachedDatabase.categoryGroups;
  $CategoriesTable get categories => attachedDatabase.categories;
  $PayeesTable get payees => attachedDatabase.payees;
  $ScheduledTransactionsTable get scheduledTransactions =>
      attachedDatabase.scheduledTransactions;
  ScheduledTransactionsDaoManager get managers =>
      ScheduledTransactionsDaoManager(this);
}

class ScheduledTransactionsDaoManager {
  final _$ScheduledTransactionsDaoMixin _db;
  ScheduledTransactionsDaoManager(this._db);
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
  $$ScheduledTransactionsTableTableManager get scheduledTransactions =>
      $$ScheduledTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.scheduledTransactions,
      );
}
