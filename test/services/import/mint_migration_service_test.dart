import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/import/mint_migration_service.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

// Mocks
class MockAccountRepository extends Mock implements AccountRepository {
  @override
  Future<void> createAccount(Account? account) => super.noSuchMethod(Invocation.method(#createAccount, [account]), returnValue: Future.value(), returnValueForMissingStub: Future.value());
}
class MockCategoryRepository extends Mock implements CategoryRepository {
    @override
  Future<List<Category>> getAllCategories() => super.noSuchMethod(Invocation.method(#getAllCategories, []), returnValue: Future.value(<Category>[]), returnValueForMissingStub: Future.value(<Category>[]));
    @override
  Future<void> createCategory(Category? category) => super.noSuchMethod(Invocation.method(#createCategory, [category]), returnValue: Future.value(), returnValueForMissingStub: Future.value());
    @override
  Future<void> createCategoryGroup(var group) => super.noSuchMethod(Invocation.method(#createCategoryGroup, [group]), returnValue: Future.value(), returnValueForMissingStub: Future.value());

}
class MockPayeeRepository extends Mock implements PayeeRepository {
  @override
  Future<List<Payee>> getAllPayees() => super.noSuchMethod(Invocation.method(#getAllPayees, []), returnValue: Future.value(<Payee>[]), returnValueForMissingStub: Future.value(<Payee>[]));
    @override
  Future<void> createPayee(Payee? payee) => super.noSuchMethod(Invocation.method(#createPayee, [payee]), returnValue: Future.value(), returnValueForMissingStub: Future.value());

}
class MockTransactionRepository extends Mock implements TransactionRepository {
  @override
  Future<List<Transaction>> getAllTransactions() => super.noSuchMethod(Invocation.method(#getAllTransactions, []), returnValue: Future.value(<Transaction>[]), returnValueForMissingStub: Future.value(<Transaction>[]));
  @override
  Future<void> batchCreateTransactions(List<Transaction>? transactions) => super.noSuchMethod(Invocation.method(#batchCreateTransactions, [transactions]), returnValue: Future.value(), returnValueForMissingStub: Future.value());
}

void main() {
  group('MintMigrationService', () {
    late MintMigrationService service;
    late MockAccountRepository accountRepo;
    late MockCategoryRepository categoryRepo;
    late MockPayeeRepository payeeRepo;
    late MockTransactionRepository transactionRepo;

    setUp(() {
      accountRepo = MockAccountRepository();
      categoryRepo = MockCategoryRepository();
      payeeRepo = MockPayeeRepository();
      transactionRepo = MockTransactionRepository();

      service = MintMigrationService(
        accountRepository: accountRepo,
        categoryRepository: categoryRepo,
        payeeRepository: payeeRepo,
        transactionRepository: transactionRepo,
      );
    });

    test('should import valid Mint CSV', () async {
      const csv = '''"Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
"6/09/2020","Safeway","Safeway Store","45.50","debit","Groceries","Chase Checking","",""''';

      when(categoryRepo.getAllCategories()).thenAnswer((_) async => []);
      when(transactionRepo.getAllTransactions()).thenAnswer((_) async => []);
      when(payeeRepo.getAllPayees()).thenAnswer((_) async => []);

      final result = await service.importFile(csv);

      expect(result.transactionsImported, 1);
      expect(result.accountsCreated, 1);
      expect(result.categoriesCreated, 1); // 1 new category
      verify(accountRepo.createAccount(any)).called(1);
      verify(transactionRepo.batchCreateTransactions(any)).called(1);
    });

    test('should detect duplicates when payee matches', () async {
       const csv = '''"Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
"6/09/2020","Safeway","Safeway Store","45.50","debit","Groceries","Chase Checking","",""''';

       // Existing Payee
       final existingPayee = Payee(id: 'p1', name: 'Safeway', createdAt: DateTime.now());

       // Existing transaction with same Date, Amount, and Payee
       final existingTx = Transaction(
         id: '1',
         accountId: 'acc1',
         date: DateTime(2020, 6, 9),
         amount: -45.50, // Debit is negative
         payeeId: 'p1',
         categoryId: 'c1',
         createdAt: DateTime.now(),
         updatedAt: DateTime.now(),
       );

       when(categoryRepo.getAllCategories()).thenAnswer((_) async => []);
       when(transactionRepo.getAllTransactions()).thenAnswer((_) async => [existingTx]);
       when(payeeRepo.getAllPayees()).thenAnswer((_) async => [existingPayee]);

       final result = await service.importFile(csv);

       expect(result.transactionsImported, 0); // Should be deduplicated
       expect(result.duplicatesSkipped, 1);
       verifyNever(transactionRepo.batchCreateTransactions(any));
    });

    test('should NOT deduplicate if payee differs', () async {
       const csv = '''"Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
"6/09/2020","Safeway","Safeway Store","45.50","debit","Groceries","Chase Checking","",""''';

       // Existing Payee
       final existingPayee = Payee(id: 'p1', name: 'Walmart', createdAt: DateTime.now());

       // Existing transaction with same Date, Amount, BUT Different Payee
       final existingTx = Transaction(
         id: '1',
         accountId: 'acc1',
         date: DateTime(2020, 6, 9),
         amount: -45.50,
         payeeId: 'p1',
         categoryId: 'c1',
         createdAt: DateTime.now(),
         updatedAt: DateTime.now(),
       );

       when(categoryRepo.getAllCategories()).thenAnswer((_) async => []);
       when(transactionRepo.getAllTransactions()).thenAnswer((_) async => [existingTx]);
       when(payeeRepo.getAllPayees()).thenAnswer((_) async => [existingPayee]);

       final result = await service.importFile(csv);

       expect(result.transactionsImported, 1); // Should NOT be deduplicated
       expect(result.duplicatesSkipped, 0);
       verify(transactionRepo.batchCreateTransactions(any)).called(1);
    });

    test('should map to existing categories', () async {
       const csv = '''"Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
"6/09/2020","Safeway","Safeway Store","45.50","debit","Groceries","Chase Checking","",""''';

       const existingCategory = Category(
         id: 'cat_groceries',
         name: 'Groceries',
         categoryGroupId: 'group1',
         goalType: null,
         targetAmount: 0,
       );

       when(categoryRepo.getAllCategories()).thenAnswer((_) async => [existingCategory]);
       when(transactionRepo.getAllTransactions()).thenAnswer((_) async => []);
       when(payeeRepo.getAllPayees()).thenAnswer((_) async => []);

       final result = await service.importFile(csv);

       // Should not create new category for Groceries
       expect(result.categoriesCreated, 0);
       expect(result.transactionsImported, 1);
    });
  });
}
