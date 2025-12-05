import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/csv/account_export_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

class MockPathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  group('AccountExportService', () {
    late AccountExportService service;

    setUp(() {
      PathProviderPlatform.instance = MockPathProviderPlatform();
      service = AccountExportService();
    });

    test('exports transactions with resolved names', () async {
      final tx = Transaction(
        id: '1',
        accountId: 'acc1',
        date: DateTime(2023, 1, 1),
        amount: -50.0,
        payeeId: 'p1',
        categoryId: 'c1',
        memo: 'Test Memo',
        cleared: TransactionClearStatus.cleared,
        approved: true,
      );

      final path = await service.exportTransactionsToCsv(
        transactions: [tx],
        accountName: 'TestAccount',
        payeeNames: {'p1': 'Resolved Payee'},
        categoryNames: {'c1': 'Resolved Category'},
      );

      final file = File(path);
      final content = await file.readAsString();

      expect(content, contains('Resolved Payee'));
      expect(content, contains('Resolved Category'));
      expect(content, contains('2023-01-01'));
      expect(content, contains('-50.0'));
      expect(content, contains('cleared'));
      expect(content, contains('Yes'));
    });
  });
}
