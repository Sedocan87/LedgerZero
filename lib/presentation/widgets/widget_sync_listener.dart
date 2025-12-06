import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

class WidgetSyncListener extends ConsumerStatefulWidget {
  final Widget child;

  const WidgetSyncListener({super.key, required this.child});

  @override
  ConsumerState<WidgetSyncListener> createState() => _WidgetSyncListenerState();
}

class _WidgetSyncListenerState extends ConsumerState<WidgetSyncListener> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTransactionUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(widgetServiceProvider).updateWidgetData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to transaction changes
    ref.listen(transactionsStreamProvider, (previous, next) {
      if (next.hasValue) {
        _onTransactionUpdate();
      }
    });

    return widget.child;
  }
}

// Helper provider to expose the stream
final transactionsStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTransactions().map((_) {});
});
