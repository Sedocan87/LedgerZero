import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';

/// Sync metadata of one synced table, read from drift's table definitions
/// (so every column of every synced table round-trips without a hand list).
class SyncedTable {
  final String name;

  /// SQL column names, in definition order.
  final List<String> columns;
  final Set<String> nullableColumns;

  /// Unique keys other than the primary key ("natural keys"), e.g.
  /// budgets (category_id, month) and report_notes (date).
  final List<List<String>> naturalKeys;

  /// Position in [SyncSchema.dependencyOrder]: parents have smaller ranks.
  final int rank;

  const SyncedTable({
    required this.name,
    required this.columns,
    required this.nullableColumns,
    required this.naturalKeys,
    required this.rank,
  });

  bool hasColumn(String column) => columns.contains(column);
}

/// The synced part of the schema and the helpers shared by generation and
/// replay.
class SyncSchema {
  /// Synced tables, parents before children (foreign keys). A test checks
  /// this order against `PRAGMA foreign_key_list`.
  static const List<String> dependencyOrder = [
    'category_groups',
    'accounts',
    'categories',
    'payees',
    'transactions',
    'budgets',
    'scheduled_transactions',
    'budget_templates',
    'report_notes',
    'import_profiles',
    'rules',
  ];

  /// Columns ignored when deciding whether two versions of a row differ in
  /// content (a conflict is only recorded for real differences).
  static const Set<String> metadataColumns = {'created_at', 'updated_at'};

  final Map<String, SyncedTable> tables;
  final int schemaVersion;

  SyncSchema._(this.tables, this.schemaVersion);

  factory SyncSchema.of(AppDatabase db) {
    final byName = {for (final t in db.allTables) t.actualTableName: t};
    final tables = <String, SyncedTable>{};
    for (var i = 0; i < dependencyOrder.length; i++) {
      final name = dependencyOrder[i];
      final info = byName[name];
      if (info == null) {
        throw StateError('synced table $name is missing');
      }
      tables[name] = SyncedTable(
        name: name,
        columns: [for (final c in info.$columns) c.name],
        nullableColumns: {
          for (final c in info.$columns)
            if (c.$nullable) c.name,
        },
        naturalKeys: [
          for (final key in info.uniqueKeys) [for (final c in key) c.name],
        ],
        rank: i,
      );
    }
    final missing = AppDatabase.syncedTables.toSet().difference(
      tables.keys.toSet(),
    );
    if (missing.isNotEmpty ||
        tables.length != AppDatabase.syncedTables.length) {
      throw StateError('dependencyOrder does not match syncedTables');
    }
    return SyncSchema._(tables, db.schemaVersion);
  }

  SyncedTable? operator [](String table) => tables[table];

  /// What replay does with a row whose parent row is missing at commit
  /// (it was deleted on another device): nullable references are cleared,
  /// required references and split children (parent_transaction_id) delete
  /// the row.
  bool deletesOnMissingParent(String table, String column) {
    if (table == 'transactions' && column == 'parent_transaction_id') {
      return true;
    }
    final t = tables[table];
    return t == null || !t.nullableColumns.contains(column);
  }

  /// The conflict timestamp of a stored `updated_at` value, in microseconds
  /// since the epoch (UTC). Missing or unreadable values count as 0.
  static int versionOf(Object? updatedAt) {
    if (updatedAt == null) {
      return 0;
    }
    if (updatedAt is int) {
      // Seconds since the epoch (drift's integer DateTime mode).
      return updatedAt * 1000000;
    }
    if (updatedAt is String) {
      final parsed = DateTime.tryParse(updatedAt);
      return parsed?.microsecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  /// Stable JSON of [row] without [metadataColumns] (content comparison).
  static String contentKey(Map<String, Object?>? row) {
    if (row == null) {
      return 'null';
    }
    final keys = row.keys.where((k) => !metadataColumns.contains(k)).toList()
      ..sort();
    return jsonEncode({for (final k in keys) k: row[k]});
  }

  /// Stable JSON of the whole [row] (sorted keys).
  static String canonicalJson(Map<String, Object?> row) {
    final keys = row.keys.toList()..sort();
    return jsonEncode({for (final k in keys) k: row[k]});
  }

  /// Wraps a raw SQL value for a custom statement.
  static Variable<Object> variable(Object? value) => Variable<Object>(value);
}
