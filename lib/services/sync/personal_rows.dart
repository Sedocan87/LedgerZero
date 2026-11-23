import 'package:ledger_zero/data/database/database.dart';

/// Rows that never leave this device: the transactions and scheduled
/// transactions of personal accounts. The account row itself syncs (name,
/// type, owner and the shared balance), so the partner can show it and a
/// transfer from a shared account into it still points at an existing
/// account. See docs/SYNC_ARCHITECTURE.md ("Personal accounts").
///
/// Tombstones are not filtered: a deleted row's account is unknown, and a
/// tombstone for a row the partner never had changes nothing there.
class PersonalRows {
  PersonalRows._(
    this._accountIds,
    this._ownAccountIds,
    this._privatePayeeIds,
    this._ownPrivatePayeeIds,
  );

  final Set<String> _accountIds;
  final Set<String> _ownAccountIds;
  final Set<String> _privatePayeeIds;
  final Set<String> _ownPrivatePayeeIds;

  /// The personal accounts as they are now (this member's and, for safety,
  /// the partner's: nothing is ever written into those here), plus payees
  /// referenced exclusively by personal accounts.
  static Future<PersonalRows> load(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT id, owner_id = ${AppDatabase.localMemberSql} AS own '
          'FROM accounts WHERE owner_id IS NOT NULL',
        )
        .get();
    final accountIds = {for (final r in rows) r.read<String>('id')};
    final ownAccountIds = {
      for (final r in rows)
        if (r.data['own'] == 1) r.read<String>('id'),
    };
    if (accountIds.isEmpty) {
      return PersonalRows._(
        accountIds,
        ownAccountIds,
        const <String>{},
        const <String>{},
      );
    }
    // Payees referenced only by personal accounts (or defaulting to one)
    // and never by any shared account stay private to this device.
    final payeeRows = await db.customSelect('''
      SELECT p.id,
        EXISTS (
          SELECT 1 FROM transactions t
          JOIN accounts a ON a.id = t.account_id
          WHERE t.payee_id = p.id AND a.owner_id IS NOT NULL
        ) OR EXISTS (
          SELECT 1 FROM scheduled_transactions s
          JOIN accounts a ON a.id = s.account_id
          WHERE s.payee_id = p.id AND a.owner_id IS NOT NULL
        ) OR EXISTS (
          SELECT 1 FROM accounts a
          WHERE a.id = p.default_account_id AND a.owner_id IS NOT NULL
        ) AS has_personal,
        EXISTS (
          SELECT 1 FROM transactions t
          JOIN accounts a ON a.id = t.account_id
          WHERE t.payee_id = p.id AND a.owner_id = ${AppDatabase.localMemberSql}
        ) OR EXISTS (
          SELECT 1 FROM scheduled_transactions s
          JOIN accounts a ON a.id = s.account_id
          WHERE s.payee_id = p.id AND a.owner_id = ${AppDatabase.localMemberSql}
        ) OR EXISTS (
          SELECT 1 FROM accounts a
          WHERE a.id = p.default_account_id AND a.owner_id = ${AppDatabase.localMemberSql}
        ) AS has_own_personal,
        EXISTS (
          SELECT 1 FROM transactions t
          JOIN accounts a ON a.id = t.account_id
          WHERE t.payee_id = p.id AND a.owner_id IS NULL
        ) OR EXISTS (
          SELECT 1 FROM scheduled_transactions s
          JOIN accounts a ON a.id = s.account_id
          WHERE s.payee_id = p.id AND a.owner_id IS NULL
        ) AS has_shared
      FROM payees p
    ''').get();
    final privatePayees = <String>{};
    final ownPrivatePayees = <String>{};
    for (final r in payeeRows) {
      final hasPersonal = r.data['has_personal'] == 1;
      final hasShared = r.data['has_shared'] == 1;
      if (hasPersonal && !hasShared) {
        final id = r.read<String>('id');
        privatePayees.add(id);
        if (r.data['has_own_personal'] == 1) {
          ownPrivatePayees.add(id);
        }
      }
    }
    return PersonalRows._(
      accountIds,
      ownAccountIds,
      privatePayees,
      ownPrivatePayees,
    );
  }

  /// Whether [row] of [table] stays on this device.
  bool isPrivate(String table, Map<String, Object?> row) => switch (table) {
    'transactions' ||
    'scheduled_transactions' => _accountIds.contains(row['account_id']),
    'payees' =>
      _privatePayeeIds.contains(row['id']) ||
          _accountIds.contains(row['default_account_id']),
    _ => false,
  };

  /// Whether [row] of [table] belongs to one of **this member's** personal
  /// accounts: it exists on this phone only, and nothing another device
  /// sends may delete or overwrite it.
  bool isOwn(String table, Map<String, Object?> row) => switch (table) {
    'transactions' ||
    'scheduled_transactions' => _ownAccountIds.contains(row['account_id']),
    'payees' =>
      _ownPrivatePayeeIds.contains(row['id']) ||
          _ownAccountIds.contains(row['default_account_id']),
    _ => false,
  };
}
