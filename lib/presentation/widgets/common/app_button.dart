import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/common/app_loading_indicator.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonType type;

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : type = ButtonType.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : type = ButtonType.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : type = ButtonType.text;

  @override
  Widget build(BuildContext context) {
    // If loading, show a small loader instead of icon/text?
    // Or alongside? For now, let's disable and show loader if loading
    // But keeping it simple for this task.

    final Widget child = Semantics(
      label: isLoading
          ? '$label, ${AppLocalizations.of(context)?.loading ?? "Loading"}'
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: AppLoadingIndicator(),
            ),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );

    final VoidCallback? hapticOnPressed = onPressed != null
        ? () {
            HapticFeedback.lightImpact();
            onPressed!();
          }
        : null;

    switch (type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : hapticOnPressed,
          child: child,
        );
      case ButtonType.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : hapticOnPressed,
          child: child,
        );
      case ButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : hapticOnPressed,
          child: child,
        );
    }
  }
}

enum ButtonType { primary, secondary, text }
