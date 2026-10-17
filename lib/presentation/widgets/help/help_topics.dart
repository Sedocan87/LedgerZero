import 'package:ledger_zero/l10n/app_localizations.dart';

/// Chapters of the user guide, in order. Help sheets link to one.
enum GuideChapter {
  start,
  accounts,
  budget,
  transactions,
  transfers,
  saving,
  overspending,
  reconcile,
  partner,
  security,
  importing;

  String title(AppLocalizations l10n) => switch (this) {
    start => l10n.guideStartTitle,
    accounts => l10n.guideAccountsTitle,
    budget => l10n.guideBudgetTitle,
    transactions => l10n.guideTransactionsTitle,
    transfers => l10n.guideTransfersTitle,
    saving => l10n.guideSavingTitle,
    overspending => l10n.guideOverspendingTitle,
    reconcile => l10n.guideReconcileTitle,
    partner => l10n.guidePartnerTitle,
    security => l10n.guideSecurityTitle,
    importing => l10n.guideImportTitle,
  };

  String body(AppLocalizations l10n) => switch (this) {
    start => l10n.guideStartBody,
    accounts => l10n.guideAccountsBody,
    budget => l10n.guideBudgetBody,
    transactions => l10n.guideTransactionsBody,
    transfers => l10n.guideTransfersBody,
    saving => l10n.guideSavingBody,
    overspending => l10n.guideOverspendingBody,
    reconcile => l10n.guideReconcileBody,
    partner => l10n.guidePartnerBody,
    security => l10n.guideSecurityBody,
    importing => l10n.guideImportBody,
  };

  /// The chapter named [name] (a route query parameter), if any.
  static GuideChapter? tryParse(String? name) =>
      values.where((c) => c.name == name).firstOrNull;
}

/// What an info button explains: a title, a short text, optional steps and
/// the guide chapter with the longer version.
enum HelpTopic {
  saving(GuideChapter.saving),
  toBeBudgeted(GuideChapter.budget),
  newMonth(GuideChapter.budget),
  onBudget(GuideChapter.accounts),
  personal(GuideChapter.partner),
  accountTypes(GuideChapter.accounts),
  accounts(GuideChapter.accounts),
  transfer(GuideChapter.transfers),
  sync(GuideChapter.partner),
  csvImport(GuideChapter.importing),
  appLock(GuideChapter.security);

  const HelpTopic(this.chapter);

  final GuideChapter chapter;

  String title(AppLocalizations l10n) => switch (this) {
    saving => l10n.helpSavingTitle,
    toBeBudgeted => l10n.helpTbbTitle,
    newMonth => l10n.helpNewMonthTitle,
    onBudget => l10n.helpOnBudgetTitle,
    personal => l10n.helpPersonalTitle,
    accountTypes => l10n.helpAccountTypesTitle,
    accounts => l10n.helpAccountsTitle,
    transfer => l10n.helpTransferTitle,
    sync => l10n.helpSyncTitle,
    csvImport => l10n.helpCsvTitle,
    appLock => l10n.helpAppLockTitle,
  };

  String body(AppLocalizations l10n) => switch (this) {
    saving => l10n.helpSavingBody,
    toBeBudgeted => l10n.helpTbbBody,
    newMonth => l10n.helpNewMonthBody,
    onBudget => l10n.helpOnBudgetBody,
    personal => l10n.helpPersonalBody,
    accountTypes => l10n.helpAccountTypesBody,
    accounts => l10n.helpAccountsBody,
    transfer => l10n.helpTransferBody,
    sync => l10n.helpSyncBody,
    csvImport => l10n.helpCsvBody,
    appLock => l10n.helpAppLockBody,
  };

  /// The steps (one per line in the translation), empty if the topic has
  /// none.
  List<String> steps(AppLocalizations l10n) {
    final text = switch (this) {
      saving => l10n.helpSavingSteps,
      toBeBudgeted => l10n.helpTbbSteps,
      newMonth => l10n.helpNewMonthSteps,
      onBudget => l10n.helpOnBudgetSteps,
      personal => l10n.helpPersonalSteps,
      accounts => l10n.helpAccountsSteps,
      transfer => l10n.helpTransferSteps,
      sync => l10n.helpSyncSteps,
      csvImport => l10n.helpCsvSteps,
      accountTypes || appLock => '',
    };
    return [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }
}
