// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get budget => 'Budget';

  @override
  String get home => 'Home';

  @override
  String get accounts => 'Accounts';

  @override
  String get transactions => 'Transactions';

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

  @override
  String get categories => 'Categories';

  @override
  String get addCategory => 'Add Category';

  @override
  String get manageCategories => 'Manage Categories';

  @override
  String get categoryGroup => 'Category Group';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String get categoryName => 'Category Name';

  @override
  String get createCategory => 'Create Category';

  @override
  String get editCategoryGroup => 'Edit Category Group';

  @override
  String get deleteCategoryGroup => 'Delete Category Group';

  @override
  String get newCategoryGroup => 'New Category Group';

  @override
  String get addCategoryGroup => 'Add Category Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get hideCategory => 'Hide Category';

  @override
  String get showCategory => 'Show Category';

  @override
  String get hidden => 'Hidden';

  @override
  String get reorderGroups => 'Reorder Groups';

  @override
  String get reorderCategories => 'Reorder Categories';

  @override
  String get color => 'Color';

  @override
  String get icon => 'Icon';

  @override
  String categoryHasTransactions(int count) {
    return 'This category has $count transactions. Select a new category for them.';
  }

  @override
  String get merge => 'Merge';

  @override
  String get reassign => 'Reassign';

  @override
  String get search => 'Search';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get budgeted => 'Budgeted';

  @override
  String get activity => 'Activity';

  @override
  String get available => 'Available';

  @override
  String get budgetPreviousMonth => 'Budget Previous Month';

  @override
  String get budgetAverageSpent => 'Budget Average Spent';

  @override
  String get budgetZeroOut => 'Zero Out';

  @override
  String get moveMoney => 'Move Money';

  @override
  String get moveMoneyFrom => 'Move from';

  @override
  String get moveMoneyTo => 'Move to';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get noCategoriesTitle => 'No Categories Yet';

  @override
  String get noCategoriesDescription =>
      'Create categories to start budgeting your money.';

  @override
  String get setupBudget => 'Setup Budget';

  @override
  String get budgetTutorialTitle => 'Welcome to Budgeting';

  @override
  String get budgetTutorialDescription =>
      'Tap on amounts to budget. Use quick actions for auto-assignment.';

  @override
  String get gotIt => 'Got it';

  @override
  String get total => 'Total';

  @override
  String get tbbTooltip =>
      'Income minus budgeted amount. This is what you have left to assign.';

  @override
  String get budgetedTooltip =>
      'The amount you\'ve assigned to this category for this month.';

  @override
  String get activityTooltip =>
      'The sum of all transactions (spending) in this category for this month.';

  @override
  String get availableTooltip =>
      'The amount available to spend. Calculated as Budgeted - Activity + Rollover.';

  @override
  String get categoryTooltip => 'Name of the category.';

  @override
  String assignTo(String name) {
    return 'Assign to $name';
  }

  @override
  String get viewMode => 'View Mode';

  @override
  String get budgetUpdated => 'Budget updated';

  @override
  String get undo => 'Undo';

  @override
  String get variance => 'Variance';

  @override
  String get remaining => 'Remaining';

  @override
  String get overspent => 'Overspent';

  @override
  String get underfunded => 'Underfunded';

  @override
  String get goalTarget => 'Goal Target';

  @override
  String get saveAsTemplate => 'Save as Template';

  @override
  String get applyTemplate => 'Apply Template';

  @override
  String get templateName => 'Template Name';

  @override
  String get templateSaved => 'Template saved';

  @override
  String get copyFromPreviousMonth => 'Copy from Previous Month';

  @override
  String get resetBudget => 'Reset Budget';

  @override
  String resetBudgetConfirmation(String month) {
    return 'Are you sure you want to reset the budget for $month? All budgeted amounts will be set to zero.';
  }

  @override
  String get reset => 'Reset';

  @override
  String get templates => 'Templates';

  @override
  String get noTemplates => 'No Templates';

  @override
  String get createTemplateDescription =>
      'Save your current budget allocations as a reusable template.';

  @override
  String get deleteTemplate => 'Delete Template';
}
