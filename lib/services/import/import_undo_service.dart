import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the last CSV import created: the ids of its transactions, each
/// with a fingerprint of the row as it was written, so an undo can tell
/// the rows nobody touched since from the ones that were edited.
class ImportBatch {
  const ImportBatch({
    required this.importedAt,
    required this.fingerprints,
    this.startingBalanceRows = const {},
  });

  /// The batch for [created], the transactions an import just wrote.
  factory ImportBatch.of(
    List<Transaction> created,
    DateTime importedAt, {
    Map<String, List<String>> startingBalanceRows = const {},
  }) => ImportBatch(
    importedAt: importedAt,
    fingerprints: {
      for (final t in created) t.id: ImportUndoService.fingerprintOf(t),
    },
    startingBalanceRows: startingBalanceRows,
  );

  final DateTime importedAt;

  /// Transaction id -> [ImportUndoService.fingerprintOf] at import time.
  final Map<String, String> fingerprints;

  /// Account id -> the ids of the rows the import took out of that
  /// account's starting balance (rows dated before the account starts).
  final Map<String, List<String>> startingBalanceRows;
}

/// Where the last import batch is kept (device-local; no table: a schema
/// change would stall sync between two phones until both update).
abstract class LastImportStore {
  ImportBatch? read();
  Future<void> write(ImportBatch batch);
  Future<void> clear();
}

/// Kept in SharedPreferences as one JSON string.
class SharedPreferencesLastImportStore implements LastImportStore {
  SharedPreferencesLastImportStore(this._prefs);

  static const key = 'last_csv_import';

  final SharedPreferences _prefs;

  @override
  ImportBatch? read() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final importedAt = DateTime.parse(decoded['importedAt'] as String);
      final rows = (decoded['rows'] as Map<String, dynamic>).map(
        (id, fingerprint) => MapEntry(id, fingerprint as String),
      );
      final startRows = decoded['startingBalanceRows'];
      return rows.isEmpty
          ? null
          : ImportBatch(
              importedAt: importedAt,
              fingerprints: rows,
              startingBalanceRows: startRows is Map<String, dynamic>
                  ? startRows.map(
                      (account, ids) => MapEntry(account, [
                        for (final id in ids as List) id as String,
                      ]),
                    )
                  : const {},
            );
    } catch (e) {
      Logger.warning('Last import record unreadable, ignoring it: $e');
      return null;
    }
  }

  @override
  Future<void> write(ImportBatch batch) => _prefs.setString(
    key,
    jsonEncode({
      'importedAt': batch.importedAt.toUtc().toIso8601String(),
      'rows': batch.fingerprints,
      if (batch.startingBalanceRows.isNotEmpty)
        'startingBalanceRows': batch.startingBalanceRows,
    }),
  );

  @override
  Future<void> clear() => _prefs.remove(key);
}

/// For tests and containers without preferences.
class InMemoryLastImportStore implements LastImportStore {
  ImportBatch? _batch;

  @override
  ImportBatch? read() => _batch;

  @override
  Future<void> write(ImportBatch batch) async => _batch = batch;

  @override
  Future<void> clear() async => _batch = null;
}

/// What undoing the last import would do.
class ImportUndoPreview {
  const ImportUndoPreview({
    required this.importedAt,
    required this.total,
    required this.removable,
    required this.changed,
    required this.gone,
    this.startingBalanceRestores = const {},
  });

  final DateTime importedAt;

  /// Transactions the import created.
  final int total;

  /// Ids of the transactions that are exactly as the import wrote them;
  /// these are deleted.
  final List<String> removable;

  /// Transactions edited, reconciled, split or re-linked since the import
  /// (or whose transfer partner was); they are kept.
  final int changed;

  /// Transactions already deleted.
  final int gone;

  /// Account id -> the amount (minor units) given back to the account's
  /// starting balance: the sum of the [removable] rows the import had
  /// taken out of it.
  final Map<String, int> startingBalanceRestores;
}

/// "Undo last import" for the CSV transaction import.
///
/// The import records the ids of the transactions it created
/// ([LastImportStore]). Undoing deletes them through
/// [TransactionService.deleteMany], the same path as deleting them by
/// hand: one unit of work, soft deletes that sync to the other phone, and
/// one action on the undo stack (so the undo itself can be undone).
///
/// Only rows that are still exactly as imported are deleted. A row the
/// user edited, categorised, approved, reconciled, split or turned into a
/// transfer since is the user's work and is kept, as is the other leg of
/// its transfer; the caller tells the user how many ([ImportUndoPreview]).
/// A row the import itself wrote as reconciled (the file said so) is
/// unchanged and goes with the rest.
///
/// An import that took rows out of an account's starting balance (rows
/// dated before the account starts) gives the deleted ones back to it, in
/// the same unit of work.
///
/// Not covered: payees the import created stay (they may be in use by
/// now), and the YNAB migration, which also creates accounts, categories,
/// budgets and scheduled transactions and overwrites budgeted amounts,
/// has no undo.
class ImportUndoService {
  ImportUndoService({
    required this._transactionRepository,
    required this._transactionService,
    required this._store,
    this._accountRepository,
    this._unitOfWork,
  });

