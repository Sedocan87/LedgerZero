import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';

class RulePerformanceStats {
  final int processedCount;
  final int modifiedCount;
  final int durationMs;

  RulePerformanceStats({
    required this.processedCount,
    required this.modifiedCount,
    required this.durationMs,
  });
}

/// How much a rule may change a transaction.
enum RuleApplyMode {
  /// Suggestions for a transaction the user is entering (manual create,
  /// quick-add): only empty fields (category, payee, memo) are filled. The
  /// account, cleared and approved flags are never touched, and nothing the
  /// user chose is overridden.
  suggest,

  /// Transactions created automatically (CSV import, scheduled
  /// occurrences): fills empty category / payee / memo and applies the
  /// cleared and approved actions. The account is never moved.
  automatic,

  /// The explicit "apply rules to all transactions" command: every action
  /// is applied and overwrites the current value.
  overwrite,
}

/// Matches transactions against user rules and applies their actions.
///
/// Priority convention (the only one in the app): rules are evaluated in
/// ascending `priority` order, `0` being the highest priority (the top of
/// the Rules screen). Every matching rule is applied, but each field is set
/// by the highest-priority matching rule that has an action for it; a
/// lower-priority rule can only set fields no higher-priority match set.
/// Inactive rules and rules without conditions never match.
///
/// Conditions: `payee` compares the payee name (of `payeeId`, or the
/// `payeeName` hint for rows whose payee does not exist yet); `description`
/// compares the memo and the optional `description` hint (e.g. the bank's
/// original description of an imported row); `amount` compares the signed
/// amount in minor units. String comparisons are case-insensitive; `regex`
/// uses a case-insensitive regular expression.
///
/// Actions whose target does not exist on this phone (an imported rule
/// naming another phone's category, payee or account) or that would move
/// a transaction into a closed or the partner's account are ignored (see
/// [withValidReferences]); [loadActiveRules] and
/// [applyRulesToAllTransactions] filter them, so a rule can never cause a
/// foreign-key failure on import or catch-up.
class RuleMatchingService {
  final PayeeRepository _payeeRepository;
  final TransactionRepository _transactionRepository;
  final RuleRepository? _ruleRepository;

  /// Validate category / account targets; without them only payees are
  /// checked.
  final CategoryRepository? _categoryRepository;
  final AccountRepository? _accountRepository;

  /// "Apply to all" runs in one unit of work when given.
  final UnitOfWork? _unitOfWork;

  RuleMatchingService(
    this._payeeRepository,
    this._transactionRepository, [
    this._ruleRepository,
    this._categoryRepository,
    this._accountRepository,
    this._unitOfWork,
  ]);

