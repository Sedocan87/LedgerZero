import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_list_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/empty_state.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/screens/accounts/widgets/account_card.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_sort_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_filter_provider.dart';

/// Remembers that the hint above the partner's accounts was dismissed.
const partnerAccountsHintKey = 'hint_partner_accounts_seen';

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
                  hintText: l10n.accountSearchHint,
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
              tooltip: l10n.clearSearch,
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
              tooltip: l10n.search,
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.filter,
            onSelected: (value) {
              if (value == 'showClosed') {
                final current = ref.read(accountFilterProvider);
                ref.read(accountFilterProvider.notifier).state = current
                    .copyWith(showClosed: !current.showClosed);
              }
            },
            itemBuilder: (context) {
              final filter = ref.read(accountFilterProvider);
              return [
                CheckedPopupMenuItem(
                  value: 'showClosed',
                  checked: filter.showClosed,
                  child: Text(l10n.accountShowClosed),
                ),
              ];
            },
          ),
          const InfoButton(HelpTopic.accounts),
          PopupMenuButton<AccountSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.sort,
            onSelected: (option) {
              ref.read(accountSortProvider.notifier).state = option;
            },
            itemBuilder: (context) => [
              for (final option in AccountSortOption.values)
                PopupMenuItem(value: option, child: Text(option.label(l10n))),
            ],
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            if (_isSearching) {
              return Center(child: Text(l10n.noMatchingAccounts));
            }
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: l10n.noAccountsYet,
              description: l10n.createFirstAccountMessage,
              actionLabel: l10n.createAccount,
              onAction: () => context.push('/accounts/add?first=1'),
            );
          }
          final currencies = accounts.map((a) => a.currency).toSet();
          final showTotalBanner = accounts.length > 1 && currencies.length == 1;
          // The partner's personal accounts come last, under their own
          // header.
          final own = accounts.where((a) => !a.isPartners).toList();
          final partners = accounts.where((a) => a.isPartners).toList();

          Widget card(Account account) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 5,
            ),
            child: AccountCard(
              account: account,
              onTap: () {
                context.goNamed(
                  'account-detail',
                  pathParameters: {'id': account.id},
                );
              },
            ),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, 88),
                children: [
                  if (showTotalBanner)
                    _NetWorthBanner(
                      accounts: accounts,
                      currency: currencies.first,
                    ),
                  for (final account in own) card(account),
                  if (partners.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md + 4,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.accountsPartnerSection,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    OneTimeHintCard(
                      prefsKey: partnerAccountsHintKey,
                      text: l10n.hintPartnerAccounts,
                      topic: HelpTopic.personal,
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                    ),
                    for (final account in partners) card(account),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => const AppLoadingIndicator(),
        error: (error, stack) => LoadErrorView(
          error: error,
          stackTrace: stack,
          onRetry: () => ref.invalidate(accountsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'accounts-fab',
        onPressed: () {
          context.goNamed('add-account');
        },
        tooltip: l10n.createAccount,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Net worth of all accounts. With personal accounts in the household, a
/// line below splits it into shared, this user's and the partner's part.
class _NetWorthBanner extends ConsumerWidget {
  const _NetWorthBanner({required this.accounts, required this.currency});

  final List<Account> accounts;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    int sum(AccountOwner owner) => accounts
        .where((a) => a.owner == owner)
        .fold<int>(0, (total, a) => total + a.balance);
    final total = accounts.fold<int>(0, (sum, a) => sum + a.balance);
    final split = accounts.any((a) => a.isPersonal);
    final onBanner = scheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Card(
        color: scheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.netWorth,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onBanner,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fmt.formatMoney(total, currencyCode: currency),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: onBanner,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (split) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final (label, owner) in [
                  (l10n.netWorthShared, AccountOwner.shared),
                  (l10n.netWorthMine, AccountOwner.me),
                  (l10n.netWorthPartner, AccountOwner.partner),
                ])
                  if (accounts.any((a) => a.owner == owner))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        key: Key('netWorth.${owner.name}'),
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: onBanner,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            fmt.formatMoney(sum(owner), currencyCode: currency),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onBanner,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
