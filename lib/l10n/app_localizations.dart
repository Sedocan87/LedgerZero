import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// The budget tab label
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// The home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// The accounts tab label
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// The transactions tab label
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// The reports tab label
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// Label for To Be Budgeted amount
  ///
  /// In en, this message translates to:
  /// **'To Be Budgeted'**
  String get toBeBudgeted;

  /// Label for total income
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get totalIncome;

  /// Label for total spending
  ///
  /// In en, this message translates to:
  /// **'Total Spending'**
  String get totalSpending;

  /// Label for recent transactions section
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// Message shown when there are no recent transactions
  ///
  /// In en, this message translates to:
  /// **'No recent transactions'**
  String get noRecentTransactions;

  /// Tooltip for add transaction button
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get addTransaction;

  /// Title for edit transaction screen
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// Welcome message for new users
  ///
  /// In en, this message translates to:
  /// **'Welcome to LedgerZero'**
  String get welcomeToLedgerZero;

  /// Message prompting user to create their first account
  ///
  /// In en, this message translates to:
  /// **'Create your first account to get started with budgeting.'**
  String get createFirstAccountMessage;

  /// Button label to create an account
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @accountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get accountDetails;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get accountNotFound;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get noTransactions;

  /// No description provided for @unknownPayee.
  ///
  /// In en, this message translates to:
  /// **'Unknown Payee'**
  String get unknownPayee;

  /// No description provided for @balanceTrend.
  ///
  /// In en, this message translates to:
  /// **'Balance Trend'**
  String get balanceTrend;

  /// No description provided for @noTransactionsTrend.
  ///
  /// In en, this message translates to:
  /// **'No transactions to show trend'**
  String get noTransactionsTrend;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @closeAccount.
  ///
  /// In en, this message translates to:
  /// **'Close Account'**
  String get closeAccount;

  /// No description provided for @reopenAccount.
  ///
  /// In en, this message translates to:
  /// **'Reopen Account'**
  String get reopenAccount;

  /// No description provided for @reconcileAccount.
  ///
  /// In en, this message translates to:
  /// **'Reconcile Account'**
  String get reconcileAccount;

  /// No description provided for @exportToCsv.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV'**
  String get exportToCsv;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this account? This cannot be undone.'**
  String get deleteAccountConfirmation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @exportedTo.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String exportedTo(String path);

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance: {balance}'**
  String currentBalance(double balance);

  /// No description provided for @enterActualBalance.
  ///
  /// In en, this message translates to:
  /// **'Enter Actual Balance'**
  String get enterActualBalance;

  /// No description provided for @discrepancyFound.
  ///
  /// In en, this message translates to:
  /// **'Discrepancy Found'**
  String get discrepancyFound;

  /// No description provided for @discrepancyMessage.
  ///
  /// In en, this message translates to:
  /// **'There is a difference of {diff}. Create an adjustment transaction?'**
  String discrepancyMessage(String diff);

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @reconcile.
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get reconcile;

  /// No description provided for @accountReconciled.
  ///
  /// In en, this message translates to:
  /// **'Account Reconciled!'**
  String get accountReconciled;

  /// No description provided for @adjustmentCreated.
  ///
  /// In en, this message translates to:
  /// **'Adjustment created and account reconciled.'**
  String get adjustmentCreated;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @inflow.
  ///
  /// In en, this message translates to:
  /// **'Inflow'**
  String get inflow;

  /// No description provided for @outflow.
  ///
  /// In en, this message translates to:
  /// **'Outflow'**
  String get outflow;

  /// No description provided for @payee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get payee;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @memo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get memo;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @cleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get cleared;

  /// No description provided for @uncleared.
  ///
  /// In en, this message translates to:
  /// **'Uncleared'**
  String get uncleared;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Save & Add Another'**
  String get saveAndAddAnother;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get invalidAmount;

  /// No description provided for @selectAccount.
  ///
  /// In en, this message translates to:
  /// **'Please select an account'**
  String get selectAccount;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved'**
  String get transactionSaved;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To Account'**
  String get toAccount;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @categoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Category Group'**
  String get categoryGroup;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryName;

  /// No description provided for @createCategory.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get createCategory;

  /// No description provided for @editCategoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Category Group'**
  String get editCategoryGroup;

  /// No description provided for @deleteCategoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete Category Group'**
  String get deleteCategoryGroup;

  /// No description provided for @newCategoryGroup.
  ///
  /// In en, this message translates to:
  /// **'New Category Group'**
  String get newCategoryGroup;

  /// No description provided for @addCategoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Category Group'**
  String get addCategoryGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// No description provided for @hideCategory.
  ///
  /// In en, this message translates to:
  /// **'Hide Category'**
  String get hideCategory;

  /// No description provided for @showCategory.
  ///
  /// In en, this message translates to:
  /// **'Show Category'**
  String get showCategory;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @reorderGroups.
  ///
  /// In en, this message translates to:
  /// **'Reorder Groups'**
  String get reorderGroups;

  /// No description provided for @reorderCategories.
  ///
  /// In en, this message translates to:
  /// **'Reorder Categories'**
  String get reorderCategories;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @categoryHasTransactions.
  ///
  /// In en, this message translates to:
  /// **'This category has {count} transactions. Select a new category for them.'**
  String categoryHasTransactions(int count);

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @reassign.
  ///
  /// In en, this message translates to:
  /// **'Reassign'**
  String get reassign;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get importCsv;

  /// No description provided for @selectFileToImport.
  ///
  /// In en, this message translates to:
  /// **'Select a CSV file to import'**
  String get selectFileToImport;

  /// No description provided for @changeFile.
  ///
  /// In en, this message translates to:
  /// **'Change File'**
  String get changeFile;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get dateFormat;

  /// No description provided for @decimalSeparator.
  ///
  /// In en, this message translates to:
  /// **'Decimal Separator'**
  String get decimalSeparator;

  /// No description provided for @dot.
  ///
  /// In en, this message translates to:
  /// **'Dot (.)'**
  String get dot;

  /// No description provided for @comma.
  ///
  /// In en, this message translates to:
  /// **'Comma (,)'**
  String get comma;

  /// No description provided for @negativeValuesAreOutflows.
  ///
  /// In en, this message translates to:
  /// **'Negative values are outflows'**
  String get negativeValuesAreOutflows;

  /// No description provided for @columnMapping.
  ///
  /// In en, this message translates to:
  /// **'Column Mapping'**
  String get columnMapping;

  /// No description provided for @selectColumn.
  ///
  /// In en, this message translates to:
  /// **'Select Column'**
  String get selectColumn;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @continueToReview.
  ///
  /// In en, this message translates to:
  /// **'Continue to Review'**
  String get continueToReview;

  /// No description provided for @failedToParseCsv.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse CSV: {error}'**
  String failedToParseCsv(String error);

  /// No description provided for @errorPickingFile.
  ///
  /// In en, this message translates to:
  /// **'Error picking file: {error}'**
  String errorPickingFile(String error);

  /// No description provided for @validationPassed.
  ///
  /// In en, this message translates to:
  /// **'Validation passed (Simulated)'**
  String get validationPassed;

  /// No description provided for @pleaseMapColumn.
  ///
  /// In en, this message translates to:
  /// **'Please map the \"{column}\" column'**
  String pleaseMapColumn(String column);

  /// No description provided for @budgeted.
  ///
  /// In en, this message translates to:
  /// **'Budgeted'**
  String get budgeted;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @budgetPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Budget Previous Month'**
  String get budgetPreviousMonth;

  /// No description provided for @budgetAverageSpent.
  ///
  /// In en, this message translates to:
  /// **'Budget Average Spent'**
  String get budgetAverageSpent;

  /// No description provided for @budgetZeroOut.
  ///
  /// In en, this message translates to:
  /// **'Zero Out'**
  String get budgetZeroOut;

  /// No description provided for @moveMoney.
  ///
  /// In en, this message translates to:
  /// **'Move Money'**
  String get moveMoney;

  /// No description provided for @moveMoneyFrom.
  ///
  /// In en, this message translates to:
  /// **'Move from'**
  String get moveMoneyFrom;

  /// No description provided for @moveMoneyTo.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get moveMoneyTo;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @noCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Categories Yet'**
  String get noCategoriesTitle;

  /// No description provided for @noCategoriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Create categories to start budgeting your money.'**
  String get noCategoriesDescription;

  /// No description provided for @setupBudget.
  ///
  /// In en, this message translates to:
  /// **'Setup Budget'**
  String get setupBudget;

  /// No description provided for @budgetTutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Budgeting'**
  String get budgetTutorialTitle;

  /// No description provided for @budgetTutorialDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap on amounts to budget. Use quick actions for auto-assignment.'**
  String get budgetTutorialDescription;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @tbbTooltip.
  ///
  /// In en, this message translates to:
  /// **'Income minus budgeted amount. This is what you have left to assign.'**
  String get tbbTooltip;

  /// No description provided for @budgetedTooltip.
  ///
  /// In en, this message translates to:
  /// **'The amount you\'ve assigned to this category for this month.'**
  String get budgetedTooltip;

  /// No description provided for @activityTooltip.
  ///
  /// In en, this message translates to:
  /// **'The sum of all transactions (spending) in this category for this month.'**
  String get activityTooltip;

  /// No description provided for @availableTooltip.
  ///
  /// In en, this message translates to:
  /// **'The amount available to spend. Calculated as Budgeted - Activity + Rollover.'**
  String get availableTooltip;

  /// No description provided for @categoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Name of the category.'**
  String get categoryTooltip;

  /// No description provided for @assignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to {name}'**
  String assignTo(String name);

  /// Tooltip for budget view mode toggle
  ///
  /// In en, this message translates to:
  /// **'View Mode'**
  String get viewMode;

  /// Message shown when budget is updated
  ///
  /// In en, this message translates to:
  /// **'Budget updated'**
  String get budgetUpdated;

  /// Label for undo action
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @variance.
  ///
  /// In en, this message translates to:
  /// **'Variance'**
  String get variance;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @overspent.
  ///
  /// In en, this message translates to:
  /// **'Overspent'**
  String get overspent;

  /// No description provided for @underfunded.
  ///
  /// In en, this message translates to:
  /// **'Underfunded'**
  String get underfunded;

  /// No description provided for @goalTarget.
  ///
  /// In en, this message translates to:
  /// **'Goal Target'**
  String get goalTarget;

  /// No description provided for @saveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as Template'**
  String get saveAsTemplate;

  /// No description provided for @applyTemplate.
  ///
  /// In en, this message translates to:
  /// **'Apply Template'**
  String get applyTemplate;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateName;

  /// No description provided for @templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get templateSaved;

  /// No description provided for @copyFromPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Copy from Previous Month'**
  String get copyFromPreviousMonth;

  /// No description provided for @resetBudget.
  ///
  /// In en, this message translates to:
  /// **'Reset Budget'**
  String get resetBudget;

  /// No description provided for @resetBudgetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset the budget for {month}? All budgeted amounts will be set to zero.'**
  String resetBudgetConfirmation(String month);

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @noTemplates.
  ///
  /// In en, this message translates to:
  /// **'No Templates'**
  String get noTemplates;

  /// No description provided for @createTemplateDescription.
  ///
  /// In en, this message translates to:
  /// **'Save your current budget allocations as a reusable template.'**
  String get createTemplateDescription;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete Template'**
  String get deleteTemplate;

  /// Label for spending by category report
  ///
  /// In en, this message translates to:
  /// **'Spending by Category'**
  String get spendingByCategory;

  /// Label for income vs expense report
  ///
  /// In en, this message translates to:
  /// **'Income vs Expense'**
  String get incomeVsExpense;

  /// Label for net worth report
  ///
  /// In en, this message translates to:
  /// **'Net Worth'**
  String get netWorth;

  /// No description provided for @spendingTrends.
  ///
  /// In en, this message translates to:
  /// **'Spending Trends'**
  String get spendingTrends;

  /// No description provided for @topPayees.
  ///
  /// In en, this message translates to:
  /// **'Top Payees'**
  String get topPayees;

  /// No description provided for @categoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get categoryBreakdown;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @last3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 Months'**
  String get last3Months;

  /// No description provided for @last6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 Months'**
  String get last6Months;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// No description provided for @lastYear.
  ///
  /// In en, this message translates to:
  /// **'Last Year'**
  String get lastYear;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @exportReport.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get exportReport;

  /// No description provided for @selectReportToExport.
  ///
  /// In en, this message translates to:
  /// **'Select Report'**
  String get selectReportToExport;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get exportFormat;

  /// No description provided for @csv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get csv;

  /// No description provided for @pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Report exported successfully'**
  String get exportSuccess;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @budgetVsActual.
  ///
  /// In en, this message translates to:
  /// **'Budget vs Actual'**
  String get budgetVsActual;

  /// No description provided for @filterCategories.
  ///
  /// In en, this message translates to:
  /// **'Filter Categories'**
  String get filterCategories;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes for this period.'**
  String get noNotes;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get editNote;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @enterNote.
  ///
  /// In en, this message translates to:
  /// **'Please enter a note'**
  String get enterNote;

  /// No description provided for @deleteNoteConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Note?'**
  String get deleteNoteConfirmationTitle;

  /// No description provided for @deleteNoteConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteNoteConfirmationMessage;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @payees.
  ///
  /// In en, this message translates to:
  /// **'Payees'**
  String get payees;

  /// No description provided for @payeeName.
  ///
  /// In en, this message translates to:
  /// **'Payee Name'**
  String get payeeName;

  /// No description provided for @payeeDefaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default Category'**
  String get payeeDefaultCategory;

  /// No description provided for @editPayee.
  ///
  /// In en, this message translates to:
  /// **'Edit Payee'**
  String get editPayee;

  /// No description provided for @mergePayee.
  ///
  /// In en, this message translates to:
  /// **'Merge Payee'**
  String get mergePayee;

  /// No description provided for @mergePayeeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge into {name}'**
  String mergePayeeInto(String name);

  /// No description provided for @deletePayeeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete Payee?'**
  String get deletePayeeConfirmation;

  /// No description provided for @deletePayeeWarning.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? Transactions will be preserved but the payee field will be cleared.'**
  String deletePayeeWarning(String name);

  /// No description provided for @mergeWarning.
  ///
  /// In en, this message translates to:
  /// **'All transactions from this payee will be moved to {target}. This action cannot be undone.'**
  String mergeWarning(String target);

  /// No description provided for @noPayees.
  ///
  /// In en, this message translates to:
  /// **'No Payees'**
  String get noPayees;

  /// No description provided for @searchPayees.
  ///
  /// In en, this message translates to:
  /// **'Search Payees'**
  String get searchPayees;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @defaultAccount.
  ///
  /// In en, this message translates to:
  /// **'Default Account'**
  String get defaultAccount;

  /// No description provided for @usageStats.
  ///
  /// In en, this message translates to:
  /// **'Usage Statistics'**
  String get usageStats;

  /// No description provided for @timesUsed.
  ///
  /// In en, this message translates to:
  /// **'Times Used'**
  String get timesUsed;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get totalSpent;

  /// No description provided for @lastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last Used'**
  String get lastUsed;

  /// No description provided for @autoCategory.
  ///
  /// In en, this message translates to:
  /// **'Auto Category'**
  String get autoCategory;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get removeFromFavorites;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @scheduledTransactions.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Transactions'**
  String get scheduledTransactions;

  /// No description provided for @nextDate.
  ///
  /// In en, this message translates to:
  /// **'Next Date'**
  String get nextDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @autoApprove.
  ///
  /// In en, this message translates to:
  /// **'Auto Approve'**
  String get autoApprove;

  /// No description provided for @createScheduledTransaction.
  ///
  /// In en, this message translates to:
  /// **'Create Scheduled Transaction'**
  String get createScheduledTransaction;

  /// No description provided for @editScheduledTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Scheduled Transaction'**
  String get editScheduledTransaction;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @noScheduledTransactions.
  ///
  /// In en, this message translates to:
  /// **'No Scheduled Transactions'**
  String get noScheduledTransactions;

  /// No description provided for @createScheduledTransactionDescription.
  ///
  /// In en, this message translates to:
  /// **'Create scheduled transactions for recurring bills or income.'**
  String get createScheduledTransactionDescription;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @repeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Repeat Every'**
  String get repeatEvery;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Day} other{Days}}'**
  String unitDays(int count);

  /// No description provided for @unitWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Week} other{Weeks}}'**
  String unitWeeks(int count);

  /// No description provided for @unitMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Month} other{Months}}'**
  String unitMonths(int count);

  /// No description provided for @unitYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Year} other{Years}}'**
  String unitYears(int count);

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @onDate.
  ///
  /// In en, this message translates to:
  /// **'On Date'**
  String get onDate;

  /// No description provided for @afterOccurrences.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get afterOccurrences;

  /// No description provided for @occurrences.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get occurrences;

  /// No description provided for @recoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Recovery Key'**
  String get recoveryKey;

  /// No description provided for @backupRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Backup Recovery Key'**
  String get backupRecoveryKey;

  /// No description provided for @revealRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Reveal Recovery Key'**
  String get revealRecoveryKey;

  /// No description provided for @autoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock Timer'**
  String get autoLock;

  /// No description provided for @autoLockImmediate.
  ///
  /// In en, this message translates to:
  /// **'Immediate'**
  String get autoLockImmediate;

  /// No description provided for @autoLockMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Minute} other{{count} Minutes}}'**
  String autoLockMinutes(int count);

  /// No description provided for @autoLockNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get autoLockNever;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccess;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Password'**
  String get incorrectPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @biometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometric Authentication'**
  String get biometrics;

  /// No description provided for @useBiometricsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID / Fingerprint to unlock'**
  String get useBiometricsDescription;

  /// No description provided for @biometricsSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric setup failed'**
  String get biometricsSetupFailed;

  /// No description provided for @encryptionStatus.
  ///
  /// In en, this message translates to:
  /// **'Encryption Status'**
  String get encryptionStatus;

  /// No description provided for @encrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get encrypted;

  /// No description provided for @notEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Not Encrypted'**
  String get notEncrypted;

  /// No description provided for @secure.
  ///
  /// In en, this message translates to:
  /// **'Secure'**
  String get secure;

  /// No description provided for @securitySettings.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get securitySettings;

  /// No description provided for @securityAndData.
  ///
  /// In en, this message translates to:
  /// **'Security & Data'**
  String get securityAndData;

  /// No description provided for @syncSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get syncSettings;

  /// No description provided for @connectToGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Connect to Google Drive'**
  String get connectToGoogleDrive;

  /// No description provided for @disconnectFromGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectFromGoogleDrive;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @googleDriveSync.
  ///
  /// In en, this message translates to:
  /// **'Google Drive Sync'**
  String get googleDriveSync;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last Synced: {time}'**
  String lastSynced(String time);

  /// No description provided for @syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync completed successfully'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @iCloudDriveSync.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive Sync'**
  String get iCloudDriveSync;

  /// No description provided for @syncProvider.
  ///
  /// In en, this message translates to:
  /// **'Sync Provider'**
  String get syncProvider;

  /// No description provided for @connectToICloud.
  ///
  /// In en, this message translates to:
  /// **'Connect to iCloud'**
  String get connectToICloud;

  /// No description provided for @providerNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get providerNone;

  /// No description provided for @providerGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get providerGoogleDrive;

  /// No description provided for @providerICloud.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive'**
  String get providerICloud;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @syncOnlyOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Sync only on Wi-Fi'**
  String get syncOnlyOnWifi;

  /// No description provided for @syncFrequency.
  ///
  /// In en, this message translates to:
  /// **'Sync Frequency'**
  String get syncFrequency;

  /// No description provided for @frequencyManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get frequencyManual;

  /// No description provided for @frequencyRealtime.
  ///
  /// In en, this message translates to:
  /// **'Real-time'**
  String get frequencyRealtime;

  /// No description provided for @frequency15Min.
  ///
  /// In en, this message translates to:
  /// **'Every 15 Minutes'**
  String get frequency15Min;

  /// No description provided for @frequency1Hour.
  ///
  /// In en, this message translates to:
  /// **'Every Hour'**
  String get frequency1Hour;

  /// No description provided for @frequency4Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 4 Hours'**
  String get frequency4Hours;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick Add'**
  String get quickAdd;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @noAmount.
  ///
  /// In en, this message translates to:
  /// **'No amount'**
  String get noAmount;

  /// No description provided for @payeeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Payee not found'**
  String get payeeNotFound;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editDetails;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @parsingTips.
  ///
  /// In en, this message translates to:
  /// **'Parsing Tips'**
  String get parsingTips;

  /// No description provided for @parsingTipsDescription.
  ///
  /// In en, this message translates to:
  /// **'Type naturally to create transactions.'**
  String get parsingTipsDescription;

  /// No description provided for @examples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get examples;

  /// No description provided for @appDetects.
  ///
  /// In en, this message translates to:
  /// **'The app detects'**
  String get appDetects;

  /// No description provided for @saveImportProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Import Profile'**
  String get saveImportProfile;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get profileName;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Import profile saved'**
  String get profileSaved;

  /// No description provided for @loadImportProfile.
  ///
  /// In en, this message translates to:
  /// **'Load Profile'**
  String get loadImportProfile;

  /// No description provided for @deleteProfileConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this profile?'**
  String get deleteProfileConfirmation;

  /// No description provided for @confirmImport.
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get confirmImport;

  /// No description provided for @confirmImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Review and confirm transactions to import.'**
  String get confirmImportDescription;

  /// No description provided for @importedTransactions.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} Transactions'**
  String importedTransactions(int count);

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import Successful'**
  String get importSuccess;

  /// No description provided for @potentialDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Potential Duplicates'**
  String get potentialDuplicates;

  /// No description provided for @duplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: This transaction might be a duplicate.'**
  String get duplicateWarning;

  /// No description provided for @deduplicationComplete.
  ///
  /// In en, this message translates to:
  /// **'Deduplication complete. {count} duplicates found.'**
  String deduplicationComplete(int count);

  /// No description provided for @importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import Cancelled'**
  String get importCancelled;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @firstDayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'First Day of Week'**
  String get firstDayOfWeek;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @defaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default Category'**
  String get defaultCategory;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @numberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number Format'**
  String get numberFormat;

  /// No description provided for @syncAndBackup.
  ///
  /// In en, this message translates to:
  /// **'Sync & Backup'**
  String get syncAndBackup;

  /// No description provided for @importFromMint.
  ///
  /// In en, this message translates to:
  /// **'Import from Mint'**
  String get importFromMint;

  /// No description provided for @loadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Loading accounts...'**
  String get loadingAccounts;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupAndRestore;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @scheduledTransactionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Transactions'**
  String get scheduledTransactionNotifications;

  /// No description provided for @budgetAlertNotifications.
  ///
  /// In en, this message translates to:
  /// **'Budget Alerts'**
  String get budgetAlertNotifications;

  /// No description provided for @syncStatusNotifications.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatusNotifications;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @developerMode.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get developerMode;

  /// No description provided for @databaseStatistics.
  ///
  /// In en, this message translates to:
  /// **'Database Statistics'**
  String get databaseStatistics;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get cacheCleared;

  /// No description provided for @factoryReset.
  ///
  /// In en, this message translates to:
  /// **'Factory Reset'**
  String get factoryReset;

  /// No description provided for @factoryResetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to perform a factory reset? This will delete ALL data including transactions, budgets, and settings. This action cannot be undone.'**
  String get factoryResetConfirmation;

  /// No description provided for @factoryResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Factory Reset?'**
  String get factoryResetTitle;

  /// No description provided for @factoryResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Factory reset complete. Please restart the app.'**
  String get factoryResetSuccess;

  /// No description provided for @databaseSize.
  ///
  /// In en, this message translates to:
  /// **'Database Size'**
  String get databaseSize;

  /// No description provided for @tableRowCounts.
  ///
  /// In en, this message translates to:
  /// **'Table Row Counts'**
  String get tableRowCounts;

  /// No description provided for @walSize.
  ///
  /// In en, this message translates to:
  /// **'WAL Size'**
  String get walSize;

  /// No description provided for @totalRows.
  ///
  /// In en, this message translates to:
  /// **'Total Rows'**
  String get totalRows;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
