import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/recurrence/recurrence_selector.dart';
import 'package:uuid/uuid.dart';

class IncomeSettingsScreen extends ConsumerWidget {
  const IncomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledTransactionsAsync = ref.watch(scheduledTransactionsProvider);
    final payeeMapAsync = ref.watch(payeeMapProvider);
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.incomeAndSalaries)),
      body: scheduledTransactionsAsync.when(
        data: (transactions) {
          // Filter for Income: Amount > 0 and (Category is NULL)
          // Assumption: Recurring income usually doesn't have a category (goes to TBB)
          // or we can allow users to select "Inflow" categories later.
          // For now, strict filter for Null Category + Positive Amount to capture "TBB" income.
          final incomeTransactions = transactions.where((t) {
            final isPositive = (t.amount ?? 0) > 0;
            final isUncategorized = t.categoryId == null;
            return isPositive && isUncategorized;
          }).toList();

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
                    'No recurring income set up',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showAddIncomeSheet(context, ref),
                    child: const Text('Add Salary / Income'),
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
                  payeeMapAsync.value?[transaction.payeeId] ?? 'Unknown Source';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  child: const Icon(Icons.arrow_downward, color: Colors.green),
                ),
                title: Text(payeeName),
                subtitle: Text(_formatRecurrence(transaction, l10n)),
                trailing: Text(
                  NumberFormat.simpleCurrency(
                    name: currency,
                  ).format(transaction.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  // For now, just allow deleting or basic editing?
                  // Linking to full edit might be safer:
                  // context.pushNamed('edit-scheduled-transaction', pathParameters: {'id': transaction.id});
                  // Or show our simplified sheet for editing.
                  _showAddIncomeSheet(context, ref, transaction: transaction);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIncomeSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Income'),
      ),
    );
  }

  String _formatRecurrence(ScheduledTransaction t, AppLocalizations l10n) {
    // Simple formatter, can be improved
    final freq = t.frequency?.name ?? 'Unknown';
    return '$freq - Next: ${DateFormat.MMMd().format(t.nextDate ?? DateTime.now())}';
  }

  void _showAddIncomeSheet(
    BuildContext context,
    WidgetRef ref, {
    ScheduledTransaction? transaction,
  }) {
    showModalBottomSheet(
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
  late TextEditingController _nameController;
  late TextEditingController _amountController;

  String? _selectedAccountId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _nextDate = DateTime.now();
  int _interval = 1;
  DateTime? _endDate;
  int? _occurrenceCount;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();

    // Initialize if editing
    if (widget.transaction != null) {
      _amountController.text = (widget.transaction!.amount ?? 0).toString();
      _frequency = widget.transaction!.frequency ?? RecurrenceFrequency.monthly;
      _nextDate = widget.transaction!.nextDate ?? DateTime.now();
      _selectedAccountId = widget.transaction!.accountId;
      _interval = widget.transaction!.interval ?? 1;
      _endDate = widget.transaction!.endDate;
      _occurrenceCount = widget.transaction!.occurrenceCount;
    }
  }

  // ... (didChangeDependencies logic stays same if valid, but let's just replace the build block mostly)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.transaction != null && _nameController.text.isEmpty) {
      final payeeMap = ref.read(payeeMapProvider).value;
      if (payeeMap != null && widget.transaction!.payeeId != null) {
        _nameController.text = payeeMap[widget.transaction!.payeeId!] ?? '';
      }
    }

    if (_selectedAccountId == null) {
      final accounts = ref.read(accountMapProvider).value;
      if (accounts != null && accounts.isNotEmpty) {
        _selectedAccountId = accounts.keys.first;
      }
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
      final transactionRepo = ref.read(scheduledTransactionRepositoryProvider);

      // 1. Handle Payee (Create or Find)
      String? payeeId = widget.transaction?.payeeId;
      final name = _nameController.text.trim();

      // Simple logic: if name is different or new, checking existing.
      // This might link to an existing payee even if user intended a new one with same name (which is good).
      final existingPayees = await payeeRepo.getAllPayees();
      final match = existingPayees
          .where((p) => p.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;

      if (match != null) {
        payeeId = match.id;
      } else {
        // Create new
        payeeId = const Uuid().v4();
        await payeeRepo.createPayee(
          Payee(id: payeeId, name: name, createdAt: DateTime.now()),
        );
      }

      // 2. Create/Update Scheduled Transaction
      final t = ScheduledTransaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        accountId: _selectedAccountId,
        payeeId: payeeId,
        categoryId: null, // Income / Ready to Assign
        amount: double.parse(_amountController.text),
        frequency: _frequency,
        interval: _interval,
        occurrenceCount: _occurrenceCount,
        nextDate: _nextDate,
        endDate: _endDate,
        autoApprove: true, // Auto-approve salaries usually desired
        createdAt: widget.transaction?.createdAt ?? DateTime.now(),
      );

      if (widget.transaction != null) {
        await transactionRepo.updateScheduledTransaction(t);
      } else {
        await transactionRepo.createScheduledTransaction(t);
      }

      ref.invalidate(scheduledTransactionsProvider);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountMap = ref.watch(accountMapProvider).value ?? {};

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.transaction == null
                  ? 'Add Salary / Income'
                  : 'Edit Income',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              onPressed: () => context.pop(),
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
                label: 'Source Name (e.g. My Salary)',
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _amountController,
                label: 'Amount',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'Invalid Amount'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedAccountId),
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(labelText: 'Deposit Account'),
                items: accountMap.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedAccountId = v),
                validator: (v) => v == null ? 'Required' : null,
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
                  label: 'Save Income',
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
