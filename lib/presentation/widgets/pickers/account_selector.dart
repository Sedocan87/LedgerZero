import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

class AccountSelector extends ConsumerWidget {
  final ValueChanged<Account> onSelected;

  const AccountSelector({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final l10n = AppLocalizations.of(context)!;

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
              subtitle: Text(account.type.label(l10n)),
              leading: const Icon(Icons.account_balance),
              onTap: () {
                onSelected(account);
                Navigator.pop(context);
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            LoadErrorView(error: err, stackTrace: stack, compact: true),
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
