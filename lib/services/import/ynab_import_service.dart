import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/services/csv/decimal_separator_inference.dart';

/// Why a YNAB export could not be parsed.
enum YnabImportFailure {
  /// The nYNAB Register.csv lacks required columns (listed in
  /// [YnabImportException.detail]).
  missingRegisterColumns,

  /// The selected folder is not a readable YNAB4 budget bundle.
  invalidYnab4Folder,

  /// No supported date format fits every Register.csv date;
  /// [YnabImportException.detail] is the first value that does not parse.
  invalidDates,
}

/// A YNAB export that is not in the expected format. [detail] is technical
/// text for the log (for [YnabImportFailure.missingRegisterColumns]: the
/// comma-separated column names; for [YnabImportFailure.invalidDates]: the
/// first date that does not parse).
class YnabImportException implements Exception {
  const YnabImportException(this.failure, this.detail);

  final YnabImportFailure failure;
  final String detail;

  @override
  String toString() => 'YnabImportException(${failure.name}): $detail';
}

/// Service responsible for parsing YNAB export files (CSV and YNAB4)
/// and converting them into intermediate data structures.
///
/// nYNAB register splits: the CSV export has one row per split line, all
/// with the parent's account and date, and the memo prefixed with
/// "Split (i/n) " (followed by the line's own memo, if any). Consecutive
/// such rows of one account and day with the same `n` and distinct `i` are
/// grouped into one [YnabTransaction] whose [YnabTransaction.splits] hold
/// the lines (marker stripped from the memo) and whose amount is their sum.
/// A lone "Split" row without siblings is imported as a normal row. See
/// [YnabSplitItem.transferAccountId] for split lines that are transfers.
class YnabImportService {
  /// Date formats of the Register.csv, in order of preference (YNAB's
  /// default US format first). Day and month are ambiguous when no day is
  /// above 12; the first format that fits every row wins.
  static const registerDateFormats = [
    'MM/dd/yyyy',
    'dd/MM/yyyy',
    'yyyy-MM-dd',
    'dd.MM.yyyy',
  ];

  /// YNAB writes English month names ("Jan 2025") whatever the app
  /// language; `en_US` is the locale intl always has built in.
  static const _exportLocale = 'en_US';

  /// The one format of [registerDateFormats] that parses every value of
  /// [dates] strictly (the first of [fittingRegisterDateFormats]). Throws
  /// [YnabImportFailure.invalidDates] naming the first value that the
  /// best-fitting format rejects.
  static String detectRegisterDateFormat(List<String> dates) {
    final fitting = fittingRegisterDateFormats(dates);
    if (fitting.isNotEmpty) {
      return fitting.first;
    }
    String? bestFirstBad;
    var bestFailures = -1;
    for (final format in registerDateFormats) {
      final parser = DateFormat(format, _exportLocale);
      var failures = 0;
      String? firstBad;
      for (final value in dates) {
        try {
          parser.parseStrict(value);
        } on FormatException {
          failures++;
          firstBad ??= value;
        }
      }
      if (bestFailures == -1 || failures < bestFailures) {
        bestFailures = failures;
        bestFirstBad = firstBad;
      }
    }
    throw YnabImportException(
      YnabImportFailure.invalidDates,
      bestFirstBad ?? '',
    );
  }

  /// Every format of [registerDateFormats] (in order of preference) that
  /// parses all of [dates] strictly. More than one means day and month are
  /// ambiguous (no day above 12).
  static List<String> fittingRegisterDateFormats(List<String> dates) {
    final fitting = <String>[];
    for (final format in registerDateFormats) {
      final parser = DateFormat(format, _exportLocale);
      var ok = true;
      for (final value in dates) {
        try {
          parser.parseStrict(value);
        } on FormatException {
          ok = false;
          break;
        }
      }
      if (ok) {
        fitting.add(format);
      }
    }
    return fitting;
  }

