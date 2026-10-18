import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/domain/services/account_service.dart';
import 'package:ledger_zero/domain/services/category_service.dart';
import 'package:ledger_zero/domain/services/payee_service.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/presentation/providers/privacy_settings_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/backup/data_portability_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

final dataPortabilityServiceProvider = Provider<DataPortabilityService>((ref) {
  return DataPortabilityService(
    ref.watch(accountRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(payeeRepositoryProvider),
    ref.watch(budgetRepositoryProvider),
    ref.watch(scheduledTransactionRepositoryProvider),
  );
});

final undoServiceProvider = Provider<UndoService>((ref) {
  return UndoService();
});

final budgetingServiceProvider = Provider<BudgetingService>((ref) {
  return BudgetingService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    budgetRepository: ref.watch(budgetRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    budgetTemplateRepository: ref.watch(budgetTemplateRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
  );
});

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    payeeRepository: ref.watch(payeeRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    undoService: ref.watch(undoServiceProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    ruleMatchingService: ref.watch(ruleMatchingServiceProvider),
    // Budget alert: notifies when an outflow overspends a category.
    onSaved: (change) => ref
        .read(budgetAlertProducerProvider)
        .onSaved(change.before, change.after),
  );
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    maintenance: ref.watch(referenceMaintenanceRepositoryProvider),
    ruleRepository: ref.watch(ruleRepositoryProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    undoService: ref.watch(undoServiceProvider),
  );
});

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(
    accountRepository: ref.watch(accountRepositoryProvider),
    maintenance: ref.watch(referenceMaintenanceRepositoryProvider),
    ruleRepository: ref.watch(ruleRepositoryProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    undoService: ref.watch(undoServiceProvider),
  );
});

final payeeServiceProvider = Provider<PayeeService>((ref) {
  return PayeeService(
    payeeRepository: ref.watch(payeeRepositoryProvider),
    maintenance: ref.watch(referenceMaintenanceRepositoryProvider),
    ruleRepository: ref.watch(ruleRepositoryProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    undoService: ref.watch(undoServiceProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    texts: () => notificationTextsFor(appLocalizationsFor(ref)),
  );
});

final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  return CsvImportService();
});

final scheduledTransactionServiceProvider =
    Provider<ScheduledTransactionService>((ref) {
      return ScheduledTransactionService(
        ref.watch(scheduledTransactionRepositoryProvider),
        ref.watch(transactionRepositoryProvider),
        ref.watch(notificationServiceProvider),
        unitOfWork: ref.watch(unitOfWorkProvider),
        ruleMatchingService: ref.watch(ruleMatchingServiceProvider),
        accountRepository: ref.watch(accountRepositoryProvider),
        showAmountsInNotifications: () =>
            ref.read(privacySettingsProvider).notificationAmounts,
        remindersEnabled: () =>
            ref.read(settingsProvider).scheduledTransactionNotifications,
        formatAmount: (minor) =>
            ref.read(appFormatterProvider).formatMoney(minor.abs()),
        defaultMemo: () =>
            appLocalizationsFor(ref).scheduledTransactionDefaultMemo,
        reminderText: (amountText) {
          final l10n = appLocalizationsFor(ref);
          return (
            title: l10n.notificationScheduledTitle,
            body: amountText == null
                ? l10n.notificationScheduledBodyGeneric
                : l10n.notificationScheduledBodyAmount(amountText),
          );
        },
      );
    });

final ruleMatchingServiceProvider = Provider<RuleMatchingService>((ref) {
  return RuleMatchingService(
    ref.watch(payeeRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(ruleRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(unitOfWorkProvider),
  );
});
