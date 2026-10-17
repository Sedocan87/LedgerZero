import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

/// Confirms taking account [accountId] out of the budget. Its balance then
/// no longer counts towards To Be Budgeted, so money budgeted for it (e.g. a
/// reserve in a Savings & Investments category) would leave To Be Budgeted
/// short by that much in every month. The dialog offers to release it: the
/// categories of that group with money available, pre-selected, each
/// releasing at most what it has and all together at most the balance.
///
/// Returns null when cancelled, else category id -> amount to release
/// (empty when there is nothing to release or nothing was selected).
Future<Map<String, int>?> showLeaveBudgetDialog(
  BuildContext context,
  WidgetRef ref,
  String accountId,
) async {
  final month = CalendarDate.startOfMonthUtc(CalendarDate.today());
  final balance = await ref
      .read(accountRepositoryProvider)
      .getAccountBalance(accountId);
  final groupId = DeterministicId.defaultGroup(DefaultCategories.savingsGroup);
  final candidates = <(Category, int)>[];
  if (balance > 0) {
    final budgeting = ref.read(budgetingServiceProvider);
    final categories = await ref
        .read(categoryRepositoryProvider)
        .getAllCategories();
    for (final c in categories) {
      if (c.categoryGroupId != groupId || c.isHidden) {
        continue;
      }
      final available = await budgeting.calculateCategoryAvailable(c.id, month);
      if (available > 0) {
        candidates.add((c, available));
      }
    }
  }
  if (!context.mounted) {
    return null;
  }

  final selected = {for (final (c, _) in candidates) c.id};
  Map<String, int> allocation() {
    var remaining = balance;
    final result = <String, int>{};
    for (final (c, available) in candidates) {
      if (!selected.contains(c.id) || remaining <= 0) {
        continue;
      }
      final take = math.min(available, remaining);
      result[c.id] = take;
      remaining -= take;
    }
    return result;
  }

  return showDialog<Map<String, int>>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final fmt = ref.read(appFormatterProvider);
      return StatefulBuilder(
        builder: (context, setState) {
          final amounts = allocation();
          return AlertDialog(
            title: Text(l10n.accountOnBudgetChangeTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.accountOnBudgetChangeOff),
                  if (candidates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l10n.accountReleaseIntro(fmt.formatMoney(balance))),
                    for (final (c, _) in candidates)
                      CheckboxListTile(
                        key: Key('release.${c.id}'),
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(c.id),
                        title: Text(c.name),
                        subtitle: Text(
                          l10n.accountReleaseAmount(
                            fmt.formatMoney(amounts[c.id] ?? 0),
                          ),
                        ),
                        onChanged: (value) => setState(() {
                          if (value ?? false) {
                            selected.add(c.id);
                          } else {
                            selected.remove(c.id);
                          }
                        }),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, amounts),
                child: Text(l10n.continueAction),
              ),
            ],
          );
        },
      );
    },
  );
}