  /// Parses nYNAB CSV export files.
  ///
  /// [registerCsvContent]: Content of the 'Register.csv' file.
  /// [budgetCsvContent]: Content of the 'Budget.csv' file.
  /// [dateFormat]: a format of [registerDateFormats] to read the register
  /// dates with instead of the detected one (the user's choice when the
  /// file is ambiguous); it must still fit every date.
  ///
  /// Tracking accounts: the CSV does not say which accounts are off
  /// budget. An account whose rows are only its "Starting Balance" and
  /// transfer legs is taken to be a tracking account (the user can change
  /// it in the preview).
  Future<YnabImportData> parseCsvExport({
    required String registerCsvContent,
    required String budgetCsvContent,
    String? dateFormat,
  }) async {
    final transactions = <YnabTransaction>[];
    final accounts = <YnabAccount>[];
    final categoryGroups = <YnabCategoryGroup>[];
    final categories = <YnabCategory>[];
    final budgetEntries = <YnabBudgetEntry>[];
    String? chosenDateFormat;
    var dateFormatCandidates = const <String>[];
    // One decimal separator for the whole export: YNAB writes every
    // amount the same way, so "€1.234" (no decimals) is read as 1234.
    final amountParser = MoneyParser(
      decimalSeparator: inferDecimalSeparator(
        _amountCells(registerCsvContent, budgetCsvContent),
      ),
    );

    String? detectEol(String content) {
      if (content.contains('\r\n')) {
        return '\r\n';
      }
      if (content.contains('\n')) {
        return '\n';
      }
      if (content.contains('\r')) {
        return '\r';
      }
      return null;
    }

    // 1. Parse Register CSV
    final regEol = detectEol(registerCsvContent);
    final registerRows = const CsvToListConverter().convert(
      registerCsvContent,
      shouldParseNumbers: false,
      eol: regEol,
    );

    if (registerRows.isNotEmpty) {
      final headers = registerRows.first.map((e) => e.toString()).toList();
      final rows = registerRows.skip(1).toList();

      // Index headers
      final accIdx = headers.indexOf('Account');
      final dateIdx = headers.indexOf('Date');
      final payeeIdx = headers.indexOf('Payee');
      final groupIdx = headers.indexOf('Category Group');
      final catIdx = headers.indexOf('Category');
      final memoIdx = headers.indexOf('Memo');
      final outflowIdx = headers.indexOf('Outflow');
      final inflowIdx = headers.indexOf('Inflow');
      final clearedIdx = headers.indexOf('Cleared');

      final missingColumns = <String>[];
      if (accIdx == -1) {
        missingColumns.add('Account');
      }
      if (dateIdx == -1) {
        missingColumns.add('Date');
      }
      if (payeeIdx == -1) {
        missingColumns.add('Payee');
      }
      if (outflowIdx == -1) {
        missingColumns.add('Outflow');
      }
      if (inflowIdx == -1) {
        missingColumns.add('Inflow');
      }

      if (missingColumns.isNotEmpty) {
        throw YnabImportException(
          YnabImportFailure.missingRegisterColumns,
          missingColumns.join(', '),
        );
      }

      // Track unique entities to avoid duplicates in list
      final accountNames = <String>{};
      final categoryKeys = <String>{}; // "Group|Category"
      final lines = <_RegisterLine>[];

      final usableRows = [
        for (final row in rows)
          if (row.length >= headers.length) row,
      ];
      // One date format for the whole file: a per-row guess would read
      // 05/03 as May 3 in one row and 13/03 as March 13 in the next.
      final dateValues = [
        for (final row in usableRows) row[dateIdx].toString().trim(),
      ];
      dateFormatCandidates = usableRows.isEmpty
          ? registerDateFormats
          : fittingRegisterDateFormats(dateValues);
      final detected = usableRows.isEmpty
          ? registerDateFormats.first
          : detectRegisterDateFormat(dateValues);
      chosenDateFormat =
          dateFormat != null && dateFormatCandidates.contains(dateFormat)
          ? dateFormat
          : detected;
      final dateParser = DateFormat(chosenDateFormat, _exportLocale);

      for (final row in usableRows) {
        final accName = row[accIdx].toString();
        if (accountNames.add(accName)) {
          accounts.add(
            YnabAccount(
              id: accName, // Use name as ID for CSV import
              name: accName,
              type: mapAccountType(accName), // Heuristic based on name
            ),
          );
        }

        final date = CalendarDate.fromLocalPick(
          dateParser.parseStrict(row[dateIdx].toString().trim()),
        );

        final payee = row[payeeIdx].toString();
        final group = groupIdx != -1 ? row[groupIdx].toString() : '';
        final category = catIdx != -1 ? row[catIdx].toString() : '';
        final memo = memoIdx != -1 ? row[memoIdx].toString() : '';

        // Parse amounts (currency strings, either decimal style) into
        // minor units.
        int parseAmount(dynamic val) => _parseCsvAmount(val, amountParser);

        final outflow = parseAmount(row[outflowIdx]);
        final inflow = parseAmount(row[inflowIdx]);
        final amount = inflow - outflow;

        // "Cleared" / "Uncleared" / "Reconciled" (or just C / U / R).
        final clearedStr = clearedIdx != -1
            ? row[clearedIdx].toString().trim().toUpperCase()
            : 'U';
        final reconciled = clearedStr.startsWith('R');
        final cleared = reconciled || clearedStr.startsWith('C');

        // Handle categories
        if (group.isNotEmpty && category.isNotEmpty) {
          final key = '$group|$category';
          if (categoryKeys.add(key)) {
            // Determine if group exists
            final grp = categoryGroups.firstWhere(
              (g) => g.name == group,
              orElse: () => YnabCategoryGroup(id: group, name: group),
            );
            if (!categoryGroups.contains(grp)) {
              categoryGroups.add(grp);
            }

            categories.add(
              YnabCategory(id: key, groupId: group, name: category),
            );
          }
        }

        lines.add(
          _RegisterLine(
            accountName: accName,
            date: date,
            payee: payee,
            group: group,
            category: category,
            memo: memo,
            amount: amount,
            cleared: cleared,
            reconciled: reconciled,
          ),
        );
      }
      transactions.addAll(_groupRegisterLines(lines));

      // Tracking accounts: only starting balance and transfer legs.
      final hasOwnRows = <String>{};
      for (final line in lines) {
        final isStart = line.payee.trim().toLowerCase() == 'starting balance';
        if (!isStart && transferTargetName(line.payee) == null) {
          hasOwnRows.add(line.accountName);
        }
      }
      for (var i = 0; i < accounts.length; i++) {
        if (!hasOwnRows.contains(accounts[i].id)) {
          accounts[i] = accounts[i].copyWith(onBudget: false);
        }
      }
    }

    // 2. Parse Budget CSV
    var categoriesOnlyInBudget = 0;
    final budgetEol = detectEol(budgetCsvContent);
    final budgetRows = const CsvToListConverter().convert(
      budgetCsvContent,
      shouldParseNumbers: false,
      eol: budgetEol,
    );

    if (budgetRows.isNotEmpty) {
      final headers = budgetRows.first.map((e) => e.toString()).toList();
      final rows = budgetRows.skip(1).toList();

      final monthIdx = headers.indexOf('Month');
      final groupIdx = headers.indexOf('Category Group');
      final catIdx = headers.indexOf('Category');
      final budgetedIdx = headers.indexOf('Budgeted');

      if (monthIdx != -1 &&
          groupIdx != -1 &&
          catIdx != -1 &&
          budgetedIdx != -1) {
        for (final row in rows) {
          if (row.length < headers.length) {
            continue;
          }

          final month = parseBudgetMonth(row[monthIdx].toString());
          if (month == null) {
            Logger.warning('YNAB Budget.csv: unreadable month, row skipped');
            continue;
          }

          final group = row[groupIdx].toString();
          final category = row[catIdx].toString();

          final budgeted = _parseCsvAmount(row[budgetedIdx], amountParser);

          // A category budgeted but never used in the register (a sinking
          // fund, a credit card payment category) still exists.
          if (group.isNotEmpty && category.isNotEmpty) {
            final key = '$group|$category';
            if (!categories.any((c) => c.id == key)) {
              if (!categoryGroups.any((g) => g.name == group)) {
                categoryGroups.add(YnabCategoryGroup(id: group, name: group));
              }
              categories.add(
                YnabCategory(id: key, groupId: group, name: category),
              );
              categoriesOnlyInBudget++;
            }
          }

          if (budgeted != 0) {
            budgetEntries.add(
              YnabBudgetEntry(
                categoryName: category,
                categoryGroupName: group,
                month: month,
                budgeted: budgeted,
              ),
            );
          }
        }
      }
    }

    return YnabImportData(
      accounts: accounts,
      categoryGroups: categoryGroups,
      categories: categories,
      transactions: transactions,
      budgetEntries: budgetEntries,
      source: 'CSV',
      importedAt: DateTime.now().toUtc(),
      registerDateFormat: chosenDateFormat,
      dateFormatCandidates: dateFormatCandidates,
      categoriesOnlyInBudget: categoriesOnlyInBudget,
      fingerprint: fingerprintOf(registerCsvContent),
    );
  }

