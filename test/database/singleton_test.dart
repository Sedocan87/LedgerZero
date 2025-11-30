import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppDatabase singleton returns the same instance', () {
    final instance1 = AppDatabase.instance;
    final instance2 = AppDatabase.instance;

    expect(instance1, same(instance2));
  });
}
