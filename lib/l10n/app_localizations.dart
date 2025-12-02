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
