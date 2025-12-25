import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:uuid/uuid.dart';

/// Service that automatically creates categorization rules when user
/// categorizes a transaction, and applies them to matching transactions.
class AutoCategorizeService {
  final RuleRepository _ruleRepository;
  final TransactionRepository _transactionRepository;

  AutoCategorizeService(this._ruleRepository, this._transactionRepository);

  /// Called when a transaction is saved with a payee and category.
  /// Creates a rule for that payee->category mapping if one doesn't exist,
  /// and applies it to other uncategorized transactions with the same payee.
  Future<void> learnFromTransaction({
    required Payee payee,
    required String categoryId,
  }) async {
    // Check if a rule already exists for this payee
    final existingRules = await _ruleRepository.getRules();
    final hasExistingRule = existingRules.any((rule) {
      return rule.conditions.any(
        (c) =>
            c.type == RuleConditionType.payee &&
            c.operator == RuleConditionOperator.equals &&
            c.value.toLowerCase() == payee.name.toLowerCase(),
      );
    });

    if (hasExistingRule) {
      return; // Already have a rule for this payee
    }

    // Create a new rule
    final rule = Rule(
      id: const Uuid().v4(),
      name: 'Auto: ${payee.name}',
      description: 'Automatically created when you categorized ${payee.name}',
      priority: 0,
      isActive: true,
      matchLogic: RuleMatchLogic.and,
      conditions: [
        RuleCondition(
          type: RuleConditionType.payee,
          operator: RuleConditionOperator.equals,
          value: payee.name,
        ),
      ],
      actions: [
        RuleAction(type: RuleActionType.setCategory, value: categoryId),
      ],
    );

    await _ruleRepository.createRule(rule);

    // Apply to other uncategorized transactions with same payee
    await _applyRuleToExistingTransactions(payee.id, categoryId);
  }

  /// Applies category to all uncategorized transactions with the given payee.
  Future<void> _applyRuleToExistingTransactions(
    String payeeId,
    String categoryId,
  ) async {
    final allTransactions = await _transactionRepository.getAllTransactions();

    final matchingUncategorized = allTransactions.where(
      (tx) =>
          tx.payeeId == payeeId &&
          tx.categoryId == null &&
          tx.parentTransactionId == null,
    ); // Skip split children

    for (final tx in matchingUncategorized) {
      final updated = tx.copyWith(
        categoryId: categoryId,
        updatedAt: DateTime.now(),
      );
      await _transactionRepository.updateTransaction(updated);
    }
  }
}

final autoCategorizeServiceProvider = Provider<AutoCategorizeService>((ref) {
  return AutoCategorizeService(
    ref.watch(ruleRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
  );
});
