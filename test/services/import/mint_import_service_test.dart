import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/import/mint_import_service.dart';

void main() {
  group('MintImportService', () {
    late MintImportService parser;

    setUp(() {
      parser = MintImportService();
    });

    test('should parse valid Mint CSV correctly', () {
      const csv =
          '''"Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
"6/09/2020","Target","TARGET 1234","50.25","debit","Shopping","Checking Account","",""
"6/10/2020","Salary","ACME CORP PAYROLL","2000.00","credit","Income","Checking Account","","Bonus"
"6/11/2020","Amazon","AMZN MKTPLACE","120.00","debit","Shopping","Credit Card","Tag1",""
''';
      final data = parser.parseCsvExport(csv);

      expect(data.transactions.length, 3);

      // Check Debit
      expect(data.transactions[0].date, DateTime(2020, 6, 9));
      expect(data.transactions[0].description, 'Target');
      expect(data.transactions[0].amount, -50.25); // Debit should be negative
      expect(data.transactions[0].accountName, 'Checking Account');
      expect(data.transactions[0].transactionType, 'debit');

      // Check Credit
      expect(data.transactions[1].amount, 2000.00); // Credit should be positive
      expect(data.transactions[1].transactionType, 'credit');
      expect(data.transactions[1].notes, 'Bonus');

      // Check Categories
      expect(data.categories.length, 2); // Shopping, Income
      expect(data.categories, contains('Shopping'));
      expect(data.categories, contains('Income'));

      // Check Accounts
      expect(data.accounts.length, 2); // Checking Account, Credit Card
    });

    test('should handle varying date formats', () {
      const csv =
          '''"Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
"01/15/2021","Test1","Test1","10.00","debit","Test","Acc","",""
"2021-02-20","Test2","Test2","20.00","debit","Test","Acc","",""
''';
      final data = parser.parseCsvExport(csv);

      expect(data.transactions[0].date, DateTime(2021, 1, 15));
      expect(data.transactions[1].date, DateTime(2021, 2, 20));
    });
  });
}
