import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/new_month_fill_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';

/// Card for an empty current or future month: budget it like the month
/// before (or from a template) with one tap, with Undo. Shows what To Be
/// Budgeted would be afterwards and the income still expected, so the user
/// sees a shortfall before payday. "Not now" hides it for that month.
class NewMonthCard extends ConsumerStatefulWidget {
  const NewMonthCard({super.key});

  /// SharedPreferences: `yyyy-MM` of the months the card was dismissed for.
  static const dismissedKey = 'new_month_offer_dismissed';

  @override
  ConsumerState<NewMonthCard> createState() => _NewMonthCardState();
}

class _NewMonthCardState extends ConsumerState<NewMonthCard> {
  late Set<String> _dismissed;
  bool _busy = false;

  /// A fill triggered by the money arriving while the screen is open.
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _dismissed = {
      ...?ref
          .read(sharedPreferencesProvider)
          .getStringList(NewMonthCard.dismissedKey),
    };
  }

  Future<void> _dismiss(DateTime month) async {
    setState(() => _dismissed.add(CalendarDate.monthKey(month)));
    // Only the latest months matter.
    final kept = (_dismissed.toList()..sort()).reversed.take(24).toList();
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(NewMonthCard.dismissedKey, kept);
  }

  Future<void> _fill(DateTime month, Map<String, int> amounts) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final budgeting = ref.read(budgetingServiceProvider);
    setState(() => _busy = true);
    try {
      final filled = await budgeting.fillEmptyCategories(month, amounts);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.newMonthFilled(filled.length)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => budgeting.undoFill(month, filled),
          ),
        ),
      );
    } catch (e, stack) {
      Logger.error('Filling the month failed', e, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _fillFromTemplate(
    DateTime month,
    List<BudgetTemplate> templates,
  ) async {
    final template = await showDialog<BudgetTemplate>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.newMonthTemplate),
        children: [
          for (final t in templates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.name),
              ),
            ),
        ],
      ),
    );
    if (template != null && mounted) {
      await _fill(month, template.data);
    }
  }

  /// The automatic fill is waiting for this month's income: once To Be
  /// Budgeted covers the amounts, fill right away instead of at the next
  /// start (the salary was just booked or imported).
  void _retryWhenCovered(AutoFillWaiting waiting, int tbb) {
    if (_retrying || tbb < waiting.total) {
      return;
    }
    _retrying = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(newMonthFillProvider.notifier).runIfDue();
      } finally {
        _retrying = false;
      }
    });
  }

  Future<void> _fillAnyway() async {
    setState(() => _busy = true);
    try {
      await ref.read(newMonthFillProvider.notifier).fillAnyway();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _skipWaiting(DateTime month) async {
    await ref.read(newMonthFillProvider.notifier).skipMonth();
    await _dismiss(month);
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedBudgetMonthProvider);
    if (_dismissed.contains(CalendarDate.monthKey(month))) {
      return const SizedBox.shrink();
    }
    final offer = ref.watch(newMonthOfferProvider(month)).valueOrNull;
    if (offer == null || offer.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tbb = ref.watch(tbbProvider(month)).valueOrNull ?? 0;
    final income = ref.watch(monthIncomeProvider(month)).valueOrNull;
    final waiting = ref.watch(newMonthFillProvider.select((s) => s.waiting));
    if (waiting != null && waiting.month == month) {
      _retryWhenCovered(waiting, tbb);
      return _waitingCard(context, waiting, income);
    }
    final templates =
        ref.watch(budgetTemplatesProvider).valueOrNull ??
        const <BudgetTemplate>[];
    final previous = DateTime.utc(month.year, month.month - 1, 1);
    final total = offer.values.fold(0, (sum, v) => sum + v);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        key: const Key('budget.newMonthCard'),
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.08),
          scheme.surfaceContainerLow,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.event_repeat, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.newMonthTitle(
                            fmt.formatMonthName(month),
                            fmt.formatMonthName(previous),
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.newMonthBody(
                            fmt.formatMoney(total),
                            fmt.formatMoney(tbb - total),
                          ),
                          style: bodyStyle,
                        ),
                        if (income != null && income.expected > 0)
                          Text(
                            l10n.labelValue(
                              l10n.budgetIncomeLabel,
                              l10n.budgetIncomeExpected(
                                fmt.formatMoney(income.expected),
                                fmt.formatMonthDay(income.nextExpectedDate!),
                              ),
                            ),
                            style: bodyStyle,
                          ),
                      ],
                    ),
                  ),
                  const InfoButton(HelpTopic.newMonth),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  AppButton.text(
                    label: l10n.newMonthDismiss,
                    onPressed: _busy ? null : () => _dismiss(month),
                  ),
                  if (templates.isNotEmpty)
                    AppButton.text(
                      label: l10n.newMonthTemplate,
                      onPressed: _busy
                          ? null
                          : () => _fillFromTemplate(month, templates),
                    ),
                  AppButton.text(
                    key: const Key('budget.newMonthFill'),
                    label: l10n.newMonthFill(fmt.formatMonthName(previous)),
                    onPressed: _busy ? null : () => _fill(month, offer),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => showAutoFillSettingsDialog(context, ref),
                icon: const Icon(Icons.autorenew, size: 18),
                label: Text(l10n.autoFillTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _NewMonthCardState {
  /// The automatic fill is holding the month back until payday: what is
  /// missing, the income expected, "Not now" and "Fill anyway".
  Widget _waitingCard(
    BuildContext context,
    AutoFillWaiting waiting,
    MonthIncome? income,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        key: const Key('budget.autoFillWaiting'),
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.08),
          scheme.surfaceContainerLow,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_top, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.autoFillWaitingTitle(
                            fmt.formatMonthName(waiting.month),
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.autoFillWaitingBody(
                            fmt.formatMoney(waiting.total),
                            fmt.formatMoney(waiting.missing),
                          ),
                          style: bodyStyle,
                        ),
                        if (income != null && income.expected > 0)
                          Text(
                            l10n.labelValue(
                              l10n.budgetIncomeLabel,
                              l10n.budgetIncomeExpected(
                                fmt.formatMoney(income.expected),
                                fmt.formatMonthDay(income.nextExpectedDate!),
                              ),
                            ),
                            style: bodyStyle,
                          ),
                      ],
                    ),
                  ),
                  const InfoButton(HelpTopic.newMonth),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  AppButton.text(
                    label: l10n.newMonthDismiss,
                    onPressed: _busy ? null : () => _skipWaiting(waiting.month),
                  ),
                  AppButton.text(
                    key: const Key('budget.autoFillAnyway'),
                    label: l10n.autoFillAnyway,
                    onPressed: _busy ? null : _fillAnyway,
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => showAutoFillSettingsDialog(context, ref),
                icon: const Icon(Icons.autorenew, size: 18),
                label: Text(l10n.autoFillTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// After the automatic fill: what was filled from where, with Undo.
class AutoFillNoteCard extends ConsumerWidget {
  const AutoFillNoteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(newMonthFillProvider.select((s) => s.note));
    final month = ref.watch(selectedBudgetMonthProvider);
    if (note == null || note.month != month) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final previous = DateTime.utc(month.year, month.month - 1, 1);
    final controller = ref.read(newMonthFillProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        key: const Key('budget.autoFillNote'),
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.autorenew, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.autoFillNoteTitle(fmt.formatMonthName(month)),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.autoFillNoteBody(
                            fmt.formatMoney(note.total),
                            note.templateName ?? fmt.formatMonthName(previous),
                          ),
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
                    label: l10n.undo,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await controller.undoNote();
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.autoFillUndone)),
                      );
                    },
                  ),
                  AppButton.text(
                    label: l10n.ok,
                    onPressed: controller.dismissNote,
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

/// The "Fill new months automatically" setting: off, the month before or a
/// template.
Future<void> showAutoFillSettingsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final templates = await ref.read(budgetingServiceProvider).getAllTemplates();
  if (!context.mounted) {
    return;
  }
  final current = ref.read(newMonthFillProvider);
  bool isCurrent(AutoFillSource source, [String? templateId]) =>
      current.source == source &&
      (source != AutoFillSource.template || current.templateId == templateId);

  final choice = await showDialog<(AutoFillSource, String?)>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      Widget option(String label, AutoFillSource source, [String? id]) {
        final selected = isCurrent(source, id);
        return Semantics(
          selected: selected,
          child: SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (source, id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (selected)
                    Icon(
                      Icons.check,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      }

      return SimpleDialog(
        title: Text(l10n.autoFillTitle),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.autoFillExplanation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          option(l10n.autoFillOff, AutoFillSource.off),
          option(l10n.autoFillPrevious, AutoFillSource.previousMonth),
          for (final t in templates)
            option(
              l10n.autoFillTemplate(t.name),
              AutoFillSource.template,
              t.id,
            ),
        ],
      );
    },
  );
  if (choice != null) {
    await ref
        .read(newMonthFillProvider.notifier)
        .setSource(choice.$1, templateId: choice.$2);
  }
}
