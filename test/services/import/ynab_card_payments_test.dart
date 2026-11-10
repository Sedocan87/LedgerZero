// A YNAB (nYNAB CSV) budget with a credit card: its "Credit Card Payments"
// category maps onto the card's payment category and the imported numbers
// match what YNAB shows.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/services/import/ynab_data_mapper.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';

import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/test_database.dart';

// Checking with 1,000.00; a Visa with 300.00 of existing debt (YNAB's
// starting balance row of a card); January: 80.00 of groceries on the card
// (groceries has 100.00: funded), 50.00 of dining on the card (dining has
// 20.00: 30.00 credit overspending), a 200.00 payment from checking;
// February: 40.00 of groceries on the card. The account is called "Visa"
// (no "card" in its name), so only the Credit Card Payments category tells
// that it is a credit card.
const _register =
    '''"Account","Flag","Date","Payee","Category Group/Category","Category Group","Category","Memo","Outflow","Inflow","Cleared"
"Checking","","01/01/2025","Starting Balance","Inflow: Ready to Assign","Inflow","Ready to Assign","","\$0.00","\$1,000.00","Cleared"
"Visa","","01/01/2025","Starting Balance","Inflow: Ready to Assign","Inflow","Ready to Assign","","\$300.00","\$0.00","Cleared"
"Visa","","01/05/2025","Supermarket","Everyday: Groceries","Everyday","Groceries","","\$80.00","\$0.00","Cleared"
"Visa","","01/10/2025","Restaurant","Everyday: Dining","Everyday","Dining","","\$50.00","\$0.00","Cleared"
"Checking","","01/20/2025","Transfer : Visa","","","","","\$200.00","\$0.00","Cleared"
"Visa","","01/20/2025","Transfer : Checking","","","","","\$0.00","\$200.00","Cleared"
"Visa","","02/03/2025","Supermarket","Everyday: Groceries","Everyday","Groceries","","\$40.00","\$0.00","Cleared"
''';

// January assigns 100.00 to groceries, 20.00 to dining and 150.00 to the
// Visa payment category (towards the old debt); February 50.00 to
// groceries. Activity and Available are YNAB's own figures for this data.
const _budget =
    '''"Month","Category Group/Category","Category Group","Category","Budgeted","Activity","Available"
"Jan 2025","Credit Card Payments: Visa","Credit Card Payments","Visa","\$150.00","-\$100.00","\$50.00"
"Jan 2025","Everyday: Groceries","Everyday","Groceries","\$100.00","-\$80.00","\$20.00"
"Jan 2025","Everyday: Dining","Everyday","Dining","\$20.00","-\$50.00","-\$30.00"
"Feb 2025","Credit Card Payments: Visa","Credit Card Payments","Visa","\$0.00","\$40.00","\$90.00"
"Feb 2025","Everyday: Groceries","Everyday","Groceries","\$50.00","-\$40.00","\$30.00"
"Feb 2025","Everyday: Dining","Everyday","Dining","\$0.00","\$0.00","\$0.00"
''';

