import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

class PayeeDetailScreen extends ConsumerStatefulWidget {
  final String payeeId;

  const PayeeDetailScreen({super.key, required this.payeeId});

  @override
  ConsumerState<PayeeDetailScreen> createState() => _PayeeDetailScreenState();
}

class _PayeeDetailScreenState extends ConsumerState<PayeeDetailScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _notesFocusNode = FocusNode();

  bool _isEditing = false;
  bool _notesDirty = false;

  @override
  void initState() {
    super.initState();
    _notesFocusNode.addListener(_onNotesFocusChange);
  }

  @override
  void dispose() {
    _notesFocusNode.removeListener(_onNotesFocusChange);
    _notesFocusNode.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onNotesFocusChange() {
    if (!_notesFocusNode.hasFocus && _notesDirty) {
      _notesDirty = false;
      _saveNotes(_notesController.text);
    }
  }

  /// Reads the current row (not a possibly stale stream value) and saves
  /// the notes on it.
  Future<void> _saveNotes(String notes) async {
    final payee = await ref
        .read(payeeRepositoryProvider)
        .getPayeeById(widget.payeeId);
    if (payee != null) {
      await _updatePayee(payee.copyWith(notes: notes));
    }
  }

  /// The detail providers follow the database, so no refresh is needed.
  Future<void> _updatePayee(Payee payee) =>
      ref.read(payeeControllerProvider).updatePayee(payee);

  void _deletePayee(BuildContext context, Payee payee) {
    final l10n = AppLocalizations.of(context)!;

    // Always show dialog for safety
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePayeeConfirmation),
        content: Text(l10n.deletePayeeWarning(payee.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(payeeControllerProvider)
                    .deletePayee(widget.payeeId);
              } catch (e, st) {
                Logger.error('Deleting payee ${widget.payeeId} failed', e, st);
                if (context.mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context); // Dialog
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.deletePayeeFailed)),
                  );
                }
                return;
              }
              if (context.mounted) {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Screen
              }
            },
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(BuildContext context, Payee sourcePayee) {
    showDialog(
      context: context,
      builder: (context) => MergePayeeDialog(sourcePayee: sourcePayee),
    );
  }

  void _showIconPicker(BuildContext context, Payee payee) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.icon),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.none,
                  onPressed: () {
                    _updatePayee(
                      Payee(
                        id: payee.id,
                        name: payee.name,
                        autoCategoryId: payee.autoCategoryId,
                        defaultAccountId: payee.defaultAccountId,
                        createdAt: payee.createdAt,
                        icon: null,
                        color: payee.color,
                        notes: payee.notes,
                        isFavorite: payee.isFavorite,
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
                ...categoryIcons.entries.map((entry) {
                  return IconButton(
                    icon: Icon(entry.value),
                    color: payee.icon == entry.key
                        ? Theme.of(context).primaryColor
                        : null,
                    onPressed: () {
                      _updatePayee(payee.copyWith(icon: entry.key));
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Payee payee) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.color),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  _updatePayee(
                    Payee(
                      id: payee.id,
                      name: payee.name,
                      autoCategoryId: payee.autoCategoryId,
                      defaultAccountId: payee.defaultAccountId,
                      createdAt: payee.createdAt,
                      icon: payee.icon,
                      color: null,
                      notes: payee.notes,
                      isFavorite: payee.isFavorite,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
              ...categoryColors.map((colorValue) {
                return GestureDetector(
                  onTap: () {
                    _updatePayee(payee.copyWith(color: colorValue));
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                      border: payee.color == colorValue
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payeeAsync = ref.watch(payeeProvider(widget.payeeId));
    final transactionsAsync = ref.watch(
      payeeTransactionsProvider(widget.payeeId),
    );
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final l10n = AppLocalizations.of(context)!;

    final categoriesMap = ref.watch(categoryMapProvider).valueOrNull ?? {};
    final accountsMap = ref.watch(accountMapProvider).valueOrNull ?? {};
    final accountCurrencies = {
      for (final a in accountsAsync.valueOrNull ?? const <Account>[])
        a.id: a.currency,
    };

    return payeeAsync.when(
      data: (payee) {
        if (payee == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.unknownPayee)),
            body: Center(child: Text(l10n.unknownPayee)),
          );
        }

        // Initialize controllers if not editing to keep them in sync
        if (!_notesFocusNode.hasFocus) {
          if (_notesController.text != (payee.notes ?? '')) {
            _notesController.text = payee.notes ?? '';
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: _isEditing
                ? TextField(
                    controller: _nameController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n.payeeName,
                    ),
                    autofocus: true,
                  )
                : Text(payee.name),
            actions: [
              IconButton(
                icon: Icon(payee.isFavorite ? Icons.star : Icons.star_border),
                color: payee.isFavorite ? Colors.amber : null,
                tooltip: payee.isFavorite
                    ? l10n.removeFromFavorites
                    : l10n.addToFavorites,
                onPressed: () =>
                    _updatePayee(payee.copyWith(isFavorite: !payee.isFavorite)),
              ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      await _updatePayee(payee.copyWith(name: name));
                      if (mounted) {
                        setState(() => _isEditing = false);
                      }
                    }
                  },
                )
              else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _nameController.text = payee.name;
                      setState(() => _isEditing = true);
                    } else if (value == 'merge') {
                      _showMergeDialog(context, payee);
                    } else if (value == 'delete') {
                      _deletePayee(context, payee);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.rename)),
                    PopupMenuItem(value: 'merge', child: Text(l10n.merge)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.delete,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  // Stats & Settings
                  transactionsAsync.when(
                    data: (transactions) {
                      // A split counts once, through its parent; its
                      // children would otherwise be counted twice.
                      final counted = transactions
                          .where((t) => t.parentTransactionId == null)
                          .toList();
                      final count = counted.length;
                      final fmt = ref.watch(appFormatterProvider);
                      final totalSpent = counted.fold<int>(
                        0,
                        (sum, t) => sum + (t.amount < 0 ? -t.amount : 0),
                      );
                      // Show the account currency when every transaction
                      // uses the same one.
                      final currencies = counted
                          .map((t) => accountCurrencies[t.accountId])
                          .toSet();
                      final totalCurrency = currencies.length == 1
                          ? currencies.single
                          : null;
                      final lastUsed = transactions.isNotEmpty
                          ? transactions.first.date
                          : null;

                      return Card(
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.usageStats,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _StatItem(
                                    label: l10n.timesUsed,
                                    value: count.toString(),
                                  ),
                                  _StatItem(
                                    label: l10n.totalSpent,
                                    value: fmt.formatMoney(
                                      totalSpent,
                                      currencyCode: totalCurrency,
                                    ),
                                  ),
                                  _StatItem(
                                    label: l10n.lastUsed,
                                    value: lastUsed != null
                                        ? fmt.formatDate(lastUsed)
                                        : '-',
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Configuration
                              Text(
                                l10n.configuration,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),

                              // Icon & Color
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          _showIconPicker(context, payee),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              payee.icon != null
                                                  ? categoryIcons[payee.icon] ??
                                                        Icons.category
                                                  : Icons.category,
                                              color: payee.color != null
                                                  ? Color(payee.color!)
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.icon,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                                Text(
                                                  payee.icon ??
                                                      l10n.defaultLabel,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          _showColorPicker(context, payee),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  payee.color != null
                                                  ? Color(payee.color!)
                                                  : Colors.grey,
                                              radius: 12,
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.color,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                                Text(
                                                  payee.color != null
                                                      ? l10n.custom
                                                      : l10n.defaultLabel,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Auto Category
                              categoriesAsync.when(
                                data: (categories) =>
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'cat_${payee.autoCategoryId}',
                                      ),
                                      decoration: InputDecoration(
                                        labelText: l10n.autoCategory,
                                      ),
                                      initialValue: payee.autoCategoryId,
                                      isExpanded: true,
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text(l10n.none),
                                        ),
                                        ...categories.map(
                                          (c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(
                                              c.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != payee.autoCategoryId) {
                                          _updatePayee(
                                            payee.copyWith(
                                              autoCategoryId: value,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                loading: () => const LinearProgressIndicator(),
                                error: (_, _) => const SizedBox(),
                              ),
                              const SizedBox(height: 8),

                              // Default Account
                              accountsAsync.when(
                                data: (accounts) =>
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'acc_${payee.defaultAccountId}',
                                      ),
                                      decoration: InputDecoration(
                                        labelText: l10n.defaultAccount,
                                      ),
                                      initialValue: payee.defaultAccountId,
                                      isExpanded: true,
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text(l10n.none),
                                        ),
                                        ...accounts.map(
                                          (a) => DropdownMenuItem(
                                            value: a.id,
                                            child: Text(
                                              a.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != payee.defaultAccountId) {
                                          _updatePayee(
                                            payee.copyWith(
                                              defaultAccountId: value,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                loading: () => const LinearProgressIndicator(),
                                error: (_, _) => const SizedBox(),
                              ),
                              const SizedBox(height: 8),

                              // Notes
                              TextFormField(
                                controller: _notesController,
                                focusNode: _notesFocusNode,
                                decoration: InputDecoration(
                                  labelText: l10n.notes,
                                ),
                                maxLines: 2,
                                onChanged: (_) {
                                  _notesDirty = true;
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox(),
                  ),

                  Expanded(
                    child: transactionsAsync.when(
                      data: (transactions) {
                        if (transactions.isEmpty) {
                          return Center(child: Text(l10n.noTransactions));
                        }
                        return ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return TransactionListItem(
                              transaction: tx,
                              payeeName: payee.name,
                              categoryName: categoriesMap[tx.categoryId],
                              accountName: accountsMap[tx.accountId],
                              currencyCode: accountCurrencies[tx.accountId],
                              onTap: () {
                                context.push('/edit-transaction/${tx.id}');
                              },
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, s) => LoadErrorView(error: e, stackTrace: s),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        body: LoadErrorView(error: err, stackTrace: stack),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class MergePayeeDialog extends ConsumerStatefulWidget {
  final Payee sourcePayee;
  const MergePayeeDialog({super.key, required this.sourcePayee});

  @override
  ConsumerState<MergePayeeDialog> createState() => _MergePayeeDialogState();
}

class _MergePayeeDialogState extends ConsumerState<MergePayeeDialog> {
  String? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    final payeesAsync = ref.watch(payeesProvider);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.mergePayee),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.mergePayeeInto(widget.sourcePayee.name)),
          const SizedBox(height: 16),
          payeesAsync.when(
            data: (payees) {
              final candidates =
                  payees.where((p) => p.id != widget.sourcePayee.id).toList()
                    ..sort(
                      (a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                    );

              if (candidates.isEmpty) {
                return Text(l10n.noPayees);
              }
              return DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l10n.payee),
                items: candidates
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTargetId = value;
                  });
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text(l10n.error),
          ),
          const SizedBox(height: 8),
          if (_selectedTargetId != null)
            payeesAsync.maybeWhen(
              data: (payees) {
                final targetName = payees
                    .firstWhere((p) => p.id == _selectedTargetId)
                    .name;
                return Text(
                  l10n.mergeWarning(targetName),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _selectedTargetId == null
              ? null
              : () async {
                  try {
                    await ref
                        .read(payeeControllerProvider)
                        .mergePayees(widget.sourcePayee.id, _selectedTargetId!);
                  } catch (e, st) {
                    Logger.error(
                      'Merging payee ${widget.sourcePayee.id} failed',
                      e,
                      st,
                    );
                    if (context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context); // Close dialog
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.mergePayeeFailed)),
                      );
                    }
                    return;
                  }
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close detail screen
                  }
                },
          child: Text(l10n.merge),
        ),
      ],
    );
  }
}
