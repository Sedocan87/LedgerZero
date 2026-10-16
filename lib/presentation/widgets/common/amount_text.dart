import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';

/// What an amount means, for the words a screen reader adds to it.
enum AmountContext {
  /// Just the amount.
  none,

  /// A category's available amount: "… available", or "… overspent" when
  /// negative.
  available,

  /// A category's budgeted amount: "… budgeted".
  budgeted,

  /// A category's activity: "Activity …".
  activity,

  /// An account balance: "Balance …".
  balance,

  /// To Be Budgeted: "… to be budgeted", or "… overbudgeted" when negative.
  toBeBudgeted,

  /// A transaction amount: "Inflow …" / "Outflow …" by sign.
  transaction,
}

/// The spoken form of [amount] (minor units): the formatted amount plus a
/// localised word for [amountContext]. Words that already carry the sign
/// ("overspent", "outflow", ...) are combined with the unsigned amount.
String amountSemanticsLabel({
  required AppLocalizations l10n,
  required AppFormatter formatter,
  required int amount,
  AmountContext amountContext = AmountContext.none,
  String? currencyCode,
}) {
  String format(int minor) =>
      formatter.formatMoney(minor, currencyCode: currencyCode);
  final unsigned = format(amount.abs());
  return switch (amountContext) {
    AmountContext.none => format(amount),
    AmountContext.available =>
      amount < 0
          ? l10n.amountSemanticsOverspent(unsigned)
          : l10n.amountSemanticsAvailable(unsigned),
    AmountContext.budgeted => l10n.amountSemanticsBudgeted(format(amount)),
    AmountContext.activity => l10n.amountSemanticsActivity(format(amount)),
    AmountContext.balance => l10n.amountSemanticsBalance(format(amount)),
    AmountContext.toBeBudgeted =>
      amount < 0
          ? l10n.amountSemanticsOverbudgeted(unsigned)
          : l10n.amountSemanticsToBeBudgeted(unsigned),
    AmountContext.transaction =>
      amount < 0
          ? l10n.amountSemanticsOutflow(unsigned)
          : l10n.amountSemanticsInflow(unsigned),
  };
}

/// An amount (minor units) formatted with [appFormatterProvider].
///
/// Screen readers read [amountSemanticsLabel] (amount plus a word for
/// [amountContext]) instead of the raw glyphs. The visible text is exactly
/// [AppFormatter.formatMoney] of [amount].
class AmountText extends ConsumerWidget {
  /// Amount in minor units.
  final int amount;

  /// Currency of [amount]; defaults to the Settings currency.
  final String? currencyCode;

  /// What the amount means, for the spoken label.
  final AmountContext amountContext;

  /// Show a `+` for positive amounts.
  final bool signed;

  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const AmountText(
    this.amount, {
    super.key,
    this.currencyCode,
    this.amountContext = AmountContext.none,
    this.signed = false,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(appFormatterProvider);
    final text = Text(
      fmt.formatMoney(amount, currencyCode: currencyCode, signed: signed),
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return text;
    }
    return Semantics(
      label: amountSemanticsLabel(
        l10n: l10n,
        formatter: fmt,
        amount: amount,
        amountContext: amountContext,
        currencyCode: currencyCode,
      ),
      excludeSemantics: true,
      child: text,
    );
  }
}
