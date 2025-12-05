import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/services/import/mint_data_mapper.dart';
import 'package:ledger_zero/services/import/mint_import_service.dart';

final mintMigrationServiceProvider = Provider<MintMigrationService>((ref) {
  return MintMigrationService(
    accountRepository: ref.watch(accountRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    payeeRepository: ref.watch(payeeRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});

class MintMigrationResult {
  final int transactionsImported;
  final int accountsCreated;
  final int categoriesCreated;
  final int payeesCreated;
  final int duplicatesSkipped;

  MintMigrationResult({
    this.transactionsImported = 0,
    this.accountsCreated = 0,
    this.categoriesCreated = 0,
    this.payeesCreated = 0,
    this.duplicatesSkipped = 0,
  });
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    this.isValid = true,
    this.errors = const [],
    this.warnings = const [],
  });
}

class MintMigrationService {
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final PayeeRepository _payeeRepository;
  final TransactionRepository _transactionRepository;
  final MintImportService _parser = MintImportService();
  final MintDataMapper _mapper = MintDataMapper();

  MintMigrationService({
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required PayeeRepository payeeRepository,
    required TransactionRepository transactionRepository,
  })  : _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _payeeRepository = payeeRepository,
        _transactionRepository = transactionRepository;

  Future<MintMigrationResult> importFile(
      String csvContent, {
        Function(double)? onProgress,
      }) async {
    try {
      onProgress?.call(0.1); // Parsing started

      // 1. Parse CSV
      final importData = _parser.parseCsvExport(csvContent);
      onProgress?.call(0.2); // Parsing done

      // 2. Map Data
      final existingCategories = await _categoryRepository.getAllCategories();
      final mappedData = _mapper.mapData(importData, existingCategories: existingCategories);
      onProgress?.call(0.3); // Mapping done

      // Validation
      final validation = _validateData(mappedData);
      if (!validation.isValid) {
        // If critical errors, stop?
        // For now, we log and proceed or throw?
        // Let's throw if errors exist.
        if (validation.errors.isNotEmpty) {
           throw Exception('Validation failed: ${validation.errors.join(", ")}');
        }
      }

      // 3. Deduplicate
      final existingTransactions = await _transactionRepository.getAllTransactions();
      final existingPayees = await _payeeRepository.getAllPayees();

      final deduplicationResult = _removeDuplicates(
          mappedData.transactions,
          existingTransactions,
          mappedData.payees,
          existingPayees
      );

      final transactionsToImport = deduplicationResult.uniqueTransactions;
      final skippedCount = deduplicationResult.duplicatesCount;

      // 4. Save Entities
      onProgress?.call(0.4); // Saving started

      // Save Accounts
      for (final account in mappedData.accounts) {
        await _accountRepository.createAccount(account);
      }

      // Save Categories and Groups
      for (final group in mappedData.categoryGroups) {
        await _categoryRepository.createCategoryGroup(group);
      }
      for (final category in mappedData.categories) {
        await _categoryRepository.createCategory(category);
      }

      // Save Payees
      for (final payee in mappedData.payees) {
        await _payeeRepository.createPayee(payee);
      }

      // Save Transactions
      if (transactionsToImport.isNotEmpty) {
         final chunks = _chunkList(transactionsToImport, 500);
         final totalChunks = chunks.length;
         for (var i = 0; i < totalChunks; i++) {
           await _transactionRepository.batchCreateTransactions(chunks[i]);
           final progress = 0.4 + (0.6 * ((i + 1) / totalChunks));
           onProgress?.call(progress);
         }
      }

      onProgress?.call(1.0);

      return MintMigrationResult(
        transactionsImported: transactionsToImport.length,
        accountsCreated: mappedData.accounts.length,
        categoriesCreated: mappedData.categories.length,
        payeesCreated: mappedData.payees.length,
        duplicatesSkipped: skippedCount,
      );

    } catch (e, stack) {
      Logger.error('Mint Migration Failed', e, stack);
      rethrow;
    }
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> result = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      result.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return result;
  }

  _DeduplicationResult _removeDuplicates(
      List<Transaction> newTransactions,
      List<Transaction> existingTransactions,
      List<Payee> newPayees,
      List<Payee> existingPayees,
      ) {
    // Create lookup for Payee Names
    final payeeMap = <String, String>{};
    for (final p in existingPayees) {
      payeeMap[p.id] = p.name;
    }
    for (final p in newPayees) {
      payeeMap[p.id] = p.name;
    }

    final existingHashes = existingTransactions.map((tx) => _generateTransactionHash(tx, payeeMap)).toSet();
    final uniqueTransactions = <Transaction>[];
    int duplicatesCount = 0;

    for (final tx in newTransactions) {
      final hash = _generateTransactionHash(tx, payeeMap);
      if (existingHashes.contains(hash)) {
        duplicatesCount++;
      } else {
        uniqueTransactions.add(tx);
        // Add to hash set to prevent duplicates within the import file itself
        existingHashes.add(hash);
      }
    }

    return _DeduplicationResult(uniqueTransactions, duplicatesCount);
  }

  ValidationResult _validateData(MintMappedData data) {
    final errors = <String>[];
    final warnings = <String>[];

    if (data.accounts.isEmpty) {
      errors.add('No accounts found in import data.');
    }
    if (data.transactions.isEmpty) {
      warnings.add('No transactions found in import data.');
    }

    // Check for future dates
    final now = DateTime.now();
    int futureTxCount = 0;
    for (final tx in data.transactions) {
      if (tx.date.isAfter(now.add(const Duration(days: 1)))) {
        futureTxCount++;
      }
    }
    if (futureTxCount > 0) {
      warnings.add('Found $futureTxCount transactions with future dates.');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  String _generateTransactionHash(Transaction tx, Map<String, String> payeeMap) {
    final dateStr = tx.date.toIso8601String().substring(0, 10);
    final amountStr = tx.amount.toStringAsFixed(2);
    // Use Payee Name if available, otherwise empty string (though practically should always be available for imported data)
    final payeeName = (tx.payeeId != null ? payeeMap[tx.payeeId!] : '')?.trim().toLowerCase() ?? '';

    // We use a pipe delimiter to avoid ambiguity
    return sha256.convert(utf8.encode('$dateStr|$amountStr|$payeeName')).toString();
  }
}

class _DeduplicationResult {
  final List<Transaction> uniqueTransactions;
  final int duplicatesCount;

  _DeduplicationResult(this.uniqueTransactions, this.duplicatesCount);
}
