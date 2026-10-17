import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/form_utils.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class AddEditAccountScreen extends ConsumerStatefulWidget {
  final String? accountId;

  /// Opened right after onboarding: explains why an account comes first and
  /// continues to the budget once it is saved.
  final bool firstAccount;

  const AddEditAccountScreen({
    super.key,
    this.accountId,
    this.firstAccount = false,
  });

  @override
  ConsumerState<AddEditAccountScreen> createState() =>
      _AddEditAccountScreenState();
}

class _AddEditAccountScreenState extends ConsumerState<AddEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  final _nameFocus = FocusNode();
  final _balanceFocus = FocusNode();

  AccountType _selectedType = AccountType.checking;
  String _selectedCurrency = defaultCurrencyCode;
  int _selectedColor = 0xFF4CAF50; // Default Green
  String _selectedIcon = 'Wallet';
  bool _onBudget = true;

  bool _isLoading = false;
  Account? _existingAccount;
  bool _isFormDirty = false;

  /// The supported currencies, plus the selected one if it is not supported
  /// (e.g. an existing account created with another currency).
  List<String> get _currencies => [
    ...supportedCurrencyCodes,
    if (!supportedCurrencyCodes.contains(_selectedCurrency)) _selectedCurrency,
  ];

  final List<Color> _colors = const [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  final Map<String, IconData> _icons = const {
    'Wallet': Icons.account_balance_wallet,
    'Bank': Icons.account_balance,
    'Card': Icons.credit_card,
    'Cash': Icons.attach_money,
    'Savings': Icons.savings,
    'Investment': Icons.trending_up,
  };

  /// Screen reader names of the icon keys in [_icons] (the keys are stored).
  String _iconLabel(AppLocalizations l10n, String key) => switch (key) {
    'Wallet' => l10n.accountIconWallet,
    'Bank' => l10n.accountIconBank,
    'Card' => l10n.accountIconCard,
    'Cash' => l10n.accountIconCash,
    'Savings' => l10n.accountIconSavings,
    'Investment' => l10n.accountIconInvestment,
    _ => key,
  };

  @override
  void initState() {
    super.initState();
    if (widget.accountId != null) {
      _loadAccount(widget.accountId!);
    } else {
      // New accounts default to the currency chosen in Settings.
      _selectedCurrency = ref.read(appFormatterProvider).currency;
      // Restore draft if in Add mode
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
    }
  }

  void _onFieldChange() {
    if (!_isFormDirty) {
      setState(() => _isFormDirty = true);
    }
    if (widget.accountId == null) {
      _saveDraft();
    }
  }

  Future<void> _saveDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final data = {
      'name': _nameController.text,
      'type': _selectedType.index,
      'balance': _balanceController.text,
      'currency': _selectedCurrency,
      'color': _selectedColor,
      'icon': _selectedIcon,
      'onBudget': _onBudget,
    };
    await prefs.setString('draft_account_add', jsonEncode(data));
  }

  Future<void> _restoreDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final draft = prefs.getString('draft_account_add');
    if (draft != null) {
      try {
        final data = jsonDecode(draft) as Map<String, dynamic>;
        if (data['name'] != null) {
          _nameController.text = data['name'];
        }
        if (data['balance'] != null) {
          _balanceController.text = data['balance'];
        }

        setState(() {
          if (data['type'] != null) {
            _selectedType = AccountType.values[data['type']];
          }
          if (data['currency'] != null) {
            _selectedCurrency = data['currency'];
          }
          if (data['color'] != null) {
            _selectedColor = data['color'];
          }
          if (data['icon'] != null) {
            _selectedIcon = data['icon'];
          }
          if (data['onBudget'] is bool) {
            _onBudget = data['onBudget'];
          }
          _isFormDirty = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.draftRestored),
            ),
          );
        }
      } catch (e) {
        // Ignore corrupt draft
      }
    }
  }

  Future<void> _clearDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('draft_account_add');
  }

  Future<void> _loadAccount(String id) async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(accountRepositoryProvider);
      final account = await repository.getAccountById(id);

      if (mounted && account != null) {
        _existingAccount = account;
        _nameController.text = account.name;
        _balanceController.text = ref
            .read(appFormatterProvider)
            .formatAmountForInput(account.startingBalance);

        setState(() {
          _selectedType = account.type;
          _selectedCurrency = account.currency;
          _selectedColor = account.color ?? 0xFF4CAF50;
          _selectedIcon = account.icon ?? 'Wallet';
          _onBudget = account.onBudget;
          _isFormDirty = false;
        });
      }
    } catch (e, st) {
      Logger.error('Action failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Asks before an existing account moves into or out of the budget: it
  /// changes To Be Budgeted in every month.
  Future<bool> _confirmBudgetChange() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountOnBudgetChangeTitle),
        content: Text(
          _onBudget
              ? l10n.accountOnBudgetChangeOn
              : l10n.accountOnBudgetChangeOff,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      FormUtils.focusFirstError(context);
      return;
    }
    if (_existingAccount != null &&
        _existingAccount!.onBudget != _onBudget &&
        !await _confirmBudgetChange()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(accountRepositoryProvider);
      final isEditing = widget.accountId != null;

      final name = _nameController.text.trim();
      final startingBalance =
          ref.read(appFormatterProvider).parseAmount(_balanceController.text) ??
          0;

      // The current balance is computed by the repository from the starting
      // balance and the transactions, so only the starting balance is saved.
      if (isEditing && _existingAccount != null) {
        final updatedAccount = _existingAccount!.copyWith(
          name: name,
          type: _selectedType,
          currency: _selectedCurrency,
          startingBalance: startingBalance,
          onBudget: _onBudget,
          color: _selectedColor,
          icon: _selectedIcon,
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.updateAccount(updatedAccount);
      } else {
        final newAccount = Account(
          id: const Uuid().v4(),
          name: name,
          type: _selectedType,
          currency: _selectedCurrency,
          startingBalance: startingBalance,
          onBudget: _onBudget,
          color: _selectedColor,
          icon: _selectedIcon,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.createAccount(newAccount);
        await _clearDraft();
      }

      if (mounted) {
        // Clear dirty flag so we can pop
        setState(() => _isFormDirty = false);
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context)!;
        if (widget.firstAccount) {
          // The starting balance is now To Be Budgeted: assign it.
          context.go('/budget');
        } else {
          Navigator.of(context).pop();
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? l10n.accountUpdated : l10n.accountCreated,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      Logger.error('Action failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showExitConfirmation() async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.unsavedChangesTitle),
            content: Text(l10n.unsavedChangesMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.discard),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _nameFocus.dispose();
    _balanceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.accountId != null;
    final fmt = ref.watch(appFormatterProvider);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_isFormDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          setState(() => _isFormDirty = false);
          Navigator.of(context).pop();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _saveAccount,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              _saveAccount,
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? l10n.editAccount : l10n.addAccount),
          ),
          body: _isLoading && _existingAccount == null && isEditing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.firstAccount) ...[
                          Card(
                            key: const Key('firstAccount.explanation'),
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.firstAccountTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSecondaryContainer,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    l10n.firstAccountExplanation,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        AppTextField(
                          label: l10n.accountNameLabel,
                          hint: l10n.accountNameHint,
                          helperText: l10n.accountNameHelper,
                          controller: _nameController,
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _onFieldChange(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.accountNameRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        DropdownButtonFormField<AccountType>(
                          // Rebuilt when the value is set from outside
                          // (loading the account being edited).
                          key: ValueKey(_selectedType),
                          initialValue: _selectedType,
                          decoration: InputDecoration(
                            labelText: l10n.accountTypeLabel,
                            helperText: l10n.accountTypeHelper,
                          ),
                          items: AccountType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.label(l10n)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedType = value);
                              _onFieldChange();
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        SwitchListTile(
                          key: const Key('account.onBudget'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.accountOnBudgetLabel),
                          subtitle: Text(l10n.accountOnBudgetHelper),
                          value: _onBudget,
                          onChanged: (value) {
                            setState(() => _onBudget = value);
                            _onFieldChange();
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                label: l10n.startingBalanceLabel,
                                hint: fmt.formatAmountForInput(0),
                                helperText: l10n.startingBalanceHelper,
                                controller: _balanceController,
                                focusNode: _balanceFocus,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => _onFieldChange(),
                                onFieldSubmitted: (_) => _saveAccount(),
                                validator: (value) {
                                  if (value != null &&
                                      value.trim().isNotEmpty) {
                                    if (fmt.parseAmount(value) == null) {
                                      return l10n.invalidNumber;
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_selectedCurrency),
                                initialValue: _selectedCurrency,
                                decoration: InputDecoration(
                                  labelText: l10n.currency,
                                ),
                                items: _currencies.map((currency) {
                                  return DropdownMenuItem(
                                    value: currency,
                                    child: Text(currency),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedCurrency = value);
                                    _onFieldChange();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Text(
                          l10n.color,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _colors.asMap().entries.map((entry) {
                            final index = entry.key;
                            final color = entry.value;
                            final isSelected =
                                _selectedColor == color.toARGB32();
                            return Semantics(
                              label: l10n.colorOption(index + 1),
                              selected: isSelected,
                              button: true,
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _selectedColor = color.toARGB32(),
                                  );
                                  _onFieldChange();
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            const BoxShadow(
                                              blurRadius: 5,
                                              color: Colors.black26,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Text(
                          l10n.icon,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _icons.entries.map((entry) {
                            final isSelected = _selectedIcon == entry.key;
                            return ChoiceChip(
                              label: Icon(
                                entry.value,
                                semanticLabel: _iconLabel(l10n, entry.key),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedIcon = entry.key);
                                  _onFieldChange();
                                }
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        AppButton.primary(
                          label: isEditing
                              ? l10n.saveChanges
                              : l10n.createAccount,
                          isLoading: _isLoading,
                          onPressed: _saveAccount,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
