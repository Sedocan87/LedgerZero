import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:uuid/uuid.dart';

/// Suggests "payee X -> category Y" rules from the transaction history: a
/// payee with at least three categorised transactions of which 80% or more
/// share one category. Suggestions the user already has as a rule (same
/// payee condition and category action) are left out, and an accepted
/// suggestion is appended below the existing rules (lowest priority), so
/// it never overrides what the user set up.
class RuleLearningService {
  final TransactionRepository _transactionRepository;
  final PayeeRepository _payeeRepository;

  /// Names and descriptions of suggested rules (saved with the rule, so
  /// they are created in the app language).
  final AppLocalizations _l10n;

  /// The user's rules, for duplicate checks and [acceptSuggestion].
  final RuleRepository? _ruleRepository;

  RuleLearningService(
    this._transactionRepository,
    this._payeeRepository,
    this._l10n, [
    this._ruleRepository,
  ]);

  /// Whether one of [rules] already maps payee [payeeName] to [categoryId].
  static bool alreadyCovered(
    Iterable<Rule> rules,
    String payeeName,
    String categoryId,
  ) {
    final name = payeeName.toLowerCase();
    return rules.any(
      (r) =>
          r.conditions.any(
            (c) =>
                c.type == RuleConditionType.payee &&
                c.operator == RuleConditionOperator.equals &&
                c.value.toLowerCase() == name,
          ) &&
          r.actions.any(
            (a) =>
                a.type == RuleActionType.setCategory && a.value == categoryId,
          ),
    );
  }

  /// Stores [suggestion] after the existing rules (priority = their
  /// number) and returns the stored rule.
  Future<Rule> acceptSuggestion(Rule suggestion) async {
    final repository = _ruleRepository;
    if (repository == null) {
      throw StateError('RuleLearningService has no rule repository');
    }
    final existing = await repository.getRules();
    final rule = suggestion.copyWith(priority: existing.length);
    await repository.createRule(rule);
    return rule;
  }

  Future<List<Rule>> suggestRules() async {
    final transactions = await _transactionRepository.getAllTransactions();
    final payees = await _payeeRepository.getAllPayees();
    final payeeMap = {for (var p in payees) p.id: p};
    final existingRules = await _ruleRepository?.getRules() ?? const <Rule>[];

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
          if (alreadyCovered(existingRules, payeeName, catId)) {
            continue;
          }

          suggestions.add(
            Rule(
              id: const Uuid().v4(),
              name: _l10n.ruleSuggestionName(payeeName),
              description: _l10n.ruleSuggestionDescription(payeeName),
              // Set on accept: after the existing rules.
              priority: existingRules.length,
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
    ref.watch(ruleRepositoryProvider),
  );
});
