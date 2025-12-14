import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

class CreateTransactionAction implements ReversibleAction {
  final TransactionRepository repository;
  final Transaction transaction;

  CreateTransactionAction(this.repository, this.transaction);

  @override
  Future<void> redo() async {
    await repository.createTransaction(transaction);
  }

  @override
  Future<void> undo() async {
    await repository.deleteTransaction(transaction.id);
  }
}

class UpdateTransactionAction implements ReversibleAction {
  final TransactionRepository repository;
  final Transaction oldTransaction;
  final Transaction newTransaction;

  UpdateTransactionAction(
    this.repository,
    this.oldTransaction,
    this.newTransaction,
  );

  @override
  Future<void> redo() async {
    await repository.updateTransaction(newTransaction);
  }

  @override
  Future<void> undo() async {
    await repository.updateTransaction(oldTransaction);
  }
}

class DeleteTransactionAction implements ReversibleAction {
  final TransactionRepository repository;
  final Transaction transaction;

  DeleteTransactionAction(this.repository, this.transaction);

  @override
  Future<void> redo() async {
    await repository.deleteTransaction(transaction.id);
  }

  @override
  Future<void> undo() async {
    // We need to restore it.
    // Since deleteTransaction performs soft delete, we can update isDeleted to false.
    await repository.updateTransaction(transaction.copyWith(isDeleted: false));
  }
}

class BatchDeleteTransactionsAction implements ReversibleAction {
  final TransactionRepository repository;
  final List<Transaction> transactions;

  BatchDeleteTransactionsAction(this.repository, this.transactions);

  @override
  Future<void> redo() async {
    await repository.batchDeleteTransactions(
      transactions.map((t) => t.id).toList(),
    );
  }

  @override
  Future<void> undo() async {
    final restored = transactions
        .map((t) => t.copyWith(isDeleted: false))
        .toList();
    await repository.batchUpdateTransactions(restored);
  }
}

class BatchUpdateTransactionsAction implements ReversibleAction {
  final TransactionRepository repository;
  final List<Transaction> oldTransactions;
  final List<Transaction> newTransactions;

  BatchUpdateTransactionsAction(
    this.repository,
    this.oldTransactions,
    this.newTransactions,
  );

  @override
  Future<void> redo() async {
    await repository.batchUpdateTransactions(newTransactions);
  }

  @override
  Future<void> undo() async {
    await repository.batchUpdateTransactions(oldTransactions);
  }
}

class CreateTransferAction implements ReversibleAction {
  final TransactionRepository repository;
  final Transaction source;
  final Transaction destination;

  CreateTransferAction(this.repository, this.source, this.destination);

  @override
  Future<void> redo() async {
    await repository.createTransferTransaction(source, destination);
  }

  @override
  Future<void> undo() async {
    await repository.deleteLinkedTransaction(source.id);
  }
}

class CreateSplitTransactionAction implements ReversibleAction {
  final TransactionRepository repository;
  final Transaction parent;
  final List<Transaction> children;

  CreateSplitTransactionAction(this.repository, this.parent, this.children);

  @override
  Future<void> redo() async {
    await repository.createSplitTransaction(parent, children);
  }

  @override
  Future<void> undo() async {
    await repository.deleteLinkedTransaction(parent.id);
  }
}

class DeleteLinkedTransactionAction implements ReversibleAction {
  final TransactionRepository repository;
  final Transaction primaryTransaction;
  final Transaction? relatedTransaction;
  final List<Transaction> children;

  DeleteLinkedTransactionAction(
    this.repository,
    this.primaryTransaction, {
    this.relatedTransaction,
    this.children = const [],
  });

  @override
  Future<void> redo() async {
    await repository.deleteLinkedTransaction(primaryTransaction.id);
  }

  @override
  Future<void> undo() async {
    await repository.updateTransaction(
      primaryTransaction.copyWith(isDeleted: false),
    );
    if (relatedTransaction != null) {
      await repository.updateTransaction(
        relatedTransaction!.copyWith(isDeleted: false),
      );
    }
    if (children.isNotEmpty) {
      final restoredChildren = children
          .map((c) => c.copyWith(isDeleted: false))
          .toList();
      await repository.batchUpdateTransactions(restoredChildren);
    }
  }
}
