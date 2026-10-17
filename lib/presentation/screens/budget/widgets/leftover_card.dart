import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';

/// At the start of a month: money the month before left unassigned
/// ([leftoverProvider]). It stays in To Be Budgeted either way; the card
/// offers to budget it for savings (any category, the Savings & Investments
/// group listed first) or to keep it for this month, which hides the card
/// for the month.
class LeftoverCard extends ConsumerStatefulWidget {
  const LeftoverCard({super.key});

  /// SharedPreferences: `yyyy-MM` of the months the card was dismissed for.
  static const dismissedKey = 'leftover_card_dismissed';

  @override
  ConsumerState<LeftoverCard> createState() => _LeftoverCardState();
}

class _LeftoverCardState extends ConsumerState<LeftoverCard> {
  late Set<String> _dismissed;

  @override
  void initState() {
    super.initState();
    _dismissed = {
      ...?ref
          .read(sharedPreferencesProvider)
          .getStringList(LeftoverCard.dismissedKey),
    };
  }

  Future<void> _keep(DateTime month) async {
    setState(() => _dismissed.add(CalendarDate.monthKey(month)));
    final kept = (_dismissed.toList()..sort()).reversed.take(24).toList();
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(LeftoverCard.dismissedKey, kept);
  }

  Future<void> _assign(DateTime month, int amount) async {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.read(appFormatterProvider);
    final messenger = ScaffoldMessenger.of(context);
    final category = await showCategoryPicker(
      context,
      firstGroupId: DeterministicId.defaultGroup(
        DefaultCategories.savingsGroup,
      ),
    );
    if (category == null) {
      return;
    }
    final budgeting = ref.read(budgetingServiceProvider);
    try {
      await budgeting.addToCategoryBudget(category.id, amount, month);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.leftoverAssigned(fmt.formatMoney(amount), category.name),
          ),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () =>
                budgeting.addToCategoryBudget(category.id, -amount, month),
          ),
        ),
      );
    } catch (e, stack) {
      Logger.error('Budgeting the leftover failed', e, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedBudgetMonthProvider);
    if (_dismissed.contains(CalendarDate.monthKey(month))) {
      return const SizedBox.shrink();
    }
    final amount = ref.watch(leftoverProvider(month)).valueOrNull ?? 0;
    if (amount <= 0) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final previous = DateTime.utc(month.year, month.month - 1, 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        key: const Key('budget.leftoverCard'),
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.08),
          scheme.surfaceContainerLow,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.savings_outlined, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.leftoverTitle(
                            fmt.formatMoney(amount),
                            fmt.formatMonthName(previous),
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.leftoverBody(fmt.formatMonthName(month)),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  AppButton.text(
                    label: l10n.leftoverKeep(fmt.formatMonthName(month)),
                    onPressed: () => _keep(month),
                  ),
                  AppButton.text(
                    key: const Key('budget.leftoverAssign'),
                    label: l10n.leftoverAssign,
                    onPressed: () => _assign(month, amount),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
