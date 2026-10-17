import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/picker_field.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/recurrence/recurrence_selector.dart';
import 'package:uuid/uuid.dart';

/// Colour of inflow amounts on this screen.
const _incomeColor = Colors.green;

/// Lists every recurring inflow (scheduled transactions with a positive
/// amount), whether it goes to Ready to Assign or to a category.
class IncomeSettingsScreen extends ConsumerWidget {
  const IncomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledTransactionsAsync = ref.watch(scheduledTransactionsProvider);
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final accountCurrencies = {
      for (final a
          in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        a.id: a.currency,
    };
    final payeeNames = {
      for (final p in ref.watch(payeesProvider).valueOrNull ?? const <Payee>[])
        p.id: p.name,
    };
    final categoryNames = {
      for (final c
          in ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
        c.id: c.name,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.incomeAndSalaries)),
      body: scheduledTransactionsAsync.when(
        data: (transactions) {
          final incomeTransactions = transactions
              .where((t) => (t.amount ?? 0) > 0)
              .toList();

          if (incomeTransactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.incomeEmpty,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => showAddIncomeSheet(context),
                    child: Text(l10n.incomeAddTitle),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: incomeTransactions.length,
            itemBuilder: (context, index) {
              final transaction = incomeTransactions[index];
              final payeeName =
                  payeeNames[transaction.payeeId] ?? l10n.incomeUnknownSource;
              final categoryName = categoryNames[transaction.categoryId];
              final recurrence = _formatRecurrence(transaction, fmt, l10n);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _incomeColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.arrow_downward, color: _incomeColor),
                ),
                title: Text(payeeName),
                subtitle: Text(
                  categoryName == null
                      ? recurrence
                      : '$categoryName · $recurrence',
                ),
                trailing: Text(
                  fmt.formatMoney(
                    transaction.amount ?? 0,
                    currencyCode: accountCurrencies[transaction.accountId],
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _incomeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () =>
                    showAddIncomeSheet(context, transaction: transaction),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          Logger.error('Failed to load recurring income', err, stack);
          return Center(child: Text(l10n.errorOccurred));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'income-settings-fab',
        onPressed: () => showAddIncomeSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.incomeAddButton),
      ),
    );
  }

  String _formatRecurrence(
    ScheduledTransaction t,
    AppFormatter fmt,
    AppLocalizations l10n,
  ) {
    final frequency = t.frequency ?? RecurrenceFrequency.monthly;
    final interval = t.interval ?? 1;
    final String every;
    if (interval <= 1) {
      every = switch (frequency) {
        RecurrenceFrequency.daily => l10n.daily,
        RecurrenceFrequency.weekly => l10n.weekly,
        RecurrenceFrequency.monthly => l10n.monthly,
        RecurrenceFrequency.yearly => l10n.yearly,
      };
    } else {
      final unit = switch (frequency) {
        RecurrenceFrequency.daily => l10n.unitDays(interval),
        RecurrenceFrequency.weekly => l10n.unitWeeks(interval),
        RecurrenceFrequency.monthly => l10n.unitMonths(interval),
        RecurrenceFrequency.yearly => l10n.unitYears(interval),
      };
      every = l10n.recurrenceEvery(interval, unit);
    }
    final next = t.nextDate;
    if (next == null) {
      return every;
    }
    return '$every · ${l10n.labelValue(l10n.nextDate, fmt.formatDate(next))}';
  }
}

/// Opens the form for a new recurring income (or for editing [transaction])
/// as a bottom sheet. Completes when the sheet is closed.
Future<void> showAddIncomeSheet(
  BuildContext context, {
  ScheduledTransaction? transaction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => AddIncomeSheet(
        transaction: transaction,
        scrollController: scrollController,
      ),
    ),
  );
}

class AddIncomeSheet extends ConsumerStatefulWidget {
  final ScheduledTransaction? transaction;
  final ScrollController scrollController;

  const AddIncomeSheet({
    super.key,
    this.transaction,
    required this.scrollController,
  });

  @override
  ConsumerState<AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends ConsumerState<AddIncomeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedAccountId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;

