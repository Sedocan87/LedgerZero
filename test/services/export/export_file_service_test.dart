import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/csv/payee_export_service.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:ledger_zero/services/export/csv_sanitizer.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';

class _RecordingSharer implements FileSharer {
  final shared = <String>[];
  bool existedWhenShared = false;
  bool fail = false;

  @override
  Future<void> share(
    List<String> paths, {
    String? text,
    String? subject,
  }) async {
    shared.addAll(paths);
    existedWhenShared = paths.every((p) => File(p).existsSync());
    if (fail) {
      throw Exception('share sheet failed');
    }
  }
}

void main() {
  late Directory base;
  late _RecordingSharer sharer;
  late ExportFileService files;

  setUp(() {
    base = Directory.systemTemp.createTempSync('lz_exports_');
    sharer = _RecordingSharer();
    files = ExportFileService(
      sharer: sharer,
      baseDirectory: () async => base,
      deferDeletion: false,
    );
  });

  tearDown(() => base.deleteSync(recursive: true));

  group('ExportFileService', () {
    test(
      'writes into the temporary export directory and deletes after sharing',
      () async {
        final file = await files.writeString('report.csv', 'a,b');
        expect(file.parent.path, '${base.path}/exports');

        await files.shareAndDelete(file);

        expect(sharer.shared, [file.path]);
        expect(sharer.existedWhenShared, isTrue);
        expect(file.existsSync(), isFalse);
      },
    );

    test('deletes the file even when sharing fails', () async {
      sharer.fail = true;
      final file = await files.writeString('report.csv', 'a,b');
      await expectLater(files.shareAndDelete(file), throwsException);
      expect(file.existsSync(), isFalse);
    });

    test('ignores directory parts in file names', () async {
      final file = await files.writeString('../../escape.csv', 'x');
      expect(file.parent.path, '${base.path}/exports');
    });

    test('sweeps leftovers older than an hour, keeps fresh ones', () async {
      final old = await files.writeString('old.csv', 'x');
      final fresh = await files.writeString('fresh.csv', 'y');
      old.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(await files.sweepStale(), 1);
      expect(old.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('exports from the CSV services do not stay on disk', () async {
      await TransactionExportService(files: files).exportTransactionsToCsv(
        transactions: [
          Transaction(
            id: 't1',
            accountId: 'a1',
            date: DateTime.utc(2024, 5, 1),
            amount: -1250,
          ),
        ],
      );
      expect(sharer.shared, hasLength(1));
      expect(File(sharer.shared.single).existsSync(), isFalse);
      expect(Directory('${base.path}/exports').listSync(), isEmpty);
    });
  });

  group('CSV formula injection', () {
    test('neutralises text cells that a spreadsheet would evaluate', () {
      for (final evil in ['=1+1', '+1', '-2+3', '@SUM(A1)', '\tx', '\rx']) {
        expect(CsvSanitizer.cell(evil), "'$evil");
      }
      expect(CsvSanitizer.cell('Groceries'), 'Groceries');
      expect(CsvSanitizer.cell(''), '');
      expect(CsvSanitizer.cell(42), 42);
      expect(CsvSanitizer.cell(const CsvLiteral('-12.50')), '-12.50');
    });

    test(
      'transaction export neutralises payee and memo but keeps amounts numeric',
      () {
        final csv = TransactionExportService(files: files).buildCsv(
          transactions: [
            Transaction(
              id: 't1',
              accountId: 'a1',
              payeeId: 'p1',
              date: DateTime.utc(2024, 5, 1),
              amount: -1250,
              memo: '=HYPERLINK("http://evil","x")',
            ),
          ],
          payeeNames: {'p1': '@cmd'},
          accountNames: {'a1': '-Checking'},
        );
        final row = const CsvToListConverter(
          shouldParseNumbers: false,
        ).convert(csv)[1];
        expect(row[0], '2024-05-01');
        expect(row[1], "'-Checking");
        expect(row[2], "'@cmd");
        expect(row[4], "'=HYPERLINK(\"http://evil\",\"x\")");
        expect(row[5], '-12.50');
      },
    );

    test('payee export neutralises names and notes', () {
      final csv = PayeeExportService(
        files: files,
      ).buildCsv([const Payee(id: 'p1', name: '=evil()', notes: '+notes')]);
      final row = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csv)[1];
      expect(row[0], "'=evil()");
      expect(row[2], "'+notes");
    });
  });
}
