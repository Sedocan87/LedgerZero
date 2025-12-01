import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_list_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';
import 'package:ledger_zero/presentation/widgets/common/loading_indicator.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/accounts/widgets/account_card.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_sort_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_filter_provider.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountListProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '${l10n.accounts}...', // Or a localized "Search"
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleLarge,
                onChanged: (value) {
                  ref
                      .read(accountFilterProvider.notifier)
                      .update((state) => state.copyWith(searchQuery: value));
                },
              )
            : Text(l10n.accounts),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  ref
                      .read(accountFilterProvider.notifier)
                      .update((state) => state.copyWith(searchQuery: ''));
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'showClosed') {
                final current = ref.read(accountFilterProvider);
                ref.read(accountFilterProvider.notifier).state =
                    current.copyWith(showClosed: !current.showClosed);
              }
            },
            itemBuilder: (context) {
              final filter = ref.read(accountFilterProvider);
              return [
                CheckedPopupMenuItem(
                  value: 'showClosed',
                  checked: filter.showClosed,
                  child: const Text('Show Closed Accounts'),
                ),
              ];
            },
          ),
          PopupMenuButton<AccountSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              ref.read(accountSortProvider.notifier).state = option;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AccountSortOption.nameAsc,
                child: Text('Name (A-Z)'),
              ),
              const PopupMenuItem(
                value: AccountSortOption.nameDesc,
                child: Text('Name (Z-A)'),
              ),
              const PopupMenuItem(
                value: AccountSortOption.balanceAsc,
                child: Text('Balance (Low-High)'),
              ),
              const PopupMenuItem(
                value: AccountSortOption.balanceDesc,
                child: Text('Balance (High-Low)'),
              ),
              const PopupMenuItem(
                value: AccountSortOption.type,
                child: Text('Type'),
              ),
            ],
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSearching
                          ? 'No accounts found'
                          : l10n.createFirstAccountMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: AccountCard(
                      account: account,
                      onTap: () {
                        context.goNamed('account-detail',
                            pathParameters: {'id': account.id});
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorView(
          title: 'Error',
          message: error.toString(),
          onRetry: () => ref.refresh(accountListProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.goNamed('add-account');
        },
        tooltip: l10n.createAccount,
        child: const Icon(Icons.add),
      ),
    );
  }
}
