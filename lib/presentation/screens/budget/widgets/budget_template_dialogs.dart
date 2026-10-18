import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
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
                          await ref
                              .read(budgetingServiceProvider)
                              .deleteTemplate(template.id);
                          ref.invalidate(budgetTemplatesProvider);
                          if (context.mounted) {
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
