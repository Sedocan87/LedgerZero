import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:uuid/uuid.dart';

class AddEditScheduledTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const AddEditScheduledTransactionScreen({super.key, this.transactionId});

  @override
  ConsumerState<AddEditScheduledTransactionScreen> createState() => _AddEditScheduledTransactionScreenState();
}

class _AddEditScheduledTransactionScreenState extends ConsumerState<AddEditScheduledTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String? _accountId;
  String? _payeeId;
  String? _categoryId;
  double _amount = 0.0;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _nextDate = DateTime.now();
  DateTime? _endDate;
  bool _autoApprove = false;
  DateTime? _createdAt;

  bool _isLoading = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      if (widget.transactionId != null) {
        _loadTransaction();
      }
      _isInit = false;
    }
  }

  Future<void> _loadTransaction() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(scheduledTransactionRepositoryProvider);
      final transaction = await repo.getScheduledTransactionById(widget.transactionId!);
      if (transaction != null) {
        setState(() {
          _accountId = transaction.accountId;
          _payeeId = transaction.payeeId;
          _categoryId = transaction.categoryId;
          _amount = transaction.amount ?? 0.0;
          _frequency = transaction.frequency ?? RecurrenceFrequency.monthly;
          _nextDate = transaction.nextDate ?? DateTime.now();
          _endDate = transaction.endDate;
          _autoApprove = transaction.autoApprove;
          _createdAt = transaction.createdAt;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(scheduledTransactionRepositoryProvider);

      final transaction = ScheduledTransaction(
        id: widget.transactionId ?? const Uuid().v4(),
        accountId: _accountId,
        payeeId: _payeeId,
        categoryId: _categoryId,
        amount: _amount,
        frequency: _frequency,
        nextDate: _nextDate,
        endDate: _endDate,
        autoApprove: _autoApprove,
        createdAt: widget.transactionId == null ? DateTime.now() : _createdAt,
      );

      if (widget.transactionId != null) {
        await repo.updateScheduledTransaction(transaction);
      } else {
        await repo.createScheduledTransaction(transaction);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accountMap = ref.watch(accountMapProvider).value ?? {};
    final payeeMap = ref.watch(payeeMapProvider).value ?? {};
    final categoryMap = ref.watch(categoryMapProvider).value ?? {};

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId != null ? l10n.editScheduledTransaction : l10n.createScheduledTransaction),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.save),
            onPressed: _save,
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
               initialValue: _amount.toString(),
               decoration: InputDecoration(labelText: l10n.amount),
               keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
               validator: (value) {
                 if (value == null || value.isEmpty) {
                   return l10n.invalidAmount;
                 }
                 if (double.tryParse(value) == null) {
                   return l10n.invalidAmount;
                 }
                 return null;
               },
               onSaved: (value) => _amount = double.parse(value!),
             ),
             const SizedBox(height: 16),

             // Account
             DropdownButtonFormField<String>(
               key: ValueKey(_accountId),
               initialValue: (accountMap.containsKey(_accountId)) ? _accountId : null,
               decoration: InputDecoration(labelText: l10n.account),
               items: accountMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
               onChanged: (value) => setState(() => _accountId = value),
               validator: (value) => value == null ? l10n.selectAccount : null,
             ),
             const SizedBox(height: 16),

             // Payee
             DropdownButtonFormField<String>(
               key: ValueKey(_payeeId),
               initialValue: (payeeMap.containsKey(_payeeId)) ? _payeeId : null,
               decoration: InputDecoration(labelText: l10n.payee),
               items: payeeMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
               onChanged: (value) => setState(() => _payeeId = value),
             ),
             const SizedBox(height: 16),

             // Category
             DropdownButtonFormField<String>(
               key: ValueKey(_categoryId),
               initialValue: (categoryMap.containsKey(_categoryId)) ? _categoryId : null,
               decoration: InputDecoration(labelText: l10n.category),
               items: categoryMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
               onChanged: (value) => setState(() => _categoryId = value),
             ),
             const SizedBox(height: 16),

             // Frequency
             DropdownButtonFormField<RecurrenceFrequency>(
               key: ValueKey(_frequency),
               initialValue: _frequency,
               decoration: InputDecoration(labelText: l10n.frequency),
               items: RecurrenceFrequency.values.map((e) {
                 String label = '';
                 switch(e) {
                   case RecurrenceFrequency.daily: label = l10n.daily; break;
                   case RecurrenceFrequency.weekly: label = l10n.weekly; break;
                   case RecurrenceFrequency.monthly: label = l10n.monthly; break;
                   case RecurrenceFrequency.yearly: label = l10n.yearly; break;
                 }
                 return DropdownMenuItem(value: e, child: Text(label));
               }).toList(),
               onChanged: (value) => setState(() => _frequency = value!),
             ),
             const SizedBox(height: 16),

             // Next Date
             ListTile(
               title: Text(l10n.nextDate),
               subtitle: Text(DateFormat.yMMMd().format(_nextDate)),
               trailing: const Icon(AppIcons.calendar),
               onTap: () async {
                 final date = await showDatePicker(
                   context: context,
                   initialDate: _nextDate,
                   firstDate: DateTime.now().subtract(const Duration(days: 365)),
                   lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                 );
                 if (date != null) {
                   setState(() => _nextDate = date);
                 }
               },
             ),

             // End Date
             ListTile(
               title: Text(l10n.endDate),
               subtitle: Text(_endDate == null ? l10n.none : DateFormat.yMMMd().format(_endDate!)),
               trailing: IconButton(
                 icon: Icon(_endDate == null ? AppIcons.add : AppIcons.close),
                 onPressed: () async {
                   if (_endDate == null) {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _nextDate.add(const Duration(days: 30)),
                        firstDate: _nextDate,
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                   } else {
                     setState(() => _endDate = null);
                   }
                 },
               ),
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
