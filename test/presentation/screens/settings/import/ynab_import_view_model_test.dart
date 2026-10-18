import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_state.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_view_model.dart';
import 'package:ledger_zero/services/import/ynab_data_mapper.dart';
import 'package:ledger_zero/services/import/ynab_import_history.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/memory_platform_file.dart';
import '../../../../helpers/test_database.dart';

const _register =
    '"Account","Flag","Date","Payee","Category Group/Category","Category Group","Category","Memo","Outflow","Inflow","Cleared"\n'
    '"Checking","","05/03/2025","Starting Balance","Inflow: Ready to Assign","Inflow","Ready to Assign","","\$0.00","\$1,000.00","Cleared"\n'
    '"Checking","","05/04/2025","Shop","Everyday: Food","Everyday","Food","","\$10.00","\$0.00","Cleared"\n'
    '"Checking","","05/06/2025","Transfer : House","","","","","\$20.00","\$0.00","Cleared"\n'
    '"House","","05/06/2025","Transfer : Checking","","","","","\$0.00","\$20.00","Cleared"\n';
const _budget =
    '"Month","Category Group/Category","Category Group","Category","Budgeted","Activity","Available"\n';

YnabImportViewModel _viewModel(TestDatabase t, YnabImportHistory history) {
  final vm = YnabImportViewModel(
    importService: YnabImportService(),
    dataMapper: YnabDataMapper(
      accountRepo: t.accounts,
      categoryRepo: t.categories,
      payeeRepo: t.payees,
      transactionRepo: t.transactions,
      budgetRepo: t.budgets,
      scheduledTransactionRepo: t.scheduledTransactions,
      unitOfWork: t.unitOfWork,
    ),
    history: history,
  );
  vm.setMethod(YnabImportMethod.nynabCsv);
  vm.selectFiles(
    register: MemoryPlatformFile(
      name: 'Register.csv',
      bytes: _register.codeUnits,
    ),
    budget: MemoryPlatformFile(name: 'Budget.csv', bytes: _budget.codeUnits),
  );
  return vm;
}

void main() {
  test('the import currency starts at the default currency from Settings '
      'and can be changed before importing', () async {
    SharedPreferences.setMockInitialValues({'settings_currency': 'EUR'});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(t.db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(ynabImportViewModelProvider, (_, _) {});
    addTearDown(sub.close);

    expect(container.read(ynabImportViewModelProvider).currency, 'EUR');
    container.read(ynabImportViewModelProvider.notifier).setCurrency('CHF');
    expect(container.read(ynabImportViewModelProvider).currency, 'CHF');
  });

  test('the preview warns when the same export was imported before', () async {
    final t = TestDatabase();
    addTearDown(t.close);
    final history = InMemoryYnabImportHistory();

    final first = _viewModel(t, history);
    await first.validateAndParse();
    expect(first.state.currentStep, YnabImportStep.preview);
    expect(first.state.previousImportAt, isNull);
    await first.startImport();
    expect(first.state.currentStep, YnabImportStep.success);

    final second = _viewModel(t, history);
    await second.validateAndParse();
    expect(second.state.previousImportAt, isNotNull);
  });

  test('tracking accounts and the register date format can be changed in '
      'the preview', () async {
    final t = TestDatabase();
    addTearDown(t.close);
    final vm = _viewModel(t, InMemoryYnabImportHistory());
    await vm.validateAndParse();
    final data = vm.state.parsedData!;
    // Inferred: House has only a transfer leg.
    expect(data.accounts.singleWhere((a) => a.id == 'House').onBudget, isFalse);
    expect(data.registerDateFormat, 'MM/dd/yyyy');
    expect(data.dateFormatCandidates, ['MM/dd/yyyy', 'dd/MM/yyyy']);

    vm.setTracking('House', false);
    expect(
      vm.state.parsedData!.accounts
          .singleWhere((a) => a.id == 'House')
          .onBudget,
      isTrue,
    );

    await vm.setRegisterDateFormat('dd/MM/yyyy');
    final reparsed = vm.state.parsedData!;
    expect(reparsed.registerDateFormat, 'dd/MM/yyyy');
    expect(reparsed.transactions.first.date, DateTime.utc(2025, 3, 5));
    // The tracking choice survives the re-parse.
    expect(
      reparsed.accounts.singleWhere((a) => a.id == 'House').onBudget,
      isTrue,
    );

    await vm.startImport();
    expect(vm.state.currentStep, YnabImportStep.success);
    final accounts = await t.accounts.getAllAccounts();
    expect(accounts.singleWhere((a) => a.name == 'House').onBudget, isTrue);
  });
}
