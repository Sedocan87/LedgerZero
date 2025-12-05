import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:go_router/go_router.dart';

// Provider to watch rules
final rulesListProvider = StreamProvider<List<Rule>>((ref) {
  return ref.watch(ruleRepositoryProvider).watchRules();
});

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
      ),
      body: rulesAsync.when(
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
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reorder rules')));
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
                    IconButton(
                        icon: const Icon(Icons.drag_handle),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/settings/rules/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
