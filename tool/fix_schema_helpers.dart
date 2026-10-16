// Post-processes the drift schema test helpers in
// test/database/generated_migrations/.
//
// drift_dev names the getter for the SQL column `table_name` (sync_log,
// pending_sync_changes) `tableName`, which clashes with `Table.tableName` in
// the generated table classes and does not compile. This renames the column
// getter inside the table classes to `targetTableName` (the name used by the
// app's own table definitions). Data classes and companions keep their
// `tableName` fields, which do not clash.
//
// Run after `dart run drift_dev schema generate ...`:
//   dart run tool/fix_schema_helpers.dart
import 'dart:io';

void main() {
  final dir = Directory('test/database/generated_migrations');
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.dart')) {
      continue;
    }
    final lines = file.readAsLinesSync();
    var inColumnsList = false;
    var changed = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('late final GeneratedColumn<String> tableName =')) {
        lines[i] = line.replaceFirst(' tableName =', ' targetTableName =');
        changed = true;
      } else if (line.contains(r'List<GeneratedColumn> get $columns => [')) {
        inColumnsList = true;
      } else if (inColumnsList) {
        if (line.trim() == 'tableName,') {
          lines[i] = line.replaceFirst('tableName,', 'targetTableName,');
          changed = true;
        }
        if (line.trim() == '];') {
          inColumnsList = false;
        }
      }
    }
    if (changed) {
      file.writeAsStringSync('${lines.join('\n')}\n');
      stdout.writeln('fixed ${file.path}');
    }
  }
}
