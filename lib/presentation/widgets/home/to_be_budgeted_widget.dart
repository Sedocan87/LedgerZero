import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

/// The totals the home banner can show, in swipe order.
enum HomeBalancePage { toBeBudgeted, netWorth, inBudget }

/// The pages available for [accounts]: To Be Budgeted always; net worth
/// when all accounts share one currency; the on-budget total only when
/// some account is off budget (otherwise it equals net worth).
List<HomeBalancePage> homeBalancePages(List<Account> accounts) {
  final currencies = accounts.map((a) => a.currency).toSet();
  if (accounts.isEmpty || currencies.length != 1) {
    return const [HomeBalancePage.toBeBudgeted];
  }
  return [
    HomeBalancePage.toBeBudgeted,
    HomeBalancePage.netWorth,
    if (accounts.any((a) => !a.onBudget)) HomeBalancePage.inBudget,
  ];
}

/// Home banner: To Be Budgeted, swipe (or tap) for net worth and the total
/// of the budget accounts. The last page shown is remembered.
class ToBeBudgetedWidget extends ConsumerStatefulWidget {
  const ToBeBudgetedWidget({super.key});

  /// SharedPreferences key of the last page shown ([HomeBalancePage.name]).
  static const pagePrefsKey = 'home_balance_page';

  @override
  ConsumerState<ToBeBudgetedWidget> createState() => _ToBeBudgetedWidgetState();
}

class _ToBeBudgetedWidgetState extends ConsumerState<ToBeBudgetedWidget> {
  late HomeBalancePage _selected;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(ToBeBudgetedWidget.pagePrefsKey);
    _selected =
        HomeBalancePage.values.where((p) => p.name == saved).firstOrNull ??
        HomeBalancePage.toBeBudgeted;
    final pages = homeBalancePages(
      ref.read(accountsProvider).valueOrNull ?? const [],
    );
    _controller = PageController(
      initialPage: pages.indexOf(_selected).clamp(0, pages.length - 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(List<HomeBalancePage> pages, int index) {
    setState(() => _selected = pages[index]);
    ref
        .read(sharedPreferencesProvider)
        .setString(ToBeBudgetedWidget.pagePrefsKey, _selected.name);
  }

  void _showNext(List<HomeBalancePage> pages, int index) {
    _controller.animateToPage(
      (index + 1) % pages.length,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// Keeps the page view on [index] when the available pages change (e.g.
  /// the accounts finished loading and the remembered page appeared).
  void _keepPage(int index) {
    // After the frame: the page view may only be attached by this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _controller.hasClients &&
          !_controller.position.isScrollingNotifier.value &&
          _controller.page?.round() != index) {
        _controller.jumpToPage(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = ref.watch(currentMonthProvider);
    final tbbAsync = ref.watch(tbbProvider(currentMonth));
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return tbbAsync.when(
      // Keep the banner while To Be Budgeted recomputes after a write.
      skipLoadingOnReload: true,
      data: (tbb) {
        final pages = homeBalancePages(accounts);
        // A remembered page that is not available now (e.g. accounts in
        // several currencies) stays remembered; page 1 is shown meanwhile.
        final index = pages.indexOf(_selected).clamp(0, pages.length - 1);
        _keepPage(index);

        final currency = accounts.isEmpty ? null : accounts.first.currency;
        final scheme = theme.colorScheme;
        final contents = [
          for (final page in pages)
            switch (page) {
              HomeBalancePage.toBeBudgeted => _BalanceContent(
                label: l10n.toBeBudgeted,
                amount: tbb,
                amountContext: AmountContext.toBeBudgeted,
                amountColor: tbbAmountColor(context, tbb),
                status: TbbStatusChip(tbb: tbb),
              ),
              HomeBalancePage.netWorth => _BalanceContent(
                label: l10n.netWorth,
                amount: accounts.fold<int>(0, (sum, a) => sum + a.balance),
                currencyCode: currency,
                amountColor: scheme.onSurface,
              ),
              HomeBalancePage.inBudget => _BalanceContent(
                label: l10n.homeBalanceInBudget,
                amount: accounts
                    .where((a) => a.onBudget)
                    .fold<int>(0, (sum, a) => sum + a.balance),
                currencyCode: currency,
                amountColor: scheme.onSurface,
              ),
            },
        ];
        final paged = pages.length > 1;

        // One screen reader node: the page's label and amount, the page
        // position, and tap for the next total.
        return MergeSemantics(
          child: Semantics(
            value: paged ? l10n.homeBalancePage(index + 1, pages.length) : null,
            onTapHint: paged ? l10n.homeBalanceNext : null,
            child: GestureDetector(
              onTap: paged ? () => _showNext(pages, index) : null,
              // The same tonal block as To Be Budgeted on the Budget tab.
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Every page has the same layout: an invisible stand-in
                    // gives the page view its height (it follows the text
                    // scale) without duplicating any text.
                    Stack(
                      children: [
                        const Visibility(
                          visible: false,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: _BalanceContent.sizer(),
                        ),
                        Positioned.fill(
                          child: PageView(
                            controller: _controller,
                            onPageChanged: (i) => _onPageChanged(pages, i),
                            children: contents,
                          ),
                        ),
                      ],
                    ),
                    if (paged) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < pages.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: i == index ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: i == index ? 0.9 : 0.35,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
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
          ),
        );
      },
      loading: () => Container(
        height: 112,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) =>
          LoadErrorView(error: err, stackTrace: stack, compact: true),
    );
  }
}

/// One page of the home banner: the label above a large amount, with the
/// To Be Budgeted status chip beside it on that page.
class _BalanceContent extends StatelessWidget {
  const _BalanceContent({
    required this.label,
    required this.amount,
    required this.amountColor,
    this.amountContext = AmountContext.none,
    this.currencyCode,
    this.status,
  });

  /// Same layout with zero-width text: only used to size the page view.
  const _BalanceContent.sizer()
    : label = '\u200B',
      amount = null,
      amountColor = Colors.transparent,
      amountContext = AmountContext.none,
      currencyCode = null,
      status = const _ChipSizer();

  final String label;

  /// `null` for [_BalanceContent.sizer].
  final int? amount;
  final Color amountColor;
  final AmountContext amountContext;
  final String? currencyCode;

  /// Shown beside the amount (the To Be Budgeted status chip).
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.displaySmall?.tabular.copyWith(
      color: amountColor,
      letterSpacing: -0.5,
    );
    final labelText = Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The To Be Budgeted amount's label already says what it is.
          if (amountContext == AmountContext.toBeBudgeted)
            ExcludeSemantics(child: labelText)
          else
            labelText,
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: amount == null
                      ? Text(label, style: amountStyle)
                      : AmountText(
                          amount!,
                          currencyCode: currencyCode,
                          amountContext: amountContext,
                          maxLines: 1,
                          style: amountStyle,
                        ),
                ),
              ),
              if (status case final status?) ...[
                const SizedBox(width: 10),
                status,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// An empty status chip of the real one's height, for the sizer.
class _ChipSizer extends StatelessWidget {
  const _ChipSizer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('\u200B', style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
