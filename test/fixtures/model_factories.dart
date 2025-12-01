import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

/// Creates a test [Account] with default values.
Account createTestAccount({
  String id = 'acc1',
  String name = 'Test Account',
  AccountType type = AccountType.checking,
  String currency = 'USD',
  double startingBalance = 0.0,
  double currentBalance = 0.0,
  bool isClosed = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    currency: currency,
    startingBalance: startingBalance,
    currentBalance: currentBalance,
    isClosed: isClosed,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

/// Creates a test [Budget] with default values.
Budget createTestBudget({
  String id = 'budget1',
  String? categoryId,
  String month = '2023-10',
  double budgeted = 0.0,
  double activity = 0.0,
  double available = 0.0,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Budget(
    id: id,
    categoryId: categoryId,
    month: month,
    budgeted: budgeted,
    activity: activity,
    available: available,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

/// Creates a test [Category] with default values.
Category createTestCategory({
  String id = 'cat1',
  String name = 'Test Category',
  String? categoryGroupId,
  bool isHidden = false,
  int? sortOrder,
  DateTime? createdAt,
}) {
  return Category(
    id: id,
    name: name,
    categoryGroupId: categoryGroupId,
    isHidden: isHidden,
    sortOrder: sortOrder,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Creates a test [CategoryGroup] with default values.
CategoryGroup createTestCategoryGroup({
  String id = 'group1',
  String name = 'Test Group',
  int? sortOrder,
  DateTime? createdAt,
}) {
  return CategoryGroup(
    id: id,
    name: name,
    sortOrder: sortOrder,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Creates a test [Payee] with default values.
Payee createTestPayee({
  String id = 'payee1',
  String name = 'Test Payee',
  String? autoCategoryId,
  DateTime? createdAt,
}) {
  return Payee(
    id: id,
    name: name,
    autoCategoryId: autoCategoryId,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Creates a test [ScheduledTransaction] with default values.
ScheduledTransaction createTestScheduledTransaction({
  String id = 'sched1',
  String? accountId,
  String? payeeId,
  String? categoryId,
  double? amount,
  RecurrenceFrequency? frequency,
  DateTime? nextDate,
  DateTime? endDate,
  bool autoApprove = false,
  DateTime? createdAt,
}) {
  return ScheduledTransaction(
    id: id,
    accountId: accountId,
    payeeId: payeeId,
    categoryId: categoryId,
    amount: amount,
    frequency: frequency,
    nextDate: nextDate,
    endDate: endDate,
    autoApprove: autoApprove,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Creates a test [Transaction] with default values.
Transaction createTestTransaction({
  String id = 'tx1',
  String accountId = 'acc1',
  DateTime? date,
  double amount = -10.0,
  String? payeeId,
  String? categoryId,
  String? memo,
  TransactionClearStatus cleared = TransactionClearStatus.uncleared,
  bool approved = true,
  bool isDeleted = false,
  String? transferAccountId,
  String? transferTransactionId,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Transaction(
    id: id,
    accountId: accountId,
    date: date ?? DateTime.now(),
    amount: amount,
    payeeId: payeeId,
    categoryId: categoryId,
    memo: memo,
    cleared: cleared,
    approved: approved,
    isDeleted: isDeleted,
    transferAccountId: transferAccountId,
    transferTransactionId: transferTransactionId,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
  );
}
