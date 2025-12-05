import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/home_empty_state.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/to_be_budgeted_widget.dart';

final hasAccountsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final accounts = await ref.watch(accountRepositoryProvider).getAllAccounts();
  return accounts.isNotEmpty;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Check backup status on home screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backupSchedulerProvider).checkBackupDue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAccountsAsync = ref.watch(hasAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.home),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: AppLocalizations.of(context)!.settings,
          ),
        ],
      ),
      body: SafeArea(
        child: hasAccountsAsync.when(
          data: (hasAccounts) {
            if (!hasAccounts) {
              return const HomeEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async {
                final now = DateTime.now();
                final currentMonth = DateTime(now.year, now.month);

                // Trigger sync alongside data refresh
                await Future.wait([
                  ref.refresh(tbbProvider(currentMonth).future),
                  ref.refresh(monthlyStatsProvider(currentMonth).future),
                  ref.refresh(recentTransactionsProvider.future),
                  ref.read(syncControllerProvider.notifier).syncNow(),
                ]);
              },
              child: const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ToBeBudgetedWidget(),
                    SizedBox(height: 16),
                    DashboardStatsWidget(),
                    SizedBox(height: 16),
                    RecentTransactionsWidget(),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-transaction'),
        tooltip: AppLocalizations.of(context)!.addTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}
