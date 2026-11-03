import 'package:flutter/material.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/domain/entities/account.dart';

/// The icons offered by the account editor, by the key stored in
/// `Account.icon`.
const Map<String, IconData> accountIconOptions = {
  'Wallet': Icons.account_balance_wallet,
  'Bank': Icons.account_balance,
  'Card': Icons.credit_card,
  'Cash': Icons.attach_money,
  'Savings': Icons.savings,
  'Investment': Icons.trending_up,
};

/// Colour and icon the editor saved on every account before they were shown
/// anywhere (green wallet). An account carrying exactly this pair was never
/// customised, so it keeps its type's look.
const int legacyDefaultAccountColor = 0xFF4CAF50;
const String legacyDefaultAccountIcon = 'Wallet';

/// The account's own colour and icon, or `null` where it uses its type's.
({int? color, String? icon}) accountCustomAppearance(Account account) {
  if (account.color == legacyDefaultAccountColor &&
      account.icon == legacyDefaultAccountIcon) {
    return (color: null, icon: null);
  }
  return (
    color: account.color,
    icon: accountIconOptions.containsKey(account.icon) ? account.icon : null,
  );
}

/// The icon and accent colour an account is shown with: the ones picked in
/// the editor, else its type's defaults.
({IconData icon, Color color}) accountAppearance(
  Account account,
  ThemeData theme,
) {
  final isDark = theme.brightness == Brightness.dark;
  final (IconData typeIcon, Color typeColor) = switch (account.type) {
    AccountType.checking => (
      Icons.account_balance_rounded,
      theme.colorScheme.primary,
    ),
    AccountType.savings => (
      Icons.savings_rounded,
      isDark ? Colors.teal.shade300 : const Color(0xFF00796B),
    ),
    AccountType.credit => (
      Icons.credit_card_rounded,
      isDark ? Colors.amber.shade300 : const Color(0xFFE65100),
    ),
    AccountType.cash => (
      Icons.payments_rounded,
      isDark ? Colors.green.shade300 : AppColors.income,
    ),
    AccountType.investment => (
      Icons.trending_up_rounded,
      isDark ? Colors.indigo.shade200 : const Color(0xFF3949AB),
    ),
  };
  final custom = accountCustomAppearance(account);
  return (
    icon: custom.icon != null ? accountIconOptions[custom.icon]! : typeIcon,
    color: custom.color != null ? Color(custom.color!) : typeColor,
  );
}

/// The rounded square with the account's icon, as on the accounts list.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.size = 48});

  final Account account;
  final double size;

  @override
  Widget build(BuildContext context) {
    final look = accountAppearance(account, Theme.of(context));
    return Container(
      key: const Key('account.avatar'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: look.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(
          size >= 48 ? AppRadius.md : AppRadius.sm,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(look.icon, color: look.color, size: size / 2),
    );
  }
}
