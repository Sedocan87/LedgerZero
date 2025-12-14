import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';

class PayeeSelector extends ConsumerWidget {
  final ValueChanged<Payee> onSelected;

  const PayeeSelector({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We use all payees here, but suggestedPayeesProvider is also fine
    final payeesAsync = ref.watch(payeesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => payeesAsync.when(
        data: (payees) {
          // Sort payees alphabetically
          final sorted = List<Payee>.from(payees)
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Payee',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final payee = sorted[index];
                    return ListTile(
                      title: Text(payee.name),
                      leading: const Icon(Icons.store),
                      onTap: () {
                        onSelected(payee);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  static void show(BuildContext context, ValueChanged<Payee> onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PayeeSelector(onSelected: onSelected),
    );
  }
}
