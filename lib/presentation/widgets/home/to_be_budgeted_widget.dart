import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/app/theme.dart';
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
        final contents = [
          for (final page in pages)
            switch (page) {
              HomeBalancePage.toBeBudgeted => _tbbContent(tbb),
              HomeBalancePage.netWorth => _BalanceContent(
                icon: Icons.trending_up_rounded,
                label: l10n.netWorth,
                amount: accounts.fold<int>(0, (sum, a) => sum + a.balance),
                currencyCode: currency,
                textColor: Colors.white,
              ),
              HomeBalancePage.inBudget => _BalanceContent(
                icon: Icons.account_balance_outlined,
                label: l10n.homeBalanceInBudget,
                amount: accounts
                    .where((a) => a.onBudget)
                    .fold<int>(0, (sum, a) => sum + a.balance),
                currencyCode: currency,
                textColor: Colors.white,
              ),
            },
        ];
        final (gradientColors, textColor) = switch (pages[index]) {
          HomeBalancePage.toBeBudgeted => _tbbColors(tbb, theme),
          HomeBalancePage.netWorth => (
            const [Color(0xFF004D40), Color(0xFF00796B)],
            Colors.white,
          ),
          HomeBalancePage.inBudget => (
            const [Color(0xFF263238), Color(0xFF455A64)],
            Colors.white,
          ),
        };
        final paged = pages.length > 1;

        // One screen reader node: the page's label and amount, the page
        // position, and tap for the next total.
        return MergeSemantics(
          child: Semantics(
            value: paged ? l10n.homeBalancePage(index + 1, pages.length) : null,
            onTapHint: paged ? l10n.homeBalanceNext : null,
            child: GestureDetector(
              onTap: paged ? () => _showNext(pages, index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg + 4,
                ),
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
                      const SizedBox(height: AppSpacing.md),
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
                                  color: textColor.withValues(
                                    alpha: i == index ? 0.9 : 0.4,
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
        height: 128,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) =>
          LoadErrorView(error: err, stackTrace: stack, compact: true),
    );
  }

  /// Gradient and text colour of the To Be Budgeted page. White text on the
  /// fixed green / red gradients, the theme's text colour on the neutral one.
  (List<Color>, Color) _tbbColors(int tbb, ThemeData theme) {
    if (tbb > 0) {
      return (const [Color(0xFF1B5E20), AppColors.success], Colors.white);
    } else if (tbb < 0) {
      return (const [Color(0xFF8E0000), AppColors.expense], Colors.white);
    }
    return (
      [
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.surfaceContainer,
      ],
      theme.colorScheme.onSurface,
    );
  }

  Widget _tbbContent(int tbb) {
    final theme = Theme.of(context);
    return _BalanceContent(
      icon: Icons.account_balance_wallet_outlined,
      label: AppLocalizations.of(context)!.toBeBudgeted,
      amount: tbb,
      amountContext: AmountContext.toBeBudgeted,
      textColor: _tbbColors(tbb, theme).$2,
    );
  }
}

/// One page of the home banner: a pill label above a large amount.
class _BalanceContent extends StatelessWidget {
  const _BalanceContent({
    required this.icon,
    required this.label,
    required this.amount,
    required this.textColor,
    this.amountContext = AmountContext.none,
    this.currencyCode,
  });

  /// Same layout with zero-width text: only used to size the page view.
  const _BalanceContent.sizer()
    : icon = Icons.circle,
      label = '\u200B',
      amount = null,
      textColor = Colors.transparent,
      amountContext = AmountContext.none,
      currencyCode = null;

  final IconData icon;
  final String label;

  /// `null` for [_BalanceContent.sizer].
  final int? amount;
  final Color textColor;
  final AmountContext amountContext;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.displaySmall?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    );
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor.withValues(alpha: 0.9),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The To Be Budgeted amount's label already says what it is.
          if (amountContext == AmountContext.toBeBudgeted)
            ExcludeSemantics(child: pill)
          else
            pill,
          const SizedBox(height: AppSpacing.md),
          if (amount case final amount?)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AmountText(
                amount,
                currencyCode: currencyCode,
                amountContext: amountContext,
                style: amountStyle,
              ),
            )
          else
            Text(label, style: amountStyle),
        ],
      ),
    );
  }
}
