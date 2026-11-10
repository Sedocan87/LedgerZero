import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/new_month_fill_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_month_actions.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

Future<void> showSaveTemplateDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context)!.saveAsTemplate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.createTemplateDescription),
            const SizedBox(height: 16),
            AppTextField(
              controller: controller,
              label: AppLocalizations.of(context)!.templateName,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final month = ref.read(selectedBudgetMonthProvider);
                await ref
                    .read(budgetingServiceProvider)
                    .saveBudgetTemplate(name, month);
                ref.invalidate(budgetTemplatesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.templateSaved,
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      );
    },
  );
}

/// Asks before deleting [template] (it cannot be brought back) and says
/// so when the automatic fill uses it: new months are then filled like the
/// month before ([NewMonthFillController.templateDeleted]). Returns whether
/// the template was deleted.
Future<bool> confirmAndDeleteTemplate(
  BuildContext context,
  WidgetRef ref,
  BudgetTemplate template,
) async {
  final usedByAutoFill = ref
      .read(newMonthFillProvider.notifier)
      .usesTemplate(template.id);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l10n.budgetTemplateDeleteTitle),
        content: Text(
          usedByAutoFill
              ? '${l10n.budgetTemplateDeleteBody(template.name)}\n\n'
                    '${l10n.budgetTemplateDeleteAutoFill}'
              : l10n.budgetTemplateDeleteBody(template.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('budget.templateDeleteConfirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(budgetingServiceProvider).deleteTemplate(template.id);
    await ref.read(newMonthFillProvider.notifier).templateDeleted(template.id);
    ref.invalidate(budgetTemplatesProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.budgetTemplateDeleted(template.name))),
    );
    return true;
  } catch (e, stack) {
    Logger.error('Deleting a budget template failed', e, stack);
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    return false;
  }
}

Future<void> showApplyTemplateDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Fetch templates
  final templates = await ref.read(budgetingServiceProvider).getAllTemplates();

  if (!context.mounted) {
    return;
  }

  if (templates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.noTemplates)),
    );
    return;
  }

  final chosen = await showDialog<BudgetTemplate>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context)!.applyTemplate),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A template is a merge: only its categories change.
              Text(
                AppLocalizations.of(context)!.applyTemplateDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return ListTile(
                      title: Text(template.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: AppLocalizations.of(context)!.deleteTemplate,
                        onPressed: () async {
                          final deleted = await confirmAndDeleteTemplate(
                            context,
                            ref,
                            template,
                          );
                          if (deleted && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      onTap: () => Navigator.pop(context, template),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      );
    },
  );
  if (chosen == null || !context.mounted) {
    return;
  }

  final month = ref.read(selectedBudgetMonthProvider);
  final fmt = ref.read(appFormatterProvider);
  final ok = await confirmMonthOverwrite(
    context,
    ref,
    month: month,
    message: l10n.budgetApplyTemplateConfirmation(
      fmt.formatMonthYear(month),
      chosen.name,
    ),
  );
  if (!ok || !context.mounted) {
    return;
  }
  await runMonthAction(
    context,
    ref,
    run: () => ref
        .read(budgetingServiceProvider)
        .applyBudgetTemplate(chosen.id, month),
    message: l10n.budgetTemplateApplied(chosen.name),
  );
}
