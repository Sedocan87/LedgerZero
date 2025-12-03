import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/screens/payees/widgets/payee_list_item.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';

class PayeesScreen extends ConsumerWidget {
  const PayeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payeesAsync = ref.watch(filteredPayeesProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.payees),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: l10n.searchPayees,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(payeeSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          Expanded(
            child: payeesAsync.when(
              data: (payees) {
                if (payees.isEmpty) {
                  return Center(
                    child: Text(l10n.noPayees),
                  );
                }
                return ListView.builder(
                  itemCount: payees.length,
                  itemBuilder: (context, index) {
                    final payee = payees[index];
                    return PayeeListItem(
                      payee: payee,
                      onTap: () {
                        context.push('/settings/payees/${payee.id}');
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => ErrorView(title: l10n.error, message: err.toString()),
            ),
          ),
        ],
      ),
    );
  }
}
