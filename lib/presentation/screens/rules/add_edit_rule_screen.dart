import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/services/rule_template_service.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/pickers/account_selector.dart';
import 'package:ledger_zero/presentation/widgets/pickers/category_selector.dart';
import 'package:ledger_zero/presentation/widgets/pickers/payee_selector.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/core/utils/logger.dart';

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
      final rule = await ref
          .read(ruleRepositoryProvider)
          .getRule(widget.ruleId!);
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
    final l10n = AppLocalizations.of(context)!;
    final name = template.kind.title(l10n);
    final rule = template.kind == RuleTemplateKind.keywordCategorization
        ? template.createRule(
            name: name,
            keyword: l10n.ruleTemplateKeywordExample,
          )
        : template.createRule(name: name);
    setState(() {
      _nameController.text = rule.name;
      _matchLogic = rule.matchLogic;
      _conditions = List.from(rule.conditions);
      _actions = List.from(rule.actions);
      _isActive = rule.isActive;
    });
  }

  void _showTemplatesDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ruleChooseTemplate),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: RuleTemplateService.templates.length,
            itemBuilder: (context, index) {
              final template = RuleTemplateService.templates[index];
              return ListTile(
                title: Text(template.kind.title(l10n)),
                subtitle: Text(template.kind.description(l10n)),
                onTap: () {
                  _applyTemplate(template);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (_conditions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.ruleNeedsCondition)));
      return;
    }
    if (_actions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.ruleNeedsAction)));
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
    } catch (e, st) {
      Logger.error('Action failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (widget.ruleId == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ruleDeleteTitle),
        content: Text(l10n.ruleDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(ruleRepositoryProvider).deleteRule(widget.ruleId!);
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ruleId != null ? l10n.ruleEditTitle : l10n.ruleNewTitle,
        ),
        actions: [
          if (widget.ruleId == null)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: l10n.ruleUseTemplate,
              onPressed: _showTemplatesDialog,
            ),
          if (widget.ruleId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: l10n.ruleDeleteTitle,
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _nameController,
              label: l10n.ruleNameLabel,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.ruleActive),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.ruleConditionsHeading,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.ruleMatchLabel),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<RuleMatchLogic>(
                    isExpanded: true,
                    value: _matchLogic,
                    onChanged: (v) => setState(() => _matchLogic = v!),
                    items: RuleMatchLogic.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.label(l10n),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
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
                      Expanded(child: _ConditionDisplay(condition: condition)),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: l10n.delete,
                        onPressed: () =>
                            setState(() => _conditions.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            AppButton.secondary(
              label: l10n.ruleAddCondition,
              onPressed: _showAddConditionDialog,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.ruleActionsHeading,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(child: _ActionDisplay(action: action)),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: l10n.delete,
                        onPressed: () =>
                            setState(() => _actions.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            AppButton.secondary(
              label: l10n.ruleAddAction,
              onPressed: _showAddActionDialog,
            ),
            const SizedBox(height: 32),
            AppButton.primary(label: l10n.ruleSave, onPressed: _save),
          ],
        ),
      ),
    );
  }

  void _showAddConditionDialog() {
    RuleConditionType type = RuleConditionType.description;
    RuleConditionOperator op = RuleConditionOperator.contains;
    final valueController = TextEditingController();
    String? valueError;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.ruleAddCondition),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<RuleConditionType>(
                initialValue: type,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.ruleFieldLabel),
                items: RuleConditionType.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e.label(l10n),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => type = v!),
              ),
              DropdownButtonFormField<RuleConditionOperator>(
                initialValue: op,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.ruleOperatorLabel),
                items: RuleConditionOperator.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e.label(l10n),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => op = v!),
              ),
              if (type == RuleConditionType.payee)
                TextField(
                  controller: valueController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: l10n.pickerSelectPayee,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () {
                    PayeeSelector.show(context, (payee) {
                      valueController.text =
                          payee.name; // Store Name for comparison
                    });
                  },
                )
              else if (type == RuleConditionType.amount)
                TextField(
                  controller: valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    // Compared with the signed amount: -12.50 is an outflow.
                    labelText: l10n.ruleAmountValueLabel,
                    errorText: valueError,
                  ),
                )
              else
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(labelText: l10n.ruleValueLabel),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                if (valueController.text.isEmpty) {
                  return;
                }
                final RuleCondition condition;
                if (type == RuleConditionType.amount) {
                  // Amount conditions store minor units.
                  final minor = ref
                      .read(appFormatterProvider)
                      .parseAmount(valueController.text);
                  if (minor == null) {
                    setDialogState(() => valueError = l10n.invalidAmount);
                    return;
                  }
                  condition = RuleCondition.amount(operator: op, minor: minor);
                } else {
                  condition = RuleCondition(
                    type: type,
                    operator: op,
                    value: valueController.text,
                  );
                }
                setState(() => _conditions.add(condition));
                Navigator.pop(ctx);
              },
              child: Text(l10n.add),
            ),
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
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l10n.ruleAddAction),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<RuleActionType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.ruleActionLabel),
                  items: RuleActionType.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e.label(l10n),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
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
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  if (valueController.text.isNotEmpty) {
                    setState(() {
                      _actions.add(
                        RuleAction(type: type, value: valueController.text),
                      );
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: Text(l10n.add),
              ),
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
    Function(String, String) onUpdate,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final selection = Text(
      displayValue.isEmpty ? l10n.tapToSelect : displayValue,
    );
    if (type == RuleActionType.setCategory) {
      return InkWell(
        onTap: () {
          CategorySelector.show(context, (category) {
            controller.text = category.id;
            onUpdate(category.id, category.name);
          });
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.pickerSelectCategory,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: selection,
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
          decoration: InputDecoration(
            labelText: l10n.pickerSelectPayee,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: selection,
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
          decoration: InputDecoration(
            labelText: l10n.pickerSelectAccount,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: selection,
        ),
      );
    } else if (type == RuleActionType.markCleared ||
        type == RuleActionType.markApproved) {
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? 'true' : controller.text,
        items: [
          DropdownMenuItem(value: 'true', child: Text(l10n.yes)),
          DropdownMenuItem(value: 'false', child: Text(l10n.no)),
        ],
        onChanged: (v) {
          controller.text = v!;
          onUpdate(v, v == 'true' ? l10n.yes : l10n.no);
        },
        decoration: InputDecoration(labelText: l10n.ruleValueLabel),
      );
    } else {
      return TextField(
        controller: controller,
        decoration: InputDecoration(labelText: l10n.ruleValueLabel),
        onChanged: (v) => onUpdate(v, v),
      );
    }
  }
}

class _ConditionDisplay extends ConsumerWidget {
  final RuleCondition condition;

  const _ConditionDisplay({required this.condition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountMinor = condition.amountMinor;
    final valueText = amountMinor != null
        ? ref.watch(appFormatterProvider).formatMoney(amountMinor)
        : condition.value;
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(label: Text(condition.type.label(l10n))),
        Text(condition.operator.label(l10n)),
        Text(valueText, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ActionDisplay extends ConsumerWidget {
  final RuleAction action;

  const _ActionDisplay({required this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    String description = '';

    switch (action.type) {
      case RuleActionType.setCategory:
        final categoriesAsync = ref.watch(categoriesProvider);
        final name = categoriesAsync.maybeWhen(
          data: (list) => list
              .firstWhere(
                (c) => c.id == action.value,
                orElse: () => Category(
                  id: '',
                  name: l10n.unknown,
                  color: 0,
                  icon: '0',
                  createdAt: DateTime.now(),
                ),
              )
              .name,
          orElse: () => l10n.loading,
        );
        description = l10n.ruleActionSummarySetCategory(name);
        break;
      case RuleActionType.setPayee:
        final payeesAsync = ref.watch(payeesProvider);
        final name = payeesAsync.maybeWhen(
          data: (list) => list
              .firstWhere(
                (p) => p.id == action.value,
                orElse: () => Payee(
                  id: '',
                  name: l10n.unknown,
                  createdAt: DateTime.now(),
                ),
              )
              .name,
          orElse: () => l10n.loading,
        );
        description = l10n.ruleActionSummarySetPayee(name);
        break;
      case RuleActionType.setAccount:
        final accountsAsync = ref.watch(accountsProvider);
        final name = accountsAsync.maybeWhen(
          data: (list) => list
              .firstWhere(
                (a) => a.id == action.value,
                orElse: () => Account(
                  id: '',
                  name: l10n.unknown,
                  type: AccountType.checking,
                ),
              )
              .name,
          orElse: () => l10n.loading,
        );
        description = l10n.ruleActionSummarySetAccount(name);
        break;
      case RuleActionType.setMemo:
        description = l10n.ruleActionSummarySetMemo(action.value);
        break;
      case RuleActionType.markCleared:
        description = l10n.ruleActionSummaryFlag(
          action.type.label(l10n),
          action.value == 'true' ? l10n.yes : l10n.no,
        );
        break;
      case RuleActionType.markApproved:
        description = l10n.ruleActionSummaryFlag(
          action.type.label(l10n),
          action.value == 'true' ? l10n.yes : l10n.no,
        );
        break;
    }

    return Text(description);
  }
}
