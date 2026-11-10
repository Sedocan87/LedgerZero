import 'package:flutter/material.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/enum_labels.dart';
import 'package:ledger_zero/presentation/widgets/common/account_avatar.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';

/// One row of the accounts list: a plain row, no card.
///
/// `[account badge] [name / "Type · Personal"] [balance]`. Whether the
/// account is in the budget, off budget or closed is said by the group
/// heading the row sits under.
class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;

  /// A hairline above the row, inset to the text (rows that follow another
  /// row of the same group).
  final bool showDivider;

  const AccountCard({
    super.key,
    required this.account,
    this.onTap,
    this.showDivider = false,
  });

  /// Left edge of the row's text: the divider starts here.
  static const double textInset = 16 + 40 + 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final typeName = l10n == null
        ? account.type.name
        : account.type.label(l10n);
    // A personal account is always off budget: its owner says enough.
    final owner = switch (account.owner) {
      AccountOwner.me => l10n?.accountPersonalBadge,
      AccountOwner.partner => l10n?.accountPartnerBadge,
      AccountOwner.shared => null,
    };

    final row = LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AccountAvatar(account: account, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [typeName, ?owner].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amounts are shown in the account's own currency. A long one
            // shrinks rather than squeezing the name out.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: AmountText(
                  account.balance,
                  currencyCode: account.currency,
                  amountContext: AmountContext.balance,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _balanceColor(theme, account),
                    fontWeight: FontWeight.w600,
                    fontFeatures: _tabularFigures,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
        InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Center(child: row),
          ),
        ),
      ],
    );
  }
}

// Amount style of the accounts list. Kept together so the theme's helpers
// (tabular figures, semantic colours; DESIGN.md §1-§2) can replace them in
// one place.
const _tabularFigures = [FontFeature.tabularFigures()];

/// The text colour, except an overdrawn account (below zero; a credit card
/// below zero is just its debt, not a state to flag).
Color _balanceColor(ThemeData theme, Account account) =>
    account.balance < 0 && account.type != AccountType.credit
    ? (theme.brightness == Brightness.dark
          ? Colors.red.shade300
          : AppColors.expense)
    : theme.colorScheme.onSurface;
