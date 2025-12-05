import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/services/import/rule_import_export_service.dart';
import 'package:ledger_zero/services/rules/rule_conflict_service.dart';
import 'package:ledger_zero/services/rules/rule_learning_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';
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
    data: (rules) => ref.watch(ruleConflictServiceProvider).detectConflicts(rules),
    loading: () => [],
    error: (_, __) => [],
  );
});

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesListProvider);
    final conflicts = ref.watch(ruleConflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export') {
                  try {
                      final service = ref.read(ruleImportExportServiceProvider);
                      await service.exportRules();
                  } catch (e) {
                      if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                      }
                  }
              } else if (value == 'import') {
                  try {
                      final service = ref.read(ruleImportExportServiceProvider);
                      final count = await service.importRules();
                      if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count rules')));
                      }
                  } catch (e) {
                      if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                      }
                  }
              } else if (value == 'apply') {
                  final rules = ref.read(rulesListProvider).valueOrNull;
                  if (rules == null || rules.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No rules to apply')));
                      return;
                  }

                  final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                          title: const Text('Apply Rules'),
                          content: const Text('This will scan all existing transactions and apply the active rules. This cannot be undone automatically.'),
                          actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
                          ],
                      ),
                  );

                  if (confirm == true && context.mounted) {
                      try {
                          // Show loading indicator
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                          );

                          final service = ref.read(ruleMatchingServiceProvider);
                          final stats = await service.applyRulesToAllTransactions(rules);

                          if (context.mounted) {
                              Navigator.pop(context); // Close loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Updated ${stats.modifiedCount} transactions in ${stats.durationMs}ms'))
                              );
                          }
                      } catch (e) {
                          if (context.mounted) {
                              Navigator.pop(context); // Close loading
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                      }
                  }
              } else if (value == 'suggest') {
                  showDialog(
                      context: context,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                      final suggestions = await ref.read(ruleLearningServiceProvider).suggestRules();
                      if (context.mounted) {
                          Navigator.pop(context); // close loader
                          _showSuggestionsDialog(context, ref, suggestions);
                      }
                  } catch (e) {
                      if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                  }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'import', child: Text('Import Rules')),
              const PopupMenuItem(value: 'export', child: Text('Export Rules')),
              const PopupMenuItem(value: 'apply', child: Text('Apply Rules to All Transactions')),
              const PopupMenuItem(value: 'suggest', child: Text('Suggest Rules from History')),
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
                   Expanded(child: Text('${conflicts.length} rule conflicts detected', style: const TextStyle(color: Colors.black87))),
                   TextButton(
                       onPressed: () {
                           showDialog(
                               context: context,
                               builder: (ctx) => AlertDialog(
                                   title: const Text('Conflicts'),
                                   content: SizedBox(
                                       width: double.maxFinite,
                                       child: ListView.builder(
                                           shrinkWrap: true,
                                           itemCount: conflicts.length,
                                           itemBuilder: (ctx, i) => ListTile(
                                               title: Text('${conflicts[i].ruleA.name} vs ${conflicts[i].ruleB.name}'),
                                               subtitle: Text(conflicts[i].description),
                                           ),
                                       ),
                                   ),
                                   actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                               ),
                           );
                       },
                       child: const Text('VIEW')
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
                        const Text('No rules found'),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Create Rule',
                          onPressed: () => context.push('/settings/rules/add'),
                        ),
                      ],
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: rules.length,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = rules.removeAt(oldIndex);
                    rules.insert(newIndex, item);

                    // Update priority locally and save
                    final updatedRules = <Rule>[];
                    for(int i=0; i<rules.length; i++) {
                        updatedRules.add(rules[i].copyWith(priority: i));
                    }

                    ref.read(ruleRepositoryProvider).reorderRules(updatedRules).catchError((e) {
                       Logger.error('Failed to reorder rules', e);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reorder rules')));
                    });
                  },
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return ListTile(
                      key: ValueKey(rule.id),
                      title: Text(rule.name),
                      subtitle: Text('${rule.conditions.length} conditions, ${rule.actions.length} actions'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: rule.isActive,
                            onChanged: (val) {
                               ref.read(ruleRepositoryProvider).updateRule(rule.copyWith(isActive: val));
                            },
                          ),
                          const IconButton(
                              icon: Icon(Icons.drag_handle),
                              onPressed: null, // ReorderableListView handles this via long press or handle
                          ),
                        ],
                      ),
                      onTap: () => context.push('/settings/rules/edit/${rule.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (err, stack) => ErrorView(message: err.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/rules/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSuggestionsDialog(BuildContext context, WidgetRef ref, List<Rule> suggestions) {
      if (suggestions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No suggestions found based on transaction history.')));
          return;
      }

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Suggested Rules'),
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
                                      onPressed: () async {
                                          try {
                                             await ref.read(ruleRepositoryProvider).createRule(rule);
                                             if (ctx.mounted) {
                                                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Rule added')));
                                                Navigator.pop(ctx); // Close dialog to refresh or simple dismiss
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
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
          ),
      );
  }
}
