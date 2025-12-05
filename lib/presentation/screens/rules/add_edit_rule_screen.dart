import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/services/rule_template_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/pickers/account_selector.dart';
import 'package:ledger_zero/presentation/widgets/pickers/category_selector.dart';
import 'package:ledger_zero/presentation/widgets/pickers/payee_selector.dart';
import 'package:uuid/uuid.dart';

class AddEditRuleScreen extends ConsumerStatefulWidget {
  final String? ruleId;

  const AddEditRuleScreen({super.key, this.ruleId});

  @override
  ConsumerState<AddEditRuleScreen> createState() => _AddEditRuleScreenState();
}

class _AddEditRuleScreenState extends ConsumerState<AddEditRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late RuleMatchLogic _matchLogic;
  List<RuleCondition> _conditions = [];
  List<RuleAction> _actions = [];
  bool _isActive = true;
  int _priority = 0; // Default, will be set on load or save

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _matchLogic = RuleMatchLogic.and;
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.ruleId != null) {
      final rule = await ref.read(ruleRepositoryProvider).getRule(widget.ruleId!);
      if (rule != null) {
        _nameController.text = rule.name;
        _matchLogic = rule.matchLogic;
        _conditions = List.from(rule.conditions);
        _actions = List.from(rule.actions);
        _isActive = rule.isActive;
        _priority = rule.priority;
      }
    } else {
        // For new rule, set priority to lowest (highest number)
        final rules = await ref.read(ruleRepositoryProvider).getRules();
        if (rules.isNotEmpty) {
            _priority = rules.length;
        }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _applyTemplate(RuleTemplate template) {
      final rule = template.createRule();
      setState(() {
          _nameController.text = rule.name;
          _matchLogic = rule.matchLogic;
          _conditions = List.from(rule.conditions);
          _actions = List.from(rule.actions);
          _isActive = rule.isActive;
      });
  }

  void _showTemplatesDialog() {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text('Choose a Template'),
              content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: RuleTemplateService.templates.length,
                      itemBuilder: (context, index) {
                          final template = RuleTemplateService.templates[index];
                          return ListTile(
                              title: Text(template.name),
                              subtitle: Text(template.description),
                              onTap: () {
                                  _applyTemplate(template);
                                  Navigator.pop(context);
                              },
                          );
                      },
                  ),
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ],
          ),
      );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_conditions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one condition')));
        return;
    }
    if (_actions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one action')));
        return;
    }

    final rule = Rule(
      id: widget.ruleId ?? const Uuid().v4(),
      name: _nameController.text,
      priority: _priority,
      isActive: _isActive,
      matchLogic: _matchLogic,
      conditions: _conditions,
      actions: _actions,
    );

    try {
      if (widget.ruleId != null) {
        await ref.read(ruleRepositoryProvider).updateRule(rule);
      } else {
        await ref.read(ruleRepositoryProvider).createRule(rule);
      }
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving rule: $e')));
      }
    }
  }

  Future<void> _delete() async {
      if (widget.ruleId == null) return;

      final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Delete Rule'),
              content: const Text('Are you sure you want to delete this rule?'),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ],
          ),
      );

      if (confirm == true) {
          await ref.read(ruleRepositoryProvider).deleteRule(widget.ruleId!);
          if (mounted) context.pop();
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ruleId != null ? 'Edit Rule' : 'New Rule'),
        actions: [
            if (widget.ruleId == null)
               IconButton(
                   icon: const Icon(Icons.auto_awesome),
                   tooltip: 'Use Template',
                   onPressed: _showTemplatesDialog
               ),
            if (widget.ruleId != null)
                IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Rule Name',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 16),
            const Text('Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
                children: [
                    const Text('Match: '),
                    DropdownButton<RuleMatchLogic>(
                        value: _matchLogic,
                        onChanged: (v) => setState(() => _matchLogic = v!),
                        items: RuleMatchLogic.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                    ),
                    const Text(' of the following conditions:'),
                ],
            ),
            ..._conditions.asMap().entries.map((entry) {
                final index = entry.key;
                final condition = entry.value;
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                            children: [
                                Expanded(
                                    child: _ConditionDisplay(condition: condition),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => setState(() => _conditions.removeAt(index)),
                                )
                            ],
                        ),
                    ),
                );
            }),
            AppButton(
                label: 'Add Condition',
                variant: AppButtonVariant.secondary,
                onPressed: _showAddConditionDialog,
            ),
            const SizedBox(height: 24),
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._actions.asMap().entries.map((entry) {
                final index = entry.key;
                final action = entry.value;
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                            children: [
                                Expanded(
                                    child: _ActionDisplay(action: action),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => setState(() => _actions.removeAt(index)),
                                )
                            ],
                        ),
                    ),
                );
            }),
            AppButton(
                label: 'Add Action',
                variant: AppButtonVariant.secondary,
                onPressed: _showAddActionDialog,
            ),
            const SizedBox(height: 32),
            AppButton(
                label: 'Save Rule',
                onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddConditionDialog() {
      RuleConditionType type = RuleConditionType.description;
      RuleConditionOperator op = RuleConditionOperator.contains;
      final valueController = TextEditingController();

      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialogState) => AlertDialog(
                  title: const Text('Add Condition'),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          DropdownButtonFormField<RuleConditionType>(
                              value: type,
                              decoration: const InputDecoration(labelText: 'Field'),
                              items: RuleConditionType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                              onChanged: (v) => setDialogState(() => type = v!),
                          ),
                          DropdownButtonFormField<RuleConditionOperator>(
                              value: op,
                              decoration: const InputDecoration(labelText: 'Operator'),
                              items: RuleConditionOperator.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                              onChanged: (v) => setDialogState(() => op = v!),
                          ),
                          if (type == RuleConditionType.payee)
                             TextField(
                               controller: valueController,
                               readOnly: true,
                               decoration: const InputDecoration(
                                   labelText: 'Select Payee',
                                   suffixIcon: Icon(Icons.arrow_drop_down)
                               ),
                               onTap: () {
                                   PayeeSelector.show(context, (payee) {
                                       valueController.text = payee.name; // Store Name for comparison
                                   });
                               },
                             )
                          else
                             TextField(
                                 controller: valueController,
                                 decoration: const InputDecoration(labelText: 'Value'),
                             ),
                      ],
                  ),
                  actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(onPressed: () {
                          if (valueController.text.isNotEmpty) {
                              setState(() {
                                  _conditions.add(RuleCondition(type: type, operator: op, value: valueController.text));
                              });
                              Navigator.pop(ctx);
                          }
                      }, child: const Text('Add')),
                  ],
              ),
          ),
      );
  }

  void _showAddActionDialog() {
      RuleActionType type = RuleActionType.setCategory;
      final valueController = TextEditingController();
      // Store readable name for display in dialog before save, but ID in valueController
      String displayValue = '';

      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialogState) {
                  return AlertDialog(
                      title: const Text('Add Action'),
                      content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              DropdownButtonFormField<RuleActionType>(
                                  value: type,
                                  decoration: const InputDecoration(labelText: 'Action'),
                                  items: RuleActionType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                                  onChanged: (v) {
                                      setDialogState(() {
                                          type = v!;
                                          valueController.clear();
                                          displayValue = '';
                                      });
                                  },
                              ),
                              const SizedBox(height: 16),
                              _buildActionValueInput(
                                  context,
                                  type,
                                  valueController,
                                  displayValue,
                                  (val, display) {
                                      setDialogState(() {
                                          displayValue = display;
                                      });
                                  }
                              ),
                          ],
                      ),
                      actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(onPressed: () {
                              if (valueController.text.isNotEmpty) {
                                  setState(() {
                                      _actions.add(RuleAction(type: type, value: valueController.text));
                                  });
                                  Navigator.pop(ctx);
                              }
                          }, child: const Text('Add')),
                      ],
                  );
              },
          ),
      );
  }

  Widget _buildActionValueInput(
      BuildContext context,
      RuleActionType type,
      TextEditingController controller,
      String displayValue,
      Function(String, String) onUpdate
  ) {
      if (type == RuleActionType.setCategory) {
          return InkWell(
              onTap: () {
                  CategorySelector.show(context, (category) {
                      controller.text = category.id;
                      onUpdate(category.id, category.name);
                  });
              },
              child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Select Category',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(displayValue.isEmpty ? 'Tap to select' : displayValue),
              ),
          );
      } else if (type == RuleActionType.setPayee) {
           return InkWell(
              onTap: () {
                  PayeeSelector.show(context, (payee) {
                      controller.text = payee.id;
                      onUpdate(payee.id, payee.name);
                  });
              },
              child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Select Payee',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(displayValue.isEmpty ? 'Tap to select' : displayValue),
              ),
          );
      } else if (type == RuleActionType.setAccount) {
           return InkWell(
              onTap: () {
                  AccountSelector.show(context, (account) {
                      controller.text = account.id;
                      onUpdate(account.id, account.name);
                  });
              },
              child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Select Account',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(displayValue.isEmpty ? 'Tap to select' : displayValue),
              ),
          );
      } else if (type == RuleActionType.markCleared || type == RuleActionType.markApproved) {
           return DropdownButtonFormField<String>(
               value: controller.text.isEmpty ? 'true' : controller.text,
               items: const [
                   DropdownMenuItem(value: 'true', child: Text('Yes')),
                   DropdownMenuItem(value: 'false', child: Text('No')),
               ],
               onChanged: (v) {
                   controller.text = v!;
                   onUpdate(v, v == 'true' ? 'Yes' : 'No');
               },
               decoration: const InputDecoration(labelText: 'Value'),
           );
      } else {
          return TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Value'),
              onChanged: (v) => onUpdate(v, v),
          );
      }
  }
}

