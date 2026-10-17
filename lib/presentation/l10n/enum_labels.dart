import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/rule_template_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_sort_provider.dart';

/// Localised display names for domain enums. Enum `.name`s are storage
/// identifiers and are never shown to users.

/// Languages the app ships in, as endonyms (shown untranslated in the
/// language picker, so users always find their own language).
const Map<String, String> kLanguageEndonyms = {
  'en': 'English',
  'de': 'Deutsch',
};

extension AccountTypeLabel on AccountType {
  String label(AppLocalizations l10n) => switch (this) {
    AccountType.checking => l10n.accountTypeChecking,
    AccountType.savings => l10n.accountTypeSavings,
    AccountType.credit => l10n.accountTypeCredit,
    AccountType.cash => l10n.accountTypeCash,
    AccountType.investment => l10n.accountTypeInvestment,
  };
}

extension TransactionClearStatusLabel on TransactionClearStatus {
  String label(AppLocalizations l10n) => switch (this) {
    TransactionClearStatus.uncleared => l10n.uncleared,
    TransactionClearStatus.cleared => l10n.cleared,
    TransactionClearStatus.reconciled => l10n.transactionStatusReconciled,
  };
}

extension RecurrenceFrequencyLabel on RecurrenceFrequency {
  String label(AppLocalizations l10n) => switch (this) {
    RecurrenceFrequency.daily => l10n.daily,
    RecurrenceFrequency.weekly => l10n.weekly,
    RecurrenceFrequency.monthly => l10n.monthly,
    RecurrenceFrequency.yearly => l10n.yearly,
  };
}

extension AccountSortOptionLabel on AccountSortOption {
  String label(AppLocalizations l10n) => switch (this) {
    AccountSortOption.nameAsc => l10n.accountSortNameAsc,
    AccountSortOption.nameDesc => l10n.accountSortNameDesc,
    AccountSortOption.balanceAsc => l10n.accountSortBalanceAsc,
    AccountSortOption.balanceDesc => l10n.accountSortBalanceDesc,
    AccountSortOption.type => l10n.accountSortType,
  };
}

extension RuleMatchLogicLabel on RuleMatchLogic {
  String label(AppLocalizations l10n) => switch (this) {
    RuleMatchLogic.and => l10n.ruleMatchAll,
    RuleMatchLogic.or => l10n.ruleMatchAny,
  };
}

extension RuleConditionTypeLabel on RuleConditionType {
  String label(AppLocalizations l10n) => switch (this) {
    RuleConditionType.payee => l10n.ruleFieldPayee,
    RuleConditionType.amount => l10n.ruleFieldAmount,
    RuleConditionType.description => l10n.ruleFieldDescription,
  };
}

extension RuleConditionOperatorLabel on RuleConditionOperator {
  String label(AppLocalizations l10n) => switch (this) {
    RuleConditionOperator.equals => l10n.ruleOperatorEquals,
    RuleConditionOperator.contains => l10n.ruleOperatorContains,
    RuleConditionOperator.startsWith => l10n.ruleOperatorStartsWith,
    RuleConditionOperator.endsWith => l10n.ruleOperatorEndsWith,
    RuleConditionOperator.greaterThan => l10n.ruleOperatorGreaterThan,
    RuleConditionOperator.lessThan => l10n.ruleOperatorLessThan,
    RuleConditionOperator.regex => l10n.ruleOperatorRegex,
  };
}

extension RuleActionTypeLabel on RuleActionType {
  String label(AppLocalizations l10n) => switch (this) {
    RuleActionType.setCategory => l10n.ruleActionSetCategory,
    RuleActionType.setPayee => l10n.ruleActionSetPayee,
    RuleActionType.setAccount => l10n.ruleActionSetAccount,
    RuleActionType.setMemo => l10n.ruleActionSetMemo,
    RuleActionType.markCleared => l10n.ruleActionMarkCleared,
    RuleActionType.markApproved => l10n.ruleActionMarkApproved,
  };
}

extension RuleTemplateKindLabel on RuleTemplateKind {
  String title(AppLocalizations l10n) => switch (this) {
    RuleTemplateKind.categorizeByPayee => l10n.ruleTemplatePayeeTitle,
    RuleTemplateKind.autoClearSmall => l10n.ruleTemplateAutoClearTitle,
    RuleTemplateKind.autoApproveBill => l10n.ruleTemplateAutoApproveTitle,
    RuleTemplateKind.keywordCategorization => l10n.ruleTemplateKeywordTitle,
  };

  String description(AppLocalizations l10n) => switch (this) {
    RuleTemplateKind.categorizeByPayee => l10n.ruleTemplatePayeeDescription,
    RuleTemplateKind.autoClearSmall => l10n.ruleTemplateAutoClearDescription,
    RuleTemplateKind.autoApproveBill => l10n.ruleTemplateAutoApproveDescription,
    RuleTemplateKind.keywordCategorization =>
      l10n.ruleTemplateKeywordDescription,
  };
}
