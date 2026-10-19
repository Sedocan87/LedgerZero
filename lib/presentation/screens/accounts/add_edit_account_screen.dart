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
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/form_utils.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/widgets/leave_budget_dialog.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/salary_prompt.dart';
import 'package:ledger_zero/presentation/screens/settings/income/income_settings_screen.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/core/utils/logger.dart';

/// Remembers that the "outside the budget" hint after creating an account
/// was shown.
const offBudgetAccountHintKey = 'hint_offbudget_account_seen';

class AddEditAccountScreen extends ConsumerStatefulWidget {
  final String? accountId;

  /// Opened right after onboarding: explains why an account comes first and
  /// continues to the budget once it is saved.
  final bool firstAccount;

  /// The last onboarding step: saving marks onboarding done (which rebuilds
  /// the router) before opening the budget. Implies [firstAccount].
  final bool finishesOnboarding;

  const AddEditAccountScreen({
    super.key,
    this.accountId,
    this.firstAccount = false,
    this.finishesOnboarding = false,
  }) : assert(!finishesOnboarding || firstAccount);

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
  bool _personal = false;

  /// An existing shared account that already synced cannot become personal
  /// (the partner's phone has its transactions).
  bool _personalLocked = false;

  bool _isLoading = false;
  Account? _existingAccount;
  bool _isFormDirty = false;

  /// Whether another open account is in the budget (read in `build`). The
  /// first on-budget account sets the budget currency; every later one
  /// uses it.
  bool _otherOnBudgetExists = false;

  /// This account sets the budget currency: it is in the budget and no
  /// other open account is.
  bool get _setsBudgetCurrency => _onBudget && !_otherOnBudgetExists;

  /// The currency is fixed to the budget currency.
  bool get _currencyLocked => _onBudget && _otherOnBudgetExists;

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
      'personal': _personal,
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
          if (data['personal'] == true) {
            _personal = true;
            _onBudget = false;
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
      final locked =
          account != null &&
          !account.isPersonal &&
          await repository.wasSynced(account.id);

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
          _personal = account.isPersonal;
          _personalLocked = locked;
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

  /// Asks before an existing account moves into the budget: it changes To
  /// Be Budgeted in every month (leaving it: [showLeaveBudgetDialog]).
  Future<bool> _confirmBudgetChange() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountOnBudgetChangeTitle),
        content: Text(l10n.accountOnBudgetChangeOn),
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

