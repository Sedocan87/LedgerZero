import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
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
import 'package:ledger_zero/presentation/screens/transactions/form/picker_field.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/widgets/recurrence/recurrence_selector.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

/// Keys of the picker fields (for tests).
const scheduledAccountFieldKey = Key('scheduled_account_field');
const scheduledPayeeFieldKey = Key('scheduled_payee_field');
const scheduledCategoryFieldKey = Key('scheduled_category_field');

class AddEditScheduledTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const AddEditScheduledTransactionScreen({super.key, this.transactionId});

  @override
  ConsumerState<AddEditScheduledTransactionScreen> createState() =>
      _AddEditScheduledTransactionScreenState();
}

class _AddEditScheduledTransactionScreenState
    extends ConsumerState<AddEditScheduledTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String? _accountId;
  String? _payeeId;
  String? _categoryId;

  /// Amount in minor units (signed: negative = outflow).
  int _amount = 0;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  int _interval = 1;

  /// Calendar days (UTC midnight).
  DateTime _nextDate = CalendarDate.today();
  DateTime? _endDate;
  int? _occurrenceCount;
  bool _autoApprove = false;
  DateTime? _createdAt;
  String? _memo;

  /// Day of month monthly/yearly occurrences aim for (see
  /// [ScheduledTransaction.anchorDay]). Kept from the loaded schedule until
  /// the user picks a new next date; defaults to the next date's day.
  int? _anchorDay;

  /// True while an existing schedule is loaded.
  late bool _isLoading = widget.transactionId != null;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null) {
      _loadTransaction(widget.transactionId!);
    }
  }

  Future<void> _loadTransaction(String id) async {
    try {
      final repo = ref.read(scheduledTransactionRepositoryProvider);
      final transaction = await repo.getScheduledTransactionById(id);
      if (!mounted) {
        return;
      }
      if (transaction != null) {
        setState(() {
          _accountId = transaction.accountId;
          _payeeId = transaction.payeeId;
          _categoryId = transaction.categoryId;
          _amount = transaction.amount ?? 0;
          _frequency = transaction.frequency ?? RecurrenceFrequency.monthly;
          _interval = transaction.interval ?? 1;
          _nextDate = transaction.nextDate != null
              ? CalendarDate.normalize(transaction.nextDate!)
              : CalendarDate.today();
          _endDate = transaction.endDate != null
              ? CalendarDate.normalize(transaction.endDate!)
              : null;
          _occurrenceCount = transaction.occurrenceCount;
          _autoApprove = transaction.autoApprove;
          _createdAt = transaction.createdAt;
          _memo = transaction.memo;
          _anchorDay = transaction.anchorDay;
        });
      }
    } catch (e, stack) {
      Logger.error('Failed to load scheduled transaction $id', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.scheduledLoadFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final transaction = ScheduledTransaction(
        id: widget.transactionId ?? const Uuid().v4(),
        accountId: _accountId,
        payeeId: _payeeId,
        categoryId: _categoryId,
        amount: _amount,
        frequency: _frequency,
        interval: _interval,
        occurrenceCount: _occurrenceCount,
        nextDate: _nextDate,
        endDate: _endDate,
        autoApprove: _autoApprove,
        memo: _memo,
        anchorDay: _anchorDay ?? _nextDate.day,
        createdAt: widget.transactionId == null
            ? DateTime.now().toUtc()
            : _createdAt,
      );

      // Validates the amount, stores the schedule and its reminder.
      await ref
          .read(scheduledTransactionServiceProvider)
          .saveScheduledTransaction(
            transaction,
            isNew: widget.transactionId == null,
          );

      if (mounted) {
        context.pop();
      }
    } catch (e, stack) {
      Logger.error('Failed to save scheduled transaction', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.scheduledSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final accountNames = <String, String>{
      for (final a
          in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        a.id: a.name,
    };
    final payeeNames = <String, String>{
      for (final p in ref.watch(payeesProvider).valueOrNull ?? const <Payee>[])
        p.id: p.name,
    };
    final categoryNames = <String, String>{
      for (final c
          in ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
        c.id: c.name,
    };

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transactionId != null
              ? l10n.editScheduledTransaction
              : l10n.createScheduledTransaction,
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.save),
            tooltip: l10n.save,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount
            TextFormField(
              initialValue: widget.transactionId == null && _amount == 0
                  ? ''
                  : fmt.formatAmountForInput(_amount),
              decoration: InputDecoration(labelText: l10n.amount),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (value) {
                final amount = fmt.parseAmount(value);
                if (amount == null) {
                  return l10n.invalidAmount;
                }
                if (amount == 0) {
                  return l10n.amountMustNotBeZero;
                }
                return null;
              },
              onSaved: (value) => _amount = fmt.parseAmount(value) ?? 0,
            ),
            const SizedBox(height: 16),

            // Account
            PickerField(
              fieldKey: scheduledAccountFieldKey,
              label: l10n.account,
              text: accountNames[_accountId] ?? '',
              validator: (_) => _accountId == null ? l10n.selectAccount : null,
              onTap: () async {
                final picked = await showAccountPicker(context);
                if (picked != null && mounted) {
                  setState(() => _accountId = picked.id);
                }
              },
            ),
            const SizedBox(height: 16),

            // Payee
            PickerField(
              fieldKey: scheduledPayeeFieldKey,
              label: l10n.payee,
              text: payeeNames[_payeeId] ?? '',
              onClear: () => setState(() => _payeeId = null),
              onTap: () async {
                final picked = await showPayeePicker(context);
                if (picked != null && mounted) {
                  setState(() => _payeeId = picked.id);
                }
              },
            ),
            const SizedBox(height: 16),

            // Category
            PickerField(
              fieldKey: scheduledCategoryFieldKey,
              label: l10n.category,
              text: categoryNames[_categoryId] ?? '',
              onClear: () => setState(() => _categoryId = null),
              onTap: () async {
                final picked = await showCategoryPicker(context);
                if (picked != null && mounted) {
                  setState(() => _categoryId = picked.id);
                }
              },
            ),
            const SizedBox(height: 16),

            // Memo
            TextFormField(
              initialValue: _memo ?? '',
              decoration: InputDecoration(labelText: l10n.memo),
              textCapitalization: TextCapitalization.sentences,
              onSaved: (value) {
                final memo = value?.trim() ?? '';
                _memo = memo.isEmpty ? null : memo;
              },
            ),
            const SizedBox(height: 16),

            // Frequency & End Date
            RecurrenceSelector(
              frequency: _frequency,
              onFrequencyChanged: (value) => setState(() => _frequency = value),
              interval: _interval,
              onIntervalChanged: (value) => setState(() => _interval = value),
              endDate: _endDate,
              onEndDateChanged: (value) => setState(() => _endDate = value),
              occurrenceCount: _occurrenceCount,
              onOccurrenceCountChanged: (value) =>
                  setState(() => _occurrenceCount = value),
              nextDate: _nextDate,
            ),
            const SizedBox(height: 16),

            // Next Date
            ListTile(
              title: Text(l10n.nextDate),
              subtitle: Text(fmt.formatDate(_nextDate)),
              trailing: const Icon(AppIcons.calendar),
              onTap: () async {
                final initial = CalendarDate.toLocalDay(_nextDate);
                final now = DateTime.now();
                var first = DateTime(now.year - 1, now.month, now.day);
                if (initial.isBefore(first)) {
                  first = initial;
                }
                var last = DateTime(now.year + 5, now.month, now.day);
                if (initial.isAfter(last)) {
                  last = initial;
                }
                final date = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: first,
                  lastDate: last,
                );
                if (date != null && mounted) {
                  setState(() {
                    _nextDate = CalendarDate.fromLocalPick(date);
                    _anchorDay = _nextDate.day;
                  });
                }
              },
            ),

            // Auto Approve
            SwitchListTile(
              title: Text(l10n.autoApprove),
              value: _autoApprove,
              onChanged: (value) => setState(() => _autoApprove = value),
            ),
          ],
        ),
      ),
    );
  }
}
