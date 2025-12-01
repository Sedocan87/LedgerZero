import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.md),
              child: child,
            ),
    );
  }
}
