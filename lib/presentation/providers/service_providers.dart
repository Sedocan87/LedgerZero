import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/services/analytics_service.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/backup/data_portability_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:ledger_zero/services/widget/widget_service.dart';
import 'package:uuid/uuid.dart';

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

final securityManagerProvider = Provider<SecurityManager>((ref) {
  return SecurityManager();
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
  );
});

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(undoServiceProvider),
  );
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(
    accountRepository: ref.watch(accountRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
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
        const Uuid(),
      );
    });

final ruleMatchingServiceProvider = Provider<RuleMatchingService>((ref) {
  return RuleMatchingService(
    ref.watch(payeeRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
  );
});

final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService(
    ref.watch(budgetingServiceProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(payeeRepositoryProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