class _ConditionDisplay extends StatelessWidget {
    final RuleCondition condition;

    const _ConditionDisplay({required this.condition});

    @override
    Widget build(BuildContext context) {
        return Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
                Chip(label: Text(condition.type.name)),
                Text(condition.operator.name),
                Text(condition.value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
        );
    }
}

class _ActionDisplay extends ConsumerWidget {
    final RuleAction action;

    const _ActionDisplay({required this.action});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
        String description = '';

        switch (action.type) {
            case RuleActionType.setCategory:
                final categoriesAsync = ref.watch(categoriesProvider);
                final name = categoriesAsync.maybeWhen(
                    data: (list) => list.firstWhere((c) => c.id == action.value, orElse: () => Category(id: '', name: 'Unknown', color: 0, icon: 0, createdAt: DateTime.now())).name,
                    orElse: () => 'Loading...',
                );
                description = 'Set Category to "$name"';
                break;
            case RuleActionType.setPayee:
                final payeesAsync = ref.watch(payeesProvider);
                final name = payeesAsync.maybeWhen(
                    data: (list) => list.firstWhere((p) => p.id == action.value, orElse: () => Payee(id: '', name: 'Unknown', createdAt: DateTime.now())).name,
                    orElse: () => 'Loading...',
                );
                description = 'Set Payee to "$name"';
                break;
            case RuleActionType.setAccount:
                 final accountsAsync = ref.watch(accountsProvider);
                 final name = accountsAsync.maybeWhen(
                     data: (list) => list.firstWhere((a) => a.id == action.value, orElse: () => Account(id: '', name: 'Unknown', type: AccountType.checking)).name,
                     orElse: () => 'Loading...',
                 );
                 description = 'Set Account to "$name"';
                 break;
            case RuleActionType.setMemo:
                description = 'Set Memo to "${action.value}"';
                break;
            case RuleActionType.markCleared:
                description = 'Mark Cleared: ${action.value == 'true' ? 'Yes' : 'No'}';
                break;
            case RuleActionType.markApproved:
                description = 'Mark Approved: ${action.value == 'true' ? 'Yes' : 'No'}';
                break;
        }

        return Text(description);
    }
}
