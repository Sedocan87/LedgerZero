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
  PersonalRows._(this._accountIds, this._ownAccountIds);

  final Set<String> _accountIds;
  final Set<String> _ownAccountIds;

  /// The personal accounts as they are now (this member's and, for safety,
  /// the partner's: nothing is ever written into those here).
  static Future<PersonalRows> load(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT id, owner_id = ${AppDatabase.localMemberSql} AS own '
          'FROM accounts WHERE owner_id IS NOT NULL',
        )
        .get();
    return PersonalRows._(
      {for (final r in rows) r.read<String>('id')},
      {
        for (final r in rows)
          if (r.data['own'] == 1) r.read<String>('id'),
      },
    );
  }

  /// Whether [row] of [table] stays on this device.
  bool isPrivate(String table, Map<String, Object?> row) => switch (table) {
    'transactions' ||
    'scheduled_transactions' => _accountIds.contains(row['account_id']),
    _ => false,
  };

  /// Whether [row] of [table] belongs to one of **this member's** personal
  /// accounts: it exists on this phone only, and nothing another device
  /// sends may delete it.
  bool isOwn(String table, Map<String, Object?> row) => switch (table) {
    'transactions' ||
    'scheduled_transactions' => _ownAccountIds.contains(row['account_id']),
    _ => false,
  };
}
