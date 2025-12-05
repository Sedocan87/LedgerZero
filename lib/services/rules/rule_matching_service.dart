import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class RuleMatchingService {
  final PayeeRepository _payeeRepository;

  RuleMatchingService(this._payeeRepository);

  /// Applies rules to a list of transactions.
  /// Returns a list of transactions that have been modified by the rules.
  /// Note: The original list is not modified.
  Future<List<Transaction>> applyRules(List<Transaction> transactions, List<Rule> rules) async {
    // Sort rules by priority (ascending: 0 is highest priority)
    final sortedRules = List<Rule>.from(rules)..sort((a, b) => a.priority.compareTo(b.priority));

    final result = <Transaction>[];
    for (var transaction in transactions) {
        var current = transaction;
        for (final rule in sortedRules) {
             if (rule.isActive && await _matches(current, rule)) {
                 current = await _applyActions(current, rule.actions);
             }
        }
        result.add(current);
    }
    return result;
  }

  Future<bool> _matches(Transaction transaction, Rule rule) async {
    if (rule.conditions.isEmpty) return false;

    if (rule.matchLogic == RuleMatchLogic.and) {
      for (final condition in rule.conditions) {
        if (!await _checkCondition(transaction, condition)) {
          return false;
        }
      }
      return true;
    } else { // OR
      for (final condition in rule.conditions) {
        if (await _checkCondition(transaction, condition)) {
          return true;
        }
      }
      return false;
    }
  }

  Future<bool> _checkCondition(Transaction transaction, RuleCondition condition) async {
    switch (condition.type) {
      case RuleConditionType.payee:
        return _checkPayeeCondition(transaction, condition);
      case RuleConditionType.amount:
        return _checkAmountCondition(transaction, condition);
      case RuleConditionType.description:
        return _checkDescriptionCondition(transaction, condition);
      default:
        Logger.warning('Unknown rule condition type: ${condition.type}');
        return false;
    }
  }

  Future<bool> _checkPayeeCondition(Transaction transaction, RuleCondition condition) async {
      // If the transaction already has a payee assigned, check the payee name.
      if (transaction.payeeId != null) {
          final payee = await _payeeRepository.getPayeeById(transaction.payeeId!);
          if (payee != null) {
              return _compareString(payee.name, condition.operator, condition.value);
          }
      }
      return false;
  }

  bool _checkAmountCondition(Transaction transaction, RuleCondition condition) {
      final amount = transaction.amount;
      final conditionValue = double.tryParse(condition.value);
      if (conditionValue == null) return false;

      switch (condition.operator) {
          case RuleConditionOperator.equals:
              return amount == conditionValue;
          case RuleConditionOperator.greaterThan:
              return amount > conditionValue;
          case RuleConditionOperator.lessThan:
              return amount < conditionValue;
          default:
              return false;
      }
  }

  bool _checkDescriptionCondition(Transaction transaction, RuleCondition condition) {
      final memo = transaction.memo ?? '';
      return _compareString(memo, condition.operator, condition.value);
  }

  bool _compareString(String input, RuleConditionOperator op, String value) {
      final normalizedInput = input.toLowerCase();
      final normalizedValue = value.toLowerCase();

      switch (op) {
          case RuleConditionOperator.equals:
              return normalizedInput == normalizedValue;
          case RuleConditionOperator.contains:
              return normalizedInput.contains(normalizedValue);
          case RuleConditionOperator.startsWith:
              return normalizedInput.startsWith(normalizedValue);
          case RuleConditionOperator.endsWith:
              return normalizedInput.endsWith(normalizedValue);
          case RuleConditionOperator.regex:
              try {
                  return RegExp(value, caseSensitive: false).hasMatch(input);
              } catch (e) {
                  Logger.error('Invalid regex in rule', e);
                  return false;
              }
          default:
              return false;
      }
  }

  Future<Transaction> _applyActions(Transaction transaction, List<RuleAction> actions) async {
    var t = transaction;
    for (final action in actions) {
      switch (action.type) {
        case RuleActionType.setCategory:
           t = t.copyWith(categoryId: action.value);
           break;
        case RuleActionType.setPayee:
           t = t.copyWith(payeeId: action.value);
           break;
        case RuleActionType.setAccount:
           t = t.copyWith(accountId: action.value);
           break;
        case RuleActionType.setMemo:
           t = t.copyWith(memo: action.value);
           break;
        case RuleActionType.markCleared:
            if (action.value.toLowerCase() == 'true') {
               t = t.copyWith(cleared: TransactionClearStatus.cleared);
            } else if (action.value.toLowerCase() == 'false') {
               t = t.copyWith(cleared: TransactionClearStatus.uncleared);
            }
            break;
        case RuleActionType.markApproved:
            if (action.value.toLowerCase() == 'true') {
                t = t.copyWith(approved: true);
            } else if (action.value.toLowerCase() == 'false') {
                t = t.copyWith(approved: false);
            }
            break;
      }
    }
    return t;
  }

  // Preview method for Task 579
  Future<Transaction> previewRules(Transaction transaction, List<Rule> rules) async {
      return (await applyRules([transaction], rules)).first;
  }
}