  /// Imports with more rows than this are not recorded (the record lives
  /// in SharedPreferences, which is read whole at every app start).
  static const maxRecordedRows = 10000;

  final TransactionRepository _transactionRepository;
  final TransactionService _transactionService;
  final LastImportStore _store;
  final AccountRepository? _accountRepository;
  final UnitOfWork? _unitOfWork;

  /// The fields of [t] an edit can change, hashed. Timestamps are left
  /// out: writing a row sets them.
  static String fingerprintOf(Transaction t) => sha1
      .convert(
        utf8.encode(
          [
            t.accountId,
            t.date.toUtc().millisecondsSinceEpoch,
            t.amount,
            t.payeeId,
            t.categoryId,
            t.memo,
            t.cleared.name,
            t.approved,
            t.transferAccountId,
            t.transferTransactionId,
            t.parentTransactionId,
          ].join('\u{1F}'),
        ),
      )
      .toString()
      .substring(0, 12);

  /// Remembers [created] as the last import. An import too large to
  /// record forgets the previous one, so "undo last import" never undoes
  /// an older import than the last.
  static Future<void> record(
    LastImportStore store,
    List<Transaction> created,
    DateTime importedAt, {
    Map<String, List<String>> startingBalanceRows = const {},
  }) async {
    try {
      if (created.isEmpty || created.length > maxRecordedRows) {
        await store.clear();
      } else {
        await store.write(
          ImportBatch.of(
            created,
            importedAt,
            startingBalanceRows: startingBalanceRows,
          ),
        );
      }
    } catch (e, st) {
      // The import itself succeeded; only its undo is unavailable.
      Logger.error('Recording the import for undo failed', e, st);
    }
  }

  /// What [undo] would do now, or `null` when no import is recorded.
  Future<ImportUndoPreview?> preview() async {
    final batch = _store.read();
    if (batch == null) {
      return null;
    }
    final ids = batch.fingerprints.keys.toList();
    final rows = <String, Transaction>{};
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      for (final row
          in await _transactionRepository.getTransactionsByIdsIncludingDeleted(
            chunk,
          )) {
        rows[row.id] = row;
      }
    }
    final splitParents = await _transactionRepository
        .watchSplitParentIds()
        .first;

    var gone = 0;
    final untouched = <String>{};
    for (final id in ids) {
      final row = rows[id];
      if (row == null || row.isDeleted) {
        gone++;
      } else if (fingerprintOf(row) == batch.fingerprints[id] &&
          !splitParents.contains(id)) {
        untouched.add(id);
      }
    }
    // A transfer goes as a whole or not at all.
    final removable = [
      for (final id in untouched)
        if (rows[id]!.transferTransactionId == null ||
            untouched.contains(rows[id]!.transferTransactionId))
          id,
    ];
    final removableIds = removable.toSet();
    final restores = <String, int>{};
    for (final MapEntry(key: account, value: rowIds)
        in batch.startingBalanceRows.entries) {
      final sum = Money.sum([
        for (final id in rowIds)
          if (removableIds.contains(id)) rows[id]!.amount,
      ]);
      if (sum != 0) {
        restores[account] = sum;
      }
    }
    return ImportUndoPreview(
      importedAt: batch.importedAt,
      total: ids.length,
      removable: removable,
      changed: ids.length - gone - removable.length,
      gone: gone,
      startingBalanceRestores: restores,
    );
  }

  /// Deletes the transactions of the last import that are unchanged and
  /// forgets the import. Returns what was done (`removable` are the
  /// deleted ids), or `null` when no import is recorded.
  Future<ImportUndoPreview?> undo() async {
    final preview = await this.preview();
    if (preview == null) {
      return null;
    }
    Future<void> undo() async {
      if (preview.removable.isNotEmpty) {
        await _transactionService.deleteMany(
          preview.removable,
          allowReconciledChange: true,
        );
      }
      final accounts = _accountRepository;
      if (accounts == null) {
        return;
      }
      for (final MapEntry(key: id, value: amount)
          in preview.startingBalanceRestores.entries) {
        final account = await accounts.getAccountById(id);
        if (account != null) {
          await accounts.updateAccount(
            account.copyWith(
              startingBalance: account.startingBalance + amount,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
        }
      }
    }

    final unitOfWork = _unitOfWork;
    await (unitOfWork == null ? undo() : unitOfWork.run(undo));
    await _store.clear();
    return preview;
  }
}

final lastImportStoreProvider = Provider<LastImportStore>((ref) {
  return SharedPreferencesLastImportStore(ref.watch(sharedPreferencesProvider));
});

final importUndoServiceProvider = Provider<ImportUndoService>((ref) {
  return ImportUndoService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    transactionService: ref.watch(transactionServiceProvider),
    store: ref.watch(lastImportStoreProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
  );
});