  /// Next occurrence (calendar day, UTC midnight).
  DateTime _nextDate = CalendarDate.today();
  int _interval = 1;
  DateTime? _endDate;
  int? _occurrenceCount;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.transaction;
    if (existing != null) {
      _amountController.text = ref
          .read(appFormatterProvider)
          .formatAmountForInput(existing.amount ?? 0);
      _frequency = existing.frequency ?? RecurrenceFrequency.monthly;
      _nextDate = existing.nextDate != null
          ? CalendarDate.normalize(existing.nextDate!)
          : CalendarDate.today();
      _selectedAccountId = existing.accountId;
      _interval = existing.interval ?? 1;
      _endDate = existing.endDate;
      _occurrenceCount = existing.occurrenceCount;
    }
    _loadDefaults();
  }

  /// Fills the source name of an existing schedule and preselects the first
  /// open account for a new one.
  Future<void> _loadDefaults() async {
    try {
      final payeeId = widget.transaction?.payeeId;
      if (payeeId != null) {
        final payee = await ref
            .read(payeeRepositoryProvider)
            .getPayeeById(payeeId);
        if (mounted && payee != null && _nameController.text.isEmpty) {
          _nameController.text = payee.name;
        }
      }
      if (_selectedAccountId == null) {
        final accounts = await ref
            .read(accountRepositoryProvider)
            .getAllAccounts();
        final first = accounts
            .where((a) => !a.isClosed && !a.isPartners)
            .firstOrNull;
        if (mounted && first != null && _selectedAccountId == null) {
          setState(() => _selectedAccountId = first.id);
        }
      }
    } catch (e, stack) {
      Logger.error('Failed to load income defaults', e, stack);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payeeRepo = ref.read(payeeRepositoryProvider);
      final amount = ref
          .read(appFormatterProvider)
          .parseAmount(_amountController.text);

      // Link to an existing payee with the same name, else create one.
      final name = _nameController.text.trim();
      final existingPayees = await payeeRepo.getAllPayees();
      final match = existingPayees
          .where((p) => p.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      final String payeeId;
      if (match != null) {
        payeeId = match.id;
      } else {
        payeeId = const Uuid().v4();
        await payeeRepo.createPayee(
          Payee(id: payeeId, name: name, createdAt: DateTime.now().toUtc()),
        );
      }

      final existing = widget.transaction;
      final t = ScheduledTransaction(
        id: existing?.id ?? const Uuid().v4(),
        accountId: _selectedAccountId,
        payeeId: payeeId,
        // New income goes to Ready to Assign; an edited schedule keeps its
        // category.
        categoryId: existing?.categoryId,
        amount: amount,
        frequency: _frequency,
        interval: _interval,
        occurrenceCount: _occurrenceCount,
        nextDate: _nextDate,
        endDate: _endDate,
        // Salaries are usually wanted without manual approval.
        autoApprove: existing?.autoApprove ?? true,
        memo: existing?.memo,
        anchorDay: existing?.anchorDay ?? _nextDate.day,
        createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
      );

      // Validates the amount, stores the schedule and its reminder.
      await ref
          .read(scheduledTransactionServiceProvider)
          .saveScheduledTransaction(t, isNew: existing == null);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      Logger.error('Failed to save recurring income', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.incomeSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountNames = {
      for (final a
          in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        a.id: a.name,
    };
    final fmt = ref.watch(appFormatterProvider);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.transaction == null
                    ? l10n.incomeAddTitle
                    : l10n.incomeEditTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: l10n.cancel,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _nameController,
                label: l10n.incomeSourceName,
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.incomeNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _amountController,
                label: l10n.amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final amount = fmt.parseAmount(v);
                  return amount == null || amount <= 0
                      ? l10n.invalidAmount
                      : null;
                },
              ),
              const SizedBox(height: 16),
              PickerField(
                label: l10n.incomeDepositAccount,
                text: accountNames[_selectedAccountId] ?? '',
                validator: (_) =>
                    _selectedAccountId == null ? l10n.selectAccount : null,
                onTap: () async {
                  final picked = await showAccountPicker(context);
                  if (picked != null && mounted) {
                    setState(() => _selectedAccountId = picked.id);
                  }
                },
              ),
              const SizedBox(height: 16),
              RecurrenceSelector(
                frequency: _frequency,
                interval: _interval,
                occurrenceCount: _occurrenceCount,
                endDate: _endDate,
                nextDate: _nextDate,
                onFrequencyChanged: (v) => setState(() => _frequency = v),
                onIntervalChanged: (v) => setState(() => _interval = v),
                onEndDateChanged: (v) => setState(() => _endDate = v),
                onOccurrenceCountChanged: (v) =>
                    setState(() => _occurrenceCount = v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: l10n.incomeSaveButton,
                  onPressed: _isLoading ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