  /// SHA-256 of an export's text, the key of the "already imported" check.
  static String fingerprintOf(String content) =>
      sha256.convert(utf8.encode(content)).toString();

  /// The amount cells of both files (Outflow, Inflow, Budgeted), for the
  /// decimal separator inference.
  static Iterable<String> _amountCells(String register, String budget) sync* {
    for (final (content, columns) in [
      (register, ['Outflow', 'Inflow']),
      (budget, ['Budgeted']),
    ]) {
      if (content.trim().isEmpty) {
        continue;
      }
      final rows = const CsvToListConverter().convert(
        content,
        shouldParseNumbers: false,
        eol: content.contains('\r\n') ? '\r\n' : '\n',
      );
      if (rows.isEmpty) {
        continue;
      }
      final headers = rows.first.map((e) => e.toString()).toList();
      final indices = [
        for (final c in columns)
          if (headers.contains(c)) headers.indexOf(c),
      ];
      for (final row in rows.skip(1)) {
        for (final i in indices) {
          if (row.length > i) {
            yield row[i].toString();
          }
        }
      }
    }
  }

  /// The month of a Budget.csv row: "Jan 2025" (English month names,
  /// whatever the app language), a register-style date or an ISO date.
  /// `null` when the value is none of these.
  static DateTime? parseBudgetMonth(String value) {
    final text = value.trim();
    for (final format in ['MMM yyyy', 'MMMM yyyy', ...registerDateFormats]) {
      try {
        final parsed = DateFormat(format, _exportLocale).parseStrict(text);
        return DateTime(parsed.year, parsed.month);
      } on FormatException {
        // Try the next format.
      }
    }
    return null;
  }

