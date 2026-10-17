import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/income/income_settings_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';

/// One-time card suggesting to set up the salary, shown while an account
/// exists but no recurring income does. Setting one up hides it; declining
/// (here or in the question after the first account) hides it for good, and
/// the salary stays reachable from the income line under To Be Budgeted.
class SalaryPrompt extends ConsumerStatefulWidget {
  const SalaryPrompt({super.key});

  /// SharedPreferences flag: the suggestion was declined.
  static const handledKey = 'salary_prompt_handled';

  @override
  ConsumerState<SalaryPrompt> createState() => _SalaryPromptState();
}

class _SalaryPromptState extends ConsumerState<SalaryPrompt> {
  late bool _handled;

  @override
  void initState() {
    super.initState();
    _handled =
        ref.read(sharedPreferencesProvider).getBool(SalaryPrompt.handledKey) ??
        false;
  }

  Future<void> _dismiss() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(SalaryPrompt.handledKey, true);
    if (mounted) {
      setState(() => _handled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_handled) {
      return const SizedBox.shrink();
    }
    final accounts = ref.watch(accountsProvider).valueOrNull;
    final schedules = ref.watch(scheduledTransactionsProvider).valueOrNull;
    if (accounts == null ||
        accounts.isEmpty ||
        schedules == null ||
        schedules.any((s) => (s.amount ?? 0) > 0 && !s.isFinished)) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        key: const Key('budget.salaryPrompt'),
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
                  Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.salaryPromptTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.salaryPromptBody,
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
                    label: l10n.salaryPromptDismiss,
                    onPressed: _dismiss,
                  ),
                  AppButton.text(
                    label: l10n.budgetIncomeAddButton,
                    onPressed: () => showAddIncomeSheet(context),
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
