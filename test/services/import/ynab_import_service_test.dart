import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';

const _header =
    '"Account","Flag","Date","Payee","Category Group/Category",'
    '"Category Group","Category","Memo","Outflow","Inflow","Cleared"';

String _row(
  String account,
  String date,
  String payee,
  String group,
  String category,
  String memo,
  String outflow,
  String inflow, [
  String cleared = 'Cleared',
]) =>
    '"$account","","$date","$payee","${group.isEmpty ? '' : '$group: $category'}",'
    '"$group","$category","$memo","$outflow","$inflow","$cleared"';

Future<void> _writeYnab4Bundle(
  Directory root,
  Map<String, dynamic> json,
) async {
  await File('${root.path}/Budget.ymeta').writeAsString('{}');
  final device = Directory('${root.path}/data1-ABCD/device-1');
  await device.create(recursive: true);
  await File('${device.path}/Budget.yfull').writeAsString(jsonEncode(json));
}

void main() {
  final service = YnabImportService();

  group('parseSplitMarker', () {
    test('reads index, count and the remaining memo', () {
      final m = YnabImportService.parseSplitMarker('Split (2/3) Groceries');
      expect(m?.index, 2);
      expect(m?.count, 3);
      expect(m?.memo, 'Groceries');
      expect(YnabImportService.parseSplitMarker('Split (1/2) ')?.memo, '');
      expect(YnabImportService.parseSplitMarker('split(1/2)x')?.memo, 'x');
    });

    test('rejects non-markers and invalid numbers', () {
      expect(YnabImportService.parseSplitMarker('Splitting the bill'), isNull);
      expect(YnabImportService.parseSplitMarker('Split (3/2) x'), isNull);
      expect(YnabImportService.parseSplitMarker('Split (0/2) x'), isNull);
      expect(YnabImportService.parseSplitMarker('Split (1/1) x'), isNull);
      expect(YnabImportService.parseSplitMarker(null), isNull);
    });
  });

  group('parseCsvExport splits', () {
    test('groups consecutive split lines into one split transaction', () async {
      final register = [
        _header,
        _row(
          'Checking',
          '01/15/2025',
          'Market',
          'Everyday',
          'Food',
          'Split (1/3) Groceries',
          '\$60.00',
          '\$0.00',
        ),
        // Line order inside the export does not matter.
        _row(
          'Checking',
          '01/15/2025',
          'Market',
          'Everyday',
          'Household',
          'Split (3/3) Soap',
          '\$10.00',
          '\$0.00',
        ),
        _row(
          'Checking',
          '01/15/2025',
          'Pharmacy',
          'Everyday',
          'Fun',
          'Split (2/3) ',
          '\$30.00',
          '\$0.00',
        ),
        // A second split on the same day and account, same line count.
        _row(
          'Checking',
          '01/15/2025',
          'Bakery',
          'Everyday',
          'Food',
          'Split (1/2) Bread',
          '\$4.00',
          '\$0.00',
          'Uncleared',
        ),
        _row(
          'Checking',
          '01/15/2025',
          'Bakery',
          'Everyday',
          'Fun',
          'Split (2/2) Cake',
          '\$6.00',
          '\$0.00',
          'Uncleared',
        ),
        _row(
          'Checking',
          '01/16/2025',
          'Landlord',
          'Bills',
          'Rent',
          '',
          '\$400.00',
          '\$0.00',
        ),
        // A lone split line without siblings is a normal row.
        _row(
          'Checking',
          '01/17/2025',
          'Kiosk',
          'Everyday',
          'Food',
          'Split (1/2) Gum',
          '\$1.00',
          '\$0.00',
        ),
      ].join('\n');

      final data = await service.parseCsvExport(
        registerCsvContent: register,
        budgetCsvContent: '',
      );

      expect(data.transactions, hasLength(4));

      final market = data.transactions[0];
      expect(market.amount, -10000);
      expect(market.categoryName, isNull);
      expect(market.transferAccountId, isNull);
      expect(market.memo, isNull);
      expect(market.cleared, isTrue);
      expect(market.splits.map((s) => s.amount), [-6000, -3000, -1000]);
      expect(market.splits.map((s) => s.categoryName), [
        'Food',
        'Fun',
        'Household',
      ]);
      expect(market.splits.map((s) => s.memo), ['Groceries', '', 'Soap']);
      // The line with its own payee keeps it.
      expect(market.payeeName, 'Market');
      expect(market.splits.map((s) => s.payeeName), [null, 'Pharmacy', null]);

      final bakery = data.transactions[1];
      expect(bakery.payeeName, 'Bakery');
      expect(bakery.amount, -1000);
      expect(bakery.cleared, isFalse);
      expect(bakery.splits.map((s) => s.memo), ['Bread', 'Cake']);

      final rent = data.transactions[2];
      expect(rent.splits, isEmpty);
      expect(rent.categoryName, 'Rent');

      final lone = data.transactions[3];
      expect(lone.splits, isEmpty);
      expect(lone.amount, -100);
      expect(lone.categoryName, 'Food');
      expect(lone.memo, 'Gum');
    });

    test('a transfer split line keeps its target account', () async {
      final register = [
        _header,
        _row(
          'Checking',
          '01/15/2025',
          'Market',
          'Everyday',
          'Food',
          'Split (1/2) ',
          '\$60.00',
          '\$0.00',
        ),
        _row(
          'Checking',
          '01/15/2025',
          'Transfer : Savings',
          '',
          '',
          'Split (2/2) Cash back',
          '\$20.00',
          '\$0.00',
        ),
        _row(
          'Savings',
          '01/15/2025',
          'Transfer : Checking',
          '',
          '',
          'Cash back',
          '\$0.00',
          '\$20.00',
        ),
      ].join('\n');

      final data = await service.parseCsvExport(
        registerCsvContent: register,
        budgetCsvContent: '',
      );

      expect(data.transactions, hasLength(2));
      final split = data.transactions.first;
      expect(split.payeeName, 'Market');
      expect(split.amount, -8000);
      expect(split.splits[0].transferAccountId, isNull);
      expect(split.splits[1].transferAccountId, 'Savings');
      expect(split.splits[1].payeeName, 'Transfer : Savings');
      expect(split.splits[1].memo, 'Cash back');
      expect(data.transactions[1].transferAccountId, 'Checking');
    });

    test('missing columns raise a typed exception', () async {
      await expectLater(
        service.parseCsvExport(
          registerCsvContent: '"Account","Date"\n"Checking","01/01/2025"',
          budgetCsvContent: '',
        ),
        throwsA(
          isA<YnabImportException>()
              .having(
                (e) => e.failure,
                'failure',
                YnabImportFailure.missingRegisterColumns,
              )
              .having((e) => e.detail, 'detail', 'Payee, Outflow, Inflow'),
        ),
      );
    });
  });

  group('parseYnab4', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ynab4_test');
    });
    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test(
      'reads closed accounts, split transfers and schedule recurrence',
      () async {
        await _writeYnab4Bundle(dir, {
          'accounts': [
            {
              'entityId': 'A1',
              'accountName': 'Checking',
              'accountType': 'Checking',
              'onBudget': true,
            },
            {
              'entityId': 'A2',
              'accountName': 'Old Savings',
              'accountType': 'Savings',
              'onBudget': true,
              'hidden': true,
            },
          ],
          'payees': [
            {'entityId': 'P1', 'name': 'Market'},
          ],
          'masterCategories': [
            {'entityId': 'M1', 'name': 'Everyday'},
          ],
          'subCategories': [
            {'entityId': 'C1', 'masterCategoryId': 'M1', 'name': 'Food'},
          ],
          'transactions': [
            {
              'entityId': 'T1',
              'accountId': 'A1',
              'date': '2025-01-15',
              'payeeId': 'P1',
              'categoryId': 'Category/__Split__',
              'amount': -80.0,
              'cleared': 'Cleared',
            },
          ],
          'subTransactions': [
            {
              'entityId': 'S1',
              'entitiesTransactionId': 'T1',
              'categoryId': 'C1',
              'amount': -60.0,
            },
            {
              'entityId': 'S2',
              'entitiesTransactionId': 'T1',
              'amount': -20.0,
              'targetAccountId': 'A2',
            },
          ],
          'scheduledTransactions': [
            {
              'entityId': 'SCH1',
              'accountId': 'A1',
              'date': '2025-02-01',
              'amount': -500.0,
              'frequency': 'EveryOtherWeek',
              'targetAccountId': 'A2',
              'memo': 'Saving',
            },
            {
              'entityId': 'SCH2',
              'accountId': 'A1',
              'date': '2025-02-01',
              'amount': -100.0,
              'frequency': 'Never',
            },
            {
              'entityId': 'SCH3',
              'accountId': 'A1',
              'date': '2025-02-01',
              'amount': -100.0,
              'frequency': 'TwiceAYear',
            },
          ],
          'monthlyBudgets': [],
        });

        final data = await service.parseYnab4(dir.path);

        final old = data.accounts.singleWhere((a) => a.id == 'A2');
        expect(old.isClosed, isTrue);

        final tx = data.transactions.single;
        expect(tx.amount, -8000);
        expect(tx.splits.map((s) => s.amount), [-6000, -2000]);
        expect(tx.splits[0].transferAccountId, isNull);
        expect(tx.splits[1].transferAccountId, 'A2');

        final sch = {for (final s in data.scheduledTransactions) s.id: s};
        expect(sch['SCH1']!.frequency, RecurrenceFrequency.weekly);
        expect(sch['SCH1']!.interval, 2);
        expect(sch['SCH1']!.transferAccountId, 'A2');
        expect(sch['SCH1']!.amount, -50000);
        expect(sch['SCH2']!.occurrenceCount, 1);
        expect(sch['SCH3']!.frequency, RecurrenceFrequency.monthly);
        expect(sch['SCH3']!.interval, 6);
      },
    );

    test(
      'a folder that is not a YNAB4 bundle raises a typed exception',
      () async {
        await expectLater(
          service.parseYnab4(dir.path),
          throwsA(
            isA<YnabImportException>().having(
              (e) => e.failure,
              'failure',
              YnabImportFailure.invalidYnab4Folder,
            ),
          ),
        );
      },
    );
  });

  group('parseCsvExport dates', () {
    Future<List<DateTime>> datesOf(List<String> dates) async {
      final data = await service.parseCsvExport(
        registerCsvContent: [
          _header,
          for (final d in dates)
            _row('Checking', d, 'Shop', '', '', '', '1', ''),
        ].join('\n'),
        budgetCsvContent: '',
      );
      return [for (final t in data.transactions) t.date];
    }

    test(
      'dd/MM/yyyy is detected once for the file (no day/month rollover)',
      () async {
        // 05/03 alone would also fit MM/dd; 13/03 decides for the whole file.
        expect(await datesOf(['05/03/2025', '13/03/2025']), [
          DateTime.utc(2025, 3, 5),
          DateTime.utc(2025, 3, 13),
        ]);
      },
    );

    test('ambiguous files use MM/dd/yyyy (YNAB default)', () async {
      expect(await datesOf(['05/03/2025']), [DateTime.utc(2025, 5, 3)]);
    });

    test('dd.MM.yyyy and yyyy-MM-dd are accepted', () async {
      expect(await datesOf(['31.12.2024']), [DateTime.utc(2024, 12, 31)]);
      expect(await datesOf(['2024-12-31']), [DateTime.utc(2024, 12, 31)]);
    });

    test(
      'no format fits every row: typed error naming the first bad value',
      () async {
        await expectLater(
          datesOf(['01/02/2025', '13/01/2025', 'tomorrow']),
          throwsA(
            isA<YnabImportException>()
                .having(
                  (e) => e.failure,
                  'failure',
                  YnabImportFailure.invalidDates,
                )
                .having((e) => e.detail, 'detail', 'tomorrow'),
          ),
        );
        await expectLater(
          datesOf(['12/31/2025', '31/12/2025']),
          throwsA(
            isA<YnabImportException>().having(
              (e) => e.failure,
              'failure',
              YnabImportFailure.invalidDates,
            ),
          ),
        );
      },
    );
  });

  test('Budget.csv months use English names whatever the app locale', () async {
    await initializeDateFormatting('de');
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = previous);

    final data = await service.parseCsvExport(
      registerCsvContent: _header,
      budgetCsvContent:
          '"Month","Category Group/Category","Category Group","Category",'
          '"Budgeted","Activity","Available"\n'
          '"May 2025","Bills: Rent","Bills","Rent","\$400.00","\$0.00","\$0.00"\n'
          '"Oct 2025","Bills: Rent","Bills","Rent","\$410.00","\$0.00","\$0.00"',
    );
    expect(data.budgetEntries.map((e) => (e.month.year, e.month.month)), [
      (2025, 5),
      (2025, 10),
    ]);
  });

  test(
    'YNAB4: hidden master and sub categories are kept, flagged hidden',
    () async {
      final dir = await Directory.systemTemp.createTemp('ynab4_hidden');
      addTearDown(() => dir.delete(recursive: true));
      await _writeYnab4Bundle(dir, {
        'accounts': [
          {
            'entityId': 'A1',
            'accountName': 'Checking',
            'accountType': 'Checking',
            'onBudget': true,
          },
        ],
        'masterCategories': [
          {'entityId': 'M1', 'name': 'Everyday'},
          {'entityId': 'M2', 'name': 'Old Stuff', 'isHidden': true},
        ],
        'subCategories': [
          {'entityId': 'C1', 'masterCategoryId': 'M1', 'name': 'Food'},
          {
            'entityId': 'C2',
            'masterCategoryId': 'M1',
            'name': 'Snacks',
            'isHidden': true,
          },
          {'entityId': 'C3', 'masterCategoryId': 'M2', 'name': 'Hobby'},
          // Master category not listed (YNAB4 "Hidden Categories").
          {
            'entityId': 'C4',
            'masterCategoryId': 'MasterCategory/__Hidden__',
            'name': 'Gym',
          },
        ],
        'transactions': [
          {
            'entityId': 'T1',
            'accountId': 'A1',
            'date': '2025-01-15',
            'categoryId': 'C3',
            'amount': -10.0,
          },
          {
            'entityId': 'T2',
            'accountId': 'A1',
            'date': '2025-01-16',
            'categoryId': 'C4',
            'amount': -20.0,
          },
        ],
      });

      final data = await service.parseYnab4(dir.path);
      final groups = {for (final g in data.categoryGroups) g.name: g};
      expect(groups['Old Stuff']!.isHidden, isTrue);
      expect(groups['Hidden Categories']!.isHidden, isTrue);
      final hidden = {for (final c in data.categories) c.name: c.isHidden};
      expect(hidden, {
        'Food': false,
        'Snacks': true,
        'Hobby': false,
        'Gym': false,
      });
      expect(
        data.transactions.map((t) => (t.categoryGroupName, t.categoryName)),
        [('Old Stuff', 'Hobby'), ('Hidden Categories', 'Gym')],
      );
    },
  );
}
