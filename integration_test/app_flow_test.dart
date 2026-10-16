// The main user journey on a device, with real storage (Keychain/Keystore,
// SQLCipher file, preferences):
//
// 1. First launch: onboarding with a master password and recovery key,
//    first account, a transaction, money assigned in the budget.
// 2. Relaunch: the app starts locked; a wrong password is rejected, the
//    right one unlocks the same data; a CSV file is imported through the
//    import screens; "Lock now" returns to the login screen.
//
// The tests run in order and share the device state. Biometric unlock
// cannot be exercised on a simulator/emulator and is replaced by "not
// available".
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_calculator.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/screens/login_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:path_provider/path_provider.dart';

import 'helpers.dart';

const password = 'Correct Horse Battery 9';

/// A picked file that lives on local disk.
final class _DiskPlatformFile extends PlatformFile {
  _DiskPlatformFile(this.file);
  final File file;

  @override
  String get name => file.uri.pathSegments.last;

  @override
  Uri get uri => file.uri;

  @override
  XFile get xFile => XFile(file.path, name: name);

  @override
  int? lengthSync() => file.lengthSync();

  @override
  Future<int?> length() => file.length();

  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}

/// Returns a fixed file instead of opening the system file picker.
class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.file);
  final File file;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => _DiskPlatformFile(file);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch: onboarding, account, transaction, budget', (
    tester,
  ) async {
    await resetAppData();
    final app = await launchApp(tester);

    // Welcome slides.
    await tapWhenShown(tester, find.text('Next'));
    await tapWhenShown(tester, find.text('Next'));
    await tapWhenShown(tester, find.text('Get Started'));

    // Master password, then the recovery key (key derivation runs here).
    await waitFor(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField).at(0), password);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tapWhenShown(tester, find.text('Continue'));
    await waitFor(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tapWhenShown(tester, find.widgetWithText(ElevatedButton, 'Continue'));

    // Budget basics and completion.
    await tapWhenShown(tester, find.text("I'm ready!"));
    await tapWhenShown(tester, find.text('Create your first account'));

    // First account: 1,000.00 starting balance.
    await waitFor(tester, find.text('Create Account'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Checking');
    await tester.enterText(find.byType(TextFormField).at(1), '1000');
    await tapWhenShown(
      tester,
      find.widgetWithText(ElevatedButton, 'Create Account'),
    );
    // The first account leads to the budget.
    await waitFor(tester, find.text('Groceries'));
    await dismissTutorial(tester);

    final accounts = await app.read(accountRepositoryProvider).getAllAccounts();
    expect(accounts.map((a) => (a.name, a.balance)), [('Checking', 100000)]);
    final accountId = accounts.single.id;

    // A 12.34 expense.
    unawaited(
      app.read(routerProvider).push('/add-transaction?accountId=$accountId'),
    );
    await waitFor(tester, find.widgetWithText(AppTextField, 'Amount'));
    await dismissTutorial(tester);
    await tester.enterText(
      find.widgetWithText(AppTextField, 'Amount'),
      '12.34',
    );
    await tester.enterText(
      find.widgetWithText(AppTextField, 'Payee'),
      'Corner Shop',
    );
    await tester.pump();
    await tapWhenShown(tester, find.widgetWithIcon(IconButton, Icons.check));
    await waitForAbsent(tester, find.widgetWithText(AppTextField, 'Amount'));

    final rows = await app
        .read(transactionRepositoryProvider)
        .getAllTransactions();
    expect(rows.map((t) => t.amount), [-1234]);

    // Assign 50.00 to Groceries with the budget calculator.
    app.read(routerProvider).go('/budget');
    await waitFor(tester, find.text('Groceries'));
    await dismissTutorial(tester);
    final groceriesRow = find.ancestor(
      of: find.text('Groceries'),
      matching: find.byType(BudgetCategoryRow),
    );
    await tapWhenShown(
      tester,
      find.descendant(of: groceriesRow, matching: find.text(r'$0.00')),
    );
    await waitFor(tester, find.byType(BudgetCalculator));
    Finder calculatorKey(String label) => find
        .descendant(
          of: find.byType(BudgetCalculator),
          matching: find.text(label),
        )
        .last;
    for (final key in ['5', '0']) {
      await tapWhenShown(tester, calculatorKey(key));
    }
    await waitFor(
      tester,
      find.descendant(
        of: find.byType(BudgetCalculator),
        matching: find.text('50'),
      ),
    );
    await tapWhenShown(tester, calculatorKey('OK'));
    await waitForAbsent(tester, find.byType(BudgetCalculator));
    await tester.pump(const Duration(seconds: 1));

    final month = CalendarDate.startOfMonthUtc(CalendarDate.today());
    final budgeting = app.read(budgetingServiceProvider);
    final groceries =
        (await app.read(categoryRepositoryProvider).getAllCategories())
            .firstWhere((c) => c.name == 'Groceries');
    expect(
      await budgeting.calculateCategoryAvailable(groceries.id, month),
      5000,
    );
    // 1,000.00 - 12.34 (uncategorised) - 50.00 budgeted.
    expect(await budgeting.calculateTBB(month), 100000 - 1234 - 5000);

    await closeApp(tester, app);
  });

  testWidgets('relaunch: locked, password unlock, CSV import, lock now', (
    tester,
  ) async {
    final app = await launchApp(tester);
    await waitFor(tester, find.byType(LoginScreen));
    expect(find.byType(HomeScreen), findsNothing);

    // A wrong password keeps the app locked.
    await tester.enterText(find.byType(TextField).first, 'not the password');
    await tapWhenShown(tester, find.text('Unlock'));
    await waitFor(tester, find.text('Incorrect Password'));
    expect(app.read(appLockStateProvider), AppLockState.locked);

    await tester.enterText(find.byType(TextField).first, password);
    await tapWhenShown(tester, find.text('Unlock'));
    await waitFor(tester, find.byType(HomeScreen));
    await dismissTutorial(tester);
    expect(app.read(appLockStateProvider), AppLockState.unlocked);

    // The data of the first launch is there (same keyed database file).
    final accounts = await app.read(accountRepositoryProvider).getAllAccounts();
    expect(accounts.map((a) => (a.name, a.balance)), [
      ('Checking', 100000 - 1234),
    ]);

    // CSV import through the import screens (the system picker is faked).
    final dir = await getTemporaryDirectory();
    final csv = File('${dir.path}/it_import.csv')
      ..writeAsStringSync(
        'Date,Payee,Amount,Memo\n'
        '2024-03-01,Employer,2500.00,Salary\n'
        '2024-03-02,Bakery,-4.50,Bread\n'
        '2024-03-03,Grocer,-45.67,\n',
      );
    FilePickerPlatform.instance = _FakeFilePicker(csv);
    unawaited(app.read(routerProvider).push('/settings/import-csv'));
    await tapWhenShown(tester, find.text('Select File'));
    await tapWhenShown(tester, find.text('Continue to Review'));
    await tapWhenShown(tester, find.text('Import'));
    // Account dialog (the only account is preselected).
    await waitFor(tester, find.byType(AlertDialog));
    await tapWhenShown(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Import'),
      ),
    );
    await waitFor(tester, find.text('Import Successful'));
    await tapWhenShown(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Transactions'),
      ),
    );
    csv.deleteSync();

    final after = await app.read(accountRepositoryProvider).getAllAccounts();
    expect(after.single.balance, 100000 - 1234 + 250000 - 450 - 4567);

    // Lock now: back to the login screen, the database is closed.
    await app.read(sessionProvider.notifier).lock();
    await waitFor(tester, find.byType(LoginScreen));
    expect(app.read(appLockStateProvider), AppLockState.locked);

    await closeApp(tester, app);
    await resetAppData();
  });
}
