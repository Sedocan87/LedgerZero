import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
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
                await ref.read(budgetingServiceProvider).saveBudgetTemplate(name, month);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.templateSaved)),
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

Future<void> showApplyTemplateDialog(BuildContext context, WidgetRef ref) async {
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

  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context)!.applyTemplate),
        content: SizedBox(
          width: double.maxFinite,
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
                    await ref.read(budgetingServiceProvider).deleteTemplate(template.id);
                    Navigator.pop(context);
                    // Re-open to refresh? Or just close. Simple to just close.
                  },
                ),
                onTap: () async {
                   final month = ref.read(selectedBudgetMonthProvider);
                   await ref.read(budgetingServiceProvider).applyBudgetTemplate(template.id, month);

                   ref.invalidate(budgetViewModelProvider);
                   ref.invalidate(tbbProvider);

                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.budgetUpdated)),
                     );
                     Navigator.pop(context);
                   }
                },
              );
            },
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
}
