// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get budget => 'Budget';

  @override
  String get home => 'Startseite';

  @override
  String get accounts => 'Konten';

  @override
  String get transactions => 'Transaktionen';

  @override
  String get toBeBudgeted => 'To Be Budgeted';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get totalSpending => 'Total Spending';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get noRecentTransactions => 'No recent transactions';

  @override
  String get addTransaction => 'Add Transaction';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get welcomeToLedgerZero => 'Welcome to LedgerZero';

  @override
  String get createFirstAccountMessage =>
      'Create your first account to get started with budgeting.';

  @override
  String get createAccount => 'Create Account';

  @override
  String get accountDetails => 'Account Details';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get accountNotFound => 'Account not found';

  @override
  String get noTransactions => 'No transactions';

  @override
  String get unknownPayee => 'Unknown Payee';

  @override
  String get balanceTrend => 'Balance Trend';

  @override
  String get noTransactionsTrend => 'No transactions to show trend';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get closeAccount => 'Close Account';

  @override
  String get reopenAccount => 'Reopen Account';

  @override
  String get reconcileAccount => 'Reconcile Account';

  @override
  String get exportToCsv => 'Export to CSV';

  @override
  String get deleteAccountConfirmation =>
      'Are you sure you want to delete this account? This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String exportedTo(String path) {
    return 'Exported to $path';
  }

  @override
  String currentBalance(double balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
    );
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Current Balance: $balanceString';
  }

  @override
  String get enterActualBalance => 'Enter Actual Balance';

  @override
  String get discrepancyFound => 'Discrepancy Found';

  @override
  String discrepancyMessage(String diff) {
    return 'There is a difference of $diff. Create an adjustment transaction?';
  }

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get reconcile => 'Reconcile';

  @override
  String get accountReconciled => 'Account Reconciled!';

  @override
  String get adjustmentCreated => 'Adjustment created and account reconciled.';

  @override
  String get amount => 'Amount';

  @override
  String get inflow => 'Inflow';

  @override
  String get outflow => 'Outflow';

  @override
  String get payee => 'Payee';

  @override
  String get category => 'Category';

  @override
  String get account => 'Account';

  @override
  String get memo => 'Memo';

  @override
  String get notes => 'Notes';

  @override
  String get date => 'Date';

  @override
  String get cleared => 'Cleared';

  @override
  String get uncleared => 'Uncleared';

  @override
  String get save => 'Save';

  @override
  String get saveAndAddAnother => 'Save & Add Another';

  @override
  String get transfer => 'Transfer';

  @override
  String get split => 'Split';

  @override
  String get recurring => 'Recurring';

  @override
  String get invalidAmount => 'Please enter a valid amount';

  @override
  String get selectAccount => 'Please select an account';

  @override
  String get transactionSaved => 'Transaction saved';

  @override
  String get toAccount => 'To Account';

  @override
  String get frequency => 'Frequency';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';
}