  /// [rules] sorted by the priority convention (stable for equal values).
  static List<Rule> sortByPriority(Iterable<Rule> rules) {
    final indexed = rules.toList().asMap().entries.toList()
      ..sort((a, b) {
        final byPriority = a.value.priority.compareTo(b.value.priority);
        return byPriority != 0 ? byPriority : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  /// The active rules from the repository, sorted by priority, without
  /// actions whose target does not exist ([withValidReferences]).
  Future<List<Rule>> loadActiveRules() async {
    final repository = _ruleRepository;
    if (repository == null) {
      return const [];
    }
    final rules = await repository.getRules();
    return withValidReferences(sortByPriority(rules.where((r) => r.isActive)));
  }

  /// [rules] without the actions that cannot be applied here: a category,
  /// payee or account id that does not exist, or an account that is closed
  /// or the partner's. The stored rules are left as they are (the Rules
  /// screen shows them; deleting the entity rewrites them).
  Future<List<Rule>> withValidReferences(List<Rule> rules) async {
    final cache = <String, bool>{};
    Future<bool> usable(RuleAction action) async {
      final key = '${action.type.name}:${action.value}';
      final cached = cache[key];
      if (cached != null) {
        return cached;
      }
      final bool result;
      switch (action.type) {
        case RuleActionType.setCategory:
          final categories = _categoryRepository;
          result =
              categories == null ||
              await categories.getCategoryById(action.value) != null;
        case RuleActionType.setPayee:
          result = await _payeeRepository.getPayeeById(action.value) != null;
        case RuleActionType.setAccount:
          final accounts = _accountRepository;
          if (accounts == null) {
            result = true;
          } else {
            final account = await accounts.getAccountById(action.value);
            result =
                account != null && !account.isClosed && !account.isPartners;
          }
        case RuleActionType.setMemo:
        case RuleActionType.markCleared:
        case RuleActionType.markApproved:
          result = true;
      }
      return cache[key] = result;
    }

    final result = <Rule>[];
    for (final rule in rules) {
      final actions = <RuleAction>[
        for (final action in rule.actions)
          if (await usable(action)) action,
      ];
      if (actions.length != rule.actions.length) {
        Logger.warning(
          'Rule ${rule.id}: ${rule.actions.length - actions.length} '
          'action(s) with unknown targets ignored',
        );
      }
      result.add(
        actions.length == rule.actions.length
            ? rule
            : rule.copyWith(actions: actions),
      );
    }
    return result;
  }

  /// Applies [rules] to one transaction according to [mode].
  ///
  /// Pass [payeeName] when the transaction's payee does not exist yet,
  /// [description] for extra text the description condition should see, and
  /// [isSplitParent] for the parent row of a split (it never gets a
  /// category). Transfer legs and split lines never change account, and a
  /// reconciled row is never marked cleared/uncleared by a rule.
  Future<Transaction> apply(
    Transaction transaction,
    List<Rule> rules, {
    RuleApplyMode mode = RuleApplyMode.overwrite,
    String? payeeName,
    String? description,
    bool isSplitParent = false,
  }) async {
    final resolvedPayeeName =
        payeeName ?? await _payeeNameOf(transaction.payeeId);
    final setFields = <RuleActionType>{};
    if (mode != RuleApplyMode.overwrite) {
      // Values the user (or the source) already provided are kept.
      if (transaction.categoryId != null) {
        setFields.add(RuleActionType.setCategory);
      }
      if (transaction.payeeId != null) {
        setFields.add(RuleActionType.setPayee);
      }
      if (transaction.memo != null && transaction.memo!.isNotEmpty) {
        setFields.add(RuleActionType.setMemo);
      }
      setFields.add(RuleActionType.setAccount);
      if (mode == RuleApplyMode.suggest) {
        setFields
          ..add(RuleActionType.markCleared)
          ..add(RuleActionType.markApproved);
      }
    }
    // Transfer legs never carry a category or payee and never move to
    // another account (the other leg would point at the wrong account).
    if (transaction.transferAccountId != null) {
      setFields
        ..add(RuleActionType.setCategory)
        ..add(RuleActionType.setPayee)
        ..add(RuleActionType.setAccount);
    }
    // A split line stays in its parent's account.
    if (transaction.parentTransactionId != null) {
      setFields.add(RuleActionType.setAccount);
    }
    // Split parents never carry a category (their lines do) and never move
    // away from their lines.
    if (isSplitParent) {
      setFields
        ..add(RuleActionType.setCategory)
        ..add(RuleActionType.setAccount);
    }
    // A reconciled row is never downgraded by a rule.
    if (transaction.cleared == TransactionClearStatus.reconciled) {
      setFields.add(RuleActionType.markCleared);
    }

    var current = transaction;
    for (final rule in sortByPriority(rules)) {
      if (!rule.isActive ||
          !_matches(transaction, rule, resolvedPayeeName, description)) {
        continue;
      }
      for (final action in rule.actions) {
        if (setFields.contains(action.type)) {
          continue;
        }
        final updated = _applyAction(current, action);
        if (updated != null) {
          current = updated;
          setFields.add(action.type);
        }
      }
    }
    return current;
  }

  /// Applies rules to a list of transactions ([RuleApplyMode.overwrite]
  /// unless [mode] says otherwise). The input list is not modified.
  Future<List<Transaction>> applyRules(
    List<Transaction> transactions,
    List<Rule> rules, {
    RuleApplyMode mode = RuleApplyMode.overwrite,
  }) async {
    final result = <Transaction>[];
    for (final transaction in transactions) {
      result.add(await apply(transaction, rules, mode: mode));
    }
    return result;
  }

  /// Bulk applies rules to all existing transactions in the database (the
  /// explicit "apply to all" command, [RuleApplyMode.overwrite]), in one
  /// unit of work. Rows in the partner's personal accounts are left alone
  /// (they live on the partner's phone), and actions with unknown or
  /// unbookable targets are ignored ([withValidReferences]).
  Future<RulePerformanceStats> applyRulesToAllTransactions(
    List<Rule> rules,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final usable = await withValidReferences(rules);
      final partnerAccountIds = <String>{
        for (final a in await _accountRepository?.getAllAccounts() ?? const [])
          if (a.isPartners) a.id,
      };
      Future<({int processed, int modified})> run() async {
        final allTransactions = await _transactionRepository
            .getAllTransactions();
        final modified = <Transaction>[];
        for (final original in allTransactions) {
          if (partnerAccountIds.contains(original.accountId)) {
            continue;
          }
          final updated = await apply(
            original,
            usable,
            isSplitParent: await _transactionRepository.isSplitParent(
              original.id,
            ),
          );
          if (original != updated) {
            modified.add(updated.copyWith(updatedAt: DateTime.now().toUtc()));
          }
        }
        if (modified.isNotEmpty) {
          await _transactionRepository.batchUpdateTransactions(modified);
        }
        return (processed: allTransactions.length, modified: modified.length);
      }

      final unitOfWork = _unitOfWork;
      final counts = unitOfWork == null
          ? await run()
          : await unitOfWork.run(run);
      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;
      Logger.info(
        'Applied rules to ${counts.processed} transactions. '
        'Modified ${counts.modified}. Duration: ${duration}ms',
      );
      return RulePerformanceStats(
        processedCount: counts.processed,
        modifiedCount: counts.modified,
        durationMs: duration,
      );
    } catch (e) {
      Logger.error('Error applying rules to all transactions', e);
      rethrow;
    }
  }

  /// Preview of [RuleApplyMode.overwrite] on one transaction.
  Future<Transaction> previewRules(Transaction transaction, List<Rule> rules) =>
      apply(transaction, rules);

  Future<String?> _payeeNameOf(String? payeeId) async {
    if (payeeId == null) {
      return null;
    }
    return (await _payeeRepository.getPayeeById(payeeId))?.name;
  }

  bool _matches(
    Transaction transaction,
    Rule rule,
    String? payeeName,
    String? description,
  ) {
    if (rule.conditions.isEmpty) {
      return false;
    }
    bool check(RuleCondition c) =>
        _checkCondition(transaction, c, payeeName, description);
    return rule.matchLogic == RuleMatchLogic.and
        ? rule.conditions.every(check)
        : rule.conditions.any(check);
  }

  bool _checkCondition(
    Transaction transaction,
    RuleCondition condition,
    String? payeeName,
    String? description,
  ) {
    switch (condition.type) {
      case RuleConditionType.payee:
        return payeeName != null &&
            _compareString(payeeName, condition.operator, condition.value);
      case RuleConditionType.amount:
        return _checkAmountCondition(transaction.amount, condition);
      case RuleConditionType.description:
        final texts = [
          transaction.memo,
          description,
        ].whereType<String>().where((t) => t.isNotEmpty).toList();
        if (texts.isEmpty) {
          texts.add('');
        }
        return texts.any(
          (t) => _compareString(t, condition.operator, condition.value),
        );
    }
  }

  bool _checkAmountCondition(int amount, RuleCondition condition) {
    final conditionValue = condition.amountMinor;
    if (conditionValue == null) {
      return false;
    }
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
      case RuleConditionOperator.greaterThan:
      case RuleConditionOperator.lessThan:
        return false;
    }
  }

  /// The transaction with [action] applied, or `null` if the action does
  /// not change anything recognisable (unknown boolean value).
  Transaction? _applyAction(Transaction t, RuleAction action) {
    switch (action.type) {
      case RuleActionType.setCategory:
        return t.copyWith(categoryId: action.value);
      case RuleActionType.setPayee:
        return t.copyWith(payeeId: action.value);
      case RuleActionType.setAccount:
        return t.copyWith(accountId: action.value);
      case RuleActionType.setMemo:
        return t.copyWith(memo: action.value);
      case RuleActionType.markCleared:
        return switch (action.value.toLowerCase()) {
          'true' => t.copyWith(cleared: TransactionClearStatus.cleared),
          'false' => t.copyWith(cleared: TransactionClearStatus.uncleared),
          _ => null,
        };
      case RuleActionType.markApproved:
        return switch (action.value.toLowerCase()) {
          'true' => t.copyWith(approved: true),
          'false' => t.copyWith(approved: false),
          _ => null,
        };
    }
  }
}