  /// Asks before a personal account becomes shared: its transactions then
  /// sync to the partner, and it cannot become personal again.
  Future<bool> _confirmShare() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountShareTitle),
        content: Text(l10n.accountShareBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.accountShareAction),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// After the first account: asks for the salary (unless recurring income
  /// already exists) and opens its form. "Skip" also retires the salary
  /// card on the budget screen.
  Future<void> _offerSalary() async {
    try {
      final schedules = await ref
          .read(scheduledTransactionRepositoryProvider)
          .getAllScheduledTransactions();
      if (schedules.any((s) => (s.amount ?? 0) > 0 && !s.isFinished)) {
        return;
      }
    } catch (e, st) {
      Logger.error('Loading recurring income failed', e, st);
      return;
    }
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final add = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('firstAccount.salaryQuestion'),
        icon: const Icon(Icons.payments_outlined),
        title: Text(l10n.firstAccountSalaryTitle),
        content: Text(l10n.salaryPromptBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.skip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.budgetIncomeAddButton),
          ),
        ],
      ),
    );
    if (add == false) {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(SalaryPrompt.handledKey, true);
    } else if (add == true && mounted) {
      await showAddIncomeSheet(context);
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      FormUtils.focusFirstError(context);
      return;
    }
    if (_existingAccount != null &&
        _existingAccount!.isPersonal &&
        !_personal &&
        !await _confirmShare()) {
      return;
    }
    if (!mounted) {
      return;
    }
    // Leaving the budget can release money budgeted for this account.
    var release = const <String, int>{};
    if (_existingAccount != null && _existingAccount!.onBudget != _onBudget) {
      if (_onBudget) {
        if (!await _confirmBudgetChange()) {
          return;
        }
      } else {
        final chosen = await showLeaveBudgetDialog(
          context,
          ref,
          _existingAccount!.id,
        );
        if (chosen == null) {
          return;
        }
        release = chosen;
      }
    }

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(accountRepositoryProvider);
      final isEditing = widget.accountId != null;
      var released = 0;

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
          owner: _personal ? AccountOwner.me : AccountOwner.shared,
          color: _selectedColor,
          icon: _selectedIcon,
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.updateAccount(updatedAccount);
        final month = CalendarDate.startOfMonthUtc(CalendarDate.today());
        final budgeting = ref.read(budgetingServiceProvider);
        for (final MapEntry(key: categoryId, value: amount)
            in release.entries) {
          released += await budgeting.releaseFromCategory(
            categoryId,
            amount,
            month,
          );
        }
      } else {
        final newAccount = Account(
          id: const Uuid().v4(),
          name: name,
          type: _selectedType,
          currency: _selectedCurrency,
          startingBalance: startingBalance,
          onBudget: _onBudget,
          owner: _personal ? AccountOwner.me : AccountOwner.shared,
          color: _selectedColor,
          icon: _selectedIcon,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.createAccount(newAccount);
        await _clearDraft();
      }
      // The budget's account decides the budget currency (Settings).
      if (_setsBudgetCurrency &&
          _selectedCurrency != ref.read(settingsProvider).currency) {
        await ref
            .read(settingsProvider.notifier)
            .setCurrency(_selectedCurrency);
      }

      if (mounted) {
        // Clear dirty flag so we can pop
        setState(() => _isFormDirty = false);
        final messenger = ScaffoldMessenger.of(context);
        final rootNavigator = Navigator.of(context, rootNavigator: true);
        final l10n = AppLocalizations.of(context)!;
        if (widget.firstAccount) {
          // Saved: no spinner behind the question.
          setState(() => _isLoading = false);
          await _offerSalary();
          if (!mounted) {
            return;
          }
          // The starting balance is now To Be Budgeted: assign it.
          if (widget.finishesOnboarding) {
            // Finishing onboarding rebuilds the router (it follows the
            // auth state); navigate once the new one is in place.
            ref.read(authProvider.notifier).setOnboarded(true);
            final router = ref.read(routerProvider);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => router.go('/budget'),
            );
          } else {
            context.go('/budget');
          }
        } else {
          Navigator.of(context).pop();
        }
        // The first account outside the budget: how to save into it.
        final prefs = ref.read(sharedPreferencesProvider);
        if (!isEditing &&
            !_onBudget &&
            !(prefs.getBool(offBudgetAccountHintKey) ?? false)) {
          await prefs.setBool(offBudgetAccountHintKey, true);
          final helpContext = rootNavigator.context;
          messenger.showSnackBar(
            SnackBar(
              key: const Key('hint.offBudgetAccount'),
              content: Text(l10n.hintOffBudgetAccount),
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: l10n.helpShowMe,
                onPressed: () {
                  if (helpContext.mounted) {
                    showHelpSheet(helpContext, HelpTopic.saving);
                  }
                },
              ),
            ),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              released > 0
                  ? l10n.accountReleased(
                      ref.read(appFormatterProvider).formatMoney(released),
                    )
                  : isEditing
                  ? l10n.accountUpdated
                  : l10n.accountCreated,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AccountSharedException catch (e, st) {
      Logger.warning('Account cannot become personal', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.accountPersonalSynced),
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

  /// A switch title followed by its ⓘ button.
  Widget _titleWithInfo(String title, HelpTopic topic) => Row(
    children: [
      Flexible(child: Text(title)),
      InfoButton(topic),
    ],
  );

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
    final budgetCurrency = ref.watch(
      settingsProvider.select((s) => s.currency),
    );
    _otherOnBudgetExists =
        ref
            .watch(accountsProvider)
            .valueOrNull
            ?.any(
              (a) => a.onBudget && !a.isClosed && a.id != widget.accountId,
            ) ??
        false;
    // Locked: only the budget currency (plus the account's own one when an
    // older account differs, so it can be corrected).
    final currencies = _currencyLocked
        ? [
            budgetCurrency,
            if (_selectedCurrency != budgetCurrency) _selectedCurrency,
          ]
        : _currencies;

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

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<AccountType>(
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
                                    setState(() {
                                      _selectedType = value;
                                      // A new savings or investment account
                                      // starts outside the budget (net worth
                                      // only); the switch below can change it.
                                      // Not for the first account: its balance
                                      // is meant to be budgeted.
                                      if (widget.accountId == null &&
                                          !widget.firstAccount &&
                                          !_personal) {
                                        _onBudget = !value.startsOffBudget;
                                      }
                                    });
                                    _onFieldChange();
                                  }
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: InfoButton(HelpTopic.accountTypes),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        SwitchListTile(
                          key: const Key('account.onBudget'),
                          contentPadding: EdgeInsets.zero,
                          title: _titleWithInfo(
                            l10n.accountOnBudgetLabel,
                            HelpTopic.onBudget,
                          ),
                          subtitle: Text(
                            _personal
                                ? l10n.accountOnBudgetPersonal
                                : l10n.accountOnBudgetHelper,
                          ),
                          value: _onBudget,
                          onChanged: _personal
                              ? null
                              : (value) {
                                  setState(() {
                                    _onBudget = value;
                                    if (value && _otherOnBudgetExists) {
                                      _selectedCurrency = budgetCurrency;
                                    }
                                  });
                                  _onFieldChange();
                                },
                        ),
                        // The first account is the budget's own account.
                        if (!widget.firstAccount)
                          SwitchListTile(
                            key: const Key('account.personal'),
                            contentPadding: EdgeInsets.zero,
                            title: _titleWithInfo(
                              l10n.accountPersonalLabel,
                              HelpTopic.personal,
                            ),
                            subtitle: Text(
                              _personalLocked
                                  ? l10n.accountPersonalSynced
                                  : l10n.accountPersonalHelper,
                            ),
                            value: _personal,
                            onChanged: _personalLocked
                                ? null
                                : (value) {
                                    setState(() {
                                      _personal = value;
                                      // Personal accounts are off-budget;
                                      // back to shared, a new account gets
                                      // its type's default again.
                                      if (value) {
                                        _onBudget = false;
                                      } else if (_existingAccount == null) {
                                        _onBudget =
                                            !_selectedType.startsOffBudget;
                                      }
                                    });
                                    _onFieldChange();
                                  },
                          ),
                        const SizedBox(height: AppSpacing.sm),

                        AppTextField(
                          label: l10n.startingBalanceLabel,
                          hint: fmt.formatAmountForInput(0),
                          helperText: l10n.startingBalanceHelper,
                          controller: _balanceController,
                          focusNode: _balanceFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _onFieldChange(),
                          onFieldSubmitted: (_) => _saveAccount(),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (fmt.parseAmount(value) == null) {
                                return l10n.invalidNumber;
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // The first on-budget account sets the budget
                        // currency; later on-budget accounts are fixed to
                        // it; off-budget accounts may use any currency.
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'currency-$_selectedCurrency-$_currencyLocked',
                          ),
                          initialValue: _selectedCurrency,
                          decoration: InputDecoration(
                            labelText: _setsBudgetCurrency
                                ? l10n.budgetCurrencyLabel
                                : l10n.currency,
                            helperText: _setsBudgetCurrency
                                ? l10n.budgetCurrencyHelper
                                : _currencyLocked
                                ? l10n.accountCurrencyLockedHelper(
                                    budgetCurrency,
                                  )
                                : null,
                            helperMaxLines: 3,
                          ),
                          items: currencies.map((currency) {
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
