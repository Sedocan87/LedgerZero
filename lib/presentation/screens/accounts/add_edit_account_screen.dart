import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/common/buttons.dart';
import 'package:uuid/uuid.dart';

class AddEditAccountScreen extends ConsumerStatefulWidget {
  final String? accountId;

  const AddEditAccountScreen({super.key, this.accountId});

  @override
  ConsumerState<AddEditAccountScreen> createState() => _AddEditAccountScreenState();
}

class _AddEditAccountScreenState extends ConsumerState<AddEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  final _nameFocus = FocusNode();
  final _balanceFocus = FocusNode();

  AccountType _selectedType = AccountType.checking;
  String _selectedCurrency = 'USD';
  int _selectedColor = 0xFF4CAF50; // Default Green
  String _selectedIcon = 'Wallet';

  bool _isLoading = false;
  double _initialStartingBalance = 0.0;
  Account? _existingAccount;
  bool _isFormDirty = false;

  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY'];

  final List<Color> _colors = const [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
    Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
    Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
    Colors.brown, Colors.grey, Colors.blueGrey,
  ];

  final Map<String, IconData> _icons = const {
    'Wallet': Icons.account_balance_wallet,
    'Bank': Icons.account_balance,
    'Card': Icons.credit_card,
    'Cash': Icons.attach_money,
    'Savings': Icons.savings,
    'Investment': Icons.trending_up,
  };

  @override
  void initState() {
    super.initState();
    if (widget.accountId != null) {
      _loadAccount(widget.accountId!);
    } else {
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
           _isFormDirty = true;
         });

         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Draft restored')),
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
        _balanceController.text = account.startingBalance.toString();
        _initialStartingBalance = account.startingBalance;

        setState(() {
          _selectedType = account.type;
          _selectedCurrency = account.currency;
          _selectedColor = account.color ?? 0xFF4CAF50;
          _selectedIcon = account.icon ?? 'Wallet';
          _isFormDirty = false;
        });
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading account: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(accountRepositoryProvider);
      final isEditing = widget.accountId != null;

      final name = _nameController.text.trim();
      final startingBalance = double.tryParse(_balanceController.text) ?? 0.0;

      if (isEditing && _existingAccount != null) {
        final balanceDiff = startingBalance - _initialStartingBalance;
        final newCurrentBalance = _existingAccount!.currentBalance + balanceDiff;

        final updatedAccount = _existingAccount!.copyWith(
          name: name,
          type: _selectedType,
          currency: _selectedCurrency,
          startingBalance: startingBalance,
          currentBalance: newCurrentBalance,
          color: _selectedColor,
          icon: _selectedIcon,
          updatedAt: DateTime.now(),
        );
        await repository.updateAccount(updatedAccount);
      } else {
        final newAccount = Account(
          id: const Uuid().v4(),
          name: name,
          type: _selectedType,
          currency: _selectedCurrency,
          startingBalance: startingBalance,
          currentBalance: startingBalance,
          color: _selectedColor,
          icon: _selectedIcon,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.createAccount(newAccount);
        await _clearDraft();
      }

      if (mounted) {
        // Clear dirty flag so we can pop
        setState(() => _isFormDirty = false);
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Account updated' : 'Account created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error saving account: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ?? false;
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
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveAccount,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _saveAccount,
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? 'Edit Account' : 'Add Account'),
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
                        AppTextField(
                          label: 'Account Name',
                          hint: 'e.g. Chase Checking',
                          helperText: 'Enter a descriptive name for this account',
                          controller: _nameController,
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _onFieldChange(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an account name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        DropdownButtonFormField<AccountType>(
                          // ignore: deprecated_member_use
                          value: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Account Type',
                            helperText: 'Select the type of account',
                          ),
                          items: AccountType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.name.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedType = value);
                              _onFieldChange();
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                label: 'Starting Balance',
                                hint: '0.00',
                                helperText: 'Current balance of the account',
                                controller: _balanceController,
                                focusNode: _balanceFocus,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => _onFieldChange(),
                                onFieldSubmitted: (_) => _saveAccount(),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid number';
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
                                // ignore: deprecated_member_use
                                value: _selectedCurrency,
                                decoration: const InputDecoration(labelText: 'Currency'),
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

                        Text('Color', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _colors.asMap().entries.map((entry) {
                            final index = entry.key;
                            final color = entry.value;
                            // ignore: deprecated_member_use
                            final isSelected = _selectedColor == color.value;
                            return Semantics(
                              label: 'Color option ${index + 1}',
                              selected: isSelected,
                              button: true,
                              child: GestureDetector(
                                onTap: () {
                                  // ignore: deprecated_member_use
                                  setState(() => _selectedColor = color.value);
                                  _onFieldChange();
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                                    boxShadow: isSelected ? [const BoxShadow(blurRadius: 5, color: Colors.black26)] : null,
                                  ),
                                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Text('Icon', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _icons.entries.map((entry) {
                            final isSelected = _selectedIcon == entry.key;
                            return ChoiceChip(
                              label: Icon(entry.value, semanticLabel: entry.key),
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
                          label: isEditing ? 'Save Changes' : 'Create Account',
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
