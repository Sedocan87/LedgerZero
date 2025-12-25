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
import 'package:ledger_zero/core/constants/dimensions.dart';

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

  Future<void> _refreshHome() async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    // Trigger sync alongside data refresh
    await Future.wait([
      ref.refresh(tbbProvider(currentMonth).future),
      ref.refresh(monthlyStatsProvider(currentMonth).future),
      ref.refresh(recentTransactionsProvider.future),
      ref.read(syncControllerProvider.notifier).syncNow(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final hasAccountsAsync = ref.watch(hasAccountsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.home),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: l10n.settings,
          ),
        ],
      ),
      body: hasAccountsAsync.when(
        data: (hasAccounts) {
          if (!hasAccounts) {
            return const HomeEmptyState();
          }
          return RefreshIndicator(
            onRefresh: _refreshHome,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const ToBeBudgetedWidget(),
                      const SizedBox(height: AppSpacing.md),
                      const DashboardStatsWidget(),
                      const SizedBox(height: AppSpacing.md),
                      const RecentTransactionsWidget(),
                      // Add extra padding at bottom for FAB
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: hasAccountsAsync.valueOrNull == true
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/add-transaction'),
              tooltip: l10n.addTransaction,
              icon: const Icon(Icons.add),
              label: Text(l10n.addTransaction),
            )
          : null,
    );
  }
}
