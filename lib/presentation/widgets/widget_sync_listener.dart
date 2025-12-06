import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

class WidgetSyncListener extends ConsumerWidget {
  final Widget child;

  const WidgetSyncListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to transaction changes
    ref.listen(transactionsStreamProvider, (previous, next) {
      if (next.hasValue) {
        ref.read(widgetServiceProvider).updateWidgetData();
      }
    });

    return child;
  }
}

// Helper provider to expose the stream
final transactionsStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTransactions().map((_) {});
});