void main() {
  late TestDatabase t;
  final jan = DateTime.utc(2025, 1, 1);
  final feb = DateTime.utc(2025, 2, 1);

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  Future<void> import() async {
    final data = await YnabImportService().parseCsvExport(
      registerCsvContent: _register,
      budgetCsvContent: _budget,
    );
    await YnabDataMapper(
      accountRepo: t.accounts,
      categoryRepo: t.categories,
      payeeRepo: t.payees,
      transactionRepo: t.transactions,
      budgetRepo: t.budgets,
      scheduledTransactionRepo: t.scheduledTransactions,
      unitOfWork: t.unitOfWork,
    ).importData(data, currency: 'USD');
  }

  /// The imported category [name] (not a seeded default of that name).
  Future<String> categoryNamed(String name, {String? group}) async {
    final groups = {
      for (final g in await t.categories.getAllCategoryGroups()) g.id: g.name,
    };
    return (await t.categories.getAllCategories())
        .firstWhere(
          (c) =>
              c.name == name &&
              (group == null || groups[c.categoryGroupId] == group),
        )
        .id;
  }

  test('the parser recognises the card by its payment category', () async {
    final data = await YnabImportService().parseCsvExport(
      registerCsvContent: _register,
      budgetCsvContent: _budget,
    );
    final visa = data.accounts.firstWhere((a) => a.name == 'Visa');
    expect(visa.type, AccountType.credit);
    // The payment category is not a category of its own.
    expect(data.categoriesOnlyInBudget, 0);
  });

  test('Credit Card Payments maps onto the card\'s payment category; the '
      'numbers match YNAB', () async {
    await import();
    final accounts = await t.accounts.getAllAccounts();
    final visa = accounts.firstWhere((a) => a.name == 'Visa');
    expect(visa.type, AccountType.credit);
    final payment = CardPayments.categoryId(visa.id);

    // No ordinary "Visa" category, no second Credit Card Payments group.
    final categories = await t.categories.getAllCategories();
    expect(categories.where((c) => c.name == 'Visa').map((c) => c.id), [
      payment,
    ]);
    final groups = await t.categories.getAllCategoryGroups();
    expect(
      groups.where((g) => g.name == 'Credit Card Payments').map((g) => g.id),
      [CardPayments.groupId],
    );
    // The payment to the card is a linked transfer, not a categorised row.
    final legs = (await t.transactions.getAllTransactions())
        .where((r) => r.transferAccountId != null)
        .toList();
    expect(legs, hasLength(2));
    expect(legs.every((l) => l.categoryId == null), isTrue);

    final groceries = await categoryNamed('Groceries', group: 'Everyday');
    final dining = await categoryNamed('Dining', group: 'Everyday');
    Future<int> available(String id, DateTime m) =>
        t.budgeting.calculateCategoryAvailable(id, m);

    // Ready to Assign (YNAB: one figure for every month): 1,000 of income
    // - 270 assigned in January - 50 assigned in February = 680. The card's
    // 300 of existing debt does not reduce it, and January's 30 of credit
    // overspending is not taken from February.
    expect(await t.budgeting.calculateTBB(jan), 68000);
    expect(await t.budgeting.calculateTBB(feb), 68000);

    // January. Groceries: 100 - 80 = 20 (the 80 was funded and moved to
    // Visa). Dining: 20 - 50 = -30, credit overspending (YNAB's yellow).
    // Visa payment: 150 assigned + 80 + 20 funded spending - 200 payment =
    // 50 (YNAB's Activity -100, Available 50).
    expect(await available(groceries, jan), 2000);
    expect(await available(dining, jan), -3000);
    final janPerf = await t.budgeting.calculateBatchCategoryPerformance(jan);
    expect(janPerf[dining]!['creditOverspent'], 3000);
    expect(janPerf[payment]!['activity'], -10000);
    expect(await available(payment, jan), 5000);
    // Card balance -300 - 80 - 50 + 200 = -230; still missing 230 - 50 =
    // 180 (old debt 300 - 150 assigned + 30 unfunded dining).
    final janStatus = (await t.budgeting.calculateCardPaymentStatus(
      visa.id,
      jan,
    ))!;
    expect(janStatus.balance, -23000);
    expect(janStatus.missing, 18000);

    // February. Groceries: 20 + 50 - 40 = 30 (funded, moved to Visa).
    // Dining starts at 0. Visa payment: 50 + 40 = 90 (YNAB's Activity 40,
    // Available 90). Card balance -270, still missing 180.
    expect(await available(groceries, feb), 3000);
    expect(await available(dining, feb), 0);
    expect(await available(payment, feb), 9000);
    final febStatus = (await t.budgeting.calculateCardPaymentStatus(
      visa.id,
      feb,
    ))!;
    expect(febStatus.balance, -27000);
    expect(febStatus.missing, 18000);

    await expectLedgerInvariant(t, jan);
    await expectLedgerInvariant(t, feb);
  });

  test('a payment category whose card is not a budget card is imported as '
      'an ordinary category, so its money is kept', () async {
    // "Amex" appears only in Budget.csv: no such account in the register.
    const budget =
        '''"Month","Category Group/Category","Category Group","Category","Budgeted","Activity","Available"
"Jan 2025","Credit Card Payments: Amex","Credit Card Payments","Amex","\$25.00","\$0.00","\$25.00"
''';
    final data = await YnabImportService().parseCsvExport(
      registerCsvContent: _register,
      budgetCsvContent: budget,
    );
    await YnabDataMapper(
      accountRepo: t.accounts,
      categoryRepo: t.categories,
      payeeRepo: t.payees,
      transactionRepo: t.transactions,
      budgetRepo: t.budgets,
      scheduledTransactionRepo: t.scheduledTransactions,
      unitOfWork: t.unitOfWork,
    ).importData(data, currency: 'USD');
    final amex = await categoryNamed('Amex');
    expect(await t.budgeting.calculateCategoryAvailable(amex, jan), 2500);
    final category = (await t.categories.getCategoryById(amex))!;
    expect(category.categoryGroupId, isNot(CardPayments.groupId));
    await expectLedgerInvariant(t, jan);
  });
}
