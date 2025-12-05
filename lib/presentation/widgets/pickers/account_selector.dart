import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';

class AccountSelector extends ConsumerWidget {
  final ValueChanged<Account> onSelected;

  const AccountSelector({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => accountsAsync.when(
        data: (accounts) => ListView.builder(
          controller: scrollController,
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return ListTile(
              title: Text(account.name),
              subtitle: Text(account.type.name.toUpperCase()),
              leading: const Icon(Icons.account_balance),
              onTap: () {
                onSelected(account);
                Navigator.pop(context);
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  static void show(BuildContext context, ValueChanged<Account> onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AccountSelector(onSelected: onSelected),
    );
  }
}
