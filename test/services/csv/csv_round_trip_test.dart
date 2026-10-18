// CSV export -> CSV import round trip: exporting every account of a ledger
// and importing the files into a fresh database (same accounts, same
// budgets, categories picked from the file's Category column as the user
// would in the review step) gives identical balances, available amounts
// and To Be Budgeted.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_platform_file.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:ledger_zero/services/import/transaction_import_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/test_database.dart';

void main() {
  late TestDatabase source;
  late TestDatabase target;
  final month = sampleLedgerMonth;

  setUp(() async {
    source = TestDatabase();
    target = TestDatabase();
    await seedSampleLedger(source);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('export every account, import into a fresh ledger: identical '
      'balances, available and TBB', () async {
    final payees = await source.payees.getAllPayees();
    final categories = await source.categories.getAllCategories();
    final targetCategories = {
      for (final c in await target.categories.getAllCategories()) c.name: c.id,
    };
    final csvService = CsvImportService();
    final importer = TransactionImportService(
      transactionRepository: target.transactions,
      payeeRepository: target.payees,
      ruleMatchingService: RuleMatchingService(
        target.payees,
        target.transactions,
        target.rules,
      ),
      unitOfWork: target.unitOfWork,
    );

    for (final account in await source.accounts.getAllAccounts()) {
      final csv = TransactionExportService().buildCsv(
        transactions: await source.transactions.getTransactionsByAccount(
          account.id,
        ),
        payeeNames: {for (final p in payees) p.id: p.name},
        categoryNames: {for (final c in categories) c.id: c.name},
        accountNames: {account.id: account.name},
      );

      final bytes = Uint8List.fromList(utf8.encode(csv));
      final data = await csvService.parseCsvFile(
        MemoryPlatformFile(name: '${account.name}.csv', bytes: bytes),
      );
      final mapping = {
        'Date': 'Date',
        'Amount': 'Amount',
        'Payee': 'Payee',
        'Memo': 'Memo',
      };
      expect(
        csvService
            .validateCsvData(
              data: data,
              columnMapping: mapping,
              dateFormat: 'yyyy-MM-dd',
              decimalSeparator: '.',
            )
            .isValid,
        isTrue,
      );
      final rows = csvService.convertCsvToTransactions(
        data: data,
        columnMapping: mapping,
        dateFormat: 'yyyy-MM-dd',
        decimalSeparator: '.',
        outflowIsNegative: true,
      );
      // The review step: the user picks the category named in the file.
      final h = data.headers;
      final categoryOf = {
        for (final r in data.rows)
          '${r[h.indexOf('Date')]}|${r[h.indexOf('Amount')]}|'
                  '${r[h.indexOf('Payee')]}':
              '${r[h.indexOf('Category')]}',
      };
      expect(rows, hasLength(data.rows.length));
      expect(categoryOf, hasLength(data.rows.length), reason: 'unique rows');
      for (final row in rows) {
        final day = row.date.toIso8601String().substring(0, 10);
        final amount = Money.toDecimalString(row.amount);
        final name = categoryOf['$day|$amount|${row.payeeName}']!;
        row.categoryId = name.isEmpty ? null : targetCategories[name];
      }

      final created = await target.addAccount(
        name: account.name,
        type: account.type,
        startingBalance: account.startingBalance,
      );
      await importer.importTransactions(rows, created.id);
    }
    for (final budget in await source.budgets.getBudgetsForMonth('2024-03')) {
      final name = categories.firstWhere((c) => c.id == budget.categoryId).name;
      await target.budgeting.setCategoryBudgetedAmount(
        targetCategories[name]!,
        budget.budgeted,
        month,
      );
    }

    expect(
      await ledgerFingerprint(target, month),
      await ledgerFingerprint(source, month),
    );
    await expectLedgerInvariant(target, month);
  });

  test('a split is exported as its lines, with the parent payee', () async {
    final checking = (await source.accounts.getAllAccounts()).firstWhere(
      (a) => a.name == 'Checking',
    );
    final payees = await source.payees.getAllPayees();
    final csv = TransactionExportService().buildCsv(
      transactions: await source.transactions.getTransactionsByAccount(
        checking.id,
      ),
      payeeNames: {for (final p in payees) p.id: p.name},
    );
    final lines = csv.split('\r\n').where((l) => l.contains('2024-03-06'));
    expect(lines.map((l) => l.split(',')[5]).toList()..sort(), [
      '-30.00',
      '-60.00',
    ]);
    expect(lines.every((l) => l.contains('Department Store')), isTrue);
  });

  test('one file for every account, imported with "account from file": '
      'transfers are linked again, cleared states, categories and a '
      'sanitised payee survive', () async {
    // Extras the sample ledger lacks: a payee the sanitiser must quote, an
    // uncleared and a reconciled row.
    final checking = (await source.accounts.getAllAccounts()).firstWhere(
      (a) => a.name == 'Checking',
    );
    await source.payees.createPayee(const Payee(id: 'p-fees', name: '-Fees'));
    await source.addTransaction(
      accountId: checking.id,
      amount: -500,
      date: DateTime.utc(2024, 3, 7),
      payeeId: 'p-fees',
      cleared: TransactionClearStatus.uncleared,
    );
    await source.addTransaction(
      accountId: checking.id,
      amount: -600,
      date: DateTime.utc(2024, 3, 8),
      payeeId: 'p-fees',
      cleared: TransactionClearStatus.reconciled,
    );

    final payees = await source.payees.getAllPayees();
    final categories = await source.categories.getAllCategories();
    final accounts = await source.accounts.getAllAccounts();
    final csv = TransactionExportService().buildCsv(
      transactions: await source.transactions.getAllTransactions(),
      payeeNames: {for (final p in payees) p.id: p.name},
      categoryNames: {for (final c in categories) c.id: c.name},
      accountNames: {for (final a in accounts) a.id: a.name},
    );
    expect(csv, contains("'-Fees"), reason: 'the sanitiser quoted it');

    final csvService = CsvImportService();
    final data = await csvService.parseCsvFile(
      MemoryPlatformFile(name: 'all.csv', bytes: utf8.encode(csv)),
    );
    final mapping = CsvImportService.autoMapColumns(data.headers);
    expect(mapping[CsvField.transfer], 'Transfer');
    expect(mapping[CsvField.account], 'Account');
    expect(mapping[CsvField.cleared], 'Cleared');
    expect(
      csvService
          .validateCsvData(
            data: data,
            columnMapping: mapping,
            dateFormat: 'yyyy-MM-dd',
            decimalSeparator: '.',
          )
          .isValid,
      isTrue,
    );
    final rows = csvService.convertCsvToTransactions(
      data: data,
      columnMapping: mapping,
      dateFormat: 'yyyy-MM-dd',
      decimalSeparator: '.',
      outflowIsNegative: true,
    );
    csvService.assignCategories(
      imported: rows,
      categories: await target.categories.getAllCategories(),
      groups: await target.categories.getAllCategoryGroups(),
    );
    expect(rows.where((r) => r.hasUnmatchedCategory), isEmpty);
    expect(rows.where((r) => r.payeeName == '-Fees'), hasLength(2));

    final targetIds = <String, String>{};
    for (final account in accounts) {
      final created = await target.addAccount(
        name: account.name,
        type: account.type,
        startingBalance: account.startingBalance,
      );
      targetIds[CsvImportService.normalizePayee(account.name)] = created.id;
    }
    for (final row in rows) {
      row.accountId =
          targetIds[CsvImportService.normalizePayee(row.accountName!)];
    }
    final importer = TransactionImportService(
      transactionRepository: target.transactions,
      payeeRepository: target.payees,
      ruleMatchingService: RuleMatchingService(
        target.payees,
        target.transactions,
        target.rules,
      ),
      unitOfWork: target.unitOfWork,
    );
    await importer.importTransactions(
      rows,
      targetIds.values.first,
      accountIdsByName: targetIds,
    );
    for (final budget in await source.budgets.getBudgetsForMonth('2024-03')) {
      final name = categories.firstWhere((c) => c.id == budget.categoryId).name;
      final id = (await target.categories.getAllCategories())
          .firstWhere((c) => c.name == name)
          .id;
      await target.budgeting.setCategoryBudgetedAmount(
        id,
        budget.budgeted,
        month,
      );
    }

    expect(
      await ledgerFingerprint(target, month),
      await ledgerFingerprint(source, month),
    );
    await expectLedgerInvariant(target, month);

    final imported = await target.transactions.getAllTransactions();
    final legs = imported.where((t) => t.transferAccountId != null).toList();
    expect(legs, hasLength(2));
    expect(legs[0].transferTransactionId, legs[1].id);
    expect(legs[1].transferTransactionId, legs[0].id);
    expect(legs.every((l) => l.payeeId == null), isTrue);
    // Cleared states come back as exported (split parents are not
    // exported; their lines carry the parent's state).
    final sourceRows = await source.transactions.getAllTransactions();
    final parents = {for (final t in sourceRows) t.parentTransactionId};
    expect(
      imported.map((t) => '${t.amount}|${t.cleared.name}'),
      unorderedEquals([
        for (final t in sourceRows)
          if (!parents.contains(t.id)) '${t.amount}|${t.cleared.name}',
      ]),
    );
    final targetPayees = await target.payees.getAllPayees();
    expect(targetPayees.map((p) => p.name), contains('-Fees'));
    expect(targetPayees.map((p) => p.name), isNot(contains("'-Fees")));
  });
}
