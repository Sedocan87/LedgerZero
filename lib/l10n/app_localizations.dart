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
  /// **'Loading…'**
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

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

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

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @numberFormatSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow language'**
  String get numberFormatSystem;

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

  /// No description provided for @budgetedTooltip.
  ///
  /// In en, this message translates to:
  /// **'The amount you\'ve assigned to this category for this month.'**
  String get budgetedTooltip;

  /// No description provided for @activityTooltip.
  ///
  /// In en, this message translates to:
  /// **'The sum of this month\'s transactions in this category.'**
  String get activityTooltip;

  /// No description provided for @availableTooltip.
  ///
  /// In en, this message translates to:
  /// **'What you can still spend: budgeted plus activity plus what carried over from last month.'**
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
  /// **'Exporting…'**
  String get exporting;

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

  /// No description provided for @biometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometric Authentication'**
  String get biometrics;

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

  /// No description provided for @syncProvider.
  ///
  /// In en, this message translates to:
  /// **'Sync Provider'**
  String get syncProvider;

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
  /// **'{count, plural, =1{Imported 1 transaction} other{Imported {count} transactions}}'**
  String importedTransactions(int count);

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import Successful'**
  String get importSuccess;

  /// No description provided for @duplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: This transaction might be a duplicate.'**
  String get duplicateWarning;

  /// No description provided for @deduplicationComplete.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Duplicate check complete. No duplicates found.} =1{Duplicate check complete. 1 duplicate found.} other{Duplicate check complete. {count} duplicates found.}}'**
  String deduplicationComplete(int count);

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

  /// No description provided for @loadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Loading accounts…'**
  String get loadingAccounts;

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

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @faqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get faqSubtitle;

  /// No description provided for @userGuide.
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get userGuide;

  /// No description provided for @userGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How LedgerZero works'**
  String get userGuideSubtitle;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @contactSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'support@ledgerzero.app'**
  String get contactSupportSubtitle;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server communication failed'**
  String get serverError;

  /// No description provided for @cacheError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load cached data'**
  String get cacheError;

  /// No description provided for @databaseError.
  ///
  /// In en, this message translates to:
  /// **'Database operation failed'**
  String get databaseError;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Synchronization failed'**
  String get syncError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @incomeAndSalaries.
  ///
  /// In en, this message translates to:
  /// **'Income & Salaries'**
  String get incomeAndSalaries;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @reducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduced Motion'**
  String get reducedMotion;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @addSplit.
  ///
  /// In en, this message translates to:
  /// **'Add Split'**
  String get addSplit;

  /// Memo of a transaction generated from a schedule that has neither a memo nor a payee.
  ///
  /// In en, this message translates to:
  /// **'Scheduled transaction'**
  String get scheduledTransactionDefaultMemo;

  /// Title of a delete confirmation for a named item (category, group).
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteNamedTitle(String name);

  /// Number of transactions in a category that is about to be deleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{This category has no transactions.} =1{This category has 1 transaction.} other{This category has {count} transactions.}}'**
  String deleteCategoryTransactionCount(int count);

  /// Option when deleting a category: move its data to a target category.
  ///
  /// In en, this message translates to:
  /// **'Move everything to another category'**
  String get deleteCategoryMoveOption;

  /// Explains what happens when a category is deleted with a target.
  ///
  /// In en, this message translates to:
  /// **'Transactions, budgeted amounts, rules, scheduled transactions and payee defaults move to the selected category. To Be Budgeted does not change.'**
  String get deleteCategoryMoveExplanation;

  /// Option when deleting a category: no target category.
  ///
  /// In en, this message translates to:
  /// **'Delete without replacement'**
  String get deleteCategoryNoTargetOption;

  /// Explains what happens when a category is deleted without a target.
  ///
  /// In en, this message translates to:
  /// **'The money budgeted in this category goes back to To Be Budgeted. Its transactions become uncategorized and also count towards To Be Budgeted. Rules, scheduled transactions and payee defaults that use it are cleared.'**
  String get deleteCategoryNoTargetExplanation;

  /// Label of the target category picker when deleting a category.
  ///
  /// In en, this message translates to:
  /// **'Target category'**
  String get deleteCategoryTargetLabel;

  /// Shown when no target category is available.
  ///
  /// In en, this message translates to:
  /// **'There is no other category to move to.'**
  String get deleteCategoryNoOtherCategories;

  /// Error when deleting a category fails.
  ///
  /// In en, this message translates to:
  /// **'The category could not be deleted. Please try again.'**
  String get deleteCategoryFailed;

  /// Snackbar after a category was deleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categoryDeletedMessage;

  /// Confirmation for deleting an empty category group.
  ///
  /// In en, this message translates to:
  /// **'This group contains no categories. Delete it?'**
  String get deleteGroupEmptyConfirmation;

  /// Shown when deleting a non-empty category group.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This group contains 1 category.} other{This group contains {count} categories.}} Choose a group to move them to. Their budgets and transactions move with them.'**
  String deleteGroupMoveExplanation(int count);

  /// Label of the target group picker.
  ///
  /// In en, this message translates to:
  /// **'Move categories to'**
  String get deleteGroupTargetLabel;

  /// Shown when a non-empty group cannot be deleted.
  ///
  /// In en, this message translates to:
  /// **'This group contains categories and there is no other group to move them to. Create another group or delete its categories first.'**
  String get deleteGroupNoOtherGroup;

  /// Error when deleting a category group fails.
  ///
  /// In en, this message translates to:
  /// **'The group could not be deleted. Please try again.'**
  String get deleteGroupFailed;

  /// Delete account dialog: recommend closing instead.
  ///
  /// In en, this message translates to:
  /// **'Recommended: close the account instead. A closed account is hidden from everyday use but keeps all transactions and history.'**
  String get deleteAccountCloseRecommendation;

  /// Delete account dialog: what deletion removes.
  ///
  /// In en, this message translates to:
  /// **'Deleting permanently removes all of this account\'s transactions and scheduled transactions. This cannot be undone.'**
  String get deleteAccountPermanentWarning;

  /// Delete account dialog: what happens to transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers to or from other accounts stay in those accounts as normal uncategorized transactions, which changes To Be Budgeted.'**
  String get deleteAccountTransfersWarning;

  /// Button in the delete account dialog.
  ///
  /// In en, this message translates to:
  /// **'Close account instead'**
  String get closeAccountInstead;

  /// Button for a permanent deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;

  /// Snackbar after an account was closed.
  ///
  /// In en, this message translates to:
  /// **'Account closed'**
  String get accountClosedMessage;

  /// Snackbar after an account was deleted; count = converted transfer legs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Account deleted.} =1{Account deleted. 1 transfer in another account is now a normal transaction.} other{Account deleted. {count} transfers in other accounts are now normal transactions.}}'**
  String accountDeletedMessage(int count);

  /// Error when deleting an account fails.
  ///
  /// In en, this message translates to:
  /// **'The account could not be deleted. Please try again.'**
  String get deleteAccountFailed;

  /// Error when closing/reopening an account fails.
  ///
  /// In en, this message translates to:
  /// **'The account could not be updated. Please try again.'**
  String get accountUpdateFailed;

  /// Title of an outgoing transfer leg.
  ///
  /// In en, this message translates to:
  /// **'Transfer to {account}'**
  String transferToAccount(String account);

  /// Title of an incoming transfer leg.
  ///
  /// In en, this message translates to:
  /// **'Transfer from {account}'**
  String transferFromAccount(String account);

  /// Error when deleting a payee fails.
  ///
  /// In en, this message translates to:
  /// **'The payee could not be deleted. Please try again.'**
  String get deletePayeeFailed;

  /// Error when merging payees fails.
  ///
  /// In en, this message translates to:
  /// **'The payees could not be merged. Please try again.'**
  String get mergePayeeFailed;

  /// Memo of the adjustment transaction created by reconciliation.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation balance adjustment'**
  String get reconcileAdjustmentMemo;

  /// Account balance including uncleared transactions.
  ///
  /// In en, this message translates to:
  /// **'Working balance'**
  String get reconcileWorkingBalance;

  /// Balance of cleared and reconciled transactions.
  ///
  /// In en, this message translates to:
  /// **'Cleared balance'**
  String get reconcileClearedBalance;

  /// Cleared balance up to the chosen statement date.
  ///
  /// In en, this message translates to:
  /// **'Cleared balance up to the statement date'**
  String get reconcileClearedUpToDate;

  /// Date of the bank statement.
  ///
  /// In en, this message translates to:
  /// **'Statement date'**
  String get reconcileStatementDate;

  /// Balance shown on the bank statement.
  ///
  /// In en, this message translates to:
  /// **'Statement balance'**
  String get reconcileStatementBalance;

  /// Statement balance minus cleared balance.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get reconcileDifference;

  /// Explains what reconciling does.
  ///
  /// In en, this message translates to:
  /// **'All cleared transactions up to the statement date will be marked as reconciled. If the cleared balance differs from the statement, an uncategorized adjustment is created; it counts towards To Be Budgeted.'**
  String get reconcileExplanation;

  /// Result of a reconciliation without adjustment.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions to reconcile. The balance matches the statement.} =1{1 transaction reconciled. The balance matches the statement.} other{{count} transactions reconciled. The balance matches the statement.}}'**
  String reconcileResultMatched(int count);

  /// Result of a reconciliation that created an adjustment.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions reconciled.} =1{1 transaction reconciled.} other{{count} transactions reconciled.}} An adjustment of {amount} was created.'**
  String reconcileResultAdjusted(int count, String amount);

  /// Error when reconciling fails.
  ///
  /// In en, this message translates to:
  /// **'The account could not be reconciled. Please try again.'**
  String get reconcileFailed;

  /// Label of the source account field of a transfer
  ///
  /// In en, this message translates to:
  /// **'From Account'**
  String get fromAccount;

  /// Validation error of the split editor
  ///
  /// In en, this message translates to:
  /// **'The split amounts must add up to the total amount.'**
  String get txSplitSumMismatch;

  /// Validation error of the split editor
  ///
  /// In en, this message translates to:
  /// **'Every split line needs an amount.'**
  String get txSplitLineZero;

  /// Validation error for transfers
  ///
  /// In en, this message translates to:
  /// **'Source and destination accounts must be different.'**
  String get txTransferSameAccount;

  /// Validation error for split transfers
  ///
  /// In en, this message translates to:
  /// **'A transfer cannot be split.'**
  String get txTransferNoSplit;

  /// Shown when saving a recurring split
  ///
  /// In en, this message translates to:
  /// **'Recurring split transactions are not supported yet.'**
  String get txRecurringSplitUnsupported;

  /// Shown when saving a recurring transfer
  ///
  /// In en, this message translates to:
  /// **'Recurring transfers are not supported yet.'**
  String get txRecurringTransferUnsupported;

  /// Snackbar after creating a recurring transaction
  ///
  /// In en, this message translates to:
  /// **'Scheduled transaction created'**
  String get txScheduledCreated;

  /// Generic save error
  ///
  /// In en, this message translates to:
  /// **'The transaction could not be saved.'**
  String get txSaveFailed;

  /// Title of the confirmation before changing a reconciled transaction
  ///
  /// In en, this message translates to:
  /// **'Change a reconciled transaction?'**
  String get txReconciledChangeTitle;

  /// Body of the confirmation before changing a reconciled transaction
  ///
  /// In en, this message translates to:
  /// **'This transaction is already reconciled with a bank statement. If you change it, your reconciled balance no longer matches that statement.'**
  String get txReconciledChangeMessage;

  /// Extra note in the delete confirmation
  ///
  /// In en, this message translates to:
  /// **'This includes transactions already reconciled with a bank statement. If you delete them, your reconciled balance no longer matches that statement.'**
  String get txReconciledDeleteMessage;

  /// Confirm button for changing a reconciled transaction
  ///
  /// In en, this message translates to:
  /// **'Change anyway'**
  String get txChangeAnyway;

  /// Title of the delete confirmation for one transaction
  ///
  /// In en, this message translates to:
  /// **'Delete transaction?'**
  String get txDeleteTitle;

  /// Title of the bulk delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete {count} transactions?'**
  String txDeleteManyTitle(int count);

  /// Body of the delete confirmation
  ///
  /// In en, this message translates to:
  /// **'You can undo this right after deleting.'**
  String get txDeleteMessage;

  /// Note in the delete confirmation when a transfer is involved
  ///
  /// In en, this message translates to:
  /// **'The other side of the transfer is deleted too.'**
  String get txDeleteTransferNote;

  /// Note in the delete confirmation when a split is involved
  ///
  /// In en, this message translates to:
  /// **'The whole split transaction with all of its lines is deleted.'**
  String get txDeleteSplitNote;

  /// Snackbar after deleting transactions
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Transaction deleted} other{{count} transactions deleted}}'**
  String txDeletedCount(int count);

  /// Generic error for a failed transaction action
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get txActionFailed;

  /// Hint of the transaction search field
  ///
  /// In en, this message translates to:
  /// **'Search payee, category, memo or amount'**
  String get txSearchHint;

  /// Section title of the payee filter
  ///
  /// In en, this message translates to:
  /// **'Payees'**
  String get txFilterPayees;

  /// Lower bound of the amount filter (absolute amount)
  ///
  /// In en, this message translates to:
  /// **'Amount from'**
  String get txFilterAmountFrom;

  /// Upper bound of the amount filter (absolute amount)
  ///
  /// In en, this message translates to:
  /// **'Amount to'**
  String get txFilterAmountTo;

  /// Title of the category activity list opened from the budget
  ///
  /// In en, this message translates to:
  /// **'{category}: {month}'**
  String txCategoryActivityTitle(String category, String month);

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @masterPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Master password'**
  String get masterPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Password rule shown under a new password field
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters'**
  String passwordMinLength(int count);

  /// No description provided for @passwordTooCommon.
  ///
  /// In en, this message translates to:
  /// **'This password is too common. Please choose another one.'**
  String get passwordTooCommon;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'A long passphrase of several words is easiest to remember.'**
  String get passwordHint;

  /// No description provided for @passwordStrengthTitle.
  ///
  /// In en, this message translates to:
  /// **'Password strength: {label}'**
  String passwordStrengthTitle(String label);

  /// No description provided for @passwordStrengthTooShort.
  ///
  /// In en, this message translates to:
  /// **'too short'**
  String get passwordStrengthTooShort;

  /// No description provided for @passwordStrengthCommon.
  ///
  /// In en, this message translates to:
  /// **'too common'**
  String get passwordStrengthCommon;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'good'**
  String get passwordStrengthGood;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'strong'**
  String get passwordStrengthStrong;

  /// No description provided for @setupProtectTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your data'**
  String get setupProtectTitle;

  /// No description provided for @setupFailed.
  ///
  /// In en, this message translates to:
  /// **'Security setup failed. Please try again.'**
  String get setupFailed;

  /// No description provided for @biometricPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock LedgerZero'**
  String get biometricPromptTitle;

  /// No description provided for @biometricPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it is you to unlock your data'**
  String get biometricPromptSubtitle;

  /// No description provided for @loginUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get loginUnlock;

  /// No description provided for @loginUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get loginUseBiometrics;

  /// No description provided for @loginUseRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Use recovery key'**
  String get loginUseRecoveryKey;

  /// No description provided for @loginVaultMissing.
  ///
  /// In en, this message translates to:
  /// **'The key data of this app is missing, so your data cannot be unlocked. You can reset the app and restore a backup.'**
  String get loginVaultMissing;

  /// No description provided for @loginDatabaseKeyMismatch.
  ///
  /// In en, this message translates to:
  /// **'Your key is correct, but the database file could not be opened with it.'**
  String get loginDatabaseKeyMismatch;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Unlocking failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @biometricsInvalidated.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock was turned off because the biometrics on this device changed. Unlock with your password and turn it on again in Settings.'**
  String get biometricsInvalidated;

  /// No description provided for @biometricsUnlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock failed. Please use your password.'**
  String get biometricsUnlockFailed;

  /// No description provided for @recoveryKeyEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery key'**
  String get recoveryKeyEnterTitle;

  /// No description provided for @recoveryKeyEnterHint.
  ///
  /// In en, this message translates to:
  /// **'32 characters; spaces and dashes are optional'**
  String get recoveryKeyEnterHint;

  /// No description provided for @recoveryKeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'This recovery key is not correct.'**
  String get recoveryKeyInvalid;

  /// No description provided for @recoveryKeyNeedsPassword.
  ///
  /// In en, this message translates to:
  /// **'An update is still being completed. Please unlock once with your password.'**
  String get recoveryKeyNeedsPassword;

  /// No description provided for @encryptionStatusEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted with SQLCipher (AES-256)'**
  String get encryptionStatusEncrypted;

  /// No description provided for @encryptionStatusPlaintext.
  ///
  /// In en, this message translates to:
  /// **'The database file is NOT encrypted'**
  String get encryptionStatusPlaintext;

  /// No description provided for @encryptionStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get encryptionStatusUnknown;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @privacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySection;

  /// No description provided for @crashReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Save crash reports'**
  String get crashReportsTitle;

  /// No description provided for @crashReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When on, errors are recorded on this device only, with amounts, e-mail addresses and database values removed. Nothing is sent unless you share the log yourself.'**
  String get crashReportsSubtitle;

  /// No description provided for @notificationAmountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show amounts in notifications'**
  String get notificationAmountsTitle;

  /// No description provided for @notificationAmountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, reminders only say that a transaction is due, so no financial details appear on the lock screen.'**
  String get notificationAmountsSubtitle;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic log'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and share saved crash reports'**
  String get diagnosticsSubtitle;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No diagnostic data saved.'**
  String get diagnosticsEmpty;

  /// No description provided for @diagnosticsShareExplanation.
  ///
  /// In en, this message translates to:
  /// **'This is exactly what will be shared. Please review it before sending it to anyone.'**
  String get diagnosticsShareExplanation;

  /// No description provided for @diagnosticsShare.
  ///
  /// In en, this message translates to:
  /// **'Share diagnostic log'**
  String get diagnosticsShare;

  /// No description provided for @diagnosticsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete diagnostic data'**
  String get diagnosticsDelete;

  /// No description provided for @diagnosticsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic data deleted'**
  String get diagnosticsDeleted;

  /// No description provided for @notificationScheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming transaction'**
  String get notificationScheduledTitle;

  /// No description provided for @notificationScheduledBodyGeneric.
  ///
  /// In en, this message translates to:
  /// **'A scheduled transaction is due tomorrow.'**
  String get notificationScheduledBodyGeneric;

  /// No description provided for @notificationScheduledBodyAmount.
  ///
  /// In en, this message translates to:
  /// **'A scheduled transaction of {amount} is due tomorrow.'**
  String notificationScheduledBodyAmount(String amount);

  /// No description provided for @backupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreateTitle;

  /// No description provided for @backupCreateExplanation.
  ///
  /// In en, this message translates to:
  /// **'A full copy of your data, always encrypted with a backup password you choose. Keep this password: without it the backup cannot be opened. For a readable copy, use the JSON or CSV export instead.'**
  String get backupCreateExplanation;

  /// No description provided for @backupPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPasswordLabel;

  /// No description provided for @backupUploadToCloud.
  ///
  /// In en, this message translates to:
  /// **'Also upload to your sync storage'**
  String get backupUploadToCloud;

  /// No description provided for @backupUploadNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Set up Google Drive sync first'**
  String get backupUploadNotConfigured;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExport;

  /// No description provided for @backupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating backup…'**
  String get backupCreating;

  /// No description provided for @backupUploaded.
  ///
  /// In en, this message translates to:
  /// **'Backup uploaded'**
  String get backupUploaded;

  /// No description provided for @backupUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. The backup was still created and can be shared.'**
  String get backupUploadFailed;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup failed. Please try again.'**
  String get backupFailed;

  /// No description provided for @backupShareSubject.
  ///
  /// In en, this message translates to:
  /// **'LedgerZero backup'**
  String get backupShareSubject;

  /// No description provided for @restoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreTitle;

  /// No description provided for @restoreExplanation.
  ///
  /// In en, this message translates to:
  /// **'Replace all data on this device with a backup file (.lzbk).'**
  String get restoreExplanation;

  /// No description provided for @restoreFromFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get restoreFromFile;

  /// No description provided for @restoreSelective.
  ///
  /// In en, this message translates to:
  /// **'Merge transactions from a backup (date range)'**
  String get restoreSelective;

  /// No description provided for @restorePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the backup password'**
  String get restorePasswordTitle;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all data?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Everything on this device will be replaced by the backup. If you use sync, changes made on your other devices after this backup was created will sync back in.'**
  String get restoreConfirmMessage;

  /// No description provided for @restoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreAction;

  /// No description provided for @restoreSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get restoreSuccessTitle;

  /// No description provided for @restoreSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your data was restored. If you use sync, this device will resynchronise and newer changes from your other devices will come back in.'**
  String get restoreSuccessMessage;

  /// No description provided for @restoreWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong backup password, or the file is damaged.'**
  String get restoreWrongPassword;

  /// No description provided for @restoreInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'This file is not a LedgerZero backup that can be restored.'**
  String get restoreInvalidFile;

  /// No description provided for @restoreNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of LedgerZero. Please update the app first.'**
  String get restoreNewerVersion;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'The restore failed. Your data was not changed.'**
  String get restoreFailed;

  /// No description provided for @selectiveRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transactions merged.'**
  String get selectiveRestoreSuccess;

  /// No description provided for @syncPassphraseSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a sync passphrase'**
  String get syncPassphraseSetTitle;

  /// No description provided for @syncPassphraseSetExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted before it leaves this device. Choose a sync passphrase: you need to enter it on every device you want to sync. It cannot be recovered, not even by the developer, so keep it somewhere safe.'**
  String get syncPassphraseSetExplanation;

  /// No description provided for @syncPassphraseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your sync passphrase'**
  String get syncPassphraseEnterTitle;

  /// No description provided for @syncPassphraseEnterExplanation.
  ///
  /// In en, this message translates to:
  /// **'This sync folder is already used by another device. Enter the sync passphrase you set there.'**
  String get syncPassphraseEnterExplanation;

  /// No description provided for @syncPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync passphrase'**
  String get syncPassphraseLabel;

  /// No description provided for @syncPassphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm sync passphrase'**
  String get syncPassphraseConfirmLabel;

  /// No description provided for @syncPassphraseSetButton.
  ///
  /// In en, this message translates to:
  /// **'Set passphrase'**
  String get syncPassphraseSetButton;

  /// No description provided for @syncPassphraseEnterButton.
  ///
  /// In en, this message translates to:
  /// **'Enter passphrase'**
  String get syncPassphraseEnterButton;

  /// No description provided for @syncPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong sync passphrase.'**
  String get syncPassphraseWrong;

  /// No description provided for @syncPassphraseFolderExists.
  ///
  /// In en, this message translates to:
  /// **'Another device has just set up sync. Enter the passphrase set there.'**
  String get syncPassphraseFolderExists;

  /// No description provided for @syncPassphraseFailed.
  ///
  /// In en, this message translates to:
  /// **'The sync passphrase could not be saved. Please try again.'**
  String get syncPassphraseFailed;

  /// No description provided for @syncPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All changes uploaded} =1{1 change waiting to upload} other{{count} changes waiting to upload}}'**
  String syncPendingChanges(int count);

  /// No description provided for @syncUpdateAppRequired.
  ///
  /// In en, this message translates to:
  /// **'Another device uses a newer version of LedgerZero. Update the app to sync its changes.'**
  String get syncUpdateAppRequired;

  /// No description provided for @syncLegacyFolderFound.
  ///
  /// In en, this message translates to:
  /// **'The sync folder still contains files from an older LedgerZero version (ending in .json.gz). They are no longer used and can be deleted.'**
  String get syncLegacyFolderFound;

  /// No description provided for @syncQuarantineTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change file could not be applied} other{{count} change files could not be applied}}'**
  String syncQuarantineTitle(int count);

  /// No description provided for @syncQuarantineExplanation.
  ///
  /// In en, this message translates to:
  /// **'Changes from the affected device wait until the file can be applied. Other devices keep syncing.'**
  String get syncQuarantineExplanation;

  /// No description provided for @syncQuarantineRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get syncQuarantineRetry;

  /// No description provided for @syncQuarantineShare.
  ///
  /// In en, this message translates to:
  /// **'Share diagnostics'**
  String get syncQuarantineShare;

  /// No description provided for @syncQuarantineSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip file'**
  String get syncQuarantineSkip;

  /// No description provided for @syncQuarantineSkipConfirm.
  ///
  /// In en, this message translates to:
  /// **'The changes in this file will not be applied on this device. Skip it?'**
  String get syncQuarantineSkipConfirm;

  /// No description provided for @syncConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync conflicts'**
  String get syncConflictsTitle;

  /// No description provided for @syncConflictsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No conflicts} =1{1 change was replaced by a newer one} other{{count} changes were replaced by newer ones}}'**
  String syncConflictsCount(int count);

  /// No description provided for @syncConflictsExplanation.
  ///
  /// In en, this message translates to:
  /// **'These edits made on this device lost against newer edits made on another device. Keep yours to apply them again on all devices.'**
  String get syncConflictsExplanation;

  /// No description provided for @syncConflictsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sync conflicts.'**
  String get syncConflictsEmpty;

  /// No description provided for @syncConflictKeepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get syncConflictKeepMine;

  /// No description provided for @syncConflictDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get syncConflictDismiss;

  /// No description provided for @syncConflictKeepFailed.
  ///
  /// In en, this message translates to:
  /// **'Your version could not be restored because it refers to data that was deleted.'**
  String get syncConflictKeepFailed;

  /// No description provided for @syncConflictMine.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get syncConflictMine;

  /// No description provided for @syncConflictTheirs.
  ///
  /// In en, this message translates to:
  /// **'Other device'**
  String get syncConflictTheirs;

  /// No description provided for @syncConflictDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get syncConflictDeleted;

  /// No description provided for @syncConflictResolvedAt.
  ///
  /// In en, this message translates to:
  /// **'Replaced on {time}'**
  String syncConflictResolvedAt(String time);

  /// No description provided for @syncTableAccounts.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get syncTableAccounts;

  /// No description provided for @syncTableCategories.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get syncTableCategories;

  /// No description provided for @syncTableCategoryGroups.
  ///
  /// In en, this message translates to:
  /// **'Category group'**
  String get syncTableCategoryGroups;

  /// No description provided for @syncTableTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get syncTableTransactions;

  /// No description provided for @syncTablePayees.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get syncTablePayees;

  /// No description provided for @syncTableBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get syncTableBudgets;

  /// No description provided for @syncTableScheduledTransactions.
  ///
  /// In en, this message translates to:
  /// **'Scheduled transaction'**
  String get syncTableScheduledTransactions;

  /// No description provided for @syncTableBudgetTemplates.
  ///
  /// In en, this message translates to:
  /// **'Budget template'**
  String get syncTableBudgetTemplates;

  /// No description provided for @syncTableReportNotes.
  ///
  /// In en, this message translates to:
  /// **'Report note'**
  String get syncTableReportNotes;

  /// No description provided for @syncTableImportProfiles.
  ///
  /// In en, this message translates to:
  /// **'Import profile'**
  String get syncTableImportProfiles;

  /// No description provided for @syncTableRules.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get syncTableRules;

  /// No description provided for @syncStatusConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {email}'**
  String syncStatusConnectedAs(String email);

  /// No description provided for @syncStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get syncStatusConnected;

  /// No description provided for @syncStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get syncStatusDisconnected;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused while the app is locked'**
  String get syncStatusPaused;

  /// No description provided for @pickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get pickerNoMatches;

  /// No description provided for @scheduledDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this scheduled transaction? Transactions it has already created are kept.'**
  String get scheduledDeleteConfirmation;

  /// No description provided for @scheduledSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The scheduled transaction could not be saved. Please try again.'**
  String get scheduledSaveFailed;

  /// No description provided for @scheduledLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The scheduled transaction could not be loaded.'**
  String get scheduledLoadFailed;

  /// No description provided for @scheduledActionFailed.
  ///
  /// In en, this message translates to:
  /// **'The scheduled transaction could not be updated. Please try again.'**
  String get scheduledActionFailed;

  /// No description provided for @incomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recurring income set up'**
  String get incomeEmpty;

  /// No description provided for @incomeAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Salary / Income'**
  String get incomeAddTitle;

  /// No description provided for @incomeAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get incomeAddButton;

  /// No description provided for @incomeEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Income'**
  String get incomeEditTitle;

  /// No description provided for @incomeUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get incomeUnknownSource;

  /// No description provided for @incomeSourceName.
  ///
  /// In en, this message translates to:
  /// **'Source name (e.g. My Salary)'**
  String get incomeSourceName;

  /// No description provided for @incomeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get incomeNameRequired;

  /// No description provided for @incomeDepositAccount.
  ///
  /// In en, this message translates to:
  /// **'Deposit account'**
  String get incomeDepositAccount;

  /// No description provided for @incomeSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Income'**
  String get incomeSaveButton;

  /// No description provided for @incomeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The income could not be saved. Please try again.'**
  String get incomeSaveFailed;

  /// No description provided for @recurrenceEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {count} {unit}'**
  String recurrenceEvery(int count, String unit);

  /// No description provided for @ynabImportTitle.
  ///
  /// In en, this message translates to:
  /// **'YNAB Migration'**
  String get ynabImportTitle;

  /// No description provided for @ynabImportSelectVersion.
  ///
  /// In en, this message translates to:
  /// **'Select your YNAB version'**
  String get ynabImportSelectVersion;

  /// No description provided for @ynabImportMethodCsv.
  ///
  /// In en, this message translates to:
  /// **'nYNAB (CSV Export)'**
  String get ynabImportMethodCsv;

  /// No description provided for @ynabImportMethodYnab4.
  ///
  /// In en, this message translates to:
  /// **'YNAB 4 (Classic)'**
  String get ynabImportMethodYnab4;

  /// No description provided for @ynabImportMethodHint.
  ///
  /// In en, this message translates to:
  /// **'For nYNAB: Export your budget as CSV from the web app.\nFor YNAB 4: Select your budget folder (ending in .ynab4).'**
  String get ynabImportMethodHint;

  /// No description provided for @ynabImportUploadCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload CSV Files'**
  String get ynabImportUploadCsvTitle;

  /// No description provided for @ynabImportNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get ynabImportNotSelected;

  /// No description provided for @ynabImportNextPreview.
  ///
  /// In en, this message translates to:
  /// **'Next: Preview'**
  String get ynabImportNextPreview;

  /// No description provided for @ynabImportSelectFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Select YNAB4 Folder'**
  String get ynabImportSelectFolderTitle;

  /// No description provided for @ynabImportBudgetFolder.
  ///
  /// In en, this message translates to:
  /// **'Budget Folder'**
  String get ynabImportBudgetFolder;

  /// No description provided for @ynabImportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Preview'**
  String get ynabImportPreviewTitle;

  /// No description provided for @ynabImportPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the data found in your import files.'**
  String get ynabImportPreviewSubtitle;

  /// No description provided for @ynabImportAccountClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get ynabImportAccountClosed;

  /// No description provided for @ynabImportAccountActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get ynabImportAccountActive;

  /// No description provided for @ynabImportAccountTypeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get ynabImportAccountTypeChecking;

  /// No description provided for @ynabImportAccountTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get ynabImportAccountTypeSavings;

  /// No description provided for @ynabImportAccountTypeCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get ynabImportAccountTypeCredit;

  /// No description provided for @ynabImportAccountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get ynabImportAccountTypeCash;

  /// No description provided for @ynabImportAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{type} • {status}'**
  String ynabImportAccountSubtitle(String type, String status);

  /// No description provided for @ynabImportCategoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String ynabImportCategoryCount(int count);

  /// No description provided for @ynabImportTotalTransactions.
  ///
  /// In en, this message translates to:
  /// **'Total Transactions'**
  String get ynabImportTotalTransactions;

  /// No description provided for @ynabImportBudgetEntries.
  ///
  /// In en, this message translates to:
  /// **'Budget Entries'**
  String get ynabImportBudgetEntries;

  /// No description provided for @ynabImportScheduledTransactions.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Transactions'**
  String get ynabImportScheduledTransactions;

  /// No description provided for @ynabImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Import'**
  String get ynabImportConfirm;

  /// No description provided for @ynabImportInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Migrating your budget…'**
  String get ynabImportInProgressTitle;

  /// No description provided for @ynabImportInProgressBody.
  ///
  /// In en, this message translates to:
  /// **'This may take a moment depending on the size of your history.'**
  String get ynabImportInProgressBody;

  /// No description provided for @ynabImportDoNotClose.
  ///
  /// In en, this message translates to:
  /// **'Please do not close the app or switch screens.'**
  String get ynabImportDoNotClose;

  /// No description provided for @ynabImportSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to LedgerZero!'**
  String get ynabImportSuccessTitle;

  /// No description provided for @ynabImportSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your YNAB data has been successfully migrated.'**
  String get ynabImportSuccessBody;

  /// No description provided for @ynabImportStartBudgeting.
  ///
  /// In en, this message translates to:
  /// **'Start Budgeting'**
  String get ynabImportStartBudgeting;

  /// No description provided for @ynabImportErrorFilePick.
  ///
  /// In en, this message translates to:
  /// **'The file could not be opened. Please try again.'**
  String get ynabImportErrorFilePick;

  /// No description provided for @ynabImportErrorFolderPick.
  ///
  /// In en, this message translates to:
  /// **'The folder could not be opened. Please try again.'**
  String get ynabImportErrorFolderPick;

  /// No description provided for @ynabImportErrorFilesMissing.
  ///
  /// In en, this message translates to:
  /// **'Please select both Register.csv and Budget.csv.'**
  String get ynabImportErrorFilesMissing;

  /// No description provided for @ynabImportErrorFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'Please select the YNAB 4 budget folder.'**
  String get ynabImportErrorFolderMissing;

  /// No description provided for @ynabImportErrorMissingColumns.
  ///
  /// In en, this message translates to:
  /// **'Register.csv is missing required columns: {columns}. Please export the register again from YNAB.'**
  String ynabImportErrorMissingColumns(String columns);

  /// No description provided for @ynabImportErrorInvalidYnab4.
  ///
  /// In en, this message translates to:
  /// **'This folder is not a valid YNAB 4 budget. Please select the folder ending in .ynab4.'**
  String get ynabImportErrorInvalidYnab4;

  /// No description provided for @ynabImportErrorUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The selected files could not be read. Please check that they are unmodified YNAB exports.'**
  String get ynabImportErrorUnreadable;

  /// No description provided for @ynabImportErrorImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The import failed. No data was changed; please try again.'**
  String get ynabImportErrorImportFailed;

  /// No description provided for @exportFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get exportFailedGeneric;

  /// No description provided for @emptyAccountTransactionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Transactions you add to this account appear here.'**
  String get emptyAccountTransactionsMessage;

  /// No description provided for @noMatchingTransactions.
  ///
  /// In en, this message translates to:
  /// **'No matching transactions'**
  String get noMatchingTransactions;

  /// No description provided for @noMatchingTransactionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or clear the filters.'**
  String get noMatchingTransactionsMessage;

  /// No description provided for @emptyTransactionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Record your first transaction to see it here.'**
  String get emptyTransactionsMessage;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @rules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rules;

  /// No description provided for @rulesSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Categorize new and imported transactions automatically'**
  String get rulesSettingsSubtitle;

  /// No description provided for @settingsManageSection.
  ///
  /// In en, this message translates to:
  /// **'Manage data'**
  String get settingsManageSection;

  /// No description provided for @importFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please check the file and try again.'**
  String get importFailedGeneric;

  /// No description provided for @clearCacheFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the cache.'**
  String get clearCacheFailed;

  /// No description provided for @backupAndExport.
  ///
  /// In en, this message translates to:
  /// **'Backup & Export'**
  String get backupAndExport;

  /// No description provided for @exportPlaintextWarning.
  ///
  /// In en, this message translates to:
  /// **'Exports are not encrypted: anyone who gets the file can read it.'**
  String get exportPlaintextWarning;

  /// No description provided for @exportAllCsv.
  ///
  /// In en, this message translates to:
  /// **'All transactions (CSV)'**
  String get exportAllCsv;

  /// No description provided for @exportAllCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A spreadsheet of every transaction'**
  String get exportAllCsvSubtitle;

  /// No description provided for @exportFilteredCsv.
  ///
  /// In en, this message translates to:
  /// **'Filtered transactions (CSV)'**
  String get exportFilteredCsv;

  /// No description provided for @exportFilteredCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose dates, accounts and categories'**
  String get exportFilteredCsvSubtitle;

  /// No description provided for @exportAllJson.
  ///
  /// In en, this message translates to:
  /// **'All data (JSON)'**
  String get exportAllJson;

  /// No description provided for @exportAllJsonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything in a format other apps can read'**
  String get exportAllJsonSubtitle;

  /// No description provided for @backupReminderFrequency.
  ///
  /// In en, this message translates to:
  /// **'Backup reminder'**
  String get backupReminderFrequency;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @exportFilterAll.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get exportFilterAll;

  /// No description provided for @exportFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected means everything is included.'**
  String get exportFilterHint;

  /// No description provided for @importSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String importSelectedCount(int count);

  /// No description provided for @categoriesImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new categories} =1{1 new category imported} other{{count} new categories imported}}'**
  String categoriesImported(int count);

  /// No description provided for @categoryImportInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'This file is not a category list. Expected the columns Group, Category (and optionally Hidden).'**
  String get categoryImportInvalidFile;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @noMatchingCategories.
  ///
  /// In en, this message translates to:
  /// **'No matching categories'**
  String get noMatchingCategories;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Add a category group to get started.'**
  String get noCategoriesYet;

  /// No description provided for @notificationChannelScheduledName.
  ///
  /// In en, this message translates to:
  /// **'Scheduled transactions'**
  String get notificationChannelScheduledName;

  /// No description provided for @notificationChannelScheduledDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders for upcoming scheduled transactions'**
  String get notificationChannelScheduledDescription;

  /// No description provided for @notificationChannelBackupName.
  ///
  /// In en, this message translates to:
  /// **'Backup reminders'**
  String get notificationChannelBackupName;

  /// No description provided for @notificationChannelBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders to back up your data'**
  String get notificationChannelBackupDescription;

  /// No description provided for @notificationChannelSyncName.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get notificationChannelSyncName;

  /// No description provided for @notificationChannelSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications when a sync fails'**
  String get notificationChannelSyncDescription;

  /// No description provided for @notificationChannelBudgetName.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get notificationChannelBudgetName;

  /// No description provided for @notificationChannelBudgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts when a category is overspent'**
  String get notificationChannelBudgetDescription;

  /// No description provided for @notificationOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationOpenAction;

  /// No description provided for @notificationBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup reminder'**
  String get notificationBackupTitle;

  /// No description provided for @notificationBackupBody.
  ///
  /// In en, this message translates to:
  /// **'It has been a while since your last backup. Tap to back up your data.'**
  String get notificationBackupBody;

  /// No description provided for @notificationSyncFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get notificationSyncFailedTitle;

  /// No description provided for @notificationSyncFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your data could not be synced. Tap to open the sync settings.'**
  String get notificationSyncFailedBody;

  /// No description provided for @notificationBudgetAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Category overspent'**
  String get notificationBudgetAlertTitle;

  /// No description provided for @notificationBudgetAlertBodyGeneric.
  ///
  /// In en, this message translates to:
  /// **'A budget category is overspent this month. Tap to review your budget.'**
  String get notificationBudgetAlertBodyGeneric;

  /// No description provided for @notificationBudgetAlertBodyAmount.
  ///
  /// In en, this message translates to:
  /// **'{category} is overspent by {amount} this month.'**
  String notificationBudgetAlertBodyAmount(String category, String amount);

  /// No description provided for @onboardingCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get onboardingCompleteTitle;

  /// No description provided for @onboardingCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Next, add the account you pay from, such as your checking account. Its balance becomes the money you can budget.'**
  String get onboardingCompleteMessage;

  /// No description provided for @onboardingCreateFirstAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your first account'**
  String get onboardingCreateFirstAccount;

  /// No description provided for @onboardingSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkipForNow;

  /// No description provided for @firstAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with one account'**
  String get firstAccountTitle;

  /// No description provided for @firstAccountExplanation.
  ///
  /// In en, this message translates to:
  /// **'Enter the current balance of an account you use every day. That amount becomes To Be Budgeted, ready to assign to your categories. You can add more accounts later.'**
  String get firstAccountExplanation;

  /// No description provided for @budgetNoAccountsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add an account first: its balance is the money you assign to your categories.'**
  String get budgetNoAccountsMessage;

  /// No description provided for @noAccountsYet.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccountsYet;

  /// No description provided for @noMatchingAccounts.
  ///
  /// In en, this message translates to:
  /// **'No matching accounts'**
  String get noMatchingAccounts;

  /// No description provided for @csvParseFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read as CSV. Please check its format.'**
  String get csvParseFailedGeneric;

  /// No description provided for @filePickFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'The file could not be opened.'**
  String get filePickFailedGeneric;

  /// No description provided for @reportNoDataToExport.
  ///
  /// In en, this message translates to:
  /// **'There is no data to export for this report.'**
  String get reportNoDataToExport;

  /// Screen reader label for a category's available amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} available'**
  String amountSemanticsAvailable(String amount);

  /// Screen reader label for a negative available amount (amount without sign).
  ///
  /// In en, this message translates to:
  /// **'{amount} overspent'**
  String amountSemanticsOverspent(String amount);

  /// Screen reader label for a category's budgeted amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} budgeted'**
  String amountSemanticsBudgeted(String amount);

  /// Screen reader label for a category's activity.
  ///
  /// In en, this message translates to:
  /// **'Activity {amount}'**
  String amountSemanticsActivity(String amount);

  /// Screen reader label for an account balance.
  ///
  /// In en, this message translates to:
  /// **'Balance {amount}'**
  String amountSemanticsBalance(String amount);

  /// Screen reader label for a positive or zero To Be Budgeted amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} to be budgeted'**
  String amountSemanticsToBeBudgeted(String amount);

  /// Screen reader label for a negative To Be Budgeted amount (amount without sign).
  ///
  /// In en, this message translates to:
  /// **'{amount} overbudgeted'**
  String amountSemanticsOverbudgeted(String amount);

  /// Screen reader label for a positive transaction amount (amount without sign).
  ///
  /// In en, this message translates to:
  /// **'Inflow {amount}'**
  String amountSemanticsInflow(String amount);

  /// Screen reader label for a negative transaction amount (amount without sign).
  ///
  /// In en, this message translates to:
  /// **'Outflow {amount}'**
  String amountSemanticsOutflow(String amount);

  /// Screen reader label for the budget progress view.
  ///
  /// In en, this message translates to:
  /// **'{spent} spent of {budgeted} budgeted'**
  String amountSemanticsSpentOfBudgeted(String spent, String budgeted);

  /// Screen reader summary of a bar chart; items is a comma separated list of 'label: amount'.
  ///
  /// In en, this message translates to:
  /// **'Bar Chart showing: {items}'**
  String chartBarSemantics(String items);

  /// Screen reader summary of a pie chart; items is a comma separated list of 'label percent'.
  ///
  /// In en, this message translates to:
  /// **'Pie chart: {items}'**
  String chartPieSemantics(String items);

  /// Screen reader summary of a line chart; series is one summary per line.
  ///
  /// In en, this message translates to:
  /// **'Line chart. {series}'**
  String chartLineSemantics(String series);

  /// Screen reader summary of one line of a line chart.
  ///
  /// In en, this message translates to:
  /// **'{series} from {start} to {end}: lowest {min}, highest {max}, latest {latest}'**
  String chartLineSeriesSemantics(
    String series,
    String start,
    String end,
    String min,
    String max,
    String latest,
  );

  /// Screen reader summary of the budget vs actual chart.
  ///
  /// In en, this message translates to:
  /// **'Budget vs actual: {items}'**
  String chartBudgetVsActualSemantics(String items);

  /// One category in the budget vs actual chart summary.
  ///
  /// In en, this message translates to:
  /// **'{category}: {budgeted} budgeted, {actual} spent'**
  String chartBudgetVsActualItemSemantics(
    String category,
    String budgeted,
    String actual,
  );

  /// Chart bucket that groups the smallest categories.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get chartOthers;

  /// Shown instead of a pie chart when all values are zero.
  ///
  /// In en, this message translates to:
  /// **'Total spending is zero'**
  String get chartTotalZero;

  /// Button that shows the next tutorial step.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutorialNext;

  /// Button on the last tutorial step.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get tutorialFinish;

  /// Shown in a transaction row without a payee.
  ///
  /// In en, this message translates to:
  /// **'No Payee'**
  String get transactionNoPayee;

  /// Screen reader label and tooltip of the icon on unapproved transactions.
  ///
  /// In en, this message translates to:
  /// **'Not yet approved'**
  String get transactionNotApproved;

  /// Clear status of a reconciled transaction.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get transactionStatusReconciled;

  /// Tooltip of the clear status button in a transaction row.
  ///
  /// In en, this message translates to:
  /// **'{status}. Tap to change'**
  String transactionClearStatusTooltip(String status);

  /// Account type.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get accountTypeChecking;

  /// Account type.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountTypeSavings;

  /// Account type.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get accountTypeCredit;

  /// Account type.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// Screen reader label of the warning icon on a category budgeted below its goal.
  ///
  /// In en, this message translates to:
  /// **'Below goal target'**
  String get budgetGoalUnderfunded;

  /// Generic button: close a dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Generic button: add the item being edited
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Name shown when a referenced item (category, payee, account) no longer exists
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Validation error for an empty required text field
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// Placeholder of a picker field with no selection
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get tapToSelect;

  /// Label/title of a category picker
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get pickerSelectCategory;

  /// Label/title of a payee picker
  ///
  /// In en, this message translates to:
  /// **'Select payee'**
  String get pickerSelectPayee;

  /// Label/title of an account picker
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get pickerSelectAccount;

  /// Title of the rule template dialog
  ///
  /// In en, this message translates to:
  /// **'Choose a template'**
  String get ruleChooseTemplate;

  /// Validation when saving a rule without conditions
  ///
  /// In en, this message translates to:
  /// **'Add at least one condition.'**
  String get ruleNeedsCondition;

  /// Validation when saving a rule without actions
  ///
  /// In en, this message translates to:
  /// **'Add at least one action.'**
  String get ruleNeedsAction;

  /// Title of the delete-rule confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete rule?'**
  String get ruleDeleteTitle;

  /// Body of the delete-rule confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this rule?'**
  String get ruleDeleteMessage;

  /// App bar title when editing a rule
  ///
  /// In en, this message translates to:
  /// **'Edit Rule'**
  String get ruleEditTitle;

  /// App bar title when creating a rule
  ///
  /// In en, this message translates to:
  /// **'New Rule'**
  String get ruleNewTitle;

  /// Tooltip of the button that opens rule templates
  ///
  /// In en, this message translates to:
  /// **'Use template'**
  String get ruleUseTemplate;

  /// Label of the rule name field
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get ruleNameLabel;

  /// Switch: whether the rule is applied
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get ruleActive;

  /// Section heading in the rule editor
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get ruleConditionsHeading;

  /// Section heading in the rule editor
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get ruleActionsHeading;

  /// Label before the all/any dropdown in the rule editor
  ///
  /// In en, this message translates to:
  /// **'Applies when'**
  String get ruleMatchLabel;

  /// Rule match logic AND; follows 'Applies when'
  ///
  /// In en, this message translates to:
  /// **'all conditions match'**
  String get ruleMatchAll;

  /// Rule match logic OR; follows 'Applies when'
  ///
  /// In en, this message translates to:
  /// **'any condition matches'**
  String get ruleMatchAny;

  /// Button/dialog title in the rule editor
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get ruleAddCondition;

  /// Button/dialog title in the rule editor
  ///
  /// In en, this message translates to:
  /// **'Add action'**
  String get ruleAddAction;

  /// Save button of the rule editor
  ///
  /// In en, this message translates to:
  /// **'Save rule'**
  String get ruleSave;

  /// Label of the condition field dropdown
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get ruleFieldLabel;

  /// Label of the condition operator dropdown
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get ruleOperatorLabel;

  /// Label of the condition/action value field
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get ruleValueLabel;

  /// Label of the action type dropdown
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get ruleActionLabel;

  /// Rule condition field
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get ruleFieldPayee;

  /// Rule condition field
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get ruleFieldAmount;

  /// Rule condition field: transaction memo or imported bank description
  ///
  /// In en, this message translates to:
  /// **'Memo / description'**
  String get ruleFieldDescription;

  /// Rule condition operator
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get ruleOperatorEquals;

  /// Rule condition operator
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get ruleOperatorContains;

  /// Rule condition operator
  ///
  /// In en, this message translates to:
  /// **'starts with'**
  String get ruleOperatorStartsWith;

  /// Rule condition operator
  ///
  /// In en, this message translates to:
  /// **'ends with'**
  String get ruleOperatorEndsWith;

  /// Rule condition operator
  ///
  /// In en, this message translates to:
  /// **'is greater than'**
  String get ruleOperatorGreaterThan;

  /// Rule condition operator
  ///
  /// In en, this message translates to:
  /// **'is less than'**
  String get ruleOperatorLessThan;

  /// Rule condition operator: regular expression
  ///
  /// In en, this message translates to:
  /// **'matches pattern (regex)'**
  String get ruleOperatorRegex;

  /// Rule action type
  ///
  /// In en, this message translates to:
  /// **'Set category'**
  String get ruleActionSetCategory;

  /// Rule action type
  ///
  /// In en, this message translates to:
  /// **'Set payee'**
  String get ruleActionSetPayee;

  /// Rule action type
  ///
  /// In en, this message translates to:
  /// **'Set account'**
  String get ruleActionSetAccount;

  /// Rule action type
  ///
  /// In en, this message translates to:
  /// **'Set memo'**
  String get ruleActionSetMemo;

  /// Rule action type
  ///
  /// In en, this message translates to:
  /// **'Mark as cleared'**
  String get ruleActionMarkCleared;

  /// Rule action type
  ///
  /// In en, this message translates to:
  /// **'Mark as approved'**
  String get ruleActionMarkApproved;

  /// Summary of a rule action
  ///
  /// In en, this message translates to:
  /// **'Set category to “{name}”'**
  String ruleActionSummarySetCategory(String name);

  /// Summary of a rule action
  ///
  /// In en, this message translates to:
  /// **'Set payee to “{name}”'**
  String ruleActionSummarySetPayee(String name);

  /// Summary of a rule action
  ///
  /// In en, this message translates to:
  /// **'Set account to “{name}”'**
  String ruleActionSummarySetAccount(String name);

  /// Summary of a rule action
  ///
  /// In en, this message translates to:
  /// **'Set memo to “{memo}”'**
  String ruleActionSummarySetMemo(String memo);

  /// Summary of a yes/no rule action, e.g. 'Mark as cleared: Yes'
  ///
  /// In en, this message translates to:
  /// **'{action}: {value}'**
  String ruleActionSummaryFlag(String action, String value);

  /// Rule template title; also the name of the created rule
  ///
  /// In en, this message translates to:
  /// **'Categorize by payee name'**
  String get ruleTemplatePayeeTitle;

  /// Rule template description
  ///
  /// In en, this message translates to:
  /// **'Set a category when the payee name contains a keyword.'**
  String get ruleTemplatePayeeDescription;

  /// Rule template title; also the name of the created rule
  ///
  /// In en, this message translates to:
  /// **'Auto-clear small amounts'**
  String get ruleTemplateAutoClearTitle;

  /// Rule template description
  ///
  /// In en, this message translates to:
  /// **'Mark transactions under a set amount as cleared.'**
  String get ruleTemplateAutoClearDescription;

  /// Rule template title; also the name of the created rule
  ///
  /// In en, this message translates to:
  /// **'Auto-approve a recurring bill'**
  String get ruleTemplateAutoApproveTitle;

  /// Rule template description
  ///
  /// In en, this message translates to:
  /// **'Approve transactions from one payee automatically (e.g. Netflix).'**
  String get ruleTemplateAutoApproveDescription;

  /// Rule template title; also the name of the created rule
  ///
  /// In en, this message translates to:
  /// **'Categorize by keyword'**
  String get ruleTemplateKeywordTitle;

  /// Rule template description
  ///
  /// In en, this message translates to:
  /// **'Set a category based on a keyword in the memo or description.'**
  String get ruleTemplateKeywordDescription;

  /// Example keyword pre-filled by the keyword rule template
  ///
  /// In en, this message translates to:
  /// **'coffee'**
  String get ruleTemplateKeywordExample;

  /// Snackbar after importing rules
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rules imported} =1{1 rule imported} other{{count} rules imported}}'**
  String rulesImported(int count);

  /// Snackbar when applying rules but none exist
  ///
  /// In en, this message translates to:
  /// **'There are no rules to apply.'**
  String get rulesNoneToApply;

  /// Title of the apply-rules confirmation
  ///
  /// In en, this message translates to:
  /// **'Apply rules?'**
  String get rulesApplyTitle;

  /// Body of the apply-rules confirmation
  ///
  /// In en, this message translates to:
  /// **'All existing transactions are checked and the active rules are applied. This cannot be undone automatically.'**
  String get rulesApplyMessage;

  /// Snackbar after applying rules to all transactions
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions changed} =1{1 transaction updated} other{{count} transactions updated}}'**
  String rulesApplied(int count);

  /// Rules screen menu item
  ///
  /// In en, this message translates to:
  /// **'Import rules'**
  String get rulesMenuImport;

  /// Rules screen menu item
  ///
  /// In en, this message translates to:
  /// **'Export rules'**
  String get rulesMenuExport;

  /// Rules screen menu item
  ///
  /// In en, this message translates to:
  /// **'Apply rules to all transactions'**
  String get rulesMenuApplyAll;

  /// Rules screen menu item
  ///
  /// In en, this message translates to:
  /// **'Suggest rules from history'**
  String get rulesMenuSuggest;

  /// Banner on the rules screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule conflict found} other{{count} rule conflicts found}}'**
  String rulesConflictsFound(int count);

  /// Title of the rule conflicts dialog
  ///
  /// In en, this message translates to:
  /// **'Rule conflicts'**
  String get rulesConflictsTitle;

  /// Two conflicting rule names
  ///
  /// In en, this message translates to:
  /// **'{first} vs. {second}'**
  String rulesConflictPair(String first, String second);

  /// Explains a rule conflict
  ///
  /// In en, this message translates to:
  /// **'Same conditions, but the actions contradict each other.'**
  String get rulesConflictExplanation;

  /// Generic button: show details
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Empty state of the rules screen
  ///
  /// In en, this message translates to:
  /// **'No rules yet'**
  String get rulesEmpty;

  /// Button on the empty rules screen
  ///
  /// In en, this message translates to:
  /// **'Create rule'**
  String get rulesCreate;

  /// Snackbar when reordering rules fails
  ///
  /// In en, this message translates to:
  /// **'The new order could not be saved.'**
  String get rulesReorderFailed;

  /// No description provided for @ruleConditionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 condition} other{{count} conditions}}'**
  String ruleConditionCount(int count);

  /// No description provided for @ruleActionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 action} other{{count} actions}}'**
  String ruleActionCount(int count);

  /// Rule list subtitle combining ruleConditionCount and ruleActionCount
  ///
  /// In en, this message translates to:
  /// **'{conditions}, {actions}'**
  String ruleSummary(String conditions, String actions);

  /// Snackbar when rule learning finds nothing
  ///
  /// In en, this message translates to:
  /// **'No suggestions found in your transaction history.'**
  String get rulesNoSuggestions;

  /// Title of the suggested rules dialog
  ///
  /// In en, this message translates to:
  /// **'Suggested rules'**
  String get rulesSuggestedTitle;

  /// Snackbar after adding a suggested rule
  ///
  /// In en, this message translates to:
  /// **'Rule added'**
  String get ruleAdded;

  /// Name of a rule suggested from history
  ///
  /// In en, this message translates to:
  /// **'Auto-categorize {payee}'**
  String ruleSuggestionName(String payee);

  /// Description of a rule suggested from history
  ///
  /// In en, this message translates to:
  /// **'Transactions from {payee} almost always have the same category.'**
  String ruleSuggestionDescription(String payee);

  /// Hint of the account search field
  ///
  /// In en, this message translates to:
  /// **'Search accounts'**
  String get accountSearchHint;

  /// Tooltip: close/clear the search field
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Tooltip of a filter button
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Tooltip of a sort button
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// Accounts filter menu item
  ///
  /// In en, this message translates to:
  /// **'Show closed accounts'**
  String get accountShowClosed;

  /// Account sort option
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get accountSortNameAsc;

  /// Account sort option
  ///
  /// In en, this message translates to:
  /// **'Name (Z–A)'**
  String get accountSortNameDesc;

  /// Account sort option
  ///
  /// In en, this message translates to:
  /// **'Balance (lowest first)'**
  String get accountSortBalanceAsc;

  /// Account sort option
  ///
  /// In en, this message translates to:
  /// **'Balance (highest first)'**
  String get accountSortBalanceDesc;

  /// Account sort option: by account type
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get accountSortType;

  /// Snackbar when an unsaved form draft is restored
  ///
  /// In en, this message translates to:
  /// **'Draft restored'**
  String get draftRestored;

  /// Snackbar after saving an account
  ///
  /// In en, this message translates to:
  /// **'Account updated'**
  String get accountUpdated;

  /// Snackbar after creating an account
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get accountCreated;

  /// Title of the leave-without-saving dialog
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get unsavedChangesTitle;

  /// Body of the leave-without-saving dialog
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Do you want to discard them?'**
  String get unsavedChangesMessage;

  /// Button: discard unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get editAccount;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// Label of the account name field
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountNameLabel;

  /// Example account name
  ///
  /// In en, this message translates to:
  /// **'e.g. Checking account'**
  String get accountNameHint;

  /// Helper text of the account name field
  ///
  /// In en, this message translates to:
  /// **'A name you recognise this account by'**
  String get accountNameHelper;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter an account name'**
  String get accountNameRequired;

  /// Label of the account type dropdown
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountTypeLabel;

  /// Helper text of the account type dropdown
  ///
  /// In en, this message translates to:
  /// **'Select the type of account'**
  String get accountTypeHelper;

  /// Label of the starting balance field
  ///
  /// In en, this message translates to:
  /// **'Starting Balance'**
  String get startingBalanceLabel;

  /// Helper text of the starting balance field
  ///
  /// In en, this message translates to:
  /// **'The current balance of the account'**
  String get startingBalanceHelper;

  /// Validation error for an amount field
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// Screen reader label of a colour swatch
  ///
  /// In en, this message translates to:
  /// **'Color {index}'**
  String colorOption(int index);

  /// Save button when editing
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Account icon name (screen reader)
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get accountIconWallet;

  /// Account icon name (screen reader)
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountIconBank;

  /// Account icon name (screen reader)
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get accountIconCard;

  /// Account icon name (screen reader)
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountIconCash;

  /// Account icon name (screen reader)
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountIconSavings;

  /// Account icon name (screen reader)
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountIconInvestment;

  /// App bar title in multi-select mode
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// Tooltip: leave multi-select mode
  ///
  /// In en, this message translates to:
  /// **'Close selection'**
  String get closeSelection;

  /// Tooltip of a back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Tooltip in multi-select mode
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// Tooltip in multi-select mode
  ///
  /// In en, this message translates to:
  /// **'Approve selected'**
  String get approveSelected;

  /// Tooltip in multi-select mode
  ///
  /// In en, this message translates to:
  /// **'Categorize selected'**
  String get categorizeSelected;

  /// Tooltip in multi-select mode
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// Title of the transaction filter sheet
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// Filter section: cleared status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Empty account list in the filter sheet
  ///
  /// In en, this message translates to:
  /// **'No accounts found'**
  String get noAccountsFound;

  /// Empty category list in the filter sheet
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get noCategoriesFound;

  /// Placeholder of the date range filter
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get selectDateRange;

  /// A date range
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String dateRangeValue(String start, String end);

  /// Hint of the natural-language quick add field
  ///
  /// In en, this message translates to:
  /// **'e.g. “Lunch at Mario\'s \$15”'**
  String get quickAddHint;

  /// Badge: how sure the parser is
  ///
  /// In en, this message translates to:
  /// **'{percent}% match'**
  String quickAddConfidence(int percent);

  /// Heading in the quick add tips
  ///
  /// In en, this message translates to:
  /// **'Examples:'**
  String get quickAddExamplesHeading;

  /// Heading in the quick add tips
  ///
  /// In en, this message translates to:
  /// **'The app detects:'**
  String get quickAddDetectsHeading;

  /// Quick add example input
  ///
  /// In en, this message translates to:
  /// **'“Lunch 15”'**
  String get quickAddExample1;

  /// Quick add example input
  ///
  /// In en, this message translates to:
  /// **'“Coffee \$5 at Starbucks”'**
  String get quickAddExample2;

  /// Quick add example input with a relative date the parser understands
  ///
  /// In en, this message translates to:
  /// **'“Uber 25 tomorrow”'**
  String get quickAddExample3;

  /// Quick add example input detected as income
  ///
  /// In en, this message translates to:
  /// **'“Salary 3000” (income)'**
  String get quickAddExample4;

  /// A bullet list item
  ///
  /// In en, this message translates to:
  /// **'• {text}'**
  String bulletItem(String text);

  /// Tooltip of the quick add help button
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get quickAddTipsTooltip;

  /// Transaction tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get tutTxAmountTitle;

  /// Transaction tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Start by entering the transaction amount.'**
  String get tutTxAmountBody;

  /// Transaction tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Select Payee'**
  String get tutTxPayeeTitle;

  /// Transaction tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Choose who you paid or who paid you. New payees are saved automatically.'**
  String get tutTxPayeeBody;

  /// Transaction tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Assign Category'**
  String get tutTxCategoryTitle;

  /// Transaction tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Categorize this transaction to update your budget.'**
  String get tutTxCategoryBody;

  /// Transaction tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tutTxSaveTitle;

  /// Transaction tutorial step text; quotes the saveAndAddAnother button
  ///
  /// In en, this message translates to:
  /// **'Tap here to save. “Save & Add Another” keeps the form open for the next one.'**
  String get tutTxSaveBody;

  /// Budget tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Welcome to your Budget'**
  String get tutBudgetWelcomeTitle;

  /// Budget tutorial step text
  ///
  /// In en, this message translates to:
  /// **'This is where you plan your spending.'**
  String get tutBudgetWelcomeBody;

  /// Budget tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Select Month'**
  String get tutBudgetMonthTitle;

  /// Budget tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Switch months to plan ahead or review past budgets.'**
  String get tutBudgetMonthBody;

  /// Budget tutorial step title (same term as toBeBudgeted)
  ///
  /// In en, this message translates to:
  /// **'To Be Budgeted'**
  String get tutBudgetTbbTitle;

  /// Budget tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Money you have not assigned yet. Assign it to categories until this reaches zero.'**
  String get tutBudgetTbbBody;

  /// Budget tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Budget Categories'**
  String get tutBudgetCategoriesTitle;

  /// Budget tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Tap a category to assign money. You can also move money between categories.'**
  String get tutBudgetCategoriesBody;

  /// Sync tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Choose Provider'**
  String get tutSyncProviderTitle;

  /// Sync tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Sync through your own Google Drive. Your data is encrypted before it leaves this device.'**
  String get tutSyncProviderBody;

  /// Sync tutorial step title
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get tutSyncConnectTitle;

  /// Sync tutorial step text
  ///
  /// In en, this message translates to:
  /// **'Sign in, then set a sync passphrase. You enter the same passphrase on each of your devices.'**
  String get tutSyncConnectBody;

  /// Section heading in accessibility settings
  ///
  /// In en, this message translates to:
  /// **'Visual'**
  String get accessibilityVisualSection;

  /// Accessibility switch
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get highContrastTitle;

  /// Accessibility switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Stronger contrast for colours and borders'**
  String get highContrastSubtitle;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How does envelope budgeting work?'**
  String get faqBudgetingQ;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'You give all the money you have a job: assign it to categories until To Be Budgeted is zero. You spend from what a category has available. If you overspend, move money from another category to cover it.'**
  String get faqBudgetingA;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Is my data safe?'**
  String get faqSafeQ;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Your data is stored only on your phone, in an encrypted database whose key is kept in the phone’s secure hardware (Android KeyStore). The app lock adds your fingerprint, face or phone PIN. Synced data is encrypted before it leaves the phone. There are no LedgerZero servers, no tracking and no analytics.'**
  String get faqSafeA;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do my partner and I share a budget?'**
  String get faqSyncQ;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Sync Settings. At home, pair the phones over Wi-Fi by scanning a QR code. To sync while you are apart, both phones use the same Google Drive account and sync passphrase. The user guide chapter “Using LedgerZero with a partner” explains the details.'**
  String get faqSyncA;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Can I use the app offline?'**
  String get faqOfflineQ;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Yes. Everything works offline. Sync catches up automatically when you are back online.'**
  String get faqOfflineA;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do backups work?'**
  String get faqBackupQ;

  /// FAQ answer; menu names must match the settings labels
  ///
  /// In en, this message translates to:
  /// **'Settings > Backup & Export creates a backup file that is always encrypted with a backup password you choose. Without that password the backup cannot be restored. CSV and JSON exports are readable copies and are not encrypted.'**
  String get faqBackupA;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Can I import from YNAB or my bank?'**
  String get faqImportQ;

  /// FAQ answer; menu names must match the settings labels
  ///
  /// In en, this message translates to:
  /// **'Yes. Settings > YNAB Migration imports nYNAB CSV exports and YNAB 4 budgets. Settings > Import CSV reads the CSV export of your bank.'**
  String get faqImportA;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get guideStartTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'LedgerZero uses envelope budgeting: before you spend money, you give it a job by budgeting it to a category. Add the account your money is in, add your salary, then budget until To Be Budgeted is zero. The ⓘ buttons across the app explain each part where you need it.'**
  String get guideStartBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get guideAccountsTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'Add every account with its current balance. Accounts in the budget (checking, cash, credit cards) hold the money you budget. Savings, brokerage and pension accounts usually stay outside the budget: they count towards net worth only. The type sets the icon and whether a new account starts in the budget.'**
  String get guideAccountsBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Budgeting'**
  String get guideBudgetTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'On the Budget screen, tap a category’s budgeted amount to give it money, until To Be Budgeted is zero. Income without a category adds to To Be Budgeted; add your salary as recurring income to see what is coming. Each category keeps what is left from month to month. A new month starts empty: fill it like the month before or from a template, by hand or automatically. Money left unbudgeted at the end of a month is offered for savings in the next one.'**
  String get guideBudgetBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get guideTransactionsTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'Record each expense with a payee and a category; it reduces what the category has available. Quick Add lets you type a transaction in one line, rules categorise transactions automatically, and with card notifications on, payments from your bank app arrive as transactions to approve.'**
  String get guideTransactionsBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Overspending'**
  String get guideOverspendingTitle;

  /// User guide section text
  ///
  /// In en, this message translates to:
  /// **'When a category\'s available amount turns red, you have spent more than you budgeted. Move money from another category to cover it.'**
  String get guideOverspendingBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Reconciling'**
  String get guideReconcileTitle;

  /// User guide section text
  ///
  /// In en, this message translates to:
  /// **'Now and then, compare an account with your bank statement using Reconcile Account on the account screen. Cleared transactions are marked as reconciled, and any difference is recorded as an adjustment.'**
  String get guideReconcileBody;

  /// Button: next onboarding page
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Button on the last onboarding page
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Onboarding welcome slide
  ///
  /// In en, this message translates to:
  /// **'Private budgeting that stays on your device'**
  String get onbWelcomeTagline;

  /// Onboarding welcome slide
  ///
  /// In en, this message translates to:
  /// **'Take control of your money with envelope budgeting: no sign-up, no servers, no tracking.'**
  String get onbWelcomeBody;

  /// Onboarding benefits slide title
  ///
  /// In en, this message translates to:
  /// **'Why LedgerZero?'**
  String get onbBenefitsTitle;

  /// Onboarding benefit
  ///
  /// In en, this message translates to:
  /// **'No subscription'**
  String get onbBenefitPriceTitle;

  /// Onboarding benefit
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. No recurring fees.'**
  String get onbBenefitPriceBody;

  /// Onboarding benefit
  ///
  /// In en, this message translates to:
  /// **'Your data stays with you'**
  String get onbBenefitDataTitle;

  /// Onboarding benefit
  ///
  /// In en, this message translates to:
  /// **'Stored on your device and encrypted.'**
  String get onbBenefitDataBody;

  /// Onboarding benefit
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get onbBenefitOfflineTitle;

  /// Onboarding benefit
  ///
  /// In en, this message translates to:
  /// **'Everything works without an internet connection. No server needed.'**
  String get onbBenefitOfflineBody;

  /// Onboarding privacy slide title
  ///
  /// In en, this message translates to:
  /// **'Your data, your device'**
  String get onbPrivacyTitle;

  /// Onboarding privacy slide
  ///
  /// In en, this message translates to:
  /// **'Privacy by default. That means:'**
  String get onbPrivacyIntro;

  /// Onboarding privacy point
  ///
  /// In en, this message translates to:
  /// **'No tracking, analytics or telemetry.'**
  String get onbPrivacyNoTracking;

  /// Onboarding privacy point
  ///
  /// In en, this message translates to:
  /// **'All data is encrypted on your device with AES-256.'**
  String get onbPrivacyEncrypted;

  /// Onboarding privacy point
  ///
  /// In en, this message translates to:
  /// **'We never see your financial data. Sync runs through your own Google Drive, end-to-end encrypted.'**
  String get onbPrivacyOwnCloud;

  /// App bar title of the onboarding budgeting explanation
  ///
  /// In en, this message translates to:
  /// **'Budgeting Basics'**
  String get budgetBasicsTitle;

  /// Headline of the budgeting explanation (EN uses the well-known phrase)
  ///
  /// In en, this message translates to:
  /// **'Give Every Dollar a Job'**
  String get budgetBasicsHeadline;

  /// Budgeting explanation
  ///
  /// In en, this message translates to:
  /// **'LedgerZero uses envelope budgeting. Imagine envelopes for rent, groceries and fun: when you get paid, you put money into these envelopes.'**
  String get budgetBasicsBody1;

  /// Budgeting explanation
  ///
  /// In en, this message translates to:
  /// **'When an envelope is empty, you stop spending in that category or move money over from another envelope.'**
  String get budgetBasicsBody2;

  /// Budgeting tip title
  ///
  /// In en, this message translates to:
  /// **'Zero-based'**
  String get budgetBasicsTipZeroTitle;

  /// Budgeting tip
  ///
  /// In en, this message translates to:
  /// **'Assign money until To Be Budgeted is zero.'**
  String get budgetBasicsTipZeroBody;

  /// Budgeting tip title
  ///
  /// In en, this message translates to:
  /// **'Stay flexible'**
  String get budgetBasicsTipFlexTitle;

  /// Budgeting tip
  ///
  /// In en, this message translates to:
  /// **'Overspent? No problem: move money from another category.'**
  String get budgetBasicsTipFlexBody;

  /// Button that finishes the budgeting explanation
  ///
  /// In en, this message translates to:
  /// **'I\'m ready!'**
  String get budgetBasicsReady;

  /// Validation when saving a category without group
  ///
  /// In en, this message translates to:
  /// **'Please select a category group'**
  String get categoryGroupRequired;

  /// How many transactions use a category
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not used in any transaction} =1{Used in 1 transaction} other{Used in {count} transactions}}'**
  String categoryUsage(int count);

  /// Validation for an empty name field
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// Title of the category tips dialog
  ///
  /// In en, this message translates to:
  /// **'Tips for categories'**
  String get categoryTipsTitle;

  /// Body of the category tips dialog
  ///
  /// In en, this message translates to:
  /// **'• Group similar expenses (e.g. Housing, Food).\n• Hide a category instead of deleting it to keep its history.\n• Use icons or emojis to recognise categories quickly.\n• Keep it simple: start with broad categories and split them later if needed.'**
  String get categoryTipsBody;

  /// Validation in the move money dialog
  ///
  /// In en, this message translates to:
  /// **'Source and destination categories must be different'**
  String get moveMoneySameCategory;

  /// Validation of a category dropdown
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get selectCategoryRequired;

  /// Screen reader label of the calculator backspace key
  ///
  /// In en, this message translates to:
  /// **'Delete last digit'**
  String get calculatorBackspace;

  /// Keyboard skip link
  ///
  /// In en, this message translates to:
  /// **'Skip to content'**
  String get skipToContent;

  /// Section in the payee picker
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get payeeMatchesSection;

  /// Section in the payee picker
  ///
  /// In en, this message translates to:
  /// **'Similar'**
  String get payeeSimilarSection;

  /// How similar a suggested payee is
  ///
  /// In en, this message translates to:
  /// **'{percent}% match'**
  String payeeSimilarity(int percent);

  /// Empty search result in the payee picker
  ///
  /// In en, this message translates to:
  /// **'No payees found for “{query}”'**
  String payeeNoResults(String query);

  /// Fallback column header in a PDF report
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get reportPdfDataColumn;

  /// PDF report header; date formatted per user settings
  ///
  /// In en, this message translates to:
  /// **'Created on {date}'**
  String reportPdfCreatedOn(String date);

  /// PDF report footer
  ///
  /// In en, this message translates to:
  /// **'Generated by LedgerZero'**
  String get reportPdfFooter;

  /// PDF report page counter
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String reportPdfPageOf(int page, int pages);

  /// Text attached when sharing an exported report
  ///
  /// In en, this message translates to:
  /// **'LedgerZero report: {title}'**
  String reportShareText(String title);

  /// Chart series name in the income vs expense report
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get reportIncomeSeries;

  /// Chart series name in the income vs expense report
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportExpenseSeries;

  /// Error when an imported CSV file is empty
  ///
  /// In en, this message translates to:
  /// **'The CSV file contains no data.'**
  String get csvFileEmpty;

  /// File size in kilobytes
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String fileSizeKb(double size);

  /// CSV import validation error
  ///
  /// In en, this message translates to:
  /// **'Choose the column that contains the date.'**
  String get csvIssueDateNotMapped;

  /// CSV import validation error
  ///
  /// In en, this message translates to:
  /// **'Choose the column that contains the amount.'**
  String get csvIssueAmountNotMapped;

  /// CSV import validation error
  ///
  /// In en, this message translates to:
  /// **'The selected columns are not in this file.'**
  String get csvIssueColumnsMissing;

  /// CSV import validation error; format is a date pattern like dd.MM.yyyy
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row has a date that does not match the format {format}.} other{{count} rows have dates that do not match the format {format}.}}'**
  String csvIssueInvalidDates(int count, String format);

  /// CSV import validation warning
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row has an unreadable amount and will be skipped.} other{{count} rows have unreadable amounts and will be skipped.}}'**
  String csvIssueInvalidAmounts(int count);

  /// CSV import validation warning
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 date is far from the others. Please check it in the review.} other{{count} dates are far from the others. Please check them in the review.}}'**
  String csvIssueDateOutliers(int count);

  /// A label followed by its value, e.g. 'Next date: 1 May'
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String labelValue(String label, String value);

  /// A whole number formatted for the locale (thousands separators)
  ///
  /// In en, this message translates to:
  /// **'{value}'**
  String integerValue(int value);

  /// Sync error: network or timeout
  ///
  /// In en, this message translates to:
  /// **'No connection to the cloud storage. Sync will try again when you are online.'**
  String get syncErrorNetwork;

  /// Sync error
  ///
  /// In en, this message translates to:
  /// **'You are not signed in. Please connect again.'**
  String get syncErrorNotSignedIn;

  /// Sync error
  ///
  /// In en, this message translates to:
  /// **'The sign-in has expired. Please disconnect and connect again.'**
  String get syncErrorAuthFailed;

  /// Sync error
  ///
  /// In en, this message translates to:
  /// **'Your cloud storage is full. Free up space to keep syncing.'**
  String get syncErrorStorageFull;

  /// Share sheet text of a transaction CSV export
  ///
  /// In en, this message translates to:
  /// **'LedgerZero transactions (CSV)'**
  String get transactionsShareText;

  /// Share sheet text of the payee CSV export
  ///
  /// In en, this message translates to:
  /// **'LedgerZero payees (CSV)'**
  String get payeesShareText;

  /// Share sheet text of the JSON export
  ///
  /// In en, this message translates to:
  /// **'LedgerZero data export (JSON)'**
  String get dataExportShareText;

  /// Share sheet text of the rules export
  ///
  /// In en, this message translates to:
  /// **'LedgerZero rules'**
  String get rulesShareText;

  /// Name of a default category/group created for a new budget (English key: Immediate Obligations)
  ///
  /// In en, this message translates to:
  /// **'Immediate Obligations'**
  String get seedGroupImmediate;

  /// Name of a default category/group created for a new budget (English key: Rent/Mortgage)
  ///
  /// In en, this message translates to:
  /// **'Rent/Mortgage'**
  String get seedCatRent;

  /// Name of a default category/group created for a new budget (English key: Electric)
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get seedCatElectric;

  /// Name of a default category/group created for a new budget (English key: Water)
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get seedCatWater;

  /// Name of a default category/group created for a new budget (English key: Internet)
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get seedCatInternet;

  /// Name of a default category/group created for a new budget (English key: Groceries)
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get seedCatGroceries;

  /// Name of a default category/group created for a new budget (English key: Transportation)
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get seedCatTransportation;

  /// Name of a default category/group created for a new budget (English key: True Expenses)
  ///
  /// In en, this message translates to:
  /// **'True Expenses'**
  String get seedGroupTrueExpenses;

  /// Name of a default category/group created for a new budget (English key: Medical)
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get seedCatMedical;

  /// Name of a default category/group created for a new budget (English key: Auto Maintenance)
  ///
  /// In en, this message translates to:
  /// **'Auto Maintenance'**
  String get seedCatAutoMaintenance;

  /// Name of a default category/group created for a new budget (English key: Home Maintenance)
  ///
  /// In en, this message translates to:
  /// **'Home Maintenance'**
  String get seedCatHomeMaintenance;

  /// Name of a default category/group created for a new budget (English key: Renter's/Home Insurance)
  ///
  /// In en, this message translates to:
  /// **'Renter\'s/Home Insurance'**
  String get seedCatInsurance;

  /// Name of a default category/group created for a new budget (English key: Software Subscriptions)
  ///
  /// In en, this message translates to:
  /// **'Software Subscriptions'**
  String get seedCatSubscriptions;

  /// Name of a default category/group created for a new budget (English key: Debt Payments)
  ///
  /// In en, this message translates to:
  /// **'Debt Payments'**
  String get seedGroupDebt;

  /// Name of a default category/group created for a new budget (English key: Student Loan)
  ///
  /// In en, this message translates to:
  /// **'Student Loan'**
  String get seedCatStudentLoan;

  /// Name of a default category/group created for a new budget (English key: Car Payment)
  ///
  /// In en, this message translates to:
  /// **'Car Payment'**
  String get seedCatCarPayment;

  /// Name of a default category/group created for a new budget (English key: Credit Card)
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get seedCatCreditCard;

  /// Name of a default category/group created for a new budget (English key: Quality of Life)
  ///
  /// In en, this message translates to:
  /// **'Quality of Life'**
  String get seedGroupQualityOfLife;

  /// Name of a default category/group created for a new budget (English key: Vacation)
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get seedCatVacation;

  /// Name of a default category/group created for a new budget (English key: Fitness)
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get seedCatFitness;

  /// Name of a default category/group created for a new budget (English key: Education)
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get seedCatEducation;

  /// Name of a default category/group created for a new budget (English key: Dining Out)
  ///
  /// In en, this message translates to:
  /// **'Dining Out'**
  String get seedCatDiningOut;

  /// Name of a default category/group created for a new budget (English key: Entertainment)
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get seedCatEntertainment;

  /// Name of a default category/group created for a new budget (English key: Just for Fun)
  ///
  /// In en, this message translates to:
  /// **'Just for Fun'**
  String get seedGroupFun;

  /// Name of a default category/group created for a new budget (English key: Gaming)
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get seedCatGaming;

  /// Name of a default category/group created for a new budget (English key: Music)
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get seedCatMusic;

  /// Name of a default category/group created for a new budget (English key: Fun Money)
  ///
  /// In en, this message translates to:
  /// **'Fun Money'**
  String get seedCatFunMoney;

  /// Label of the name field of a synced record in the sync conflict list
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get syncFieldName;

  /// Warning on the CSV import review when file categories did not match existing categories
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row names a category that does not exist. It will be imported without a category unless a rule or the payee\'s default category assigns one.} other{{count} rows name a category that does not exist. They will be imported without a category unless a rule or the payee\'s default category assigns one.}}'**
  String importUnmatchedCategories(int count);

  /// Row note on the CSV import review: the file's category does not exist
  ///
  /// In en, this message translates to:
  /// **'Category “{name}” not found – unassigned'**
  String importCategoryNotFound(String name);

  /// YNAB import error when no date format fits every register row
  ///
  /// In en, this message translates to:
  /// **'The dates in Register.csv do not fit one date format (MM/dd/yyyy, dd/MM/yyyy, yyyy-MM-dd or dd.MM.yyyy). First unreadable date: “{value}”. Export the budget from YNAB again or correct the Date column.'**
  String ynabImportErrorInvalidDates(String value);

  /// Label of the currency picker on the YNAB import preview
  ///
  /// In en, this message translates to:
  /// **'Currency of the imported accounts'**
  String get ynabImportCurrency;

  /// Subtitle of a YNAB tracking (off-budget) account in the import preview
  ///
  /// In en, this message translates to:
  /// **'Tracking account – not imported'**
  String get ynabImportTrackingAccount;

  /// YNAB import result: tracking (off-budget) accounts were skipped
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tracking account was not imported. Transfers between it and your budget accounts were imported as outflows and inflows of the budget accounts.} other{{count} tracking accounts were not imported. Transfers between them and your budget accounts were imported as outflows and inflows of the budget accounts.}}'**
  String ynabImportTrackingSkipped(int count);

  /// Login screen button shown when the key vault is missing; deletes all local data
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get loginResetApp;

  /// Title of the reset confirmation on the login screen
  ///
  /// In en, this message translates to:
  /// **'Reset LedgerZero?'**
  String get loginResetAppTitle;

  /// Explanation in the reset confirmation on the login screen
  ///
  /// In en, this message translates to:
  /// **'Without the key vault your data cannot be unlocked. Resetting deletes the encrypted database, all keys, settings and exported files on this device and starts the setup again; afterwards you can restore a backup. This cannot be undone. Type {word} to confirm.'**
  String loginResetAppBody(String word);

  /// Word the user must type to confirm the reset from the login screen
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get loginResetConfirmWord;

  /// Label of the field for the reset confirmation word
  ///
  /// In en, this message translates to:
  /// **'Confirmation word'**
  String get loginResetConfirmLabel;

  /// Form validation error when an amount of 0 is entered
  ///
  /// In en, this message translates to:
  /// **'The amount cannot be zero.'**
  String get amountMustNotBeZero;

  /// Budget row quick action: budget what was spent in the category last month
  ///
  /// In en, this message translates to:
  /// **'Budget Last Month\'s Spending'**
  String get budgetLastMonthSpent;

  /// Snack bar after moving budgeted money between categories (with an Undo action)
  ///
  /// In en, this message translates to:
  /// **'Money moved'**
  String get moveMoneyDone;

  /// Switch on the account form: whether the account counts towards To Be Budgeted
  ///
  /// In en, this message translates to:
  /// **'Include in budget'**
  String get accountOnBudgetLabel;

  /// Helper text under the Include in budget switch
  ///
  /// In en, this message translates to:
  /// **'Turn off for savings or investments you don\'t want to budget. They still count towards your net worth.'**
  String get accountOnBudgetHelper;

  /// Title of the dialog confirming a change of an account's Include in budget setting
  ///
  /// In en, this message translates to:
  /// **'Change what you budget?'**
  String get accountOnBudgetChangeTitle;

  /// Dialog text when an existing account is taken out of the budget
  ///
  /// In en, this message translates to:
  /// **'This account\'s balance and transactions will no longer count towards To Be Budgeted, in every month. Transfers between it and your budget accounts will move money out of or into your budget.'**
  String get accountOnBudgetChangeOff;

  /// Dialog text when an existing account is put back into the budget
  ///
  /// In en, this message translates to:
  /// **'This account\'s balance and transactions will count towards To Be Budgeted again, in every month.'**
  String get accountOnBudgetChangeOn;

  /// Badge on an account card for an account that does not count towards the budget
  ///
  /// In en, this message translates to:
  /// **'Off budget'**
  String get accountOffBudgetBadge;

  /// Hint on the transaction form instead of the category field when the account is off budget
  ///
  /// In en, this message translates to:
  /// **'This account is off budget: its transactions don\'t change your categories or To Be Budgeted.'**
  String get offBudgetTransactionHint;

  /// Home banner page: total balance of the accounts that count towards the budget
  ///
  /// In en, this message translates to:
  /// **'In budget accounts'**
  String get homeBalanceInBudget;

  /// Screen reader label of the home banner page indicator
  ///
  /// In en, this message translates to:
  /// **'{page} of {pages}'**
  String homeBalancePage(int page, int pages);

  /// Screen reader action of the home banner: tapping it shows the next total (To Be Budgeted, net worth, ...)
  ///
  /// In en, this message translates to:
  /// **'Show next total'**
  String get homeBalanceNext;

  /// Hint under the category field of a transfer between a budget account and an off-budget account
  ///
  /// In en, this message translates to:
  /// **'Optional. Without a category the money comes out of, or goes into, To Be Budgeted.'**
  String get transferCategoryHint;

  /// Default category group for money moved to savings and investment accounts
  ///
  /// In en, this message translates to:
  /// **'Savings & Investments'**
  String get seedGroupSavings;

  /// Default category (Investments group)
  ///
  /// In en, this message translates to:
  /// **'Stocks & ETFs'**
  String get seedCatStocks;

  /// Default category (Investments group)
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get seedCatCrypto;

  /// Default category (Investments group)
  ///
  /// In en, this message translates to:
  /// **'Bonds'**
  String get seedCatBonds;

  /// Default category (Investments group): private pension / retirement savings
  ///
  /// In en, this message translates to:
  /// **'Retirement'**
  String get seedCatRetirement;

  /// Title of the one-time card on the budget screen offering the Investments category group
  ///
  /// In en, this message translates to:
  /// **'Set money aside?'**
  String get savingsOfferTitle;

  /// Body of the one-time Investments offer card
  ///
  /// In en, this message translates to:
  /// **'Add a Savings & Investments group: Savings, Stocks & ETFs, Crypto, Bonds and Retirement. Budget there what you move to your savings and investment accounts each month. Keep those accounts outside the budget (switch off \"Include in budget\"): their balances then count towards your net worth only.'**
  String get savingsOfferBody;

  /// Button: add the Investments category group
  ///
  /// In en, this message translates to:
  /// **'Add categories'**
  String get savingsOfferAdd;

  /// Button: dismiss the Investments offer for good
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get savingsOfferDismiss;

  /// Snack bar after adding the Investments group
  ///
  /// In en, this message translates to:
  /// **'Savings & Investments categories added'**
  String get savingsOfferAdded;

  /// Default category (Savings & Investments group): money moved to savings accounts each month
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get seedCatSavings;

  /// No description provided for @cardNotifications.
  ///
  /// In en, this message translates to:
  /// **'Card notifications'**
  String get cardNotifications;

  /// No description provided for @cardNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add card payments from your bank app\'s notifications'**
  String get cardNotificationsSubtitle;

  /// No description provided for @cardNotificationsIntro.
  ///
  /// In en, this message translates to:
  /// **'LedgerZero can read payment notifications from your bank, card or wallet apps and add each payment as a transaction for you to review. Only the apps you choose here are read; notifications from all other apps are ignored. Everything stays on this device.'**
  String get cardNotificationsIntro;

  /// No description provided for @cardNotificationsAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification access'**
  String get cardNotificationsAccessTitle;

  /// No description provided for @cardNotificationsAccessGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get cardNotificationsAccessGranted;

  /// No description provided for @cardNotificationsAccessMissing.
  ///
  /// In en, this message translates to:
  /// **'Not granted: nothing is captured'**
  String get cardNotificationsAccessMissing;

  /// No description provided for @cardNotificationsGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get cardNotificationsGrantAccess;

  /// No description provided for @cardNotificationsManageAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage in system settings'**
  String get cardNotificationsManageAccess;

  /// No description provided for @cardNotificationsDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow LedgerZero to read notifications?'**
  String get cardNotificationsDisclosureTitle;

  /// Prominent disclosure shown before opening the system notification access screen (Google Play policy)
  ///
  /// In en, this message translates to:
  /// **'Android will now ask you to give LedgerZero access to notifications. Android grants this access for all apps, but LedgerZero only reads notifications from the bank, card or wallet apps you choose, and only takes the amount, merchant and time of a payment from them. Notifications are never sent anywhere. Captured notifications are kept encrypted on this device for 30 days, so you can add a payment again. You can revoke access at any time in the system settings.'**
  String get cardNotificationsDisclosureBody;

  /// No description provided for @cardNotificationsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get cardNotificationsContinue;

  /// No description provided for @cardNotificationsAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get cardNotificationsAppsTitle;

  /// No description provided for @cardNotificationsNoApps.
  ///
  /// In en, this message translates to:
  /// **'No apps chosen yet.'**
  String get cardNotificationsNoApps;

  /// No description provided for @cardNotificationsAddApp.
  ///
  /// In en, this message translates to:
  /// **'Add app'**
  String get cardNotificationsAddApp;

  /// No description provided for @cardNotificationsAccountMissing.
  ///
  /// In en, this message translates to:
  /// **'No account chosen: payments wait here'**
  String get cardNotificationsAccountMissing;

  /// No description provided for @cardNotificationsRemoveApp.
  ///
  /// In en, this message translates to:
  /// **'Stop watching {app}'**
  String cardNotificationsRemoveApp(String app);

  /// No description provided for @cardNotificationsPickAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app'**
  String get cardNotificationsPickAppTitle;

  /// No description provided for @cardNotificationsPickAppHint.
  ///
  /// In en, this message translates to:
  /// **'Apps with a notification showing, apps that notified recently, and installed bank apps.'**
  String get cardNotificationsPickAppHint;

  /// No description provided for @cardNotificationsNoCandidates.
  ///
  /// In en, this message translates to:
  /// **'No apps found. Keep a notification from your bank app in the notification shade and try again.'**
  String get cardNotificationsNoCandidates;

  /// No description provided for @cardNotificationsOriginActive.
  ///
  /// In en, this message translates to:
  /// **'Notification showing'**
  String get cardNotificationsOriginActive;

  /// No description provided for @cardNotificationsOriginRecent.
  ///
  /// In en, this message translates to:
  /// **'Notified recently'**
  String get cardNotificationsOriginRecent;

  /// No description provided for @cardNotificationsOriginKnown.
  ///
  /// In en, this message translates to:
  /// **'Bank or wallet app'**
  String get cardNotificationsOriginKnown;

  /// No description provided for @cardNotificationsPickAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Add payments from {app} to'**
  String cardNotificationsPickAccountTitle(String app);

  /// No description provided for @cardNotificationsNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Create an account first.'**
  String get cardNotificationsNoAccounts;

  /// No description provided for @cardNotificationsHeldTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get cardNotificationsHeldTitle;

  /// No description provided for @cardNotificationsHeldUnreadable.
  ///
  /// In en, this message translates to:
  /// **'No amount found'**
  String get cardNotificationsHeldUnreadable;

  /// No description provided for @cardNotificationsHeldNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account chosen for this app'**
  String get cardNotificationsHeldNoAccount;

  /// No description provided for @cardNotificationsHeldForeignCurrency.
  ///
  /// In en, this message translates to:
  /// **'Different currency than the account'**
  String get cardNotificationsHeldForeignCurrency;

  /// No description provided for @cardNotificationsAddManually.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get cardNotificationsAddManually;

  /// No description provided for @cardNotificationsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get cardNotificationsDismiss;

  /// No description provided for @cardNotificationsHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get cardNotificationsHowItWorksTitle;

  /// No description provided for @cardNotificationsHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'Captured payments appear in Transactions marked as not approved. Swipe left to approve one, or tap it to correct it. Payments captured while LedgerZero is closed are added the next time it starts. Declined payments, codes and balance notices are skipped. Captured notifications lists the last 30 days, so you can add a skipped or deleted payment again.'**
  String get cardNotificationsHowItWorks;

  /// No description provided for @cardNotificationsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card payment added} other{{count} card payments added}}'**
  String cardNotificationsAdded(int count);

  /// No description provided for @cardNotificationsLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Captured notifications'**
  String get cardNotificationsLogTitle;

  /// No description provided for @cardNotificationsLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add skipped or deleted payments again (last 30 days)'**
  String get cardNotificationsLogSubtitle;

  /// No description provided for @cardNotificationsLogIntro.
  ///
  /// In en, this message translates to:
  /// **'Notifications from the apps you watch, kept encrypted on this device for 30 days. Select payments to add them again as transactions for you to review. Notifications from before an app was added cannot be read.'**
  String get cardNotificationsLogIntro;

  /// No description provided for @cardNotificationsLogAllApps.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get cardNotificationsLogAllApps;

  /// No description provided for @cardNotificationsLogToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get cardNotificationsLogToday;

  /// No description provided for @cardNotificationsLogLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get cardNotificationsLogLast7Days;

  /// No description provided for @cardNotificationsLogLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get cardNotificationsLogLast30Days;

  /// No description provided for @cardNotificationsLogPickDates.
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get cardNotificationsLogPickDates;

  /// No description provided for @cardNotificationsLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing captured in this period.'**
  String get cardNotificationsLogEmpty;

  /// No description provided for @cardNotificationsLogSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get cardNotificationsLogSelectAll;

  /// No description provided for @cardNotificationsLogAddSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Add} other{Add {count}}}'**
  String cardNotificationsLogAddSelected(int count);

  /// No description provided for @cardNotificationsStatusAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get cardNotificationsStatusAdded;

  /// No description provided for @cardNotificationsStatusAddedDeleted.
  ///
  /// In en, this message translates to:
  /// **'Added, but the transaction was deleted since'**
  String get cardNotificationsStatusAddedDeleted;

  /// No description provided for @cardNotificationsStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped: contains “{phrase}”'**
  String cardNotificationsStatusSkipped(String phrase);

  /// No description provided for @cardNotificationsStatusSkippedBalance.
  ///
  /// In en, this message translates to:
  /// **'Skipped: looks like a balance notice'**
  String get cardNotificationsStatusSkippedBalance;

  /// No description provided for @cardNotificationsStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get cardNotificationsStatusDismissed;

  /// No description provided for @cardNotificationsStatusFound.
  ///
  /// In en, this message translates to:
  /// **'Was showing when the app was added'**
  String get cardNotificationsStatusFound;

  /// No description provided for @cardNotificationsLikelyDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A transaction with this amount already exists'**
  String get cardNotificationsLikelyDuplicate;

  /// No description provided for @cardNotificationsShowingFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 notification from {app} was already showing.} other{{count} notifications from {app} were already showing.}}'**
  String cardNotificationsShowingFound(int count, String app);

  /// No description provided for @cardNotificationsReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get cardNotificationsReview;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLockTitle;

  /// No description provided for @appLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for your fingerprint, face or screen lock when opening LedgerZero'**
  String get appLockSubtitle;

  /// No description provided for @appLockNeedsScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Set up a screen lock in the Android settings to use the app lock.'**
  String get appLockNeedsScreenLock;

  /// No description provided for @appLockPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock LedgerZero'**
  String get appLockPromptTitle;

  /// No description provided for @appLockPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint, face or screen lock'**
  String get appLockPromptSubtitle;

  /// No description provided for @appLockTurnedOffNoScreenLock.
  ///
  /// In en, this message translates to:
  /// **'This phone has no screen lock any more, so the app lock was turned off.'**
  String get appLockTurnedOffNoScreenLock;

  /// No description provided for @lockScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'LedgerZero is locked'**
  String get lockScreenTitle;

  /// No description provided for @lockScreenKeyError.
  ///
  /// In en, this message translates to:
  /// **'LedgerZero cannot open your data: the key stored on this phone is missing or does not match the data. Reset the app, then restore a backup or sync again from your other phone.'**
  String get lockScreenKeyError;

  /// No description provided for @legacyUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock one last time'**
  String get legacyUnlockTitle;

  /// No description provided for @legacyUnlockExplanation.
  ///
  /// In en, this message translates to:
  /// **'LedgerZero no longer uses a master password. Unlock one last time with your password or recovery key. After that, the app keeps its key in this phone\'s secure key store, and the app lock uses your fingerprint, face or screen lock.'**
  String get legacyUnlockExplanation;

  /// No description provided for @setupDeviceHeading.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this phone'**
  String get setupDeviceHeading;

  /// No description provided for @setupDeviceExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your budget is stored only on this phone, encrypted with a key that Android keeps in its secure key store. There is no account and no password to remember. So you don\'t lose anything with your phone, create backups or sync with a second phone.'**
  String get setupDeviceExplanation;

  /// No description provided for @lockScreenReadError.
  ///
  /// In en, this message translates to:
  /// **'LedgerZero could not read its key from this phone\'s secure key store just now. Your data is not affected. Try again; if it keeps failing, restart the phone.'**
  String get lockScreenReadError;

  /// No description provided for @providerLocalWifi.
  ///
  /// In en, this message translates to:
  /// **'Home Wi-Fi (phone to phone)'**
  String get providerLocalWifi;

  /// No description provided for @lanSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi sync'**
  String get lanSyncTitle;

  /// No description provided for @lanSetupExplanation.
  ///
  /// In en, this message translates to:
  /// **'Share one budget with a second phone, for example your partner\'s, without any cloud. The phones sync whenever both are on the same Wi-Fi with LedgerZero open.'**
  String get lanSetupExplanation;

  /// No description provided for @lanStart.
  ///
  /// In en, this message translates to:
  /// **'Start on this phone'**
  String get lanStart;

  /// No description provided for @lanStartHint.
  ///
  /// In en, this message translates to:
  /// **'Choose this on the phone that already has your budget.'**
  String get lanStartHint;

  /// No description provided for @lanJoin.
  ///
  /// In en, this message translates to:
  /// **'Join the other phone'**
  String get lanJoin;

  /// No description provided for @lanJoinHint.
  ///
  /// In en, this message translates to:
  /// **'Choose this on the second phone. Its data is merged into the shared budget.'**
  String get lanJoinHint;

  /// No description provided for @lanPairPhone.
  ///
  /// In en, this message translates to:
  /// **'Pair a phone'**
  String get lanPairPhone;

  /// No description provided for @lanShowCodeInstructions.
  ///
  /// In en, this message translates to:
  /// **'On the other phone open Settings > Sync, choose Home Wi-Fi, tap \"Join the other phone\" and scan this code. Both phones must be on the same Wi-Fi with LedgerZero open.'**
  String get lanShowCodeInstructions;

  /// No description provided for @lanShowCodeWarning.
  ///
  /// In en, this message translates to:
  /// **'This code gives access to your budget. Only show it to phones you trust.'**
  String get lanShowCodeWarning;

  /// No description provided for @lanCodeTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Can\'t scan? Type this code on the other phone:'**
  String get lanCodeTextLabel;

  /// No description provided for @lanScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the pairing code'**
  String get lanScanTitle;

  /// No description provided for @lanEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code instead'**
  String get lanEnterCode;

  /// No description provided for @lanEnterCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get lanEnterCodeTitle;

  /// No description provided for @lanEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Starts with lzpair1:'**
  String get lanEnterCodeHint;

  /// No description provided for @lanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is not available. Enter the code instead.'**
  String get lanCameraUnavailable;

  /// No description provided for @lanJoining.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the other phone…'**
  String get lanJoining;

  /// No description provided for @lanStarted.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi sync is on. Pair a second phone to share the budget.'**
  String get lanStarted;

  /// No description provided for @lanJoined.
  ///
  /// In en, this message translates to:
  /// **'Paired. The budget is now shared.'**
  String get lanJoined;

  /// No description provided for @lanInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'This is not a LedgerZero pairing code.'**
  String get lanInvalidCode;

  /// No description provided for @lanPhoneNotFound.
  ///
  /// In en, this message translates to:
  /// **'The other phone could not be reached. Make sure both phones are on the same Wi-Fi and LedgerZero is open on the other phone.'**
  String get lanPhoneNotFound;

  /// No description provided for @lanSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi sync could not be set up.'**
  String get lanSetupFailed;

  /// No description provided for @lanPeersTitle.
  ///
  /// In en, this message translates to:
  /// **'Paired phones'**
  String get lanPeersTitle;

  /// No description provided for @lanNoPeers.
  ///
  /// In en, this message translates to:
  /// **'No phone paired yet.'**
  String get lanNoPeers;

  /// No description provided for @lanPeerLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String lanPeerLastSync(String time);

  /// No description provided for @lanPeerNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get lanPeerNeverSynced;

  /// No description provided for @lanTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off Wi-Fi sync'**
  String get lanTurnOff;

  /// No description provided for @syncErrorPairingMismatch.
  ///
  /// In en, this message translates to:
  /// **'This phone and the other one were paired with different codes. Turn off Wi-Fi sync on this phone and pair it again.'**
  String get syncErrorPairingMismatch;

  /// Label of the income line under To Be Budgeted on the budget screen
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get budgetIncomeLabel;

  /// Income line: money that arrived in To Be Budgeted this month
  ///
  /// In en, this message translates to:
  /// **'{amount} received'**
  String budgetIncomeReceived(String amount);

  /// Income line: recurring income (salary) still to come this month and the date of the next payment, e.g. '€3,000 expected, next Oct 25'
  ///
  /// In en, this message translates to:
  /// **'{amount} expected, next {date}'**
  String budgetIncomeExpected(String amount, String date);

  /// Income line value when the month has no income yet; shown after 'Income: '
  ///
  /// In en, this message translates to:
  /// **'none this month'**
  String get budgetIncomeNone;

  /// Income line under To Be Budgeted while no recurring income is set up
  ///
  /// In en, this message translates to:
  /// **'Add your salary to budget it every month'**
  String get budgetIncomeAddPrompt;

  /// Button: open the form for a recurring income (salary)
  ///
  /// In en, this message translates to:
  /// **'Add salary'**
  String get budgetIncomeAddButton;

  /// Title of the one-time card on the budget screen suggesting to set up the salary
  ///
  /// In en, this message translates to:
  /// **'Add your salary?'**
  String get salaryPromptTitle;

  /// Body of the one-time salary card and of the salary question after the first account
  ///
  /// In en, this message translates to:
  /// **'Set it up once and it lands in To Be Budgeted every payday, ready to assign to your categories. You also see the expected amount for each month in advance.'**
  String get salaryPromptBody;

  /// Button: dismiss the salary suggestion for good (it stays reachable under To Be Budgeted)
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get salaryPromptDismiss;

  /// Title of the question asked right after the first account was created
  ///
  /// In en, this message translates to:
  /// **'When do you get paid?'**
  String get firstAccountSalaryTitle;

  /// Card on the budget screen for an empty month: copy the budget of the month before. Month names, e.g. 'Start November like October?'
  ///
  /// In en, this message translates to:
  /// **'Start {month} like {previous}?'**
  String newMonthTitle(String month, String previous);

  /// Body of the new-month card: the total that would be budgeted and what To Be Budgeted would show afterwards
  ///
  /// In en, this message translates to:
  /// **'{total} in the same categories. To Be Budgeted after: {tbb}.'**
  String newMonthBody(String total, String tbb);

  /// Button: budget the same amounts as in the month before (month name)
  ///
  /// In en, this message translates to:
  /// **'Fill like {previous}'**
  String newMonthFill(String previous);

  /// Button on the new-month card: fill the month from a saved budget template
  ///
  /// In en, this message translates to:
  /// **'Use a template'**
  String get newMonthTemplate;

  /// Button: hide the new-month card for this month
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get newMonthDismiss;

  /// Snack bar after filling a month (with Undo)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category filled} other{{count} categories filled}}'**
  String newMonthFilled(int count);

  /// Setting (budget menu, new-month card): budget every new month automatically
  ///
  /// In en, this message translates to:
  /// **'Fill new months automatically'**
  String get autoFillTitle;

  /// Budget screen menu entry that opens the automatic fill setting
  ///
  /// In en, this message translates to:
  /// **'Fill automatically…'**
  String get autoFillMenu;

  /// Explanation in the automatic fill setting
  ///
  /// In en, this message translates to:
  /// **'On the first open of a new month, categories that are still empty get these amounts. Amounts you set yourself are never overwritten, also not from the paired phone. Starts with next month.'**
  String get autoFillExplanation;

  /// Automatic fill option: do not fill new months
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get autoFillOff;

  /// Automatic fill option: copy the previous month's budgets
  ///
  /// In en, this message translates to:
  /// **'Same as the month before'**
  String get autoFillPrevious;

  /// Automatic fill option: use the saved template with this name
  ///
  /// In en, this message translates to:
  /// **'Template: {name}'**
  String autoFillTemplate(String name);

  /// Card after the automatic fill of a month (month name)
  ///
  /// In en, this message translates to:
  /// **'{month} was filled automatically'**
  String autoFillNoteTitle(String month);

  /// Body of the automatic fill card: total and where it came from (previous month name or template name)
  ///
  /// In en, this message translates to:
  /// **'{total} from {source}. Change any amount as usual.'**
  String autoFillNoteBody(String total, String source);

  /// Snack bar after undoing the automatic fill
  ///
  /// In en, this message translates to:
  /// **'Automatic budget undone'**
  String get autoFillUndone;

  /// Account type: brokerage, crypto or retirement account
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountTypeInvestment;

  /// In the dialog for taking an account out of the budget: its balance and the categories holding money budgeted for it
  ///
  /// In en, this message translates to:
  /// **'{amount} in this account leaves your budget. Release the money you budgeted for it:'**
  String accountReleaseIntro(String amount);

  /// Under a category in the release list: how much is taken out of its budget
  ///
  /// In en, this message translates to:
  /// **'Release {amount}'**
  String accountReleaseAmount(String amount);

  /// Snack bar after releasing budgeted money when an account left the budget
  ///
  /// In en, this message translates to:
  /// **'{amount} returned to To Be Budgeted'**
  String accountReleased(String amount);

  /// Card at the start of a month: money left unassigned in the month before (month name)
  ///
  /// In en, this message translates to:
  /// **'{amount} from {previous} wasn\'t budgeted'**
  String leftoverTitle(String amount, String previous);

  /// Body of the leftover card
  ///
  /// In en, this message translates to:
  /// **'It is still in To Be Budgeted for {month}. Put it towards savings?'**
  String leftoverBody(String month);

  /// Button: choose a category (savings first) to budget the leftover in
  ///
  /// In en, this message translates to:
  /// **'Budget for savings…'**
  String get leftoverAssign;

  /// Button: leave the leftover in To Be Budgeted for this month (month name)
  ///
  /// In en, this message translates to:
  /// **'Keep for {month}'**
  String leftoverKeep(String month);

  /// Snack bar after budgeting the leftover (with Undo)
  ///
  /// In en, this message translates to:
  /// **'{amount} budgeted for {category}'**
  String leftoverAssigned(String amount, String category);

  /// Switch on the account form: the account is personal to this phone's user
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get accountPersonalLabel;

  /// Explanation under the Personal switch on the account form
  ///
  /// In en, this message translates to:
  /// **'Only you see its transactions. A partner you sync with sees just its name and balance.'**
  String get accountPersonalHelper;

  /// Explanation under the disabled Personal switch for an account that has already synced
  ///
  /// In en, this message translates to:
  /// **'Already shared with your partner, so it can\'t become personal. Create a new personal account instead.'**
  String get accountPersonalSynced;

  /// Explanation under the disabled Include in budget switch of a personal account
  ///
  /// In en, this message translates to:
  /// **'Personal accounts stay outside the budget.'**
  String get accountOnBudgetPersonal;

  /// Dialog title when a personal account becomes shared
  ///
  /// In en, this message translates to:
  /// **'Share with your partner?'**
  String get accountShareTitle;

  /// Dialog text when a personal account becomes shared
  ///
  /// In en, this message translates to:
  /// **'Its transactions will sync to your partner\'s phone, and your partner can change them too. It can\'t become personal again.'**
  String get accountShareBody;

  /// Button confirming that a personal account becomes shared
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get accountShareAction;

  /// Badge on the card of this user's personal account
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get accountPersonalBadge;

  /// Badge on the card of the partner's personal account
  ///
  /// In en, this message translates to:
  /// **'Partner\'s'**
  String get accountPartnerBadge;

  /// Section header in the account list above the partner's personal accounts
  ///
  /// In en, this message translates to:
  /// **'Your partner\'s accounts'**
  String get accountsPartnerSection;

  /// Part of net worth in shared accounts
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get netWorthShared;

  /// Part of net worth in this user's personal accounts
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get netWorthMine;

  /// Part of net worth in the partner's personal accounts
  ///
  /// In en, this message translates to:
  /// **'Partner\'s'**
  String get netWorthPartner;

  /// Title on the detail screen of the partner's personal account
  ///
  /// In en, this message translates to:
  /// **'Your partner\'s personal account'**
  String get accountPartnerTitle;

  /// Text on the detail screen of the partner's personal account
  ///
  /// In en, this message translates to:
  /// **'Its transactions stay on your partner\'s phone. The balance updates whenever their phone syncs.'**
  String get accountPartnerBody;

  /// Message when a transaction involving the partner's personal account cannot be changed
  ///
  /// In en, this message translates to:
  /// **'This belongs to your partner\'s personal account. Your partner can change it on their phone.'**
  String get txPartnerAccount;

  /// Label above the balance of the partner's personal account
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalanceLabel;

  /// Tooltip and screen reader label of an info button; topic is the help topic title
  ///
  /// In en, this message translates to:
  /// **'About {topic}'**
  String helpInfoTooltip(String topic);

  /// Button in a help sheet that opens the matching user guide chapter
  ///
  /// In en, this message translates to:
  /// **'Open the user guide'**
  String get helpOpenGuide;

  /// Heading above the numbered steps in a help sheet
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get helpHowTo;

  /// Button on a one-time hint that opens the matching help sheet
  ///
  /// In en, this message translates to:
  /// **'Show me'**
  String get helpShowMe;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Saving and investing'**
  String get helpSavingTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'Keep savings and investments in their own accounts outside the budget. The budget decides how much goes there each month: budget the amount in a Savings & Investments category, then move the money with a transfer that uses that category.'**
  String get helpSavingBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'Budget the amount, for example 500 in Stocks & ETFs.\nAdd a transfer from your budget account (for example checking) to the brokerage or savings account.\nPick Stocks & ETFs as its category. The category is spent, the brokerage account grows, and To Be Budgeted stays the same.\nGains, dividends and fees inside the brokerage account need no category.'**
  String get helpSavingSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'To Be Budgeted'**
  String get helpTbbTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'Money in your budget accounts that has no job yet. Income without a category adds to it, and budgeting money to a category takes it out. Aim for zero: then every euro has a job.'**
  String get helpTbbBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'Negative means you budgeted more than you have: lower a category until it is back at zero.\nWhat is left at the end of a month carries over to the next month, where you can budget it.\nAccounts outside the budget, like savings or a brokerage account, do not count here.'**
  String get helpTbbSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Filling a new month'**
  String get helpNewMonthTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'A new month starts empty. Fill it like the month before or from a template, by hand or automatically every month (Budget menu ⋮, “Fill automatically…”).'**
  String get helpNewMonthBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'Only empty categories are filled: amounts you already set stay.\nWhat you change by hand always wins, also against your partner’s phone filling the same month.\nUndo right after filling resets only the categories you have not changed since.'**
  String get helpNewMonthSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'In or out of the budget'**
  String get helpOnBudgetTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'Accounts in the budget hold the money you spend and plan with: their balance is what you budget. Accounts outside the budget only count towards net worth.'**
  String get helpOnBudgetBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'In the budget: checking, cash, credit cards and the account your salary arrives in.\nOutside: savings, brokerage, crypto and pension accounts, loans.\nA reserve inside your checking account cannot be outside: budget it into a category like Savings instead.\nTaking an account out offers to release the money you budgeted for it, so To Be Budgeted does not go negative.'**
  String get helpOnBudgetSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Personal accounts'**
  String get helpPersonalTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'For couples who sync: a personal account belongs to you. Your partner sees its name and balance in net worth, but not its transactions, and cannot change it.'**
  String get helpPersonalBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'Personal accounts are always outside the budget.\nA transfer between a shared account and your personal one syncs as the shared side only.\nAn account can become personal only before it first syncs, so mark it before pairing. Sharing it later is always possible and sends its history.'**
  String get helpPersonalSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Account types'**
  String get helpAccountTypesTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'The type sets the icon and whether a new account starts in the budget. Savings and Investment accounts start outside the budget; the switch below changes that.'**
  String get helpAccountTypesBody;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Accounts and net worth'**
  String get helpAccountsTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'Net worth adds up all accounts, in or out of the budget. If you sync with a partner, it is your household’s net worth, and the lines below it split it into shared, yours and your partner’s.'**
  String get helpAccountsBody;

  /// Lines of a help topic explaining the account badges, one per line
  ///
  /// In en, this message translates to:
  /// **'Off budget: counts towards net worth only.\nPersonal: yours; your partner sees only its name and balance.\nPartner’s: your partner’s personal accounts, read-only, with the balance their phone last shared.'**
  String get helpAccountsSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get helpTransferTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'A transfer moves money between two of your accounts. It is neither income nor spending.'**
  String get helpTransferBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'Between two budget accounts (checking to cash): no category, nothing changes in the budget.\nFrom a budget account to one outside (checking to brokerage): pick the category you budgeted for it, for example Stocks & ETFs. Without a category the money comes out of To Be Budgeted.\nBack from outside into the budget (savings to checking): without a category it adds to To Be Budgeted.'**
  String get helpTransferSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Syncing with a partner'**
  String get helpSyncTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'Two phones can share one budget: over your home Wi-Fi without any cloud, or through a Google Drive account you both use when you are apart. Everything is encrypted before it leaves the phone.'**
  String get helpSyncBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'Every change syncs on its own. If both phones change the same thing, the later change wins and the other one is listed under conflicts, where you can keep it.\nPersonal accounts share only their name and balance.\nBoth phones need the same app version.'**
  String get helpSyncSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'Importing a CSV file'**
  String get helpCsvTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'Export your transactions from your bank as a CSV file. LedgerZero matches the columns by their names, and you can correct the matching before importing.'**
  String get helpCsvBody;

  /// Numbered steps of a help topic, one per line
  ///
  /// In en, this message translates to:
  /// **'The first row must hold the column names: delete any lines above it.\nAmounts must be in one column, negative for money going out. Separate debit and credit columns are not supported yet.\nOn the review screen, untick the rows you do not want.'**
  String get helpCsvSteps;

  /// Help topic title
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get helpAppLockTitle;

  /// Help topic text
  ///
  /// In en, this message translates to:
  /// **'The app locks with your fingerprint, face or phone PIN once it has been in the background for the time you choose. Pulling down notifications or answering a system dialog does not lock it, and after unlocking you are back where you were.'**
  String get helpAppLockBody;

  /// One-time hint in the Savings & Investments group once money is budgeted there
  ///
  /// In en, this message translates to:
  /// **'Budgeted money stays in your checking account until you move it: add a transfer to your savings or brokerage account and pick this category.'**
  String get hintSavingsTransfer;

  /// One-time snack bar after creating the first account outside the budget
  ///
  /// In en, this message translates to:
  /// **'Account created. It is outside the budget: to save into it, budget the amount in Savings & Investments and add a transfer with that category.'**
  String get hintOffBudgetAccount;

  /// One-time hint above the partner's accounts in the account list
  ///
  /// In en, this message translates to:
  /// **'These are your partner’s personal accounts. You see their balance; their transactions stay on your partner’s phone.'**
  String get hintPartnerAccounts;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get guideTransfersTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'A transfer moves money between two of your accounts and is neither income nor spending. Between two budget accounts it needs no category and changes nothing in the budget. From a budget account to an account outside the budget, the money leaves the budget: pick the category you budgeted for it, or leave the category empty to take it from To Be Budgeted. Money coming back from outside without a category adds to To Be Budgeted.'**
  String get guideTransfersBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Saving and investing'**
  String get guideSavingTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'Keep savings and investments in their own accounts outside the budget, so price changes and interest never disturb it. Each month, budget what you want to put aside in Savings & Investments (Savings, Stocks & ETFs, Crypto, Bonds, Retirement). When you move the money, add a transfer from your budget account to the savings account and pick that category: the category is spent, the savings account grows and To Be Budgeted stays the same. Example: budget 500 in Stocks & ETFs, then transfer 500 from checking to your brokerage account with Stocks & ETFs. A reserve you keep in your checking account stays in a category like Savings instead, where it carries over every month.'**
  String get guideSavingBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Using LedgerZero with a partner'**
  String get guidePartnerTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'Two phones can share one budget. Pair them in Sync Settings: over your home Wi-Fi (scan the QR code on the other phone; both need LedgerZero open on the same Wi-Fi) or through a Google Drive account you both use. Every change syncs on its own; if you both change the same thing, the later change wins and Sync Settings lists the other one. Accounts you mark as personal stay yours: your partner sees their name and balance in net worth, but not their transactions. Mark an account as personal before the first sync; you can still share it later.'**
  String get guidePartnerBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Security and backups'**
  String get guideSecurityTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'Your data is stored encrypted on your phone, and the key is kept in the phone’s secure hardware. The app lock asks for your fingerprint, face or phone PIN after the app was in the background. Create encrypted backups regularly in Settings > Backup & Export and keep the backup password safe: without it a backup cannot be restored.'**
  String get guideSecurityBody;

  /// User guide chapter title
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get guideImportTitle;

  /// User guide chapter text
  ///
  /// In en, this message translates to:
  /// **'Settings > Import CSV reads your bank’s CSV export: the first row must hold the column names, and amounts must be in one column (negative for money going out). Columns are matched by name and can be corrected before importing. YNAB budgets can be imported from Settings as well.'**
  String get guideImportBody;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'What if my fingerprint is not recognised?'**
  String get faqLockQ;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'The app lock also accepts your phone’s PIN, pattern or password, the same way your phone’s lock screen does.'**
  String get faqLockA;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do I put money into savings or investments?'**
  String get faqSavingQ;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Keep the savings or brokerage account outside the budget. Each month, budget the amount in a Savings & Investments category, then add a transfer from your checking account to the savings account and pick that category. The category is spent and To Be Budgeted stays the same.'**
  String get faqSavingA;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Can I keep an account to myself?'**
  String get faqPersonalQ;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Yes. Switch on “Personal” when you create the account. Your partner then sees only its name and balance; its transactions stay on your phone. Do this before the first sync: an account that has already synced stays shared.'**
  String get faqPersonalA;

  /// Collapsed budget section listing hidden categories that still have money budgeted or available
  ///
  /// In en, this message translates to:
  /// **'Hidden categories'**
  String get hiddenCategoriesGroup;
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
