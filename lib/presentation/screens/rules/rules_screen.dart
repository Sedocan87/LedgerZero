import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/services/import/rule_import_export_service.dart';
import 'package:ledger_zero/services/rules/rule_conflict_service.dart';
import 'package:ledger_zero/services/rules/rule_learning_service.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:go_router/go_router.dart';

// Provider to watch rules
final rulesListProvider = StreamProvider<List<Rule>>((ref) {
  return ref.watch(ruleRepositoryProvider).watchRules();
});

// Provider for conflicts
final ruleConflictsProvider = Provider<List<RuleConflict>>((ref) {
  final rulesAsync = ref.watch(rulesListProvider);
  return rulesAsync.when(
    data: (rules) =>
        ref.watch(ruleConflictServiceProvider).detectConflicts(rules),
    loading: () => [],
    error: (_, _) => [],
  );
});

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesListProvider);
    final conflicts = ref.watch(ruleConflictsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rules),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export') {
                try {
                  final service = ref.read(ruleImportExportServiceProvider);
                  await service.exportRules();
                } catch (e, st) {
                  Logger.error('Exporting rules failed', e, st);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.exportFailedGeneric)),
                    );
                  }
                }
              } else if (value == 'import') {
                try {
                  final service = ref.read(ruleImportExportServiceProvider);
                  final count = await service.importRules();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.rulesImported(count))),
                    );
                  }
                } catch (e, st) {
                  Logger.error('Importing rules failed', e, st);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.importFailedGeneric)),
                    );
                  }
                }
              } else if (value == 'apply') {
                final rules = await ref.read(ruleRepositoryProvider).getRules();
                if (!context.mounted) {
                  return;
                }
                if (rules.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.rulesNoneToApply)),
                  );
                  return;
                }

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.rulesApplyTitle),
                    content: Text(l10n.rulesApplyMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.apply),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  try {
                    // Loading indicator, closed below.
                    unawaited(
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            const Center(child: CircularProgressIndicator()),
                      ),
                    );

                    final service = ref.read(ruleMatchingServiceProvider);
                    final stats = await service.applyRulesToAllTransactions(
                      rules,
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.rulesApplied(stats.modifiedCount)),
                        ),
                      );
                    }
                  } catch (e, st) {
                    Logger.error('Applying rules failed', e, st);
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorOccurred)),
                      );
                    }
                  }
                }
              } else if (value == 'suggest') {
                unawaited(
                  showDialog<void>(
                    context: context,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                );

                try {
                  final suggestions = await ref
                      .read(ruleLearningServiceProvider)
                      .suggestRules();
                  if (context.mounted) {
                    Navigator.pop(context); // close loader
                    _showSuggestionsDialog(context, ref, suggestions);
                  }
                } catch (e, st) {
                  Logger.error('Suggesting rules failed', e, st);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
                  }
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'import', child: Text(l10n.rulesMenuImport)),
              PopupMenuItem(value: 'export', child: Text(l10n.rulesMenuExport)),
              PopupMenuItem(
                value: 'apply',
                child: Text(l10n.rulesMenuApplyAll),
              ),
              PopupMenuItem(
                value: 'suggest',
                child: Text(l10n.rulesMenuSuggest),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (conflicts.isNotEmpty)
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8.0),
              width: double.infinity,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.rulesConflictsFound(conflicts.length),
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.rulesConflictsTitle),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: conflicts.length,
                              itemBuilder: (ctx, i) => ListTile(
                                title: Text(
                                  l10n.rulesConflictPair(
                                    conflicts[i].ruleA.name,
                                    conflicts[i].ruleB.name,
                                  ),
                                ),
                                subtitle: Text(l10n.rulesConflictExplanation),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.close),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(l10n.view),
                  ),
                ],
              ),
            ),
          Expanded(
            child: rulesAsync.when(
              data: (rules) {
                if (rules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.rulesEmpty),
                        const SizedBox(height: 16),
                        AppButton.primary(
                          label: l10n.rulesCreate,
                          onPressed: () => context.push('/settings/rules/add'),
                        ),
                      ],
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: rules.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final item = rules.removeAt(oldIndex);
                    rules.insert(newIndex, item);

                    // Update priority locally and save
                    final updatedRules = <Rule>[];
                    for (int i = 0; i < rules.length; i++) {
                      updatedRules.add(rules[i].copyWith(priority: i));
                    }

                    ref
                        .read(ruleRepositoryProvider)
                        .reorderRules(updatedRules)
                        .catchError((e) {
                          Logger.error('Failed to reorder rules', e);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.rulesReorderFailed)),
                            );
                          }
                        });
                  },
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return ListTile(
                      key: ValueKey(rule.id),
                      title: Text(rule.name),
                      subtitle: Text(
                        l10n.ruleSummary(
                          l10n.ruleConditionCount(rule.conditions.length),
                          l10n.ruleActionCount(rule.actions.length),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: rule.isActive,
                            onChanged: (val) {
                              ref
                                  .read(ruleRepositoryProvider)
                                  .updateRule(rule.copyWith(isActive: val));
                            },
                          ),
                          const IconButton(
                            icon: Icon(Icons.drag_handle),
                            onPressed:
                                null, // ReorderableListView handles this via long press or handle
                          ),
                        ],
                      ),
                      onTap: () =>
                          context.push('/settings/rules/edit/${rule.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (err, stack) => LoadErrorView(
                error: err,
                stackTrace: stack,
                onRetry: () => ref.invalidate(rulesListProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'rules-fab',
        onPressed: () => context.push('/settings/rules/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSuggestionsDialog(
    BuildContext context,
    WidgetRef ref,
    List<Rule> suggestions,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.rulesNoSuggestions)));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rulesSuggestedTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (ctx, i) {
              final rule = suggestions[i];
              return Card(
                child: ListTile(
                  title: Text(rule.name),
                  subtitle: Text(rule.description ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.add,
                    onPressed: () async {
                      try {
                        await ref.read(ruleRepositoryProvider).createRule(rule);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.ruleAdded)),
                          );
                          Navigator.pop(
                            ctx,
                          ); // Close dialog to refresh or simple dismiss
                        }
                      } catch (e) {
                        Logger.error('Error adding suggested rule', e);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
