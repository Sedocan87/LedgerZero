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
  String get loading => 'Loading...';

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
  String failedToParseCsv(String error) {
    return 'Failed to parse CSV: $error';
  }

  @override
  String errorPickingFile(String error) {
    return 'Error picking file: $error';
  }

  @override
  String get validationPassed => 'Validation passed (Simulated)';

  @override
  String pleaseMapColumn(String column) {
    return 'Please map the \"$column\" column';
  }

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
  String get exporting => 'Exporting...';

  @override
  String get exportSuccess => 'Report exported successfully';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

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
  String get payeeDefaultCategory => 'Default Category';

  @override
  String get editPayee => 'Edit Payee';

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
  String get backupRecoveryKey => 'Backup Recovery Key';

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
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get passwordChangedSuccess => 'Password changed successfully';

  @override
  String get incorrectPassword => 'Incorrect Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

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
  String get notEncrypted => 'Not Encrypted';

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
  String get disconnectFromGoogleDrive => 'Disconnect';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get googleDriveSync => 'Google Drive Sync';

  @override
  String lastSynced(String time) {
    return 'Last Synced: $time';
  }

  @override
  String get syncSuccess => 'Sync completed successfully';

  @override
  String get syncFailed => 'Sync failed';

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
  String get examples => 'Examples';

  @override
  String get appDetects => 'The app detects';

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
    return 'Imported $count Transactions';
  }

  @override
  String get importSuccess => 'Import Successful';

  @override
  String get potentialDuplicates => 'Potential Duplicates';

  @override
  String get duplicateWarning =>
      'Warning: This transaction might be a duplicate.';

  @override
  String deduplicationComplete(int count) {
    return 'Deduplication complete. $count duplicates found.';
  }

  @override
  String get importCancelled => 'Import Cancelled';

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
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get numberFormat => 'Number Format';

  @override
  String get syncAndBackup => 'Sync & Backup';

  @override
  String get importFromMint => 'Import from Mint';

  @override
  String get loadingAccounts => 'Loading accounts...';

  @override
  String get backupAndRestore => 'Backup & Restore';

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
  String get developerMode => 'Developer Mode';

  @override
  String get databaseStatistics => 'Database Statistics';

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
  String get databaseSize => 'Database Size';

  @override
  String get tableRowCounts => 'Table Row Counts';

  @override
  String get walSize => 'WAL Size';

  @override
  String get totalRows => 'Total Rows';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get faq => 'FAQ';

  @override
  String get faqSubtitle => 'Frequently asked questions';

  @override
  String get userGuide => 'User Guide';

  @override
  String get userGuideSubtitle => 'Comprehensive documentation';

  @override
  String get videoTutorials => 'Video Tutorials';

  @override
  String get videoTutorialsSubtitle => 'Learn by watching on YouTube';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get contactSupportSubtitle => 'support@ledgerzero.app';
}
