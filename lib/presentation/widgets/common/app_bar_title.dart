import 'package:flutter/material.dart';

/// The title of a tab's app bar. A long title ("Transactions",
/// "Transaktionen") next to several actions is scaled down to fit on one
/// line instead of being cut off with an ellipsis.
class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, maxLines: 1),
    );
  }
}
