import 'package:drift/drift.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:uuid/uuid.dart';

class DeltaReplayService {
  final AppDatabase _db;
  final LocalDeltaQueue _deltaQueue;

  DeltaReplayService(this._db, this._deltaQueue);

  // Task 459: Batch Operations
  Future<void> replayBatch(List<SyncDelta> deltas, {List<String>? filenames}) async {
    if (deltas.isEmpty) return;

    await _db.transaction(() async {
      for (var i = 0; i < deltas.length; i++) {
        final delta = deltas[i];
        final filename = (filenames != null && i < filenames.length) ? filenames[i] : null;
        await replay(delta, filename: filename);
      }
    });
  }

  Future<void> replay(SyncDelta delta, {String? filename}) async {
    final tableName = delta.tableName;
    final action = delta.action;
    final data = delta.data;
    // Task 449: Log actions including skipped ones
    // We log at the end, recording whether it was IGNORED or APPLIED.

    try {
      if (action == SyncAction.delete) {
        // DELETE
        // Data might be just {'id': ...} or null if we handle it
        final id = data?['id'] as String? ?? (data != null && data.containsKey('id') ? data['id'] : null);
         if (id == null) {
          Logger.error('Skipping DELETE delta with missing ID: $delta');
          return;
        }

        // Conflict check
        if (await _shouldIgnore(tableName, id as String, delta.timestamp)) {
             await _logSync(delta, status: 'IGNORED_CONFLICT', filename: filename);
             return;
        }

        await _deleteRecord(tableName, id);
        await _clearPending(tableName, id);
        await _logSync(delta, status: 'APPLIED', filename: filename);

      } else {
        // INSERT / UPDATE
        if (data == null) {
           Logger.error('Skipping ${action} delta with missing data: $delta');
           return;
        }
        final id = data['id'] as String?;
        if (id == null) {
           Logger.error('Skipping ${action} delta with missing ID: $delta');
           return;
        }

        if (await _shouldIgnore(tableName, id, delta.timestamp)) {
             await _logSync(delta, status: 'IGNORED_CONFLICT', filename: filename);
             return;
        }

        // We use INSERT OR REPLACE behavior usually?
        // SyncAction.insert -> INSERT. If exists? Unique constraint error.
        // SyncAction.update -> UPDATE. If not exists? Should we INSERT?
        // Usually, if we receive UPDATE and don't have it, we should INSERT it (it means we missed the INSERT delta or it was squashed).
        // If we receive INSERT and we have it? We UPDATE it.
        // So effectively `INSERT OR REPLACE`.
        // Drift's `insertOnConflictUpdate` serves this well.

        await _upsertRecord(tableName, data);
        await _clearPending(tableName, id);
        await _logSync(delta, status: 'APPLIED');
      }
    } catch (e, stack) {
      Logger.error('Error replaying delta for $tableName', e, stack);
      await _logSync(delta, status: 'ERROR', errorMessage: e.toString(), filename: filename);
      rethrow; // Replay failure should stop the queue? Or skip?
               // If we skip, we might break dependency order. Better to stop/retry.
    }
  }

  Future<bool> _shouldIgnore(String tableName, String id, DateTime deltaTimestamp) async {
    // Task 445: Last-Writer-Wins

    // 1. Check pending sync changes (not yet generated)
    final pending = await _db.pendingSyncChangesDao.getChange(tableName, id);
    if (pending != null) {
      Logger.info('Conflict: Local pending change exists for $tableName:$id. Ignoring remote delta.');
      return true;
    }

    // 2. Check queued deltas (already generated but not uploaded)
    try {
      final pendingFiles = await _deltaQueue.getPendingDeltas();
      for (final file in pendingFiles) {
        final localDelta = await _deltaQueue.readDelta(file);
        if (localDelta.tableName == tableName && localDelta.data?['id'] == id) {
           if (localDelta.timestamp.isAfter(deltaTimestamp)) {
               Logger.info('Conflict: Local delta ${localDelta.timestamp} is newer than remote $deltaTimestamp for $tableName:$id. Ignoring remote.');
               return true;
           }
        }
      }
    } catch (e) {
      Logger.warning('Failed to check local delta queue for conflicts: $e');
    }

    // 3. Check existing record timestamp (LWW)
    try {
      final result = await _db.customSelect(
         'SELECT updated_at FROM $tableName WHERE id = ?',
         variables: [Variable.withString(id)]
      ).getSingleOrNull();

      if (result != null) {
         final updatedAtRaw = result.data['updated_at'];
         if (updatedAtRaw != null && updatedAtRaw is String) {
             final updatedAt = DateTime.parse(updatedAtRaw);
             // Ensure we check if it is really strictly after
             if (updatedAt.isAfter(deltaTimestamp)) {
                  Logger.info('Conflict: Local record updated at $updatedAt is newer than remote $deltaTimestamp for $tableName:$id. Ignoring.');
                  return true;
             }
         }
      }
    } catch (e) {
      // Ignore if table has no updated_at or other issue
    }

    return false;
  }

