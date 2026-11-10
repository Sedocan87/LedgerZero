import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/core/constants/category_icon_resolver.dart';
import 'package:ledger_zero/core/constants/icon_tint.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';

/// One row of a transaction list (the Transactions tab, an account's and a
/// payee's transactions, Home's recent ones): a plain row, no card.
///
/// `[category badge] [payee / "Category · Account"] [amount] [cleared]`.
/// The badge shows the [category]'s icon and colour; a transfer gets a swap
/// icon, a split a call-split icon and an uncategorised row the default tag
/// icon, all three on a neutral badge.
class TransactionListItem extends ConsumerWidget {
  final Transaction transaction;
  final String? payeeName;

  /// The second line's label: the category's name, "Transfer" or "Split"
  /// (`null` reads "Uncategorized").
  final String? categoryName;

  /// The category the badge is drawn for; `null` for a transfer, a split or
  /// an uncategorised row.
  final Category? category;

  /// The row is a split parent (call-split badge).
  final bool isSplit;
  final String? accountName;

  /// Currency of the transaction's account; `null` uses the Settings
  /// currency.
  final String? currencyCode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<TransactionClearStatus>? onClearStatusChanged;
  final bool isSelected;
  final bool isSelectionMode;

  /// Whether the row shows its date. Off where the list already has a
  /// heading for each day.
  final bool showDate;

  /// Whether the cleared status is shown at the end of the row.
  final bool showClearedStatus;

  /// A hairline above the row, inset to the text (rows that follow another
  /// row).
  final bool showDivider;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.payeeName,
    this.categoryName,
    this.category,
    this.isSplit = false,
    this.accountName,
    this.currencyCode,
    this.onTap,
    this.onLongPress,
    this.onClearStatusChanged,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.showDate = true,
    this.showClearedStatus = true,
    this.showDivider = false,
  });

  /// Left edge of the row's text: the divider starts here.
  static const double textInset = _hPadding + _badgeSize + _gap;
  static const double _hPadding = 16;
  static const double _badgeSize = 40;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final subtitle = [
      categoryName ?? l10n.uncategorized,
      ?accountName,
    ].join(' · ');
    final cleared = showClearedStatus && !isSelectionMode;

    final row = LayoutBuilder(
      builder: (context, constraints) {
        // The whole row's width (padding included): at most 36 % of it
        // goes to the amount.
        final amountMaxWidth = constraints.maxWidth * 0.36;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            _hPadding,
            8,
            cleared ? 4 : _hPadding,
            8,
          ),
          child: Row(
            children: [
              SizedBox(
                width: _badgeSize,
                height: _badgeSize,
                child: isSelectionMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) => onTap?.call(),
                      )
                    : _CategoryBadge(
                        transaction: transaction,
                        category: category,
                        isSplit: isSplit,
                      ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            payeeName ?? l10n.transactionNoPayee,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!transaction.approved) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: l10n.transactionNotApproved,
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: scheme.tertiary,
                              semanticLabel: l10n.transactionNotApproved,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // A long amount (large text, "-12.345,67 €") shrinks rather than
              // squeezing the payee out or overflowing the row.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: amountMaxWidth),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AmountText(
                        transaction.amount,
                        currencyCode: currencyCode,
                        amountContext: AmountContext.transaction,
                        signed: true,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _amountColor(theme, transaction.amount),
                          fontWeight: FontWeight.w600,
                          fontFeatures: _tabularFigures,
                        ),
                      ),
                      if (showDate) ...[
                        const SizedBox(height: 2),
                        Text(
                          fmt.formatDate(transaction.date),
                          style: secondary?.copyWith(
                            fontFeatures: _tabularFigures,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (cleared) _buildClearedStatus(context, l10n),
            ],
          ),
        );
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: textInset,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        Semantics(
          selected: isSelectionMode ? isSelected : null,
          child: Material(
            // Selected rows in multi-select get a tonal highlight.
            color: isSelected ? scheme.secondaryContainer : Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Center(child: row),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Cleared status indicator
  //
  // The icon stays 20 px; the tappable area is at least
  // kMinInteractiveDimension (48 x 48).
  Widget _buildClearedStatus(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final (
      IconData icon,
      Color color,
      String status,
    ) = switch (transaction.cleared) {
      TransactionClearStatus.reconciled => (
        Icons.lock,
        _successColor(theme),
        l10n.transactionStatusReconciled,
      ),
      TransactionClearStatus.cleared => (
        Icons.check_circle,
        _successColor(theme),
        l10n.cleared,
      ),
      TransactionClearStatus.uncleared => (
        Icons.check_circle_outline,
        theme.colorScheme.onSurfaceVariant,
        l10n.uncleared,
      ),
    };

    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: onClearStatusChanged != null
          ? l10n.transactionClearStatusTooltip(status)
          : status,
      onPressed: onClearStatusChanged == null
          ? null
          : () {
              final next = transaction.cleared == TransactionClearStatus.cleared
                  ? TransactionClearStatus.uncleared
                  : TransactionClearStatus.cleared;
              onClearStatusChanged!(next);
            },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: kMinInteractiveDimension,
        minHeight: kMinInteractiveDimension,
      ),
    );
  }
}

/// The rounded square at the start of a row: the category's icon on a faint
/// badge of its colour, or a neutral one for a transfer, a split or no
/// category.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({
    required this.transaction,
    required this.category,
    required this.isSplit,
  });

  final Transaction transaction;
  final Category? category;
  final bool isSplit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = this.category;
    final IconData icon;
    final Color tint;
    final Color fill;
    if (transaction.transferAccountId == null && !isSplit && category != null) {
      icon = CategoryIconResolver.iconFor(
        icon: category.icon,
        id: category.id,
        name: category.name,
      );
      tint = CategoryIconResolver.tintFor(
        color: category.color,
        icon: category.icon,
        id: category.id,
        name: category.name,
        brightness: theme.brightness,
      );
      fill = tint.withValues(alpha: IconTint.badgeAlpha);
    } else {
      icon = transaction.transferAccountId != null
          ? Icons.swap_horiz_rounded
          : isSplit
          ? Icons.call_split_rounded
          : defaultCategoryIcon;
      tint = scheme.onSurfaceVariant;
      fill = scheme.surfaceContainerHighest;
    }
    return Container(
      key: const Key('transaction.badge'),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: tint),
    );
  }
}

// Amount style of the rows. Kept together so the theme's helpers (tabular
// figures, semantic colours; DESIGN.md §1-§2) can replace them in one place.
const _tabularFigures = [FontFeature.tabularFigures()];

Color _successColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? Colors.green.shade300
    : AppColors.success;

/// Inflows in the success colour (with a "+"), outflows in the text colour.
Color _amountColor(ThemeData theme, int amount) =>
    amount > 0 ? _successColor(theme) : theme.colorScheme.onSurface;
