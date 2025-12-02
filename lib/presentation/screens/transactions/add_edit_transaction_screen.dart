import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/presentation/widgets/common/buttons.dart';
import 'package:uuid/uuid.dart';

final payeeListProvider = StreamProvider.autoDispose<List<Payee>>((ref) {
  return ref.watch(payeeRepositoryProvider).watchAllPayees();
});

final accountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

final categoriesProvider = StreamProvider.autoDispose((ref) => ref.watch(categoryRepositoryProvider).watchAllCategories());
final categoryGroupsProvider = StreamProvider.autoDispose((ref) => ref.watch(categoryRepositoryProvider).watchAllCategoryGroups());

final categoryHierarchyProvider = Provider.autoDispose<AsyncValue<Map<CategoryGroup, List<Category>>>>((ref) {
  final categoriesAsync = ref.watch(categoriesProvider);
  final groupsAsync = ref.watch(categoryGroupsProvider);

  if (categoriesAsync.isLoading || groupsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (categoriesAsync.hasError) {
    return AsyncValue.error(categoriesAsync.error!, categoriesAsync.stackTrace!);
  }
  if (groupsAsync.hasError) {
    return AsyncValue.error(groupsAsync.error!, groupsAsync.stackTrace!);
  }

  final categories = categoriesAsync.value ?? [];
  final groups = groupsAsync.value ?? [];

  final map = <CategoryGroup, List<Category>>{};

  final sortedGroups = List<CategoryGroup>.from(groups)..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

  for (final group in sortedGroups) {
    final groupCategories = categories.where((c) => c.categoryGroupId == group.id && !(c.isHidden)).toList();
    groupCategories.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    map[group] = groupCategories;
  }

  return AsyncValue.data(map);
});

final transactionDetailsProvider = FutureProvider.family.autoDispose<Transaction?, String>((ref, id) {
  return ref.watch(transactionRepositoryProvider).getTransactionById(id);
});

final splitTransactionsProvider = FutureProvider.family.autoDispose<List<Transaction>, String>((ref, id) {
  return ref.watch(transactionRepositoryProvider).getSplitTransactions(id);
});

enum TransactionFormType { expense, income, transfer }

class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? initialAccountId;

  const AddEditTransactionScreen({
    super.key,
    this.transactionId,
    this.initialAccountId,
  });

  @override
  ConsumerState<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _categoryController = TextEditingController();
  final _accountController = TextEditingController();
  final _memoController = TextEditingController();
  final _transferAccountController = TextEditingController();

  // Form State
  TransactionFormType _formType = TransactionFormType.expense;
  bool _isSplit = false;
  final List<SplitItem> _splits = [];
  bool _initialAccountLoaded = false;
  bool _initialTransactionLoaded = false;
  bool _initialSplitsLoaded = false;

  // Recurring State
  bool _isRecurring = false;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;

  DateTime _selectedDate = DateTime.now();
  Payee? _selectedPayee;
  // ignore: unused_field
  TextEditingController? _payeeController;
  Category? _selectedCategory;
  Account? _selectedAccount;
  Account? _transferAccount;
  TransactionClearStatus _clearedStatus = TransactionClearStatus.uncleared;
  Transaction? _loadedTransaction;

  // Draft State for Delayed Restoration
  String? _draftAccountId;
  String? _draftPayeeId;
  String? _draftCategoryId;

  // Autosave
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_triggerAutosave);
    _memoController.addListener(_triggerAutosave);
    // Other simple listeners

    // Restore draft if new transaction
    if (widget.transactionId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreDraft();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dateController.text.isEmpty) {
        _dateController.text = DateFormat.yMMMd().format(_selectedDate);
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _amountController.dispose();
    _dateController.dispose();
    _categoryController.dispose();
    _accountController.dispose();
    _memoController.dispose();
    _transferAccountController.dispose();
    for (var split in _splits) {
      split.dispose();
    }
    super.dispose();
  }

  void _triggerAutosave() {
    if (widget.transactionId != null) return; // Only autosave new transactions for now
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 1000), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final key = 'draft_transaction_new';

      final draft = {
        'amount': _amountController.text,
        'memo': _memoController.text,
        'date': _selectedDate.toIso8601String(),
        'accountId': _selectedAccount?.id,
        'payeeId': _selectedPayee?.id,
        'payeeName': _payeeController?.text,
        'categoryId': _selectedCategory?.id,
        'formType': _formType.index,
        'isSplit': _isSplit,
        'isRecurring': _isRecurring,
        'frequency': _frequency.index,
        'transferAccountId': _transferAccount?.id,
        'splits': _splits.map((s) => {
           'amount': s.amountController.text,
           'memo': s.memoController.text,
           'categoryId': s.category?.id
        }).toList(),
      };

      await prefs.setString(key, jsonEncode(draft));
    } catch (e) {
      // Ignore errors during autosave
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final key = 'draft_transaction_new';
      final jsonStr = prefs.getString(key);

      if (jsonStr != null) {
         final draft = jsonDecode(jsonStr) as Map<String, dynamic>;

         if (mounted) {
           setState(() {
             _amountController.text = draft['amount'] ?? '';
             _memoController.text = draft['memo'] ?? '';
             if (draft['date'] != null) {
               _selectedDate = DateTime.parse(draft['date']);
               _dateController.text = DateFormat.yMMMd().format(_selectedDate);
             }
             if (draft['formType'] != null) {
               _formType = TransactionFormType.values[draft['formType']];
             }
             _isSplit = draft['isSplit'] ?? false;
             _isRecurring = draft['isRecurring'] ?? false;
             if (draft['frequency'] != null) {
               _frequency = RecurrenceFrequency.values[draft['frequency']];
             }

             // Set Draft IDs for listener resolution
             _draftAccountId = draft['accountId'];
             _draftPayeeId = draft['payeeId'];
             _draftCategoryId = draft['categoryId'];

             // Restore splits
             if (_isSplit && draft['splits'] != null) {
                _splits.clear();
                for (var s in (draft['splits'] as List)) {
                   final item = SplitItem(
                      amount: 0,
                      categoryId: s['categoryId']
                   );
                   item.amountController.text = s['amount'] ?? '';
                   item.memoController.text = s['memo'] ?? '';
                   _splits.add(item);
                }
             }
           });

           // Trigger immediate check if providers are ready
           // (Listeners will handle if they update later, but if already loaded, we need to check)
           // But actually, ref.listen doesn't fire on current state.
           // Since we set _draftAccountId, the listeners below (which run in build) will pick it up?
           // No, listeners in build only run when PROVIDER updates.
           // We need to manually check here too.

           final accounts = ref.read(accountsProvider).valueOrNull;
           if (accounts != null && _draftAccountId != null && _selectedAccount == null) {
              try {
                final acc = accounts.firstWhere((a) => a.id == _draftAccountId);
                setState(() {
                  _selectedAccount = acc;
                  _accountController.text = acc.name;
                  _draftAccountId = null; // Clear handled draft ID
                });
              } catch (_) {}
           }
           // Same for others if needed, but listeners should handle subsequent loads.
         }
      }
    } catch (e) {
      // Ignore restore errors
    }
  }

  Future<void> _clearDraft() async {
      final prefs = ref.read(sharedPreferencesProvider);
      final key = 'draft_transaction_new';
      await prefs.remove(key);
  }

  Future<void> _saveTransaction({bool popAfterSave = true}) async {
    final amountVal = double.tryParse(_amountController.text);
    if (amountVal == null) {
      return;
    }

    // Validate Split
    if (_isSplit) {
        double splitTotal = 0;
        for (var split in _splits) {
             final val = double.tryParse(split.amountController.text) ?? 0;
             splitTotal += val;
        }
        if ((splitTotal - amountVal).abs() > 0.01) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Split amounts must equal total amount")));
            return;
        }
    }

    // Validate Accounts
    if (_selectedAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.selectAccount)));
        return;
    }

    if (_formType == TransactionFormType.transfer) {
        if (_transferAccount == null) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.selectAccount)));
             return;
        }
        if (_transferAccount!.id == _selectedAccount!.id) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source and destination accounts must be different')));
             return;
        }
    }

    final amount = (_formType == TransactionFormType.income) ? amountVal : -amountVal;

    String? payeeId;
    if (_formType != TransactionFormType.transfer && _selectedPayee != null) {
       payeeId = _selectedPayee!.id;
    }

    final transactionId = widget.transactionId ?? const Uuid().v4();

    // Check if Recurring is enabled
    if (_isRecurring && widget.transactionId == null) {
        if (_isSplit) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurring split transactions are not supported yet.')));
             return;
        }
        if (_formType == TransactionFormType.transfer) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurring transfers are not supported yet.')));
             return;
        }

        final st = ScheduledTransaction(
             id: const Uuid().v4(),
             accountId: _selectedAccount!.id,
             amount: amount,
             payeeId: payeeId,
             categoryId: _selectedCategory?.id,
             frequency: _frequency,
             nextDate: _selectedDate,
             createdAt: DateTime.now(),
        );

        try {
            await ref.read(scheduledTransactionRepositoryProvider).createScheduledTransaction(st);
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled transaction created')));
                await _clearDraft();
                if (popAfterSave) {
                  context.pop();
                } else {
                  _resetForm();
                }
            }
        } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
        }
        return;
    }

    final transaction = Transaction(
        id: transactionId,
        accountId: _selectedAccount!.id,
        date: _selectedDate,
        amount: amount,
        payeeId: payeeId,
        categoryId: (_formType == TransactionFormType.transfer || _isSplit) ? null : _selectedCategory?.id,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        cleared: _clearedStatus,
        transferAccountId: (_formType == TransactionFormType.transfer) ? _transferAccount!.id : null,
        transferTransactionId: (_formType == TransactionFormType.transfer) ? _loadedTransaction?.transferTransactionId : null,
        createdAt: _loadedTransaction?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
    );

    try {
        final repo = ref.read(transactionRepositoryProvider);

        // CLEANUP LOGIC FOR TYPE CHANGES
        if (widget.transactionId != null && _loadedTransaction != null) {
             // 1. Was Transfer -> Now Not Transfer
             if (_loadedTransaction!.transferTransactionId != null && _formType != TransactionFormType.transfer) {
                 await repo.deleteTransaction(_loadedTransaction!.transferTransactionId!);
             }

             // 2. Was Split -> Now Not Split
             if (!_isSplit) {
                 // Check if it WAS a split. We check if there are children.
                 final existingChildren = await repo.getSplitTransactions(widget.transactionId!);
                 if (existingChildren.isNotEmpty) {
                     await repo.batchDeleteTransactions(existingChildren.map((e) => e.id).toList());
                 }
             }
        }

        if (_isSplit && widget.transactionId == null) {
             // Create Split
             final children = _splits.map((s) {
                 final val = double.tryParse(s.amountController.text) ?? 0;
                 final childAmount = (_formType == TransactionFormType.income) ? val : -val;

                 return Transaction(
                     id: const Uuid().v4(),
                     accountId: _selectedAccount!.id,
                     date: _selectedDate,
                     amount: childAmount,
                     payeeId: payeeId,
                     categoryId: s.category?.id,
                     memo: s.memoController.text.isEmpty ? null : s.memoController.text,
                     parentTransactionId: transactionId,
                     createdAt: DateTime.now(),
                 );
             }).toList();

             await repo.createSplitTransaction(transaction, children);
        } else if (_formType == TransactionFormType.transfer && widget.transactionId == null) {
             // Create Transfer (Source and Dest)
             final destId = const Uuid().v4();
             final destTransaction = transaction.copyWith(
                 id: destId,
                 accountId: _transferAccount!.id,
                 amount: -amount,
                 transferAccountId: _selectedAccount!.id,
                 transferTransactionId: transactionId,
             );
             // Update source with dest link
             final sourceTransaction = transaction.copyWith(
                 transferTransactionId: destId,
             );

             await repo.createTransferTransaction(sourceTransaction, destTransaction);
        } else if (widget.transactionId != null) {
           if (_isSplit) {
               final children = _splits.map((s) {
                   final val = double.tryParse(s.amountController.text) ?? 0;
                   final childAmount = (_formType == TransactionFormType.income) ? val : -val;

                   return Transaction(
                       id: const Uuid().v4(),
                       accountId: _selectedAccount!.id,
                       date: _selectedDate,
                       amount: childAmount,
                       payeeId: payeeId,
                       categoryId: s.category?.id,
                       memo: s.memoController.text.isEmpty ? null : s.memoController.text,
                       parentTransactionId: transactionId,
                       createdAt: DateTime.now(),
                   );
               }).toList();

               await repo.updateSplitTransaction(transaction, children);
           } else if (_formType == TransactionFormType.transfer && _loadedTransaction?.transferTransactionId != null) {
               final destTransaction = transaction.copyWith(
                   id: _loadedTransaction!.transferTransactionId!,
                   accountId: _transferAccount!.id,
                   amount: -amount,
                   transferAccountId: _selectedAccount!.id,
                   transferTransactionId: transactionId,
               );
               await repo.updateTransferTransaction(transaction, destTransaction);
           } else {
               await repo.updateTransaction(transaction);
           }
        } else {
           await repo.createTransaction(transaction);
        }

        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.transactionSaved)));
            if (widget.transactionId == null) await _clearDraft();
            if (popAfterSave) {
              context.pop();
            } else {
              _resetForm();
            }
        }
    } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
    }
  }

  void _resetForm() {
    _amountController.clear();
    _memoController.clear();
    _categoryController.clear();
    _payeeController?.clear();
    _transferAccountController.clear();
    for (var s in _splits) { s.dispose(); }
    _splits.clear();

    setState(() {
      _selectedCategory = null;
      _selectedPayee = null;
      _transferAccount = null;
      _clearedStatus = TransactionClearStatus.uncleared;
      _isSplit = false;
      _isRecurring = false;
      // Preserve Account and Date
    });

    _clearDraft();
  }

  void _showAccountPicker(BuildContext context, {bool isTransfer = false}) {
    showModalBottomSheet(
      context: context,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final accountsAsync = ref.watch(accountsProvider);
            return accountsAsync.when(
              data: (accounts) => ListView.builder(
                controller: scrollController,
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return ListTile(
                    title: Text(account.name),
                    subtitle: Text(account.type.name.toUpperCase()),
                    onTap: () {
                      setState(() {
                        if (isTransfer) {
                            _transferAccount = account;
                            _transferAccountController.text = account.name;
                        } else {
                            _selectedAccount = account;
                            _accountController.text = account.name;
                        }
                        _triggerAutosave();
                      });
                      Navigator.pop(context);
                    },
                    leading: const Icon(Icons.account_balance),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            );
          },
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, {ValueChanged<Category>? onSelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Consumer(
            builder: (context, ref, _) {
                 final hierarchyAsync = ref.watch(categoryHierarchyProvider);
                 return hierarchyAsync.when(
                    data: (hierarchy) => ListView.builder(
                        controller: scrollController,
                        itemCount: hierarchy.length,
                        itemBuilder: (context, index) {
                            final group = hierarchy.keys.elementAt(index);
                            final categories = hierarchy[group]!;
                            if (categories.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                        child: Text(
                                          group.name,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ),
                                    ...categories.map((category) => ListTile(
                                        title: Text(category.name),
                                        onTap: () {
                                            if (onSelected != null) {
                                                onSelected(category);
                                            } else {
                                                setState(() {
                                                    _selectedCategory = category;
                                                    _categoryController.text = category.name;
                                                    _triggerAutosave();
                                                });
                                            }
                                            Navigator.pop(context);
                                        },
                                        leading: const Icon(Icons.label_outline),
                                    )),
                                    const Divider(),
                                ],
                            );
                        },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                 );
            }
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transactionId != null;
    final l10n = AppLocalizations.of(context)!;

    // Listen for initial account load (Add Mode)
    ref.listen(accountsProvider, (previous, next) {
      if (!isEditing && !_initialAccountLoaded && widget.initialAccountId != null && next.hasValue) {
         final accounts = next.value!;
         try {
             final initial = accounts.firstWhere((a) => a.id == widget.initialAccountId);
             setState(() {
                 _selectedAccount = initial;
                 _accountController.text = initial.name;
                 _initialAccountLoaded = true;
             });
         } catch (_) {}
      }

      // Handle Draft Restoration for Account
      if (_draftAccountId != null && _selectedAccount == null && next.hasValue) {
          try {
             final acc = next.value!.firstWhere((a) => a.id == _draftAccountId);
             setState(() {
                 _selectedAccount = acc;
                 _accountController.text = acc.name;
                 _draftAccountId = null;
             });
          } catch (_) {}
      }

      // Edit Mode - account lookup
      if (isEditing && _loadedTransaction != null && next.hasValue) {
          try {
             if (_selectedAccount == null) {
                 final account = next.value!.firstWhere((a) => a.id == _loadedTransaction!.accountId);
                 setState(() {
                     _selectedAccount = account;
                     _accountController.text = account.name;
                 });
             }
             if (_loadedTransaction!.transferAccountId != null && _transferAccount == null) {
                 final transferAccount = next.value!.firstWhere((a) => a.id == _loadedTransaction!.transferAccountId);
                 setState(() {
                     _transferAccount = transferAccount;
                     _transferAccountController.text = transferAccount.name;
                 });
             }
          } catch (_) {}
      }
    });

    // Listen for transaction load (Edit Mode)
    if (isEditing) {
      ref.listen<AsyncValue<Transaction?>>(transactionDetailsProvider(widget.transactionId!), (prev, next) {
          if (next.hasValue && next.value != null && !_initialTransactionLoaded) {
              final t = next.value!;
              setState(() {
                _loadedTransaction = t;
                _amountController.text = t.amount.abs().toString();

                if (t.transferAccountId != null) {
                    _formType = TransactionFormType.transfer;
                } else if (t.amount > 0) {
                    _formType = TransactionFormType.income;
                } else {
                    _formType = TransactionFormType.expense;
                }

                _selectedDate = t.date;
                _dateController.text = DateFormat.yMMMd().format(t.date);
                _memoController.text = t.memo ?? '';
                _clearedStatus = t.cleared;
                _initialTransactionLoaded = true;
              });

              // Immediate resolution for dependencies if already loaded
              final accounts = ref.read(accountsProvider).valueOrNull;
              if (accounts != null) {
                 if (_selectedAccount == null) {
                     try {
                        _selectedAccount = accounts.firstWhere((a) => a.id == t.accountId);
                        _accountController.text = _selectedAccount!.name;
                     } catch (_) {}
                 }
                 if (t.transferAccountId != null && _transferAccount == null) {
                     try {
                        _transferAccount = accounts.firstWhere((a) => a.id == t.transferAccountId);
                        _transferAccountController.text = _transferAccount!.name;
                     } catch (_) {}
                 }
              }

              final payees = ref.read(payeeListProvider).valueOrNull;
              if (payees != null && t.payeeId != null && _selectedPayee == null) {
                  try {
                      _selectedPayee = payees.firstWhere((p) => p.id == t.payeeId);
                      _payeeController?.text = _selectedPayee!.name;
                  } catch (_) {}
              }

              final categories = ref.read(categoriesProvider).valueOrNull;
              if (categories != null && t.categoryId != null && _selectedCategory == null) {
                  try {
                      _selectedCategory = categories.firstWhere((c) => c.id == t.categoryId);
                      _categoryController.text = _selectedCategory!.name;
                  } catch (_) {}
              }
          }
      });

      // Split Lookup
      ref.listen<AsyncValue<List<Transaction>>>(splitTransactionsProvider(widget.transactionId!), (prev, next) {
          if (next.hasValue && next.value!.isNotEmpty && !_initialSplitsLoaded) {
              final children = next.value!;
              setState(() {
                  _isSplit = true;
                  _splits.clear();

                  // Try to resolve categories immediately
                  final categories = ref.read(categoriesProvider).valueOrNull;

                  for (var child in children) {
                      Category? cat;
                      if (categories != null && child.categoryId != null) {
                          try {
                              cat = categories.firstWhere((c) => c.id == child.categoryId);
                          } catch (_) {}
                      }

                      final item = SplitItem(
                          amount: child.amount.abs(),
                          memo: child.memo,
                          category: cat,
                          categoryId: child.categoryId,
                      );
                      item.amountController.text = child.amount.abs().toString();
                      if (child.memo != null) item.memoController.text = child.memo!;
                      if (cat != null) item.categoryController.text = cat.name;
                      _splits.add(item);
                  }
                  _initialSplitsLoaded = true;
              });
          }
      });

      // Payee Lookup
      ref.listen(payeeListProvider, (prev, next) {
         // Draft logic for Payee
         if (_draftPayeeId != null && _selectedPayee == null && next.hasValue) {
             try {
                 final payee = next.value!.firstWhere((p) => p.id == _draftPayeeId);
                 setState(() {
                     _selectedPayee = payee;
                     _payeeController?.text = payee.name;
                     _draftPayeeId = null;
                 });
             } catch (_) {}
         }

         if (_loadedTransaction != null && _loadedTransaction!.payeeId != null && _selectedPayee == null && next.hasValue) {
             try {
                final payee = next.value!.firstWhere((p) => p.id == _loadedTransaction!.payeeId);
                setState(() {
                    _selectedPayee = payee;
                    _payeeController?.text = payee.name;
                });
             } catch (_) {}
         }
      });

      // Category Lookup
      ref.listen(categoriesProvider, (prev, next) {
         if (next.hasValue) {
             final categories = next.value!;

             // Draft logic for Category
             if (_draftCategoryId != null && _selectedCategory == null) {
                 try {
                     final cat = categories.firstWhere((c) => c.id == _draftCategoryId);
                     setState(() {
                         _selectedCategory = cat;
                         _categoryController.text = cat.name;
                         _draftCategoryId = null;
                     });
                 } catch (_) {}
             }

             // Main Category
             if (_loadedTransaction != null && _loadedTransaction!.categoryId != null && _selectedCategory == null) {
                 try {
                    final category = categories.firstWhere((c) => c.id == _loadedTransaction!.categoryId);
                    setState(() {
                        _selectedCategory = category;
                        _categoryController.text = category.name;
                    });
                 } catch (_) {}
             }

             // Splits Categories
             if (_isSplit) {
                 for (var split in _splits) {
                     if (split.category == null && split.categoryId != null) {
                         try {
                             final cat = categories.firstWhere((c) => c.id == split.categoryId);
                             setState(() {
                                 split.category = cat;
                                 split.categoryController.text = cat.name;
                             });
                         } catch (_) {}
                     }
                 }
             }
         }
      });
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
             if (_formKey.currentState!.validate()) {
                 if (_selectedAccount == null) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectAccount)));
                     return;
                 }
                 _saveTransaction();
             }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? l10n.editTransaction : l10n.addTransaction),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                   if (_formKey.currentState!.validate()) {
                     if (_selectedAccount == null) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectAccount)));
                         return;
                     }
                     _saveTransaction();
                   }
                },
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Transaction Type Toggle
                  SegmentedButton<TransactionFormType>(
                    segments: [
                      ButtonSegment<TransactionFormType>(
                        value: TransactionFormType.expense,
                        label: Text(l10n.outflow),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      ButtonSegment<TransactionFormType>(
                        value: TransactionFormType.income,
                        label: Text(l10n.inflow),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      ButtonSegment<TransactionFormType>(
                        value: TransactionFormType.transfer,
                        label: Text(l10n.transfer),
                        icon: const Icon(Icons.swap_horiz),
                      ),
                    ],
                    selected: {_formType},
                    onSelectionChanged: (Set<TransactionFormType> newSelection) {
                      setState(() {
                        _formType = newSelection.first;
                        _triggerAutosave();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Amount Field
                  AppTextField(
                    controller: _amountController,
                    label: l10n.amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.invalidAmount;
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount == 0) {
                         return l10n.invalidAmount;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Account Field (From)
                  AppTextField(
                    controller: _accountController,
                    label: _formType == TransactionFormType.transfer ? 'From Account' : l10n.account,
                    readOnly: true,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    onTap: () {
                        _showAccountPicker(context);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Transfer Account Field (To)
                  if (_formType == TransactionFormType.transfer) ...[
                      AppTextField(
                        controller: _transferAccountController,
                        label: l10n.toAccount,
                        readOnly: true,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        onTap: () {
                            _showAccountPicker(context, isTransfer: true);
                        },
                      ),
                      const SizedBox(height: 16),
                  ],

                  // Date Field
                  AppTextField(
                    controller: _dateController,
                    label: l10n.date,
                    readOnly: true,
                    prefixIcon: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && picked != _selectedDate) {
                        setState(() {
                          _selectedDate = picked;
                          _dateController.text = DateFormat.yMMMd().format(_selectedDate);
                          _triggerAutosave();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Payee Field (Hidden for Transfer)
                  if (_formType != TransactionFormType.transfer) ...[
                      Consumer(
                        builder: (context, ref, child) {
                          final payeesAsync = ref.watch(payeeListProvider);

                          return payeesAsync.when(
                            data: (payees) {
                              return Autocomplete<Payee>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text == '') {
                                    return const Iterable<Payee>.empty();
                                  }
                                  return payees.where((Payee option) {
                                    return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                  });
                                },
                                displayStringForOption: (Payee option) => option.name,
                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                  _payeeController = textEditingController;
                                  return AppTextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    label: l10n.payee,
                                    onFieldSubmitted: (value) {
                                        onFieldSubmitted();
                                    },
                                    onChanged: (_) => _triggerAutosave(),
                                  );
                                },
                                onSelected: (Payee selection) {
                                   setState(() {
                                     _selectedPayee = selection;
                                     _triggerAutosave();
                                   });
                                },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, stack) => Text('Error: $err'),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category / Split
                      if (!_isSplit) ...[
                          AppTextField(
                            controller: _categoryController,
                            label: l10n.category,
                            readOnly: true,
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            onTap: () {
                                _showCategoryPicker(context);
                            },
                          ),
                      ],

                      // Split Toggle
                      SwitchListTile(
                          title: Text(l10n.split),
                          value: _isSplit,
                          onChanged: (val) {
                              setState(() {
                                  _isSplit = val;
                                  if (_isSplit) _isRecurring = false; // Disable recurring
                                  if (_isSplit && _splits.isEmpty) {
                                      // Initialize with 2 splits?
                                      _splits.add(SplitItem());
                                      _splits.add(SplitItem());
                                  }
                                  _triggerAutosave();
                              });
                          },
                      ),

                      if (_isSplit) ...[
                          ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _splits.length,
                              itemBuilder: (context, index) {
                                  final split = _splits[index];
                                  return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                              children: [
                                                  Row(
                                                      children: [
                                                          Expanded(
                                                              child: AppTextField(
                                                                  controller: split.categoryController,
                                                                  label: l10n.category,
                                                                  readOnly: true,
                                                                  onTap: () {
                                                                      _showCategoryPicker(context, onSelected: (c) {
                                                                          setState(() {
                                                                              split.category = c;
                                                                              split.categoryController.text = c.name;
                                                                              _triggerAutosave();
                                                                          });
                                                                      });
                                                                  },
                                                              ),
                                                          ),
                                                          IconButton(
                                                              icon: const Icon(Icons.delete),
                                                              onPressed: () {
                                                                  setState(() {
                                                                      split.dispose();
                                                                      _splits.removeAt(index);
                                                                      _triggerAutosave();
                                                                  });
                                                              },
                                                          ),
                                                      ],
                                                  ),
                                                  Row(
                                                      children: [
                                                          Expanded(
                                                              child: AppTextField(
                                                                  controller: split.amountController,
                                                                  label: l10n.amount,
                                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                                  onChanged: (_) => _triggerAutosave(),
                                                              ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                              child: AppTextField(
                                                                  controller: split.memoController,
                                                                  label: l10n.memo,
                                                                  onChanged: (_) => _triggerAutosave(),
                                                              ),
                                                          ),
                                                      ],
                                                  ),
                                              ],
                                          ),
                                      ),
                                  );
                              },
                          ),
                          AppButton.text(
                              label: "Add Split", // TODO l10n
                              onPressed: () {
                                  setState(() {
                                      _splits.add(SplitItem());
                                      _triggerAutosave();
                                  });
                              },
                              icon: Icons.add,
                          ),
                      ],
                  ],
                  const SizedBox(height: 16),

                  // Memo Field
                  AppTextField(
                    controller: _memoController,
                    label: l10n.memo,
                    maxLines: 2,
                    onChanged: (_) => _triggerAutosave(),
                  ),
                  const SizedBox(height: 16),

                  // Cleared Toggle
                  SwitchListTile(
                      title: Text(l10n.cleared),
                      value: _clearedStatus == TransactionClearStatus.cleared || _clearedStatus == TransactionClearStatus.reconciled,
                      onChanged: (bool value) {
                          setState(() {
                              _clearedStatus = value ? TransactionClearStatus.cleared : TransactionClearStatus.uncleared;
                              _triggerAutosave();
                          });
                      },
                  ),
                  const SizedBox(height: 16),

                  // Recurring Toggle
                  if (!isEditing && !_isSplit && _formType != TransactionFormType.transfer) ...[
                       SwitchListTile(
                          title: Text(l10n.recurring),
                          value: _isRecurring,
                          onChanged: (val) {
                              setState(() {
                                  _isRecurring = val;
                                  if (_isRecurring) _isSplit = false;
                                  _triggerAutosave();
                              });
                          },
                      ),
                      if (_isRecurring) ...[
                          DropdownButtonFormField<RecurrenceFrequency>(
                              value: _frequency,
                              items: RecurrenceFrequency.values.map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                      f == RecurrenceFrequency.daily ? l10n.daily :
                                      f == RecurrenceFrequency.weekly ? l10n.weekly :
                                      f == RecurrenceFrequency.monthly ? l10n.monthly :
                                      l10n.yearly
                                  ),
                              )).toList(),
                              onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _frequency = val;
                                      _triggerAutosave();
                                    });
                                  }
                              },
                              decoration: InputDecoration(labelText: l10n.frequency),
                          ),
                      ],
                      const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 24),

                  if (!isEditing) ...[
                    AppButton.secondary(
                      label: l10n.saveAndAddAnother,
                      onPressed: () {
                         if (_formKey.currentState!.validate()) {
                             if (_selectedAccount == null) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectAccount)));
                                 return;
                             }
                             _saveTransaction(popAfterSave: false);
                         }
                      },
                      icon: Icons.playlist_add,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SplitItem {
  Category? category;
  String? categoryId; // Helper for loading
  double amount = 0;
  String? memo;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController memoController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  SplitItem({this.category, this.categoryId, this.amount = 0, this.memo});

  void dispose() {
    amountController.dispose();
    memoController.dispose();
    categoryController.dispose();
  }
}