  Future<void> _clearPending(String tableName, String id) async {
    // Remove any pending change generated by the trigger (or existing one)
    await _db.pendingSyncChangesDao.deleteChangeByTableAndId(tableName, id);
  }

  Future<void> _deleteRecord(String tableName, String id) async {
    switch (tableName) {
      case 'accounts': await _db.accountsDao.deleteAccount(id); break; // Dao missing delete? Check Dao
      case 'transactions': await _db.transactionsDao.deleteTransaction(id); break; // Might be soft delete?
      // For sync, if action is DELETE, we should probably Hard Delete or replicate Soft Delete.
      // If the delta action was DELETE, it means hard delete (or record gone).
      // If it was UPDATE with is_deleted=true, it comes as UPDATE.
      // So DELETE means physical row removal.
      case 'categories': await _db.categoriesDao.deleteCategory(id); break;
      case 'category_groups': await _db.categoriesDao.deleteCategoryGroup(id); break; // CategoriesDao handles both
      case 'payees': await _db.payeesDao.deletePayee(id); break;
      case 'budgets': await _db.budgetsDao.deleteBudget(id); break; // Need to check if DAO has this
      case 'scheduled_transactions': await _db.scheduledTransactionsDao.deleteScheduledTransaction(id); break;
      case 'budget_templates': await _db.budgetTemplatesDao.deleteBudgetTemplate(id); break;
      case 'report_notes': await _db.reportNotesDao.deleteNote(id); break;
      default: Logger.warning('Delete not implemented for $tableName');
    }
  }

