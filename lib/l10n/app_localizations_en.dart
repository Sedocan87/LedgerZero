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
  String get reports => 'Reports';

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
  String get loading => 'Loading…';

  @override
  String get error => 'Error';

  @override
  String get warning => 'Warning';

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
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

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
  String get addCategoryGroup => 'Add Category Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get hideCategory => 'Hide Category';

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
  String get merge => 'Merge';

  @override
  String get search => 'Search';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get selectFileToImport => 'Select a CSV file to import';

  @override
  String get changeFile => 'Change File';

  @override
  String get selectFile => 'Select File';

  @override
  String get dateFormat => 'Date Format';

  @override
  String get decimalSeparator => 'Decimal Separator';

  @override
  String get dot => 'Dot (.)';

  @override
  String get comma => 'Comma (,)';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get numberFormatSystem => 'Follow language';

  @override
  String get negativeValuesAreOutflows => 'Negative values are outflows';

  @override
  String get columnMapping => 'Column Mapping';

  @override
  String get selectColumn => 'Select Column';

  @override
  String get ignore => 'Ignore';

  @override
  String get continueToReview => 'Continue to Review';

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
  String get budgetedTooltip =>
      'The amount you\'ve assigned to this category for this month.';

  @override
  String get activityTooltip =>
      'The sum of this month\'s transactions in this category.';

  @override
  String get availableTooltip =>
      'What you can still spend: budgeted plus activity plus what carried over from last month.';

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

  @override
  String get spendingByCategory => 'Spending by Category';

  @override
  String get incomeVsExpense => 'Income vs Expense';

  @override
  String get netWorth => 'Net Worth';

  @override
  String get spendingTrends => 'Spending Trends';

  @override
  String get topPayees => 'Top Payees';

  @override
  String get categoryBreakdown => 'Category Breakdown';

  @override
  String get dateRange => 'Date Range';

  @override
  String get thisMonth => 'This Month';

  @override
  String get lastMonth => 'Last Month';

  @override
  String get last3Months => 'Last 3 Months';

  @override
  String get last6Months => 'Last 6 Months';

  @override
  String get thisYear => 'This Year';

  @override
  String get lastYear => 'Last Year';

  @override
  String get allTime => 'All Time';

  @override
  String get custom => 'Custom';

  @override
  String get series => 'Series';

  @override
  String get exportReport => 'Export Report';

  @override
  String get selectReportToExport => 'Select Report';

  @override
  String get exportFormat => 'Format';

  @override
  String get csv => 'CSV';

  @override
  String get pdf => 'PDF';

  @override
  String get image => 'Image';

  @override
  String get share => 'Share';

  @override
  String get exporting => 'Exporting…';

  @override
  String get budgetVsActual => 'Budget vs Actual';

  @override
  String get filterCategories => 'Filter Categories';

  @override
  String get clear => 'Clear';

  @override
  String get apply => 'Apply';

  @override
  String get noNotes => 'No notes for this period.';

  @override
  String get addNote => 'Add Note';

  @override
  String get editNote => 'Edit Note';

  @override
  String get month => 'Month';

  @override
  String get note => 'Note';

  @override
  String get enterNote => 'Please enter a note';

  @override
  String get deleteNoteConfirmationTitle => 'Delete Note?';

  @override
  String get deleteNoteConfirmationMessage => 'This action cannot be undone.';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get noteSaved => 'Note saved';

  @override
  String get settings => 'Settings';

  @override
  String get payees => 'Payees';

  @override
  String get payeeName => 'Payee Name';

  @override
  String get mergePayee => 'Merge Payee';

  @override
  String mergePayeeInto(String name) {
    return 'Merge into $name';
  }

  @override
  String get deletePayeeConfirmation => 'Delete Payee?';

  @override
  String deletePayeeWarning(String name) {
    return 'Are you sure you want to delete $name? Transactions will be preserved but the payee field will be cleared.';
  }

  @override
  String mergeWarning(String target) {
    return 'All transactions from this payee will be moved to $target. This action cannot be undone.';
  }

  @override
  String get noPayees => 'No Payees';

  @override
  String get searchPayees => 'Search Payees';

  @override
  String get rename => 'Rename';

  @override
  String get defaultAccount => 'Default Account';

  @override
  String get usageStats => 'Usage Statistics';

  @override
  String get timesUsed => 'Times Used';

  @override
  String get totalSpent => 'Total Spent';

  @override
  String get lastUsed => 'Last Used';

  @override
  String get autoCategory => 'Auto Category';

  @override
  String get configuration => 'Configuration';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get none => 'None';

  @override
  String get defaultLabel => 'Default';

  @override
  String get scheduledTransactions => 'Scheduled Transactions';

  @override
  String get nextDate => 'Next Date';

  @override
  String get endDate => 'End Date';

  @override
  String get autoApprove => 'Auto Approve';

  @override
  String get createScheduledTransaction => 'Create Scheduled Transaction';

  @override
  String get editScheduledTransaction => 'Edit Scheduled Transaction';

  @override
  String get schedule => 'Schedule';

  @override
  String get noScheduledTransactions => 'No Scheduled Transactions';

  @override
  String get createScheduledTransactionDescription =>
      'Create scheduled transactions for recurring bills or income.';

  @override
  String get skip => 'Skip';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get repeatEvery => 'Repeat Every';

  @override
  String unitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Days',
      one: 'Day',
    );
    return '$_temp0';
  }

  @override
  String unitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Weeks',
      one: 'Week',
    );
    return '$_temp0';
  }

  @override
  String unitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Months',
      one: 'Month',
    );
    return '$_temp0';
  }

  @override
  String unitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Years',
      one: 'Year',
    );
    return '$_temp0';
  }

  @override
  String get end => 'End';

  @override
  String get never => 'Never';

  @override
  String get onDate => 'On Date';

  @override
  String get afterOccurrences => 'After';

  @override
  String get occurrences => 'Occurrences';

  @override
  String get recoveryKey => 'Recovery Key';

  @override
  String get revealRecoveryKey => 'Reveal Recovery Key';

  @override
  String get autoLock => 'Auto-lock Timer';

  @override
  String get autoLockImmediate => 'Immediate';

  @override
  String autoLockMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minutes',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get autoLockNever => 'Never';

  @override
  String get incorrectPassword => 'Incorrect Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get biometrics => 'Biometric Authentication';

  @override
  String get encryptionStatus => 'Encryption Status';

  @override
  String get encrypted => 'Encrypted';

  @override
  String get secure => 'Secure';

  @override
  String get securitySettings => 'Security Settings';

  @override
  String get securityAndData => 'Security & Data';

  @override
  String get syncSettings => 'Sync Settings';

  @override
  String get connectToGoogleDrive => 'Connect to Google Drive';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get googleDriveSync => 'Google Drive Sync';

  @override
  String lastSynced(String time) {
    return 'Last Synced: $time';
  }

  @override
  String get syncProvider => 'Sync Provider';

  @override
  String get providerNone => 'None';

  @override
  String get providerGoogleDrive => 'Google Drive';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get syncOnlyOnWifi => 'Sync only on Wi-Fi';

  @override
  String get syncFrequency => 'Sync Frequency';

  @override
  String get frequencyManual => 'Manual';

  @override
  String get frequencyRealtime => 'Real-time';

  @override
  String get frequency15Min => 'Every 15 Minutes';

  @override
  String get frequency1Hour => 'Every Hour';

  @override
  String get frequency4Hours => 'Every 4 Hours';

  @override
  String get quickAdd => 'Quick Add';

  @override
  String get preview => 'Preview';

  @override
  String get confidence => 'Confidence';

  @override
  String get noAmount => 'No amount';

  @override
  String get payeeNotFound => 'Payee not found';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get editDetails => 'Edit Details';

  @override
  String get create => 'Create';

  @override
  String get parsingTips => 'Parsing Tips';

  @override
  String get parsingTipsDescription => 'Type naturally to create transactions.';

  @override
  String get saveImportProfile => 'Save Import Profile';

  @override
  String get profileName => 'Profile Name';

  @override
  String get profileSaved => 'Import profile saved';

  @override
  String get loadImportProfile => 'Load Profile';

  @override
  String get deleteProfileConfirmation =>
      'Are you sure you want to delete this profile?';

  @override
  String get confirmImport => 'Confirm Import';

  @override
  String get confirmImportDescription =>
      'Review and confirm transactions to import.';

  @override
  String importedTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count transactions',
      one: 'Imported 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get importSuccess => 'Import Successful';

  @override
  String get duplicateWarning =>
      'Warning: This transaction might be a duplicate.';

  @override
  String deduplicationComplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Duplicate check complete. $count duplicates found.',
      one: 'Duplicate check complete. 1 duplicate found.',
      zero: 'Duplicate check complete. No duplicates found.',
    );
    return '$_temp0';
  }

  @override
  String get generalSettings => 'General Settings';

  @override
  String get currency => 'Currency';

  @override
  String get firstDayOfWeek => 'First Day of Week';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get defaultCategory => 'Default Category';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get monday => 'Monday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get numberFormat => 'Number Format';

  @override
  String get loadingAccounts => 'Loading accounts…';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get scheduledTransactionNotifications => 'Scheduled Transactions';

  @override
  String get budgetAlertNotifications => 'Budget Alerts';

  @override
  String get syncStatusNotifications => 'Sync Status';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get cacheCleared => 'Cache cleared successfully';

  @override
  String get factoryReset => 'Factory Reset';

  @override
  String get factoryResetConfirmation =>
      'Are you sure you want to perform a factory reset? This will delete ALL data including transactions, budgets, and settings. This action cannot be undone.';

  @override
  String get factoryResetTitle => 'Factory Reset?';

  @override
  String get factoryResetSuccess =>
      'Factory reset complete. Please restart the app.';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get faq => 'FAQ';

  @override
  String get faqSubtitle => 'Frequently asked questions';

  @override
  String get userGuide => 'User Guide';

  @override
  String get userGuideSubtitle => 'How LedgerZero works';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get contactSupportSubtitle => 'support@ledgerzero.app';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get serverError => 'Server communication failed';

  @override
  String get cacheError => 'Failed to load cached data';

  @override
  String get databaseError => 'Database operation failed';

  @override
  String get syncError => 'Synchronization failed';

  @override
  String get retry => 'Retry';

  @override
  String get ok => 'OK';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get incomeAndSalaries => 'Income & Salaries';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get reducedMotion => 'Reduced Motion';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get addSplit => 'Add Split';

  @override
  String get scheduledTransactionDefaultMemo => 'Scheduled transaction';

  @override
  String deleteNamedTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String deleteCategoryTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This category has $count transactions.',
      one: 'This category has 1 transaction.',
      zero: 'This category has no transactions.',
    );
    return '$_temp0';
  }

  @override
  String get deleteCategoryMoveOption => 'Move everything to another category';

  @override
  String get deleteCategoryMoveExplanation =>
      'Transactions, budgeted amounts, rules, scheduled transactions and payee defaults move to the selected category. To Be Budgeted does not change.';

  @override
  String get deleteCategoryNoTargetOption => 'Delete without replacement';

  @override
  String get deleteCategoryNoTargetExplanation =>
      'The money budgeted in this category goes back to To Be Budgeted. Its transactions become uncategorized and also count towards To Be Budgeted. Rules, scheduled transactions and payee defaults that use it are cleared.';

  @override
  String get deleteCategoryTargetLabel => 'Target category';

  @override
  String get deleteCategoryNoOtherCategories =>
      'There is no other category to move to.';

  @override
  String get deleteCategoryFailed =>
      'The category could not be deleted. Please try again.';

  @override
  String get categoryDeletedMessage => 'Category deleted';

  @override
  String get deleteGroupEmptyConfirmation =>
      'This group contains no categories. Delete it?';

  @override
  String deleteGroupMoveExplanation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This group contains $count categories.',
      one: 'This group contains 1 category.',
    );
    return '$_temp0 Choose a group to move them to. Their budgets and transactions move with them.';
  }

  @override
  String get deleteGroupTargetLabel => 'Move categories to';

  @override
  String get deleteGroupNoOtherGroup =>
      'This group contains categories and there is no other group to move them to. Create another group or delete its categories first.';

  @override
  String get deleteGroupFailed =>
      'The group could not be deleted. Please try again.';

  @override
  String get deleteAccountCloseRecommendation =>
      'Recommended: close the account instead. A closed account is hidden from everyday use but keeps all transactions and history.';

  @override
  String get deleteAccountPermanentWarning =>
      'Deleting permanently removes all of this account\'s transactions and scheduled transactions. This cannot be undone.';

  @override
  String get deleteAccountTransfersWarning =>
      'Transfers to or from other accounts stay in those accounts as normal uncategorized transactions, which changes To Be Budgeted.';

  @override
  String get closeAccountInstead => 'Close account instead';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get accountClosedMessage => 'Account closed';

  @override
  String accountDeletedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Account deleted. $count transfers in other accounts are now normal transactions.',
      one:
          'Account deleted. 1 transfer in another account is now a normal transaction.',
      zero: 'Account deleted.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountFailed =>
      'The account could not be deleted. Please try again.';

  @override
  String get accountUpdateFailed =>
      'The account could not be updated. Please try again.';

  @override
  String transferToAccount(String account) {
    return 'Transfer to $account';
  }

  @override
  String transferFromAccount(String account) {
    return 'Transfer from $account';
  }

  @override
  String get deletePayeeFailed =>
      'The payee could not be deleted. Please try again.';

  @override
  String get mergePayeeFailed =>
      'The payees could not be merged. Please try again.';

  @override
  String get reconcileAdjustmentMemo => 'Reconciliation balance adjustment';

  @override
  String get reconcileWorkingBalance => 'Working balance';

  @override
  String get reconcileClearedBalance => 'Cleared balance';

  @override
  String get reconcileClearedUpToDate =>
      'Cleared balance up to the statement date';

  @override
  String get reconcileStatementDate => 'Statement date';

  @override
  String get reconcileStatementBalance => 'Statement balance';

  @override
  String get reconcileDifference => 'Difference';

  @override
  String get reconcileExplanation =>
      'All cleared transactions up to the statement date will be marked as reconciled. If the cleared balance differs from the statement, an uncategorized adjustment is created; it counts towards To Be Budgeted.';

  @override
  String reconcileResultMatched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count transactions reconciled. The balance matches the statement.',
      one: '1 transaction reconciled. The balance matches the statement.',
      zero: 'No transactions to reconcile. The balance matches the statement.',
    );
    return '$_temp0';
  }

  @override
  String reconcileResultAdjusted(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions reconciled.',
      one: '1 transaction reconciled.',
      zero: 'No transactions reconciled.',
    );
    return '$_temp0 An adjustment of $amount was created.';
  }

  @override
  String get reconcileFailed =>
      'The account could not be reconciled. Please try again.';

  @override
  String get fromAccount => 'From Account';

  @override
  String get txSplitSumMismatch =>
      'The split amounts must add up to the total amount.';

  @override
  String get txSplitLineZero => 'Every split line needs an amount.';

  @override
  String get txTransferSameAccount =>
      'Source and destination accounts must be different.';

  @override
  String get txTransferNoSplit => 'A transfer cannot be split.';

  @override
  String get txRecurringSplitUnsupported =>
      'Recurring split transactions are not supported yet.';

  @override
  String get txRecurringTransferUnsupported =>
      'Recurring transfers are not supported yet.';

  @override
  String get txScheduledCreated => 'Scheduled transaction created';

  @override
  String get txSaveFailed => 'The transaction could not be saved.';

  @override
  String get txReconciledChangeTitle => 'Change a reconciled transaction?';

  @override
  String get txReconciledChangeMessage =>
      'This transaction is already reconciled with a bank statement. If you change it, your reconciled balance no longer matches that statement.';

  @override
  String get txReconciledDeleteMessage =>
      'This includes transactions already reconciled with a bank statement. If you delete them, your reconciled balance no longer matches that statement.';

  @override
  String get txChangeAnyway => 'Change anyway';

  @override
  String get txDeleteTitle => 'Delete transaction?';

  @override
  String txDeleteManyTitle(int count) {
    return 'Delete $count transactions?';
  }

  @override
  String get txDeleteMessage => 'You can undo this right after deleting.';

  @override
  String get txDeleteTransferNote =>
      'The other side of the transfer is deleted too.';

  @override
  String get txDeleteSplitNote =>
      'The whole split transaction with all of its lines is deleted.';

  @override
  String txDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions deleted',
      one: 'Transaction deleted',
    );
    return '$_temp0';
  }

  @override
  String get txActionFailed => 'That did not work. Please try again.';

  @override
  String get txSearchHint => 'Search payee, category, memo or amount';

  @override
  String get txFilterPayees => 'Payees';

  @override
  String get txFilterAmountFrom => 'Amount from';

  @override
  String get txFilterAmountTo => 'Amount to';

  @override
  String txCategoryActivityTitle(String category, String month) {
    return '$category: $month';
  }

  @override
  String get continueAction => 'Continue';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get masterPasswordLabel => 'Master password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String passwordMinLength(int count) {
    return 'Use at least $count characters';
  }

  @override
  String get passwordTooCommon =>
      'This password is too common. Please choose another one.';

  @override
  String get passwordHint =>
      'A long passphrase of several words is easiest to remember.';

  @override
  String passwordStrengthTitle(String label) {
    return 'Password strength: $label';
  }

  @override
  String get passwordStrengthTooShort => 'too short';

  @override
  String get passwordStrengthCommon => 'too common';

  @override
  String get passwordStrengthWeak => 'weak';

  @override
  String get passwordStrengthFair => 'fair';

  @override
  String get passwordStrengthGood => 'good';

  @override
  String get passwordStrengthStrong => 'strong';

  @override
  String get setupProtectTitle => 'Protect your data';

  @override
  String get setupFailed => 'Security setup failed. Please try again.';

  @override
  String get biometricPromptTitle => 'Unlock LedgerZero';

  @override
  String get biometricPromptSubtitle => 'Confirm it is you to unlock your data';

  @override
  String get loginUnlock => 'Unlock';

  @override
  String get loginUseBiometrics => 'Use biometrics';

  @override
  String get loginUseRecoveryKey => 'Use recovery key';

  @override
  String get loginVaultMissing =>
      'The key data of this app is missing, so your data cannot be unlocked. You can reset the app and restore a backup.';

  @override
  String get loginDatabaseKeyMismatch =>
      'Your key is correct, but the database file could not be opened with it.';

  @override
  String get loginFailed => 'Unlocking failed. Please try again.';

  @override
  String get biometricsInvalidated =>
      'Biometric unlock was turned off because the biometrics on this device changed. Unlock with your password and turn it on again in Settings.';

  @override
  String get biometricsUnlockFailed =>
      'Biometric unlock failed. Please use your password.';

  @override
  String get recoveryKeyEnterTitle => 'Enter your recovery key';

  @override
  String get recoveryKeyEnterHint =>
      '32 characters; spaces and dashes are optional';

  @override
  String get recoveryKeyInvalid => 'This recovery key is not correct.';

  @override
  String get recoveryKeyNeedsPassword =>
      'An update is still being completed. Please unlock once with your password.';

  @override
  String get encryptionStatusEncrypted => 'Encrypted with SQLCipher (AES-256)';

  @override
  String get encryptionStatusPlaintext => 'The database file is NOT encrypted';

  @override
  String get encryptionStatusUnknown => 'Not checked yet';

  @override
  String get lockNow => 'Lock now';

  @override
  String get privacySection => 'Privacy';

  @override
  String get crashReportsTitle => 'Save crash reports';

  @override
  String get crashReportsSubtitle =>
      'Off by default. When on, errors are recorded on this device only, with amounts, e-mail addresses and database values removed. Nothing is sent unless you share the log yourself.';

  @override
  String get notificationAmountsTitle => 'Show amounts in notifications';

  @override
  String get notificationAmountsSubtitle =>
      'When off, reminders only say that a transaction is due, so no financial details appear on the lock screen.';

  @override
  String get diagnosticsTitle => 'Diagnostic log';

  @override
  String get diagnosticsSubtitle => 'Review and share saved crash reports';

  @override
  String get diagnosticsEmpty => 'No diagnostic data saved.';

  @override
  String get diagnosticsShareExplanation =>
      'This is exactly what will be shared. Please review it before sending it to anyone.';

  @override
  String get diagnosticsShare => 'Share diagnostic log';

  @override
  String get diagnosticsDelete => 'Delete diagnostic data';

  @override
  String get diagnosticsDeleted => 'Diagnostic data deleted';

  @override
  String get notificationScheduledTitle => 'Upcoming transaction';

  @override
  String get notificationScheduledBodyGeneric =>
      'A scheduled transaction is due tomorrow.';

  @override
  String notificationScheduledBodyAmount(String amount) {
    return 'A scheduled transaction of $amount is due tomorrow.';
  }

  @override
  String get backupCreateTitle => 'Create backup';

  @override
  String get backupCreateExplanation =>
      'A full copy of your data, always encrypted with a backup password you choose. Keep this password: without it the backup cannot be opened. For a readable copy, use the JSON or CSV export instead.';

  @override
  String get backupPasswordLabel => 'Backup password';

  @override
  String get backupUploadToCloud => 'Also upload to your sync storage';

  @override
  String get backupUploadNotConfigured => 'Set up Google Drive sync first';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupCreating => 'Creating backup…';

  @override
  String get backupUploaded => 'Backup uploaded';

  @override
  String get backupUploadFailed =>
      'Upload failed. The backup was still created and can be shared.';

  @override
  String get backupFailed => 'The backup failed. Please try again.';

  @override
  String get backupShareSubject => 'LedgerZero backup';

  @override
  String get restoreTitle => 'Restore backup';

  @override
  String get restoreExplanation =>
      'Replace all data on this device with a backup file (.lzbk).';

  @override
  String get restoreFromFile => 'Restore from file';

  @override
  String get restoreSelective =>
      'Merge transactions from a backup (date range)';

  @override
  String get restorePasswordTitle => 'Enter the backup password';

  @override
  String get restoreConfirmTitle => 'Replace all data?';

  @override
  String get restoreConfirmMessage =>
      'Everything on this device will be replaced by the backup. If you use sync, changes made on your other devices after this backup was created will sync back in.';

  @override
  String get restoreAction => 'Restore';

  @override
  String get restoreSuccessTitle => 'Restore complete';

  @override
  String get restoreSuccessMessage =>
      'Your data was restored. If you use sync, this device will resynchronise and newer changes from your other devices will come back in.';

  @override
  String get restoreWrongPassword =>
      'Wrong backup password, or the file is damaged.';

  @override
  String get restoreInvalidFile =>
      'This file is not a LedgerZero backup that can be restored.';

  @override
  String get restoreNewerVersion =>
      'This backup was made by a newer version of LedgerZero. Please update the app first.';

  @override
  String get restoreFailed => 'The restore failed. Your data was not changed.';

  @override
  String get selectiveRestoreSuccess => 'Transactions merged.';

  @override
  String get syncPassphraseSetTitle => 'Set a sync passphrase';

  @override
  String get syncPassphraseSetExplanation =>
      'Your data is encrypted before it leaves this device. Choose a sync passphrase: you need to enter it on every device you want to sync. It cannot be recovered, not even by the developer, so keep it somewhere safe.';

  @override
  String get syncPassphraseEnterTitle => 'Enter your sync passphrase';

  @override
  String get syncPassphraseEnterExplanation =>
      'This sync folder is already used by another device. Enter the sync passphrase you set there.';

  @override
  String get syncPassphraseLabel => 'Sync passphrase';

  @override
  String get syncPassphraseConfirmLabel => 'Confirm sync passphrase';

  @override
  String get syncPassphraseSetButton => 'Set passphrase';

  @override
  String get syncPassphraseEnterButton => 'Enter passphrase';

  @override
  String get syncPassphraseWrong => 'Wrong sync passphrase.';

  @override
  String get syncPassphraseFolderExists =>
      'Another device has just set up sync. Enter the passphrase set there.';

  @override
  String get syncPassphraseFailed =>
      'The sync passphrase could not be saved. Please try again.';

  @override
  String syncPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to upload',
      one: '1 change waiting to upload',
      zero: 'All changes uploaded',
    );
    return '$_temp0';
  }

  @override
  String get syncUpdateAppRequired =>
      'Another device uses a newer version of LedgerZero. Update the app to sync its changes.';

  @override
  String get syncLegacyFolderFound =>
      'The sync folder still contains files from an older LedgerZero version (ending in .json.gz). They are no longer used and can be deleted.';

  @override
  String syncQuarantineTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count change files could not be applied',
      one: '1 change file could not be applied',
    );
    return '$_temp0';
  }

  @override
  String get syncQuarantineExplanation =>
      'Changes from the affected device wait until the file can be applied. Other devices keep syncing.';

  @override
  String get syncQuarantineRetry => 'Retry';

  @override
  String get syncQuarantineShare => 'Share diagnostics';

  @override
  String get syncQuarantineSkip => 'Skip file';

  @override
  String get syncQuarantineSkipConfirm =>
      'The changes in this file will not be applied on this device. Skip it?';

  @override
  String get syncConflictsTitle => 'Sync conflicts';

  @override
  String syncConflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes were replaced by newer ones',
      one: '1 change was replaced by a newer one',
      zero: 'No conflicts',
    );
    return '$_temp0';
  }

  @override
  String get syncConflictsExplanation =>
      'These edits made on this device lost against newer edits made on another device. Keep yours to apply them again on all devices.';

  @override
  String get syncConflictsEmpty => 'No sync conflicts.';

  @override
  String get syncConflictKeepMine => 'Keep mine';

  @override
  String get syncConflictDismiss => 'Dismiss';

  @override
  String get syncConflictKeepFailed =>
      'Your version could not be restored because it refers to data that was deleted.';

  @override
  String get syncConflictMine => 'This device';

  @override
  String get syncConflictTheirs => 'Other device';

  @override
  String get syncConflictDeleted => 'Deleted';

  @override
  String syncConflictResolvedAt(String time) {
    return 'Replaced on $time';
  }

  @override
  String get syncTableAccounts => 'Account';

  @override
  String get syncTableCategories => 'Category';

  @override
  String get syncTableCategoryGroups => 'Category group';

  @override
  String get syncTableTransactions => 'Transaction';

  @override
  String get syncTablePayees => 'Payee';

  @override
  String get syncTableBudgets => 'Budget';

  @override
  String get syncTableScheduledTransactions => 'Scheduled transaction';

  @override
  String get syncTableBudgetTemplates => 'Budget template';

  @override
  String get syncTableReportNotes => 'Report note';

  @override
  String get syncTableImportProfiles => 'Import profile';

  @override
  String get syncTableRules => 'Rule';

  @override
  String syncStatusConnectedAs(String email) {
    return 'Connected as $email';
  }

  @override
  String get syncStatusConnected => 'Connected';

  @override
  String get syncStatusDisconnected => 'Disconnected';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusPaused => 'Paused while the app is locked';

  @override
  String get pickerNoMatches => 'No matches';

  @override
  String get scheduledDeleteConfirmation =>
      'Delete this scheduled transaction? Transactions it has already created are kept.';

  @override
  String get scheduledSaveFailed =>
      'The scheduled transaction could not be saved. Please try again.';

  @override
  String get scheduledLoadFailed =>
      'The scheduled transaction could not be loaded.';

  @override
  String get scheduledActionFailed =>
      'The scheduled transaction could not be updated. Please try again.';

  @override
  String get incomeEmpty => 'No recurring income set up';

  @override
  String get incomeAddTitle => 'Add Salary / Income';

  @override
  String get incomeAddButton => 'Add Income';

  @override
  String get incomeEditTitle => 'Edit Income';

  @override
  String get incomeUnknownSource => 'Unknown source';

  @override
  String get incomeSourceName => 'Source name (e.g. My Salary)';

  @override
  String get incomeNameRequired => 'Please enter a name';

  @override
  String get incomeDepositAccount => 'Deposit account';

  @override
  String get incomeSaveButton => 'Save Income';

  @override
  String get incomeSaveFailed =>
      'The income could not be saved. Please try again.';

  @override
  String recurrenceEvery(int count, String unit) {
    return 'Every $count $unit';
  }

  @override
  String get ynabImportTitle => 'YNAB Migration';

  @override
  String get ynabImportSelectVersion => 'Select your YNAB version';

  @override
  String get ynabImportMethodCsv => 'nYNAB (CSV Export)';

  @override
  String get ynabImportMethodYnab4 => 'YNAB 4 (Classic)';

  @override
  String get ynabImportMethodHint =>
      'For nYNAB: Export your budget as CSV from the web app.\nFor YNAB 4: Select your budget folder (ending in .ynab4).';

  @override
  String get ynabImportUploadCsvTitle => 'Upload CSV Files';

  @override
  String get ynabImportNotSelected => 'Not selected';

  @override
  String get ynabImportNextPreview => 'Next: Preview';

  @override
  String get ynabImportSelectFolderTitle => 'Select YNAB4 Folder';

  @override
  String get ynabImportBudgetFolder => 'Budget Folder';

  @override
  String get ynabImportPreviewTitle => 'Import Preview';

  @override
  String get ynabImportPreviewSubtitle =>
      'Review the data found in your import files.';

  @override
  String get ynabImportAccountClosed => 'Closed';

  @override
  String get ynabImportAccountActive => 'Active';

  @override
  String get ynabImportAccountTypeChecking => 'Checking';

  @override
  String get ynabImportAccountTypeSavings => 'Savings';

  @override
  String get ynabImportAccountTypeCredit => 'Credit card';

  @override
  String get ynabImportAccountTypeCash => 'Cash';

  @override
  String ynabImportAccountSubtitle(String type, String status) {
    return '$type • $status';
  }

  @override
  String ynabImportCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String get ynabImportTotalTransactions => 'Total Transactions';

  @override
  String get ynabImportBudgetEntries => 'Budget Entries';

  @override
  String get ynabImportScheduledTransactions => 'Scheduled Transactions';

  @override
  String get ynabImportConfirm => 'Confirm & Import';

  @override
  String get ynabImportInProgressTitle => 'Migrating your budget…';

  @override
  String get ynabImportInProgressBody =>
      'This may take a moment depending on the size of your history.';

  @override
  String get ynabImportDoNotClose =>
      'Please do not close the app or switch screens.';

  @override
  String get ynabImportSuccessTitle => 'Welcome to LedgerZero!';

  @override
  String get ynabImportSuccessBody =>
      'Your YNAB data has been successfully migrated.';

  @override
  String get ynabImportStartBudgeting => 'Start Budgeting';

  @override
  String get ynabImportErrorFilePick =>
      'The file could not be opened. Please try again.';

  @override
  String get ynabImportErrorFolderPick =>
      'The folder could not be opened. Please try again.';

  @override
  String get ynabImportErrorFilesMissing =>
      'Please select both Register.csv and Budget.csv.';

  @override
  String get ynabImportErrorFolderMissing =>
      'Please select the YNAB 4 budget folder.';

  @override
  String ynabImportErrorMissingColumns(String columns) {
    return 'Register.csv is missing required columns: $columns. Please export the register again from YNAB.';
  }

  @override
  String get ynabImportErrorInvalidYnab4 =>
      'This folder is not a valid YNAB 4 budget. Please select the folder ending in .ynab4.';

  @override
  String get ynabImportErrorUnreadable =>
      'The selected files could not be read. Please check that they are unmodified YNAB exports.';

  @override
  String get ynabImportErrorImportFailed =>
      'The import failed. No data was changed; please try again.';

  @override
  String get exportFailedGeneric => 'Export failed. Please try again.';

  @override
  String get emptyAccountTransactionsMessage =>
      'Transactions you add to this account appear here.';

  @override
  String get noMatchingTransactions => 'No matching transactions';

  @override
  String get noMatchingTransactionsMessage =>
      'Try a different search or clear the filters.';

  @override
  String get emptyTransactionsMessage =>
      'Record your first transaction to see it here.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get rules => 'Rules';

  @override
  String get rulesSettingsSubtitle =>
      'Categorize new and imported transactions automatically';

  @override
  String get settingsManageSection => 'Manage data';

  @override
  String get importFailedGeneric =>
      'Import failed. Please check the file and try again.';

  @override
  String get clearCacheFailed => 'Could not clear the cache.';

  @override
  String get backupAndExport => 'Backup & Export';

  @override
  String get exportPlaintextWarning =>
      'Exports are not encrypted: anyone who gets the file can read it.';

  @override
  String get exportAllCsv => 'All transactions (CSV)';

  @override
  String get exportAllCsvSubtitle => 'A spreadsheet of every transaction';

  @override
  String get exportFilteredCsv => 'Filtered transactions (CSV)';

  @override
  String get exportFilteredCsvSubtitle =>
      'Choose dates, accounts and categories';

  @override
  String get exportAllJson => 'All data (JSON)';

  @override
  String get exportAllJsonSubtitle =>
      'Everything in a format other apps can read';

  @override
  String get backupReminderFrequency => 'Backup reminder';

  @override
  String get startDate => 'Start date';

  @override
  String get exportFilterAll => 'None yet';

  @override
  String get exportFilterHint =>
      'Nothing selected means everything is included.';

  @override
  String importSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String categoriesImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new categories imported',
      one: '1 new category imported',
      zero: 'No new categories',
    );
    return '$_temp0';
  }

  @override
  String get categoryImportInvalidFile =>
      'This file is not a category list. Expected the columns Group, Category (and optionally Hidden).';

  @override
  String get help => 'Help';

  @override
  String get noMatchingCategories => 'No matching categories';

  @override
  String get noCategoriesYet =>
      'No categories yet. Add a category group to get started.';

  @override
  String get notificationChannelScheduledName => 'Scheduled transactions';

  @override
  String get notificationChannelScheduledDescription =>
      'Reminders for upcoming scheduled transactions';

  @override
  String get notificationChannelBackupName => 'Backup reminders';

  @override
  String get notificationChannelBackupDescription =>
      'Reminders to back up your data';

  @override
  String get notificationChannelSyncName => 'Sync status';

  @override
  String get notificationChannelSyncDescription =>
      'Notifications when a sync fails';

  @override
  String get notificationChannelBudgetName => 'Budget alerts';

  @override
  String get notificationChannelBudgetDescription =>
      'Alerts when a category is overspent';

  @override
  String get notificationOpenAction => 'Open';

  @override
  String get notificationBackupTitle => 'Backup reminder';

  @override
  String get notificationBackupBody =>
      'It has been a while since your last backup. Tap to back up your data.';

  @override
  String get notificationSyncFailedTitle => 'Sync failed';

  @override
  String get notificationSyncFailedBody =>
      'Your data could not be synced. Tap to open the sync settings.';

  @override
  String get notificationBudgetAlertTitle => 'Category overspent';

  @override
  String get notificationBudgetAlertBodyGeneric =>
      'A budget category is overspent this month. Tap to review your budget.';

  @override
  String notificationBudgetAlertBodyAmount(String category, String amount) {
    return '$category is overspent by $amount this month.';
  }

  @override
  String get firstAccountTitle => 'Start with one account';

  @override
  String get firstAccountExplanation =>
      'Enter the current balance of an account you use every day. That amount becomes To Be Budgeted, ready to assign to your categories. You can add more accounts later.';

  @override
  String get budgetNoAccountsMessage =>
      'Add an account first: its balance is the money you assign to your categories.';

  @override
  String get noAccountsYet => 'No accounts yet';

  @override
  String get noMatchingAccounts => 'No matching accounts';

  @override
  String get csvParseFailedGeneric =>
      'This file could not be read as CSV. Please check its format.';

  @override
  String get filePickFailedGeneric => 'The file could not be opened.';

  @override
  String get reportNoDataToExport =>
      'There is no data to export for this report.';

  @override
  String amountSemanticsAvailable(String amount) {
    return '$amount available';
  }

  @override
  String amountSemanticsOverspent(String amount) {
    return '$amount overspent';
  }

  @override
  String amountSemanticsBudgeted(String amount) {
    return '$amount budgeted';
  }

  @override
  String amountSemanticsActivity(String amount) {
    return 'Activity $amount';
  }

  @override
  String amountSemanticsBalance(String amount) {
    return 'Balance $amount';
  }

  @override
  String amountSemanticsToBeBudgeted(String amount) {
    return '$amount to be budgeted';
  }

  @override
  String amountSemanticsOverbudgeted(String amount) {
    return '$amount overbudgeted';
  }

  @override
  String amountSemanticsInflow(String amount) {
    return 'Inflow $amount';
  }

  @override
  String amountSemanticsOutflow(String amount) {
    return 'Outflow $amount';
  }

  @override
  String amountSemanticsSpentOfBudgeted(String spent, String budgeted) {
    return '$spent spent of $budgeted budgeted';
  }

  @override
  String chartBarSemantics(String items) {
    return 'Bar Chart showing: $items';
  }

  @override
  String chartPieSemantics(String items) {
    return 'Pie chart: $items';
  }

  @override
  String chartLineSemantics(String series) {
    return 'Line chart. $series';
  }

  @override
  String chartLineSeriesSemantics(
    String series,
    String start,
    String end,
    String min,
    String max,
    String latest,
  ) {
    return '$series from $start to $end: lowest $min, highest $max, latest $latest';
  }

  @override
  String chartBudgetVsActualSemantics(String items) {
    return 'Budget vs actual: $items';
  }

  @override
  String chartBudgetVsActualItemSemantics(
    String category,
    String budgeted,
    String actual,
  ) {
    return '$category: $budgeted budgeted, $actual spent';
  }

  @override
  String get chartOthers => 'Others';

  @override
  String get chartTotalZero => 'Total spending is zero';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialFinish => 'Finish';

  @override
  String get transactionNoPayee => 'No Payee';

  @override
  String get transactionNotApproved => 'Not yet approved';

  @override
  String get transactionStatusReconciled => 'Reconciled';

  @override
  String transactionClearStatusTooltip(String status) {
    return '$status. Tap to change';
  }

  @override
  String get accountTypeChecking => 'Checking';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get accountTypeCredit => 'Credit card';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get budgetGoalUnderfunded => 'Below goal target';

  @override
  String get close => 'Close';

  @override
  String get add => 'Add';

  @override
  String get unknown => 'Unknown';

  @override
  String get fieldRequired => 'Required';

  @override
  String get tapToSelect => 'Tap to select';

  @override
  String get pickerSelectCategory => 'Select category';

  @override
  String get pickerSelectPayee => 'Select payee';

  @override
  String get pickerSelectAccount => 'Select account';

  @override
  String get ruleChooseTemplate => 'Choose a template';

  @override
  String get ruleNeedsCondition => 'Add at least one condition.';

  @override
  String get ruleNeedsAction => 'Add at least one action.';

  @override
  String get ruleDeleteTitle => 'Delete rule?';

  @override
  String get ruleDeleteMessage => 'Are you sure you want to delete this rule?';

  @override
  String get ruleEditTitle => 'Edit Rule';

  @override
  String get ruleNewTitle => 'New Rule';

  @override
  String get ruleUseTemplate => 'Use template';

  @override
  String get ruleNameLabel => 'Rule name';

  @override
  String get ruleActive => 'Active';

  @override
  String get ruleConditionsHeading => 'Conditions';

  @override
  String get ruleActionsHeading => 'Actions';

  @override
  String get ruleMatchLabel => 'Applies when';

  @override
  String get ruleMatchAll => 'all conditions match';

  @override
  String get ruleMatchAny => 'any condition matches';

  @override
  String get ruleAddCondition => 'Add condition';

  @override
  String get ruleAddAction => 'Add action';

  @override
  String get ruleSave => 'Save rule';

  @override
  String get ruleFieldLabel => 'Field';

  @override
  String get ruleOperatorLabel => 'Comparison';

  @override
  String get ruleValueLabel => 'Value';

  @override
  String get ruleActionLabel => 'Action';

  @override
  String get ruleFieldPayee => 'Payee';

  @override
  String get ruleFieldAmount => 'Amount';

  @override
  String get ruleFieldDescription => 'Memo / description';

  @override
  String get ruleOperatorEquals => 'is';

  @override
  String get ruleOperatorContains => 'contains';

  @override
  String get ruleOperatorStartsWith => 'starts with';

  @override
  String get ruleOperatorEndsWith => 'ends with';

  @override
  String get ruleOperatorGreaterThan => 'is greater than';

  @override
  String get ruleOperatorLessThan => 'is less than';

  @override
  String get ruleOperatorRegex => 'matches pattern (regex)';

  @override
  String get ruleActionSetCategory => 'Set category';

  @override
  String get ruleActionSetPayee => 'Set payee';

  @override
  String get ruleActionSetAccount => 'Set account';

  @override
  String get ruleActionSetMemo => 'Set memo';

  @override
  String get ruleActionMarkCleared => 'Mark as cleared';

  @override
  String get ruleActionMarkApproved => 'Mark as approved';

  @override
  String ruleActionSummarySetCategory(String name) {
    return 'Set category to “$name”';
  }

  @override
  String ruleActionSummarySetPayee(String name) {
    return 'Set payee to “$name”';
  }

  @override
  String ruleActionSummarySetAccount(String name) {
    return 'Set account to “$name”';
  }

  @override
  String ruleActionSummarySetMemo(String memo) {
    return 'Set memo to “$memo”';
  }

  @override
  String ruleActionSummaryFlag(String action, String value) {
    return '$action: $value';
  }

  @override
  String get ruleTemplatePayeeTitle => 'Categorize by payee name';

  @override
  String get ruleTemplatePayeeDescription =>
      'Set a category when the payee name contains a keyword.';

  @override
  String get ruleTemplateAutoClearTitle => 'Auto-clear small amounts';

  @override
  String get ruleTemplateAutoClearDescription =>
      'Mark transactions under a set amount as cleared.';

  @override
  String get ruleTemplateAutoApproveTitle => 'Auto-approve a recurring bill';

  @override
  String get ruleTemplateAutoApproveDescription =>
      'Approve transactions from one payee automatically (e.g. Netflix).';

  @override
  String get ruleTemplateKeywordTitle => 'Categorize by keyword';

  @override
  String get ruleTemplateKeywordDescription =>
      'Set a category based on a keyword in the memo or description.';

  @override
  String get ruleTemplateKeywordExample => 'coffee';

  @override
  String rulesImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules imported',
      one: '1 rule imported',
      zero: 'No rules imported',
    );
    return '$_temp0';
  }

  @override
  String get rulesNoneToApply => 'There are no rules to apply.';

  @override
  String get rulesApplyTitle => 'Apply rules?';

  @override
  String get rulesApplyMessage =>
      'All existing transactions are checked and the active rules are applied. This cannot be undone automatically.';

  @override
  String rulesApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions updated',
      one: '1 transaction updated',
      zero: 'No transactions changed',
    );
    return '$_temp0';
  }

  @override
  String get rulesMenuImport => 'Import rules';

  @override
  String get rulesMenuExport => 'Export rules';

  @override
  String get rulesMenuApplyAll => 'Apply rules to all transactions';

  @override
  String get rulesMenuSuggest => 'Suggest rules from history';

  @override
  String rulesConflictsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rule conflicts found',
      one: '1 rule conflict found',
    );
    return '$_temp0';
  }

  @override
  String get rulesConflictsTitle => 'Rule conflicts';

  @override
  String rulesConflictPair(String first, String second) {
    return '$first vs. $second';
  }

  @override
  String get rulesConflictExplanation =>
      'Same conditions, but the actions contradict each other.';

  @override
  String get view => 'View';

  @override
  String get rulesEmpty => 'No rules yet';

  @override
  String get rulesCreate => 'Create rule';

  @override
  String get rulesReorderFailed => 'The new order could not be saved.';

  @override
  String ruleConditionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conditions',
      one: '1 condition',
    );
    return '$_temp0';
  }

  @override
  String ruleActionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions',
      one: '1 action',
    );
    return '$_temp0';
  }

  @override
  String ruleSummary(String conditions, String actions) {
    return '$conditions, $actions';
  }

  @override
  String get rulesNoSuggestions =>
      'No suggestions found in your transaction history.';

  @override
  String get rulesSuggestedTitle => 'Suggested rules';

  @override
  String get ruleAdded => 'Rule added';

  @override
  String ruleSuggestionName(String payee) {
    return 'Auto-categorize $payee';
  }

  @override
  String ruleSuggestionDescription(String payee) {
    return 'Transactions from $payee almost always have the same category.';
  }

  @override
  String get accountSearchHint => 'Search accounts';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get accountShowClosed => 'Show closed accounts';

  @override
  String get accountSortNameAsc => 'Name (A–Z)';

  @override
  String get accountSortNameDesc => 'Name (Z–A)';

  @override
  String get accountSortBalanceAsc => 'Balance (lowest first)';

  @override
  String get accountSortBalanceDesc => 'Balance (highest first)';

  @override
  String get accountSortType => 'Type';

  @override
  String get draftRestored => 'Draft restored';

  @override
  String get accountUpdated => 'Account updated';

  @override
  String get accountCreated => 'Account created';

  @override
  String get unsavedChangesTitle => 'Discard changes?';

  @override
  String get unsavedChangesMessage =>
      'You have unsaved changes. Do you want to discard them?';

  @override
  String get discard => 'Discard';

  @override
  String get editAccount => 'Edit Account';

  @override
  String get addAccount => 'Add Account';

  @override
  String get accountNameLabel => 'Account Name';

  @override
  String get accountNameHint => 'e.g. Checking account';

  @override
  String get accountNameHelper => 'A name you recognise this account by';

  @override
  String get accountNameRequired => 'Please enter an account name';

  @override
  String get accountTypeLabel => 'Account Type';

  @override
  String get accountTypeHelper => 'Select the type of account';

  @override
  String get startingBalanceLabel => 'Starting Balance';

  @override
  String get startingBalanceHelper => 'The current balance of the account';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String colorOption(int index) {
    return 'Color $index';
  }

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get accountIconWallet => 'Wallet';

  @override
  String get accountIconBank => 'Bank';

  @override
  String get accountIconCard => 'Card';

  @override
  String get accountIconCash => 'Cash';

  @override
  String get accountIconSavings => 'Savings';

  @override
  String get accountIconInvestment => 'Investment';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get closeSelection => 'Close selection';

  @override
  String get back => 'Back';

  @override
  String get deleteSelected => 'Delete selected';

  @override
  String get approveSelected => 'Approve selected';

  @override
  String get categorizeSelected => 'Categorize selected';

  @override
  String get selectAll => 'Select all';

  @override
  String get filters => 'Filters';

  @override
  String get status => 'Status';

  @override
  String get noAccountsFound => 'No accounts found';

  @override
  String get noCategoriesFound => 'No categories found';

  @override
  String get selectDateRange => 'Select date range';

  @override
  String dateRangeValue(String start, String end) {
    return '$start – $end';
  }

  @override
  String get quickAddHint => 'e.g. “Lunch at Mario\'s \$15”';

  @override
  String quickAddConfidence(int percent) {
    return '$percent% match';
  }

  @override
  String get quickAddExamplesHeading => 'Examples:';

  @override
  String get quickAddDetectsHeading => 'The app detects:';

  @override
  String get quickAddExample1 => '“Lunch 15”';

  @override
  String get quickAddExample2 => '“Coffee \$5 at Starbucks”';

  @override
  String get quickAddExample3 => '“Uber 25 tomorrow”';

  @override
  String get quickAddExample4 => '“Salary 3000” (income)';

  @override
  String bulletItem(String text) {
    return '• $text';
  }

  @override
  String get quickAddTipsTooltip => 'Tips';

  @override
  String get tutTxAmountTitle => 'Enter Amount';

  @override
  String get tutTxAmountBody => 'Start by entering the transaction amount.';

  @override
  String get tutTxPayeeTitle => 'Select Payee';

  @override
  String get tutTxPayeeBody =>
      'Choose who you paid or who paid you. New payees are saved automatically.';

  @override
  String get tutTxCategoryTitle => 'Assign Category';

  @override
  String get tutTxCategoryBody =>
      'Categorize this transaction to update your budget.';

  @override
  String get tutTxSaveTitle => 'Save';

  @override
  String get tutTxSaveBody =>
      'Tap here to save. “Save & Add Another” keeps the form open for the next one.';

  @override
  String get tutBudgetWelcomeTitle => 'Welcome to your Budget';

  @override
  String get tutBudgetWelcomeBody => 'This is where you plan your spending.';

  @override
  String get tutBudgetMonthTitle => 'Select Month';

  @override
  String get tutBudgetMonthBody =>
      'Switch months to plan ahead or review past budgets.';

  @override
  String get tutBudgetTbbTitle => 'To Be Budgeted';

  @override
  String get tutBudgetTbbBody =>
      'Money you have not assigned yet. Assign it to categories until this reaches zero.';

  @override
  String get tutBudgetCategoriesTitle => 'Budget Categories';

  @override
  String get tutBudgetCategoriesBody =>
      'Tap a category to assign money. You can also move money between categories.';

  @override
  String get tutSyncProviderTitle => 'Choose Provider';

  @override
  String get tutSyncProviderBody =>
      'Sync through your own Google Drive. Your data is encrypted before it leaves this device.';

  @override
  String get tutSyncConnectTitle => 'Connect';

  @override
  String get tutSyncConnectBody =>
      'Sign in, then set a sync passphrase. You enter the same passphrase on each of your devices.';

  @override
  String get accessibilityVisualSection => 'Visual';

  @override
  String get highContrastTitle => 'High contrast';

  @override
  String get highContrastSubtitle =>
      'Stronger contrast for colours and borders';

  @override
  String get faqBudgetingQ => 'How does envelope budgeting work?';

  @override
  String get faqBudgetingA =>
      'You give all the money you have a job: assign it to categories until To Be Budgeted is zero. You spend from what a category has available. If you overspend, move money from another category to cover it.';

  @override
  String get faqSafeQ => 'Is my data safe?';

  @override
  String get faqSafeA =>
      'Your data is stored only on your phone, in an encrypted database whose key is kept in the phone’s secure hardware (Android KeyStore). The app lock adds your fingerprint, face or phone PIN. Synced data is encrypted before it leaves the phone. There are no LedgerZero servers, no tracking and no analytics.';

  @override
  String get faqSyncQ => 'How do my partner and I share a budget?';

  @override
  String get faqSyncA =>
      'Open Settings > Sync Settings. At home, pair the phones over Wi-Fi by scanning a QR code. To sync while you are apart, both phones use the same Google Drive account and sync passphrase. The user guide chapter “Using LedgerZero with a partner” explains the details.';

  @override
  String get faqOfflineQ => 'Can I use the app offline?';

  @override
  String get faqOfflineA =>
      'Yes. Everything works offline. Sync catches up automatically when you are back online.';

  @override
  String get faqBackupQ => 'How do backups work?';

  @override
  String get faqBackupA =>
      'Settings > Backup & Export creates a backup file that is always encrypted with a backup password you choose. Without that password the backup cannot be restored. CSV and JSON exports are readable copies and are not encrypted.';

  @override
  String get faqImportQ => 'Can I import from YNAB or my bank?';

  @override
  String get faqImportA =>
      'Yes. Settings > YNAB Migration imports nYNAB CSV exports and YNAB 4 budgets. Settings > Import CSV reads the CSV export of your bank.';

  @override
  String get guideStartTitle => 'Getting started';

  @override
  String get guideStartBody =>
      'LedgerZero uses envelope budgeting: before you spend money, you give it a job by budgeting it to a category. Add the account your money is in, add your salary, then budget until To Be Budgeted is zero. The ⓘ buttons across the app explain each part where you need it.';

  @override
  String get guideAccountsTitle => 'Accounts';

  @override
  String get guideAccountsBody =>
      'Add every account with its current balance. Accounts in the budget (checking, cash, credit cards) hold the money you budget. Savings, brokerage and pension accounts usually stay outside the budget: they count towards net worth only. The type sets the icon and whether a new account starts in the budget.';

  @override
  String get guideBudgetTitle => 'Budgeting';

  @override
  String get guideBudgetBody =>
      'On the Budget screen, tap a category’s budgeted amount to give it money, until To Be Budgeted is zero. Income without a category adds to To Be Budgeted; add your salary as recurring income to see what is coming. Each category keeps what is left from month to month. A new month starts empty: fill it like the month before or from a template, by hand or automatically. Money left unbudgeted at the end of a month is offered for savings in the next one.';

  @override
  String get guideTransactionsTitle => 'Transactions';

  @override
  String get guideTransactionsBody =>
      'Record each expense with a payee and a category; it reduces what the category has available. Quick Add lets you type a transaction in one line, rules categorise transactions automatically, and with card notifications on, payments from your bank app arrive as transactions to approve.';

  @override
  String get guideOverspendingTitle => 'Overspending';

  @override
  String get guideOverspendingBody =>
      'When a category\'s available amount turns red, you have spent more than you budgeted. Move money from another category to cover it.';

  @override
  String get guideReconcileTitle => 'Reconciling';

  @override
  String get guideReconcileBody =>
      'Now and then, compare an account with your bank statement using Reconcile Account on the account screen. Cleared transactions are marked as reconciled, and any difference is recorded as an adjustment.';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get onbWelcomeTagline => 'Private budgeting that stays on your device';

  @override
  String get onbWelcomeBody =>
      'Take control of your money with envelope budgeting: no sign-up, no servers, no tracking.';

  @override
  String get onbBenefitsTitle => 'Why LedgerZero?';

  @override
  String get onbBenefitPriceTitle => 'No subscription';

  @override
  String get onbBenefitPriceBody => 'One-time purchase. No recurring fees.';

  @override
  String get onbBenefitDataTitle => 'Your data stays with you';

  @override
  String get onbBenefitDataBody => 'Stored on your device and encrypted.';

  @override
  String get onbBenefitOfflineTitle => 'Works offline';

  @override
  String get onbBenefitOfflineBody =>
      'Everything works without an internet connection. No server needed.';

  @override
  String get onbPrivacyTitle => 'Your data, your device';

  @override
  String get onbPrivacyIntro => 'Privacy by default. That means:';

  @override
  String get onbPrivacyNoTracking => 'No tracking, analytics or telemetry.';

  @override
  String get onbPrivacyEncrypted =>
      'All data is encrypted on your device with AES-256.';

  @override
  String get onbPrivacyOwnCloud =>
      'We never see your financial data. Sync runs through your own Google Drive, end-to-end encrypted.';

  @override
  String get budgetBasicsTitle => 'Budgeting Basics';

  @override
  String get budgetBasicsHeadline => 'Give Every Dollar a Job';

  @override
  String get budgetBasicsBody1 =>
      'LedgerZero uses envelope budgeting. Imagine envelopes for rent, groceries and fun: when you get paid, you put money into these envelopes.';

  @override
  String get budgetBasicsBody2 =>
      'When an envelope is empty, you stop spending in that category or move money over from another envelope.';

  @override
  String get budgetBasicsTipZeroTitle => 'Zero-based';

  @override
  String get budgetBasicsTipZeroBody =>
      'Assign money until To Be Budgeted is zero.';

  @override
  String get budgetBasicsTipFlexTitle => 'Stay flexible';

  @override
  String get budgetBasicsTipFlexBody =>
      'Overspent? No problem: move money from another category.';

  @override
  String get categoryGroupRequired => 'Please select a category group';

  @override
  String categoryUsage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used in $count transactions',
      one: 'Used in 1 transaction',
      zero: 'Not used in any transaction',
    );
    return '$_temp0';
  }

  @override
  String get nameRequired => 'Name is required';

  @override
  String get categoryTipsTitle => 'Tips for categories';

  @override
  String get categoryTipsBody =>
      '• Group similar expenses (e.g. Housing, Food).\n• Hide a category instead of deleting it to keep its history.\n• Use icons or emojis to recognise categories quickly.\n• Keep it simple: start with broad categories and split them later if needed.';

  @override
  String get moveMoneySameCategory =>
      'Source and destination categories must be different';

  @override
  String get selectCategoryRequired => 'Please select a category';

  @override
  String get calculatorBackspace => 'Delete last digit';

  @override
  String get skipToContent => 'Skip to content';

  @override
  String get payeeMatchesSection => 'Matches';

  @override
  String get payeeSimilarSection => 'Similar';

  @override
  String payeeSimilarity(int percent) {
    return '$percent% match';
  }

  @override
  String payeeNoResults(String query) {
    return 'No payees found for “$query”';
  }

  @override
  String get reportPdfDataColumn => 'Data';

  @override
  String reportPdfCreatedOn(String date) {
    return 'Created on $date';
  }

  @override
  String get reportPdfFooter => 'Generated by LedgerZero';

  @override
  String reportPdfPageOf(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String reportShareText(String title) {
    return 'LedgerZero report: $title';
  }

  @override
  String get reportIncomeSeries => 'Income';

  @override
  String get reportExpenseSeries => 'Expenses';

  @override
  String get csvFileEmpty => 'The CSV file contains no data.';

  @override
  String fileSizeKb(double size) {
    final intl.NumberFormat sizeNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String sizeString = sizeNumberFormat.format(size);

    return '$sizeString KB';
  }

  @override
  String get csvIssueDateNotMapped =>
      'Choose the column that contains the date.';

  @override
  String get csvIssueAmountNotMapped =>
      'Choose the column that contains the amount.';

  @override
  String get csvIssueColumnsMissing =>
      'The selected columns are not in this file.';

  @override
  String csvIssueInvalidDates(int count, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows have dates that do not match the format $format.',
      one: '1 row has a date that does not match the format $format.',
    );
    return '$_temp0';
  }

  @override
  String csvIssueInvalidAmounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows have unreadable amounts and will be skipped.',
      one: '1 row has an unreadable amount and will be skipped.',
    );
    return '$_temp0';
  }

  @override
  String csvIssueDateOutliers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count dates are far from the others. Please check them in the review.',
      one: '1 date is far from the others. Please check it in the review.',
    );
    return '$_temp0';
  }

  @override
  String labelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String integerValue(int value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString';
  }

  @override
  String get syncErrorNetwork =>
      'No connection to the cloud storage. Sync will try again when you are online.';

  @override
  String get syncErrorNotSignedIn =>
      'You are not signed in. Please connect again.';

  @override
  String get syncErrorAuthFailed =>
      'The sign-in has expired. Please disconnect and connect again.';

  @override
  String get syncErrorStorageFull =>
      'Your cloud storage is full. Free up space to keep syncing.';

  @override
  String get transactionsShareText => 'LedgerZero transactions (CSV)';

  @override
  String get payeesShareText => 'LedgerZero payees (CSV)';

  @override
  String get dataExportShareText => 'LedgerZero data export (JSON)';

  @override
  String get rulesShareText => 'LedgerZero rules';

  @override
  String get seedGroupImmediate => 'Immediate Obligations';

  @override
  String get seedCatRent => 'Rent/Mortgage';

  @override
  String get seedCatElectric => 'Electric';

  @override
  String get seedCatWater => 'Water';

  @override
  String get seedCatInternet => 'Internet';

  @override
  String get seedCatGroceries => 'Groceries';

  @override
  String get seedCatTransportation => 'Transportation';

  @override
  String get seedGroupTrueExpenses => 'True Expenses';

  @override
  String get seedCatMedical => 'Medical';

  @override
  String get seedCatAutoMaintenance => 'Auto Maintenance';

  @override
  String get seedCatHomeMaintenance => 'Home Maintenance';

  @override
  String get seedCatInsurance => 'Renter\'s/Home Insurance';

  @override
  String get seedCatSubscriptions => 'Software Subscriptions';

  @override
  String get seedGroupDebt => 'Debt Payments';

  @override
  String get seedCatStudentLoan => 'Student Loan';

  @override
  String get seedCatCarPayment => 'Car Payment';

  @override
  String get seedCatCreditCard => 'Credit Card';

  @override
  String get seedGroupQualityOfLife => 'Quality of Life';

  @override
  String get seedCatVacation => 'Vacation';

  @override
  String get seedCatFitness => 'Fitness';

  @override
  String get seedCatEducation => 'Education';

  @override
  String get seedCatDiningOut => 'Dining Out';

  @override
  String get seedCatEntertainment => 'Entertainment';

  @override
  String get seedGroupFun => 'Just for Fun';

  @override
  String get seedCatGaming => 'Gaming';

  @override
  String get seedCatMusic => 'Music';

  @override
  String get seedCatFunMoney => 'Fun Money';

  @override
  String get syncFieldName => 'Name';

  @override
  String importUnmatchedCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows name a category that does not exist. They will be imported without a category unless a rule or the payee\'s default category assigns one.',
      one:
          '1 row names a category that does not exist. It will be imported without a category unless a rule or the payee\'s default category assigns one.',
    );
    return '$_temp0';
  }

  @override
  String importCategoryNotFound(String name) {
    return 'Category “$name” not found – unassigned';
  }

  @override
  String ynabImportErrorInvalidDates(String value) {
    return 'The dates in Register.csv do not fit one date format (MM/dd/yyyy, dd/MM/yyyy, yyyy-MM-dd or dd.MM.yyyy). First unreadable date: “$value”. Export the budget from YNAB again or correct the Date column.';
  }

  @override
  String get ynabImportCurrency => 'Currency of the imported accounts';

  @override
  String get ynabImportTrackingAccount => 'Tracking account – not imported';

  @override
  String ynabImportTrackingSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tracking accounts were not imported. Transfers between them and your budget accounts were imported as outflows and inflows of the budget accounts.',
      one:
          '1 tracking account was not imported. Transfers between it and your budget accounts were imported as outflows and inflows of the budget accounts.',
    );
    return '$_temp0';
  }

  @override
  String get loginResetApp => 'Reset app';

  @override
  String get loginResetAppTitle => 'Reset LedgerZero?';

  @override
  String loginResetAppBody(String word) {
    return 'Without the key vault your data cannot be unlocked. Resetting deletes the encrypted database, all keys, settings and exported files on this device and starts the setup again; afterwards you can restore a backup. This cannot be undone. Type $word to confirm.';
  }

  @override
  String get loginResetConfirmWord => 'RESET';

  @override
  String get loginResetConfirmLabel => 'Confirmation word';

  @override
  String get amountMustNotBeZero => 'The amount cannot be zero.';

  @override
  String get budgetLastMonthSpent => 'Budget Last Month\'s Spending';

  @override
  String get moveMoneyDone => 'Money moved';

  @override
  String get accountOnBudgetLabel => 'Include in budget';

  @override
  String get accountOnBudgetHelper =>
      'Turn off for savings or investments you don\'t want to budget. They still count towards your net worth.';

  @override
  String get accountOnBudgetChangeTitle => 'Change what you budget?';

  @override
  String get accountOnBudgetChangeOff =>
      'This account\'s balance and transactions will no longer count towards To Be Budgeted, in every month. Transfers between it and your budget accounts will move money out of or into your budget.';

  @override
  String get accountOnBudgetChangeOn =>
      'This account\'s balance and transactions will count towards To Be Budgeted again, in every month.';

  @override
  String get accountOffBudgetBadge => 'Off budget';

  @override
  String get offBudgetTransactionHint =>
      'This account is off budget: its transactions don\'t change your categories or To Be Budgeted.';

  @override
  String get homeBalanceInBudget => 'In budget accounts';

  @override
  String homeBalancePage(int page, int pages) {
    return '$page of $pages';
  }

  @override
  String get homeBalanceNext => 'Show next total';

  @override
  String get transferCategoryHint =>
      'Optional. Without a category the money comes out of, or goes into, To Be Budgeted.';

  @override
  String get seedGroupSavings => 'Savings & Investments';

  @override
  String get seedCatStocks => 'Stocks & ETFs';

  @override
  String get seedCatCrypto => 'Crypto';

  @override
  String get seedCatBonds => 'Bonds';

  @override
  String get seedCatRetirement => 'Retirement';

  @override
  String get savingsOfferTitle => 'Set money aside?';

  @override
  String get savingsOfferBody =>
      'Add a Savings & Investments group: Savings, Stocks & ETFs, Crypto, Bonds and Retirement. Budget there what you move to your savings and investment accounts each month. Keep those accounts outside the budget (switch off \"Include in budget\"): their balances then count towards your net worth only.';

  @override
  String get savingsOfferAdd => 'Add categories';

  @override
  String get savingsOfferDismiss => 'No thanks';

  @override
  String get savingsOfferAdded => 'Savings & Investments categories added';

  @override
  String get seedCatSavings => 'Savings';

  @override
  String get cardNotifications => 'Card notifications';

  @override
  String get cardNotificationsSubtitle =>
      'Add card payments from your bank app\'s notifications';

  @override
  String get cardNotificationsIntro =>
      'LedgerZero can read payment notifications from your bank, card or wallet apps and add each payment as a transaction for you to review. Only the apps you choose here are read; notifications from all other apps are ignored. Everything stays on this device.';

  @override
  String get cardNotificationsAccessTitle => 'Notification access';

  @override
  String get cardNotificationsAccessGranted => 'Granted';

  @override
  String get cardNotificationsAccessMissing =>
      'Not granted: nothing is captured';

  @override
  String get cardNotificationsGrantAccess => 'Grant access';

  @override
  String get cardNotificationsManageAccess => 'Manage in system settings';

  @override
  String get cardNotificationsDisclosureTitle =>
      'Allow LedgerZero to read notifications?';

  @override
  String get cardNotificationsDisclosureBody =>
      'Android will now ask you to give LedgerZero access to notifications. Android grants this access for all apps, but LedgerZero only reads notifications from the bank, card or wallet apps you choose, and only takes the amount, merchant and time of a payment from them. Notifications are never sent anywhere. Captured notifications are kept encrypted on this device for 30 days, so you can add a payment again. You can revoke access at any time in the system settings.';

  @override
  String get cardNotificationsContinue => 'Continue';

  @override
  String get cardNotificationsAppsTitle => 'Apps';

  @override
  String get cardNotificationsNoApps => 'No apps chosen yet.';

  @override
  String get cardNotificationsAddApp => 'Add app';

  @override
  String get cardNotificationsAccountMissing =>
      'No account chosen: payments wait here';

  @override
  String cardNotificationsRemoveApp(String app) {
    return 'Stop watching $app';
  }

  @override
  String get cardNotificationsPickAppTitle => 'Choose the app';

  @override
  String get cardNotificationsPickAppHint =>
      'Apps with a notification showing, apps that notified recently, and installed bank apps.';

  @override
  String get cardNotificationsNoCandidates =>
      'No apps found. Keep a notification from your bank app in the notification shade and try again.';

  @override
  String get cardNotificationsOriginActive => 'Notification showing';

  @override
  String get cardNotificationsOriginRecent => 'Notified recently';

  @override
  String get cardNotificationsOriginKnown => 'Bank or wallet app';

  @override
  String cardNotificationsPickAccountTitle(String app) {
    return 'Add payments from $app to';
  }

  @override
  String get cardNotificationsNoAccounts => 'Create an account first.';

  @override
  String get cardNotificationsHeldTitle => 'Waiting for you';

  @override
  String get cardNotificationsHeldUnreadable => 'No amount found';

  @override
  String get cardNotificationsHeldNoAccount => 'No account chosen for this app';

  @override
  String get cardNotificationsHeldForeignCurrency =>
      'Different currency than the account';

  @override
  String get cardNotificationsAddManually => 'Add';

  @override
  String get cardNotificationsDismiss => 'Dismiss';

  @override
  String get cardNotificationsHowItWorksTitle => 'How it works';

  @override
  String get cardNotificationsHowItWorks =>
      'Captured payments appear in Transactions marked as not approved. Swipe left to approve one, or tap it to correct it. Payments captured while LedgerZero is closed are added the next time it starts. Declined payments, codes and balance notices are skipped. Captured notifications lists the last 30 days, so you can add a skipped or deleted payment again.';

  @override
  String cardNotificationsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count card payments added',
      one: '1 card payment added',
    );
    return '$_temp0';
  }

  @override
  String get cardNotificationsLogTitle => 'Captured notifications';

  @override
  String get cardNotificationsLogSubtitle =>
      'Add skipped or deleted payments again (last 30 days)';

  @override
  String get cardNotificationsLogIntro =>
      'Notifications from the apps you watch, kept encrypted on this device for 30 days. Select payments to add them again as transactions for you to review. Notifications from before an app was added cannot be read.';

  @override
  String get cardNotificationsLogAllApps => 'All apps';

  @override
  String get cardNotificationsLogToday => 'Today';

  @override
  String get cardNotificationsLogLast7Days => 'Last 7 days';

  @override
  String get cardNotificationsLogLast30Days => 'Last 30 days';

  @override
  String get cardNotificationsLogPickDates => 'Choose dates';

  @override
  String get cardNotificationsLogEmpty => 'Nothing captured in this period.';

  @override
  String get cardNotificationsLogSelectAll => 'Select all';

  @override
  String cardNotificationsLogAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count',
      zero: 'Add',
    );
    return '$_temp0';
  }

  @override
  String get cardNotificationsStatusAdded => 'Added';

  @override
  String get cardNotificationsStatusAddedDeleted =>
      'Added, but the transaction was deleted since';

  @override
  String cardNotificationsStatusSkipped(String phrase) {
    return 'Skipped: contains “$phrase”';
  }

  @override
  String get cardNotificationsStatusSkippedBalance =>
      'Skipped: looks like a balance notice';

  @override
  String get cardNotificationsStatusDismissed => 'Dismissed';

  @override
  String get cardNotificationsStatusFound =>
      'Was showing when the app was added';

  @override
  String get cardNotificationsLikelyDuplicate =>
      'A transaction with this amount already exists';

  @override
  String cardNotificationsShowingFound(int count, String app) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications from $app were already showing.',
      one: '1 notification from $app was already showing.',
    );
    return '$_temp0';
  }

  @override
  String get cardNotificationsReview => 'Review';

  @override
  String get appLockTitle => 'App lock';

  @override
  String get appLockSubtitle =>
      'Ask for your fingerprint, face or screen lock when opening LedgerZero';

  @override
  String get appLockNeedsScreenLock =>
      'Set up a screen lock in the Android settings to use the app lock.';

  @override
  String get appLockPromptTitle => 'Unlock LedgerZero';

  @override
  String get appLockPromptSubtitle =>
      'Use your fingerprint, face or screen lock';

  @override
  String get appLockTurnedOffNoScreenLock =>
      'This phone has no screen lock any more, so the app lock was turned off.';

  @override
  String get lockScreenTitle => 'LedgerZero is locked';

  @override
  String get lockScreenKeyError =>
      'LedgerZero cannot open your data: the key stored on this phone is missing or does not match the data. Reset the app, then restore a backup or sync again from your other phone.';

  @override
  String get legacyUnlockTitle => 'Unlock one last time';

  @override
  String get legacyUnlockExplanation =>
      'LedgerZero no longer uses a master password. Unlock one last time with your password or recovery key. After that, the app keeps its key in this phone\'s secure key store, and the app lock uses your fingerprint, face or screen lock.';

  @override
  String get setupDeviceHeading => 'Your data stays on this phone';

  @override
  String get setupDeviceExplanation =>
      'Your budget is stored only on this phone, encrypted with a key that Android keeps in its secure key store. There is no account and no password to remember. So you don\'t lose anything with your phone, create backups or sync with a second phone.';

  @override
  String get lockScreenReadError =>
      'LedgerZero could not read its key from this phone\'s secure key store just now. Your data is not affected. Try again; if it keeps failing, restart the phone.';

  @override
  String get providerLocalWifi => 'Home Wi-Fi (phone to phone)';

  @override
  String get lanSyncTitle => 'Wi-Fi sync';

  @override
  String get lanSetupExplanation =>
      'Share one budget with a second phone, for example your partner\'s, without any cloud. The phones sync whenever both are on the same Wi-Fi with LedgerZero open.';

  @override
  String get lanStart => 'Start on this phone';

  @override
  String get lanStartHint =>
      'Choose this on the phone that already has your budget.';

  @override
  String get lanJoin => 'Join the other phone';

  @override
  String get lanJoinHint =>
      'Choose this on the second phone. Its data is merged into the shared budget.';

  @override
  String get lanPairPhone => 'Pair a phone';

  @override
  String get lanShowCodeInstructions =>
      'On the other phone open Settings > Sync, choose Home Wi-Fi, tap \"Join the other phone\" and scan this code. Both phones must be on the same Wi-Fi with LedgerZero open.';

  @override
  String get lanShowCodeWarning =>
      'This code gives access to your budget. Only show it to phones you trust.';

  @override
  String get lanCodeTextLabel =>
      'Can\'t scan? Type this code on the other phone:';

  @override
  String get lanScanTitle => 'Scan the pairing code';

  @override
  String get lanEnterCode => 'Enter code instead';

  @override
  String get lanEnterCodeTitle => 'Pairing code';

  @override
  String get lanEnterCodeHint => 'Starts with lzpair1:';

  @override
  String get lanCameraUnavailable =>
      'The camera is not available. Enter the code instead.';

  @override
  String get lanJoining => 'Connecting to the other phone…';

  @override
  String get lanStarted =>
      'Wi-Fi sync is on. Pair a second phone to share the budget.';

  @override
  String get lanJoined => 'Paired. The budget is now shared.';

  @override
  String get lanInvalidCode => 'This is not a LedgerZero pairing code.';

  @override
  String get lanPhoneNotFound =>
      'The other phone could not be reached. Make sure both phones are on the same Wi-Fi and LedgerZero is open on the other phone.';

  @override
  String get lanSetupFailed => 'Wi-Fi sync could not be set up.';

  @override
  String get lanPeersTitle => 'Paired phones';

  @override
  String get lanNoPeers => 'No phone paired yet.';

  @override
  String lanPeerLastSync(String time) {
    return 'Last synced $time';
  }

  @override
  String get lanPeerNeverSynced => 'Not synced yet';

  @override
  String get lanTurnOff => 'Turn off Wi-Fi sync';

  @override
  String get syncErrorPairingMismatch =>
      'This phone and the other one were paired with different codes. Turn off Wi-Fi sync on this phone and pair it again.';

  @override
  String get budgetIncomeLabel => 'Income';

  @override
  String budgetIncomeReceived(String amount) {
    return '$amount received';
  }

  @override
  String budgetIncomeExpected(String amount, String date) {
    return '$amount expected, next $date';
  }

  @override
  String get budgetIncomeNone => 'none this month';

  @override
  String get budgetIncomeAddPrompt =>
      'Add your salary to budget it every month';

  @override
  String get budgetIncomeAddButton => 'Add salary';

  @override
  String get salaryPromptTitle => 'Add your salary?';

  @override
  String get salaryPromptBody =>
      'Set it up once and it lands in To Be Budgeted every payday, ready to assign to your categories. You also see the expected amount for each month in advance.';

  @override
  String get salaryPromptDismiss => 'Not now';

  @override
  String get firstAccountSalaryTitle => 'When do you get paid?';

  @override
  String newMonthTitle(String month, String previous) {
    return 'Start $month like $previous?';
  }

  @override
  String newMonthBody(String total, String tbb) {
    return '$total in the same categories. To Be Budgeted after: $tbb.';
  }

  @override
  String newMonthFill(String previous) {
    return 'Fill like $previous';
  }

  @override
  String get newMonthTemplate => 'Use a template';

  @override
  String get newMonthDismiss => 'Not now';

  @override
  String newMonthFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories filled',
      one: '1 category filled',
    );
    return '$_temp0';
  }

  @override
  String get autoFillTitle => 'Fill new months automatically';

  @override
  String get autoFillMenu => 'Fill automatically…';

  @override
  String get autoFillExplanation =>
      'On the first open of a new month, categories that are still empty get these amounts. Amounts you set yourself are never overwritten, also not from the paired phone. Starts with next month.';

  @override
  String get autoFillOff => 'Off';

  @override
  String get autoFillPrevious => 'Same as the month before';

  @override
  String autoFillTemplate(String name) {
    return 'Template: $name';
  }

  @override
  String autoFillNoteTitle(String month) {
    return '$month was filled automatically';
  }

  @override
  String autoFillNoteBody(String total, String source) {
    return '$total from $source. Change any amount as usual.';
  }

  @override
  String get autoFillUndone => 'Automatic budget undone';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String accountReleaseIntro(String amount) {
    return '$amount in this account leaves your budget. Release the money you budgeted for it:';
  }

  @override
  String accountReleaseAmount(String amount) {
    return 'Release $amount';
  }

  @override
  String accountReleased(String amount) {
    return '$amount returned to To Be Budgeted';
  }

  @override
  String leftoverTitle(String amount, String previous) {
    return '$amount from $previous wasn\'t budgeted';
  }

  @override
  String leftoverBody(String month) {
    return 'It is still in To Be Budgeted for $month. Put it towards savings?';
  }

  @override
  String get leftoverAssign => 'Budget for savings…';

  @override
  String leftoverKeep(String month) {
    return 'Keep for $month';
  }

  @override
  String leftoverAssigned(String amount, String category) {
    return '$amount budgeted for $category';
  }

  @override
  String get accountPersonalLabel => 'Personal';

  @override
  String get accountPersonalHelper =>
      'Only you see its transactions. A partner you sync with sees just its name and balance.';

  @override
  String get accountPersonalSynced =>
      'Already shared with your partner, so it can\'t become personal. Create a new personal account instead.';

  @override
  String get accountOnBudgetPersonal =>
      'Personal accounts stay outside the budget.';

  @override
  String get accountShareTitle => 'Share with your partner?';

  @override
  String get accountShareBody =>
      'Its transactions will sync to your partner\'s phone, and your partner can change them too. It can\'t become personal again.';

  @override
  String get accountShareAction => 'Share';

  @override
  String get accountPersonalBadge => 'Personal';

  @override
  String get accountPartnerBadge => 'Partner\'s';

  @override
  String get accountsPartnerSection => 'Your partner\'s accounts';

  @override
  String get netWorthShared => 'Shared';

  @override
  String get netWorthMine => 'Mine';

  @override
  String get netWorthPartner => 'Partner\'s';

  @override
  String get accountPartnerTitle => 'Your partner\'s personal account';

  @override
  String get accountPartnerBody =>
      'Its transactions stay on your partner\'s phone. The balance updates whenever their phone syncs.';

  @override
  String get txPartnerAccount =>
      'This belongs to your partner\'s personal account. Your partner can change it on their phone.';

  @override
  String get accountBalanceLabel => 'Balance';

  @override
  String helpInfoTooltip(String topic) {
    return 'About $topic';
  }

  @override
  String get helpOpenGuide => 'Open the user guide';

  @override
  String get helpHowTo => 'How it works';

  @override
  String get helpShowMe => 'Show me';

  @override
  String get helpSavingTitle => 'Saving and investing';

  @override
  String get helpSavingBody =>
      'Keep savings and investments in their own accounts outside the budget. The budget decides how much goes there each month: budget the amount in a Savings & Investments category, then move the money with a transfer that uses that category.';

  @override
  String get helpSavingSteps =>
      'Budget the amount, for example 500 in Stocks & ETFs.\nAdd a transfer from your budget account (for example checking) to the brokerage or savings account.\nPick Stocks & ETFs as its category. The category is spent, the brokerage account grows, and To Be Budgeted stays the same.\nGains, dividends and fees inside the brokerage account need no category.';

  @override
  String get helpTbbTitle => 'To Be Budgeted';

  @override
  String get helpTbbBody =>
      'Money in your budget accounts that has no job yet. Income without a category adds to it, and budgeting money to a category takes it out. Aim for zero: then every euro has a job.';

  @override
  String get helpTbbSteps =>
      'Negative means you budgeted more than you have: lower a category until it is back at zero.\nWhat is left at the end of a month carries over to the next month, where you can budget it.\nAccounts outside the budget, like savings or a brokerage account, do not count here.';

  @override
  String get helpNewMonthTitle => 'Filling a new month';

  @override
  String get helpNewMonthBody =>
      'A new month starts empty. Fill it like the month before or from a template, by hand or automatically every month (Budget menu ⋮, “Fill automatically…”).';

  @override
  String get helpNewMonthSteps =>
      'Only empty categories are filled: amounts you already set stay.\nWhat you change by hand always wins, also against your partner’s phone filling the same month.\nUndo right after filling resets only the categories you have not changed since.';

  @override
  String get helpOnBudgetTitle => 'In or out of the budget';

  @override
  String get helpOnBudgetBody =>
      'Accounts in the budget hold the money you spend and plan with: their balance is what you budget. Accounts outside the budget only count towards net worth.';

  @override
  String get helpOnBudgetSteps =>
      'In the budget: checking, cash, credit cards and the account your salary arrives in.\nOutside: savings, brokerage, crypto and pension accounts, loans.\nA reserve inside your checking account cannot be outside: budget it into a category like Savings instead.\nTaking an account out offers to release the money you budgeted for it, so To Be Budgeted does not go negative.';

  @override
  String get helpPersonalTitle => 'Personal accounts';

  @override
  String get helpPersonalBody =>
      'For couples who sync: a personal account belongs to you. Your partner sees its name and balance in net worth, but not its transactions, and cannot change it.';

  @override
  String get helpPersonalSteps =>
      'Personal accounts are always outside the budget.\nA transfer between a shared account and your personal one syncs as the shared side only.\nAn account can become personal only before it first syncs, so mark it before pairing. Sharing it later is always possible and sends its history.';

  @override
  String get helpAccountTypesTitle => 'Account types';

  @override
  String get helpAccountTypesBody =>
      'The type sets the icon and whether a new account starts in the budget. Savings and Investment accounts start outside the budget; the switch below changes that.';

  @override
  String get helpAccountsTitle => 'Accounts and net worth';

  @override
  String get helpAccountsBody =>
      'Net worth adds up all accounts, in or out of the budget. If you sync with a partner, it is your household’s net worth, and the lines below it split it into shared, yours and your partner’s.';

  @override
  String get helpAccountsSteps =>
      'Off budget: counts towards net worth only.\nPersonal: yours; your partner sees only its name and balance.\nPartner’s: your partner’s personal accounts, read-only, with the balance their phone last shared.';

  @override
  String get helpTransferTitle => 'Transfers';

  @override
  String get helpTransferBody =>
      'A transfer moves money between two of your accounts. It is neither income nor spending.';

  @override
  String get helpTransferSteps =>
      'Between two budget accounts (checking to cash): no category, nothing changes in the budget.\nFrom a budget account to one outside (checking to brokerage): pick the category you budgeted for it, for example Stocks & ETFs. Without a category the money comes out of To Be Budgeted.\nBack from outside into the budget (savings to checking): without a category it adds to To Be Budgeted.';

  @override
  String get helpSyncTitle => 'Syncing with a partner';

  @override
  String get helpSyncBody =>
      'Two phones can share one budget: over your home Wi-Fi without any cloud, or through a Google Drive account you both use when you are apart. Everything is encrypted before it leaves the phone.';

  @override
  String get helpSyncSteps =>
      'Every change syncs on its own. If both phones change the same thing, the later change wins and the other one is listed under conflicts, where you can keep it.\nPersonal accounts share only their name and balance.\nBoth phones need the same app version.';

  @override
  String get helpCsvTitle => 'Importing a CSV file';

  @override
  String get helpCsvBody =>
      'Export your transactions from your bank as a CSV file. LedgerZero matches the columns by their names, and you can correct the matching before importing.';

  @override
  String get helpCsvSteps =>
      'The first row must hold the column names: delete any lines above it.\nAmounts must be in one column, negative for money going out. Separate debit and credit columns are not supported yet.\nOn the review screen, untick the rows you do not want.';

  @override
  String get helpAppLockTitle => 'App lock';

  @override
  String get helpAppLockBody =>
      'The app locks with your fingerprint, face or phone PIN once it has been in the background for the time you choose. Pulling down notifications or answering a system dialog does not lock it, and after unlocking you are back where you were.';

  @override
  String get hintSavingsTransfer =>
      'Budgeted money stays in your checking account until you move it: add a transfer to your savings or brokerage account and pick this category.';

  @override
  String get hintOffBudgetAccount =>
      'Account created. It is outside the budget: to save into it, budget the amount in Savings & Investments and add a transfer with that category.';

  @override
  String get hintPartnerAccounts =>
      'These are your partner’s personal accounts. You see their balance; their transactions stay on your partner’s phone.';

  @override
  String get guideTransfersTitle => 'Transfers';

  @override
  String get guideTransfersBody =>
      'A transfer moves money between two of your accounts and is neither income nor spending. Between two budget accounts it needs no category and changes nothing in the budget. From a budget account to an account outside the budget, the money leaves the budget: pick the category you budgeted for it, or leave the category empty to take it from To Be Budgeted. Money coming back from outside without a category adds to To Be Budgeted.';

  @override
  String get guideSavingTitle => 'Saving and investing';

  @override
  String get guideSavingBody =>
      'Keep savings and investments in their own accounts outside the budget, so price changes and interest never disturb it. Each month, budget what you want to put aside in Savings & Investments (Savings, Stocks & ETFs, Crypto, Bonds, Retirement). When you move the money, add a transfer from your budget account to the savings account and pick that category: the category is spent, the savings account grows and To Be Budgeted stays the same. Example: budget 500 in Stocks & ETFs, then transfer 500 from checking to your brokerage account with Stocks & ETFs. A reserve you keep in your checking account stays in a category like Savings instead, where it carries over every month.';

  @override
  String get guidePartnerTitle => 'Using LedgerZero with a partner';

  @override
  String get guidePartnerBody =>
      'Two phones can share one budget. Pair them in Sync Settings: over your home Wi-Fi (scan the QR code on the other phone; both need LedgerZero open on the same Wi-Fi) or through a Google Drive account you both use. Every change syncs on its own; if you both change the same thing, the later change wins and Sync Settings lists the other one. Accounts you mark as personal stay yours: your partner sees their name and balance in net worth, but not their transactions. Mark an account as personal before the first sync; you can still share it later.';

  @override
  String get guideSecurityTitle => 'Security and backups';

  @override
  String get guideSecurityBody =>
      'Your data is stored encrypted on your phone, and the key is kept in the phone’s secure hardware. The app lock asks for your fingerprint, face or phone PIN after the app was in the background. Create encrypted backups regularly in Settings > Backup & Export and keep the backup password safe: without it a backup cannot be restored.';

  @override
  String get guideImportTitle => 'Importing';

  @override
  String get guideImportBody =>
      'Settings > Import CSV reads your bank’s CSV export: the first row must hold the column names, and amounts must be in one column (negative for money going out). Columns are matched by name and can be corrected before importing. YNAB budgets can be imported from Settings as well.';

  @override
  String get faqLockQ => 'What if my fingerprint is not recognised?';

  @override
  String get faqLockA =>
      'The app lock also accepts your phone’s PIN, pattern or password, the same way your phone’s lock screen does.';

  @override
  String get faqSavingQ => 'How do I put money into savings or investments?';

  @override
  String get faqSavingA =>
      'Keep the savings or brokerage account outside the budget. Each month, budget the amount in a Savings & Investments category, then add a transfer from your checking account to the savings account and pick that category. The category is spent and To Be Budgeted stays the same.';

  @override
  String get faqPersonalQ => 'Can I keep an account to myself?';

  @override
  String get faqPersonalA =>
      'Yes. Switch on “Personal” when you create the account. Your partner then sees only its name and balance; its transactions stay on your phone. Do this before the first sync: an account that has already synced stays shared.';

  @override
  String get categoryNotFound =>
      'This category no longer exists. It may have been deleted on this or your partner’s phone.';

  @override
  String get budgetCurrencyLabel => 'Budget currency';

  @override
  String get budgetCurrencyHelper =>
      'Your budget and every account in it use this currency. Accounts outside the budget can use any currency.';

  @override
  String accountCurrencyLockedHelper(String currency) {
    return 'Accounts in the budget use the budget currency ($currency). Switch off “Include in budget” for an account in another currency.';
  }

  @override
  String get budgetBasicsSubtitle =>
      'How envelope budgeting works in LedgerZero';

  @override
  String get factoryResetFailed =>
      'The reset could not be completed. Restart the app and try again, or clear the app\'s storage in the Android settings.';

  @override
  String get startupFailedTitle => 'LedgerZero could not start';

  @override
  String get startupFailedBody =>
      'The app\'s settings could not be read. Try again; if it keeps failing, restart your phone.';
}
