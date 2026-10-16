import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:uuid/uuid.dart';

class RuleLearningService {
  final TransactionRepository _transactionRepository;
  final PayeeRepository _payeeRepository;

  /// Names and descriptions of suggested rules (saved with the rule, so
  /// they are created in the app language).
  final AppLocalizations _l10n;

  RuleLearningService(
    this._transactionRepository,
    this._payeeRepository,
    this._l10n,
  );

  Future<List<Rule>> suggestRules() async {
    final transactions = await _transactionRepository.getAllTransactions();
    final payees = await _payeeRepository.getAllPayees();
    final payeeMap = {for (var p in payees) p.id: p};

    final suggestions = <Rule>[];

    // Group transactions by Payee
    final transactionsByPayee =
        <String, List<String>>{}; // PayeeID -> List of CategoryIDs

    for (final tx in transactions) {
      if (tx.payeeId != null && tx.categoryId != null) {
        transactionsByPayee
            .putIfAbsent(tx.payeeId!, () => [])
            .add(tx.categoryId!);
      }
    }

    // Analyze patterns
    for (final entry in transactionsByPayee.entries) {
      final payeeId = entry.key;
      final categoryIds = entry.value;

      if (categoryIds.length < 3) {
        continue; // Need at least 3 transactions to form a pattern
      }

      final total = categoryIds.length;
      final frequency = <String, int>{};
      for (final catId in categoryIds) {
        frequency[catId] = (frequency[catId] ?? 0) + 1;
      }

      // Check if any category dominates (> 80%)
      for (final catEntry in frequency.entries) {
        final catId = catEntry.key;
        final count = catEntry.value;
        final percentage = count / total;

        if (percentage >= 0.8) {
          final payeeName = payeeMap[payeeId]?.name;
          if (payeeName == null) {
            continue; // The condition matches by name.
          }

          // Check if rule already exists? (Service doesn't know existing rules easily without repo, but UI can filter)

          suggestions.add(
            Rule(
              id: const Uuid().v4(),
              name: _l10n.ruleSuggestionName(payeeName),
              description: _l10n.ruleSuggestionDescription(payeeName),
              priority: 0,
              isActive: true,
              matchLogic: RuleMatchLogic.and,
              conditions: [
                RuleCondition(
                  type: RuleConditionType.payee,
                  operator: RuleConditionOperator.equals,
                  value:
                      payeeName, // Using Name for readability/portability, could use ID if operator supports it
                ),
              ],
              actions: [
                RuleAction(type: RuleActionType.setCategory, value: catId),
              ],
            ),
          );
        }
      }
    }

    return suggestions;
  }
}

final ruleLearningServiceProvider = Provider<RuleLearningService>((ref) {
  return RuleLearningService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(payeeRepositoryProvider),
    ref.watch(appLocalizationsProvider),
  );
});
