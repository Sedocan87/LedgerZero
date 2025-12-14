import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    // using the default WebDatabase logic (IndexedDB built on top of sql.js or similar)
    // ignore: deprecated_member_use
    return WebDatabase('ledger_zero_db');
  });
}