  Future<void> _upsertRecord(String tableName, Map<String, dynamic> data) async {
    switch (tableName) {
      case 'accounts':
        await _db.into(_db.accounts).insertOnConflictUpdate(AccountsCompanion(
          id: Value(data['id']),
          name: Value(data['name']),
          type: Value(data['type']),
          currency: Value(data['currency'] ?? 'USD'),
          startingBalance: Value((data['starting_balance'] as num?)?.toDouble() ?? 0.0),
          currentBalance: Value((data['current_balance'] as num?)?.toDouble() ?? 0.0),
          isClosed: Value(data['is_closed'] == 1),
          color: Value(data['color']),
          icon: Value(data['icon']),
          notes: Value(data['notes']),
          createdAt: _parseDate(data['created_at']),
          updatedAt: _parseDate(data['updated_at']),
        ));
        break;
      case 'categories':
        await _db.into(_db.categories).insertOnConflictUpdate(CategoriesCompanion(
          id: Value(data['id']),
          name: Value(data['name']),
          categoryGroupId: Value(data['category_group_id']),
          isHidden: Value(data['is_hidden'] == 1),
          sortOrder: Value(data['sort_order']),
          goalType: Value(data['goal_type']),
          targetAmount: Value((data['target_amount'] as num?)?.toDouble()),
          targetDate: _parseDate(data['target_date']),
          color: Value(data['color']),
          icon: Value(data['icon']),
          createdAt: _parseDate(data['created_at']),
        ));
        break;
      case 'category_groups':
        await _db.into(_db.categoryGroups).insertOnConflictUpdate(CategoryGroupsCompanion(
          id: Value(data['id']),
          name: Value(data['name']),
          sortOrder: Value(data['sort_order']),
          createdAt: _parseDate(data['created_at']),
        ));
        break;
      case 'transactions':
        await _db.into(_db.transactions).insertOnConflictUpdate(TransactionsCompanion(
          id: Value(data['id']),
          accountId: Value(data['account_id']),
          date: Value(DateTime.parse(data['date'])),
          amount: Value((data['amount'] as num).toDouble()),
          payeeId: Value(data['payee_id']),
          categoryId: Value(data['category_id']),
          memo: Value(data['memo']),
          cleared: Value(data['cleared'] ?? 0),
          approved: Value(data['approved'] == 1),
          isDeleted: Value(data['is_deleted'] == 1),
          transferAccountId: Value(data['transfer_account_id']),
          transferTransactionId: Value(data['transfer_transaction_id']),
          parentTransactionId: Value(data['parent_transaction_id']),
          createdAt: _parseDate(data['created_at']),
          updatedAt: _parseDate(data['updated_at']),
        ));
        break;
      case 'payees':
        await _db.into(_db.payees).insertOnConflictUpdate(PayeesCompanion(
          id: Value(data['id']),
          name: Value(data['name']),
          autoCategoryId: Value(data['auto_category_id']),
          defaultAccountId: Value(data['default_account_id']),
          createdAt: _parseDate(data['created_at']),
          icon: Value(data['icon']),
          color: Value(data['color']),
          notes: Value(data['notes']),
          isFavorite: Value(data['is_favorite'] == 1),
        ));
        break;
      case 'budgets':
        await _db.into(_db.budgets).insertOnConflictUpdate(BudgetsCompanion(
          id: Value(data['id']),
          categoryId: Value(data['category_id']),
          month: Value(data['month']),
          budgeted: Value((data['budgeted'] as num?)?.toDouble() ?? 0.0),
          activity: Value((data['activity'] as num?)?.toDouble() ?? 0.0),
          available: Value((data['available'] as num?)?.toDouble() ?? 0.0),
          createdAt: _parseDate(data['created_at']),
          updatedAt: _parseDate(data['updated_at']),
        ));
        break;
      case 'scheduled_transactions':
        await _db.into(_db.scheduledTransactions).insertOnConflictUpdate(ScheduledTransactionsCompanion(
          id: Value(data['id']),
          accountId: Value(data['account_id']),
          payeeId: Value(data['payee_id']),
          categoryId: Value(data['category_id']),
          amount: Value((data['amount'] as num?)?.toDouble()),
          frequency: Value(data['frequency']),
          interval: Value(data['interval']),
          occurrenceCount: Value(data['occurrence_count']),
          nextDate: _parseDate(data['next_date']),
          endDate: _parseDate(data['end_date']),
          autoApprove: Value(data['auto_approve'] == 1),
          createdAt: _parseDate(data['created_at']),
        ));
        break;
       case 'budget_templates':
        await _db.into(_db.budgetTemplates).insertOnConflictUpdate(BudgetTemplatesCompanion(
          id: Value(data['id']),
          name: Value(data['name']),
          data: Value(data['data']),
          createdAt: data['created_at'] != null
              ? Value(data['created_at'] as String?)
              : const Value.absent(),
        ));
        break;
       case 'report_notes':
        await _db.into(_db.reportNotes).insertOnConflictUpdate(ReportNotesCompanion(
          id: Value(data['id']),
          date: Value(data['date']), // YYYY-MM string
          note: Value(data['note']),
          createdAt: data['created_at'] != null
              ? Value(data['created_at'] as String?)
              : const Value.absent(),
          updatedAt: data['updated_at'] != null
              ? Value(data['updated_at'] as String?)
              : const Value.absent(),
        ));
        break;
      default:
        Logger.warning('Upsert not implemented for $tableName');
    }
  }

  Value<DateTime?> _parseDate(dynamic value) {
    if (value == null) return const Value(null);
    if (value is String) return Value(DateTime.parse(value));
    if (value is int) return Value(DateTime.fromMillisecondsSinceEpoch(value));
    return const Value(null);
  }

  Future<void> _logSync(SyncDelta delta, {required String status, String? errorMessage, String? filename}) async {
    await _db.syncLogDao.insertSyncLog(
      SyncLogCompanion.insert(
        id: const Uuid().v4(),
        deltaFilename: Value(filename),
        action: Value(status), // Using Action column for Status (APPLIED, IGNORED)
        targetTableName: Value(delta.tableName),
        recordId: Value(delta.data?['id']),
        appliedAt: Value(DateTime.now()),
        deviceUuid: Value(delta.deviceUuid),
      ),
    );
  }
}
