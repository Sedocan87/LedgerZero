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
  PersonalRows._(this._accountIds);

  final Set<String> _accountIds;

  /// The personal accounts as they are now (this member's and, for safety,
  /// the partner's: nothing is ever written into those here).
  static Future<PersonalRows> load(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id FROM accounts WHERE owner_id IS NOT NULL')
        .get();
    return PersonalRows._({for (final r in rows) r.read<String>('id')});
  }

  /// Whether [row] of [table] stays on this device.
  bool isPrivate(String table, Map<String, Object?> row) => switch (table) {
    'transactions' ||
    'scheduled_transactions' => _accountIds.contains(row['account_id']),
    _ => false,
  };
}