  /// Parses a legacy YNAB4 budget folder.
  ///
  /// [folderPath]: Path to the .ynab4 directory.
  Future<YnabImportData> parseYnab4(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw YnabImportException(
        YnabImportFailure.invalidYnab4Folder,
        'YNAB4 directory not found: $folderPath',
      );
    }

    // 1. Locate Budget.ymeta to find current version
    final metaFile = File(path.join(folderPath, 'Budget.ymeta'));
    if (!await metaFile.exists()) {
      throw const YnabImportException(
        YnabImportFailure.invalidYnab4Folder,
        'Invalid YNAB4 bundle: Budget.ymeta missing',
      );
    }

    // 2. Find the data folder (usually data1-{GUID})
    String? dataFolderPath;
    await for (final entity in dir.list()) {
      if (entity is Directory &&
          path.basename(entity.path).startsWith('data')) {
        dataFolderPath = entity.path;
        break;
      }
    }

    if (dataFolderPath == null) {
      throw const YnabImportException(
        YnabImportFailure.invalidYnab4Folder,
        'Could not find data folder in YNAB4 bundle',
      );
    }

    // 3. Find the full budget file (Budget.yfull) inside the device folder
    File? yfullFile;
    final dataDir = Directory(dataFolderPath);

    await for (final entity in dataDir.list()) {
      if (entity is Directory) {
        final potentialFile = File(path.join(entity.path, 'Budget.yfull'));
        if (await potentialFile.exists()) {
          yfullFile = potentialFile;
          break;
        }
      }
    }

    if (yfullFile == null) {
      throw const YnabImportException(
        YnabImportFailure.invalidYnab4Folder,
        'Budget.yfull not found',
      );
    }

