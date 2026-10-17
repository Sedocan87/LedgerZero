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
  String get tbbTooltip =>
      'Money you have not assigned to a category yet. Budget it until this reaches zero.';

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
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get incorrectPassword => 'Incorrect Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get biometrics => 'Biometric Authentication';

  @override
  String get useBiometricsDescription => 'Use Face ID / Fingerprint to unlock';

  @override
  String get biometricsSetupFailed => 'Biometric setup failed';

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
  String get iCloudDriveSync => 'iCloud Drive Sync';

  @override
  String get syncProvider => 'Sync Provider';

  @override
  String get connectToICloud => 'Connect to iCloud';

  @override
  String get providerNone => 'None';

  @override
  String get providerGoogleDrive => 'Google Drive';

  @override
  String get providerICloud => 'iCloud Drive';

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
  String get enterPasswordPrompt => 'Please enter your password';

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
  String get setupPasswordHeading => 'Set a master password';

  @override
  String get setupPasswordExplanation =>
      'Your data is encrypted on this device with a random key. Your master password unlocks that key. If you forget the password, only your recovery key can unlock the data.';

  @override
  String get setupUseBiometrics => 'Unlock with biometrics';

  @override
  String get setupUseBiometricsSubtitle =>
      'Face ID or fingerprint, protected by this device\'s security hardware';

  @override
  String get setupPreparing => 'Preparing encryption…';

  @override
  String get setupFailed => 'Security setup failed. Please try again.';

  @override
  String get recoveryKeyHeading => 'Your recovery key';

  @override
  String get recoveryKeyExplanation =>
      'If you forget your password, this key is the only way to unlock your data. Write it down on paper and keep it somewhere safe. Anyone who has this key can unlock your data on this device.';

  @override
  String get recoveryKeyNoCopyNote =>
      'The key cannot be copied to the clipboard on purpose: other apps could read it there.';

  @override
  String get recoveryKeyConfirmSaved =>
      'I have written down my recovery key and stored it safely';

  @override
  String get biometricsEnableFailed =>
      'Biometric unlock could not be turned on. You can try again in Settings.';

  @override
  String get biometricPromptTitle => 'Unlock LedgerZero';

  @override
  String get biometricPromptEnableTitle => 'Turn on biometric unlock';

  @override
  String get biometricPromptSubtitle => 'Confirm it is you to unlock your data';

  @override
  String get loginTitle => 'Welcome back';

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
  String get setNewPasswordTitle => 'Set a new password';

  @override
  String get setNewPasswordExplanation =>
      'You unlocked with your recovery key. Please choose a new master password. Your recovery key stays valid.';

  @override
  String get migrationRecoveryKeyExplanation =>
      'LedgerZero now protects your data with a new key scheme. This is your new recovery key. Recovery keys you saved before no longer work.';

  @override
  String get migrationBiometricsReset =>
      'Biometric unlock was turned off during the update. You can turn it on again in Settings.';

  @override
  String get passwordChangedRecoveryStillValid =>
      'Password changed. Your recovery key still works.';

  @override
  String get changePasswordFailed =>
      'The password could not be changed. Please try again.';

  @override
  String get recoveryKeyScreenExplanation =>
      'Your recovery key unlocks your data if you forget your password. Confirm your password to show it or to create a new one.';

  @override
  String get recoveryKeyRegenerate => 'Create a new recovery key';

  @override
  String get recoveryKeyRegenerateConfirm =>
      'Your current recovery key will stop working. Continue?';

  @override
  String get recoveryKeyRegenerated =>
      'New recovery key saved. The old one no longer works.';

  @override
  String get confirmPasswordTitle => 'Confirm your password';

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
  String get backupUploadNotConfigured =>
      'Set up Google Drive or iCloud sync first';

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
  String get onboardingCompleteTitle => 'You\'re all set!';

  @override
  String get onboardingCompleteMessage =>
      'Next, add the account you pay from, such as your checking account. Its balance becomes the money you can budget.';

  @override
  String get onboardingCreateFirstAccount => 'Create your first account';

  @override
  String get onboardingSkipForNow => 'Skip for now';

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
      'Sync through your own Google Drive or iCloud. Your data is encrypted before it leaves this device.';

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
      'Your data is stored only on your device, in a database encrypted with AES-256 and unlocked with your master password. If you turn on sync, it is encrypted with your sync passphrase before it leaves the device. There are no LedgerZero servers, no tracking and no analytics.';

  @override
  String get faqSyncQ => 'How do I sync between devices?';

  @override
  String get faqSyncA =>
      'Open Settings > Sync Settings, choose Google Drive or iCloud (iPhone and iPad only) and sign in. On the first device you set a sync passphrase; enter the same passphrase on every other device. Keep it safe: it cannot be recovered.';

  @override
  String get faqOfflineQ => 'Can I use the app offline?';

  @override
  String get faqOfflineA =>
      'Yes. Everything works offline. Sync catches up automatically when you are back online.';

  @override
  String get faqPasswordQ => 'What if I forget my master password?';

  @override
  String get faqPasswordA =>
      'Unlock with the recovery key you wrote down during setup, then choose a new password. Without the password and the recovery key nobody can unlock your data, not even the developer.';

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
  String get guideStartTitle => '1. Getting started';

  @override
  String get guideStartBody =>
      'LedgerZero uses zero-based envelope budgeting: before you spend money, you give it a job by assigning it to a category.';

  @override
  String get guideAccountsTitle => '2. Accounts';

  @override
  String get guideAccountsBody =>
      'Add the accounts you pay from (checking, savings, credit card, cash) with their current balance. That money is what you can budget: it appears as To Be Budgeted.';

  @override
  String get guideBudgetTitle => '3. Budgeting';

  @override
  String get guideBudgetBody =>
      'On the Budget screen, tap a category\'s budgeted amount to assign money. Keep going until To Be Budgeted is zero. Income without a category adds to To Be Budgeted.';

  @override
  String get guideTransactionsTitle => '4. Transactions';

  @override
  String get guideTransactionsBody =>
      'Record each expense with a payee and a category; it reduces what the category has available. Quick Add lets you type a transaction in one line, and rules categorise imported transactions automatically.';

  @override
  String get guideOverspendingTitle => '5. Overspending';

  @override
  String get guideOverspendingBody =>
      'When a category\'s available amount turns red, you have spent more than you budgeted. Move money from another category to cover it.';

  @override
  String get guideReconcileTitle => '6. Reconciling';

  @override
  String get guideReconcileBody =>
      'Now and then, compare an account with your bank statement using Reconcile Account on the account screen. Cleared transactions are marked as reconciled, and any difference is recorded as an adjustment.';

  @override
  String get guideSyncTitle => '7. Sync and backups';

  @override
  String get guideSyncBody =>
      'Sync keeps your phones and tablets up to date through your own Google Drive or iCloud, end-to-end encrypted with your sync passphrase. Create encrypted backups regularly in Settings > Backup & Export.';

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
      'We never see your financial data. Sync runs through your own cloud (Google Drive, iCloud), end-to-end encrypted.';

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
  String get budgetBasicsReady => 'I\'m ready!';

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
  String get syncErrorICloudUnavailable =>
      'iCloud is not available. Check that you are signed in to iCloud and that iCloud Drive is on for LedgerZero.';

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
      'Add a Savings & Investments group: Cash Reserve, Stocks & ETFs, Crypto, Bonds and Retirement. Money you assign there stays out of To Be Budgeted and carries over every month, e.g. a cash reserve you always keep. To invest, transfer it to your off-budget brokerage account using the category.';

  @override
  String get savingsOfferAdd => 'Add categories';

  @override
  String get savingsOfferDismiss => 'No thanks';

  @override
  String get savingsOfferAdded => 'Savings & Investments categories added';

  @override
  String get seedCatCashReserve => 'Cash Reserve';
}