    final content = await yfullFile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    return _parseYnab4Json(json, fingerprint: fingerprintOf(content));
  }

  /// YNAB 4 keeps its income categories under the internal master
  /// category; rows in them are income (no category, To Be Budgeted).
  static const ynab4InternalMasterCategoryId = 'MasterCategory/__Internal__';
  static const ynab4IncomeCategoryIds = {
    'Category/__ImmediateIncome__',
    'Category/__DeferredIncome__',
  };

  YnabImportData _parseYnab4Json(
    Map<String, dynamic> json, {
    String? fingerprint,
  }) {
    // YNAB4 JSON Structure (Budget.yfull):
    // {
    //   "accounts": [...],
    //   "payees": [...],
    //   "masterCategories": [        // Groups, each with its categories
    //     {..., "subCategories": [...]}
    //   ],
    //   "transactions": [            // each split parent with its lines
    //     {..., "subTransactions": [...]}
    //   ],
    //   "monthlyBudgets": [...],     // Budget allocations
    //   "scheduledTransactions": [...],
    //   ...
    // }
    // Older/flattened files list "subCategories" and "subTransactions" at
    // the top level instead; both shapes are read.

    final accounts = <YnabAccount>[];
    final categoryGroups = <YnabCategoryGroup>[];
    final categories = <YnabCategory>[];
    final transactions = <YnabTransaction>[];
    final scheduledTransactions = <YnabScheduledTransaction>[];
    final budgetEntries = <YnabBudgetEntry>[];

    // 1. Accounts
    for (final acc in (json['accounts'] as List? ?? [])) {
      if (acc['isTombstone'] == true) {
        continue;
      }

      accounts.add(
        YnabAccount(
          id: acc['entityId'],
          name: acc['accountName'],
          type: _mapYnab4AccountType(acc['accountType']),
          onBudget: acc['onBudget'] ?? true,
          isClosed: acc['hidden'] ?? false,
        ),
      );
    }

    // 2. Payees (Need to map Payee ID -> Name)
    final payeeMap = <String, String>{}; // id -> name
    for (final payee in (json['payees'] as List? ?? [])) {
      if (payee['isTombstone'] == true) {
        continue;
      }
      payeeMap[payee['entityId']] = payee['name'];
    }

    // 3. Categories
    final groupMap = <String, String>{}; // id -> name

    final nestedSubCategories = <Map<String, dynamic>>[];
    for (final master in (json['masterCategories'] as List? ?? [])) {
      if (master['isTombstone'] == true) {
        continue;
      }
      for (final sub in (master['subCategories'] as List? ?? [])) {
        nestedSubCategories.add({
          ...sub as Map<String, dynamic>,
          'masterCategoryId': sub['masterCategoryId'] ?? master['entityId'],
        });
      }

      // The internal master category (income, split marker) is not a
      // group; its categories are still known so rows in them are read
      // as income (see [isReadyToAssignCategory]).
      final isInternal = master['entityId'] == ynab4InternalMasterCategoryId;
      groupMap[master['entityId']] = master['name'];
      if (isInternal) {
        continue;
      }

      // Hidden master categories are imported too (their categories
      // hidden), so their transactions keep a category.
      final group = YnabCategoryGroup(
        id: master['entityId'],
        name: master['name'],
        isHidden: master['isHidden'] == true,
      );
      categoryGroups.add(group);
    }

    final categoryMap = <String, YnabCategory>{}; // id -> Category

    for (final sub in [
      ...nestedSubCategories,
      ...(json['subCategories'] as List? ?? []),
    ]) {
      if (sub['isTombstone'] == true ||
          categoryMap.containsKey(sub['entityId'])) {
        continue;
      }

      final category = YnabCategory(
        id: sub['entityId'],
        groupId: sub['masterCategoryId'],
        name: sub['name'],
        isHidden: sub['isHidden'] == true,
      );
      categoryMap[category.id] = category;
      if (category.groupId == ynab4InternalMasterCategoryId ||
          ynab4IncomeCategoryIds.contains(category.id)) {
        continue;
      }
      categories.add(category);
    }
    // Income categories of files that do not list the internal master
    // category: known by id, so their rows are income.
    for (final id in ynab4IncomeCategoryIds) {
      categoryMap.putIfAbsent(
        id,
        () => YnabCategory(
          id: id,
          groupId: ynab4InternalMasterCategoryId,
          name: 'Immediate Income SubCategory',
        ),
      );
    }
    groupMap.putIfAbsent(
      ynab4InternalMasterCategoryId,
      () => 'Internal Master Category',
    );

    // YNAB4 keeps hidden categories under a hidden master category
    // ("Hidden Categories") that is not always listed among the master
    // categories. Such categories get a hidden group so their transactions
    // keep a category (YNAB's own group name, not an app string).
    for (final category in categories) {
      if (!categoryGroups.any((g) => g.id == category.groupId)) {
        groupMap[category.groupId] = 'Hidden Categories';
        categoryGroups.add(
          YnabCategoryGroup(
            id: category.groupId,
            name: 'Hidden Categories',
            isHidden: true,
          ),
        );
      }
    }

    // 4. Transactions & Splits
    // First, index splits by parentId (nested in each transaction, or at
    // the top level in flattened files)
    final splitsByParent = <String, List<YnabSplitItem>>{};
    final allSplits = <Map<String, dynamic>>[
      for (final tx in (json['transactions'] as List? ?? []))
        for (final split in (tx['subTransactions'] as List? ?? []))
          {
            ...split as Map<String, dynamic>,
            'entitiesTransactionId':
                split['entitiesTransactionId'] ?? tx['entityId'],
          },
      for (final split in (json['subTransactions'] as List? ?? []))
        split as Map<String, dynamic>,
    ];
    final seenSplits = <String>{};
    for (final split in allSplits) {
      if (split['isTombstone'] == true) {
        continue;
      }
      final splitId = split['entityId'];
      if (splitId != null && !seenSplits.add(splitId as String)) {
        continue;
      }
      final parentId = split['entitiesTransactionId'];
      final catId = split['categoryId'];
      final cat = categoryMap[catId];

      final item = YnabSplitItem(
        categoryGroupName: cat != null ? groupMap[cat.groupId] : null,
        categoryName: cat?.name,
        amount: _ynab4Amount(split['amount']),
        memo: split['memo'],
        payeeName: null, // YNAB4 splits don't have separate payees usually
        transferAccountId: split['targetAccountId'] as String?,
      );

      splitsByParent.putIfAbsent(parentId, () => []).add(item);
    }

    for (final tx in (json['transactions'] as List? ?? [])) {
      if (tx['isTombstone'] == true) {
        continue;
      }

      final catId = tx['categoryId'];
      final cat = categoryMap[catId];
      final splitItems = splitsByParent[tx['entityId']] ?? [];
      final payeeName = payeeMap[tx['payeeId']];

      final String? transferAccountId = tx['targetAccountId'];

      transactions.add(
        YnabTransaction(
          id: tx['entityId'],
          accountId: tx['accountId'],
          date: CalendarDate.fromLocalPick(DateTime.parse(tx['date'])),
          payeeName: payeeName,
          categoryGroupName: cat != null ? groupMap[cat.groupId] : null,
          categoryName: cat?.name,
          amount: _ynab4Amount(tx['amount']),
          memo: tx['memo'],
          cleared: tx['cleared'] == 'Cleared' || tx['cleared'] == 'Reconciled',
          reconciled: tx['cleared'] == 'Reconciled',
          transferAccountId: transferAccountId,
          splits: splitItems,
        ),
      );
    }

    // 5. Scheduled Transactions
    for (final sch in (json['scheduledTransactions'] as List? ?? [])) {
      if (sch['isTombstone'] == true) {
        continue;
      }

      final catId = sch['categoryId'];
      final cat = categoryMap[catId];
      final payeeName = payeeMap[sch['payeeId']];

      final recurrence = _ynab4Recurrence(sch['frequency'] as String?);

      scheduledTransactions.add(
        YnabScheduledTransaction(
          id: sch['entityId'],
          accountId: sch['accountId'],
          payeeName: payeeName,
          categoryGroupName: cat != null ? groupMap[cat.groupId] : null,
          categoryName: cat?.name,
          memo: sch['memo'],
          amount: _ynab4Amount(sch['amount']),
          frequency: recurrence.frequency,
          interval: recurrence.interval,
          occurrenceCount: recurrence.occurrenceCount,
          nextDate: CalendarDate.fromLocalPick(
            DateTime.parse(sch['date']),
          ), // The next occurrence
          transferAccountId: sch['targetAccountId'],
        ),
      );
    }

    // 6. Budget entries (monthlyBudgets)
    // Structure: { month: "2023-01-01", monthlySubCategoryBudgets: [...] }
    for (final mb in (json['monthlyBudgets'] as List? ?? [])) {
      if (mb['isTombstone'] == true) {
        continue;
      }

      final monthStr = mb['month']; // "2023-01-01"
      final month = DateTime.parse(monthStr);

      for (final subBudget
          in (mb['monthlySubCategoryBudgets'] as List? ?? [])) {
        if (subBudget['isTombstone'] == true) {
          continue;
        }

        final catId = subBudget['categoryId'];
        final cat = categoryMap[catId];
        if (cat == null) {
          continue;
        }

        final budgeted = _ynab4Amount(subBudget['budgeted']);

        budgetEntries.add(
          YnabBudgetEntry(
            categoryName: cat.name,
            categoryGroupName: groupMap[cat.groupId] ?? 'Unknown',
            month: month,
            budgeted: budgeted,
          ),
        );
      }
    }

    return YnabImportData(
      accounts: accounts,
      categoryGroups: categoryGroups,
      categories: categories,
      transactions: transactions,
      scheduledTransactions: scheduledTransactions,
      budgetEntries: budgetEntries,
      source: 'YNAB4',
      importedAt: DateTime.now().toUtc(),
      fingerprint: fingerprint,
    );
  }

  /// Maps a YNAB4 scheduled-transaction frequency onto LedgerZero's
  /// frequency + interval. "Never" is a one-off (one occurrence).
  /// "TwiceAMonth" has no exact equivalent; it becomes every two weeks
  /// (closest in number of occurrences per year).
  static ({RecurrenceFrequency frequency, int interval, int? occurrenceCount})
  _ynab4Recurrence(String? value) {
    switch (value) {
      case 'Never':
        return (
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          occurrenceCount: 1,
        );
      case 'Daily':
        return (
          frequency: RecurrenceFrequency.daily,
          interval: 1,
          occurrenceCount: null,
        );
      case 'Weekly':
        return (
          frequency: RecurrenceFrequency.weekly,
          interval: 1,
          occurrenceCount: null,
        );
      case 'EveryOtherWeek':
        return (
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          occurrenceCount: null,
        );
      case 'TwiceAMonth':
        Logger.warning(
          'YNAB4 schedule "TwiceAMonth" imported as every two weeks.',
        );
        return (
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          occurrenceCount: null,
        );
      case 'Every4Weeks':
        return (
          frequency: RecurrenceFrequency.weekly,
          interval: 4,
          occurrenceCount: null,
        );
      case 'EveryOtherMonth':
        return (
          frequency: RecurrenceFrequency.monthly,
          interval: 2,
          occurrenceCount: null,
        );
      case 'Every3Months':
        return (
          frequency: RecurrenceFrequency.monthly,
          interval: 3,
          occurrenceCount: null,
        );
      case 'Every4Months':
        return (
          frequency: RecurrenceFrequency.monthly,
          interval: 4,
          occurrenceCount: null,
        );
      case 'TwiceAYear':
        return (
          frequency: RecurrenceFrequency.monthly,
          interval: 6,
          occurrenceCount: null,
        );
      case 'Yearly':
        return (
          frequency: RecurrenceFrequency.yearly,
          interval: 1,
          occurrenceCount: null,
        );
      case 'EveryOtherYear':
        return (
          frequency: RecurrenceFrequency.yearly,
          interval: 2,
          occurrenceCount: null,
        );
      case 'Monthly':
      default:
        if (value != null && value != 'Monthly') {
          Logger.warning(
            'Unknown YNAB4 schedule frequency "$value"; imported as monthly.',
          );
        }
        return (
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          occurrenceCount: null,
        );
    }
  }

  AccountType _mapYnab4AccountType(String type) {
    // YNAB4 types: Checking, Savings, CreditCard, Cash, LineOfCredit, MerchantAccount, PayPal, InvestmentAccount, Mortgage, OtherAsset, OtherLiability
    switch (type) {
      case 'Checking':
        return AccountType.checking;
      case 'Savings':
        return AccountType.savings;
      case 'CreditCard':
      case 'LineOfCredit':
        return AccountType.credit;
      case 'Cash':
      case 'MerchantAccount':
      case 'PayPal':
        return AccountType.cash;
      case 'InvestmentAccount':
        return AccountType.investment;
      default:
        return AccountType.checking; // Default
    }
  }

  static final RegExp _splitMarker = RegExp(
    r'^\s*Split\s*\(\s*(\d+)\s*/\s*(\d+)\s*\)\s*',
    caseSensitive: false,
  );

  /// Parses the "Split (i/n) memo" marker that nYNAB puts in the memo of
  /// every split line. Returns `null` when [memo] carries no valid marker
  /// (1 <= i <= n, n >= 2).
  static ({int index, int count, String memo})? parseSplitMarker(String? memo) {
    if (memo == null) {
      return null;
    }
    final match = _splitMarker.firstMatch(memo);
    if (match == null) {
      return null;
    }
    final index = int.parse(match.group(1)!);
    final count = int.parse(match.group(2)!);
    if (count < 2 || index < 1 || index > count) {
      return null;
    }
    return (index: index, count: count, memo: memo.substring(match.end).trim());
  }

  /// Turns register lines into transactions, grouping split lines into one
  /// split transaction each (see the class comment).
  static List<YnabTransaction> _groupRegisterLines(List<_RegisterLine> lines) {
    final result = <YnabTransaction>[];
    String nextId() => 'TX_${result.length}';

    YnabTransaction single(_RegisterLine line, {String? memo}) =>
        YnabTransaction(
          id: nextId(),
          accountId: line.accountName,
          date: line.date,
          payeeName: line.payee,
          categoryGroupName: line.group,
          categoryName: line.category,
          memo: memo ?? line.memo,
          amount: line.amount,
          cleared: line.cleared,
          reconciled: line.reconciled,
          // The register marks a transfer leg with the payee
          // "Transfer : <Account Name>"; CSV account ids are names.
          transferAccountId: transferTargetName(line.payee),
        );

    var i = 0;
    while (i < lines.length) {
      final first = lines[i];
      final marker = parseSplitMarker(first.memo);
      if (marker == null) {
        result.add(single(first));
        i++;
        continue;
      }

      // Collect the consecutive lines of this split.
      final group = <({int index, String memo, _RegisterLine line})>[
        (index: marker.index, memo: marker.memo, line: first),
      ];
      final seen = {marker.index};
      var j = i + 1;
      while (j < lines.length && group.length < marker.count) {
        final next = lines[j];
        final m = parseSplitMarker(next.memo);
        if (m == null ||
            m.count != marker.count ||
            seen.contains(m.index) ||
            next.accountName != first.accountName ||
            next.date != first.date) {
          break;
        }
        group.add((index: m.index, memo: m.memo, line: next));
        seen.add(m.index);
        j++;
      }
      i = j;

      if (group.length < 2) {
        Logger.warning(
          'YNAB CSV: split line ${marker.index}/${marker.count} without its '
          'sibling lines; importing it as a normal transaction.',
        );
        result.add(single(first, memo: marker.memo));
        continue;
      }
      if (group.length != marker.count) {
        Logger.warning(
          'YNAB CSV: split with ${group.length} of ${marker.count} lines; '
          'importing the lines that are present.',
        );
      }
      group.sort((a, b) => a.index.compareTo(b.index));

      // The parent's payee: the one all lines share, otherwise the first
      // line's. Lines with a different payee keep their own.
      final payees = group.map((g) => g.line.payee).toSet();
      final parentPayee = payees.length == 1
          ? payees.single
          : group
                .map((g) => g.line.payee)
                .firstWhere(
                  (p) => p.trim().isNotEmpty && transferTargetName(p) == null,
                  orElse: () => '',
                );
      final head = group.first.line;

      result.add(
        YnabTransaction(
          id: nextId(),
          accountId: head.accountName,
          date: head.date,
          payeeName: parentPayee,
          amount: Money.sum(group.map((g) => g.line.amount)),
          cleared: head.cleared,
          reconciled: head.reconciled,
          splits: [
            for (final g in group)
              YnabSplitItem(
                categoryGroupName: g.line.group,
                categoryName: g.line.category,
                memo: g.memo,
                amount: g.line.amount,
                payeeName: g.line.payee == parentPayee ? null : g.line.payee,
                transferAccountId: transferTargetName(g.line.payee),
              ),
          ],
        ),
      );
    }
    return result;
  }

  static final RegExp _transferPayee = RegExp(
    r'^\s*Transfer\s*:\s*(.*?)\s*$',
    caseSensitive: false,
  );

  /// The account name of a YNAB transfer payee ("Transfer : Savings",
  /// spaces around the colon optional), or `null` if [payeeName] is not a
  /// transfer payee.
  static String? transferTargetName(String? payeeName) {
    if (payeeName == null) {
      return null;
    }
    final match = _transferPayee.firstMatch(payeeName);
    final name = match?.group(1);
    return name == null || name.isEmpty ? null : name;
  }

  /// Helper to map YNAB account types to LedgerZero AccountType
  static AccountType mapAccountType(String ynabType) {
    final normalized = ynabType.toLowerCase().trim();
    if (normalized.contains('checking')) {
      return AccountType.checking;
    }
    if (normalized.contains('saving')) {
      return AccountType.savings;
    }
    if (normalized.contains('credit')) {
      return AccountType.credit;
    }
    if (normalized.contains('card')) {
      return AccountType.credit;
    }
    if (normalized.contains('cash')) {
      return AccountType.cash;
    }
    if (normalized.contains('invest') ||
        normalized.contains('brokerage') ||
        normalized.contains('retirement')) {
      return AccountType.investment;
    }
    return AccountType.checking; // Default
  }

  /// Parses a YNAB CSV amount cell ("$1,234.56", "1.234,56 €", "") into
  /// minor units with the export's [parser]. Unparsable or empty cells
  /// count as 0.
  static int _parseCsvAmount(dynamic value, MoneyParser parser) {
    final text = value?.toString() ?? '';
    return parser.tryParse(text) ?? 0;
  }

  /// YNAB4 JSON amounts are major-unit numbers.
  static int _ynab4Amount(dynamic value) {
    if (value is num) {
      return Money.fromMajor(value);
    }
    return Money.fromDecimalString(value?.toString() ?? '') ?? 0;
  }
}

/// One parsed row of the nYNAB Register.csv.
class _RegisterLine {
  const _RegisterLine({
    required this.accountName,
    required this.date,
    required this.payee,
    required this.group,
    required this.category,
    required this.memo,
    required this.amount,
    required this.cleared,
    required this.reconciled,
  });

  final String accountName;
  final DateTime date;
  final String payee;
  final String group;
  final String category;
  final String memo;
  final int amount;
  final bool cleared;
  final bool reconciled;
}
