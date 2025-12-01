import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/presentation/widgets/common/buttons.dart';

class SuccessView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onContinue;
  final String? continueLabel;

  const SuccessView({
    super.key,
    required this.title,
    required this.message,
    this.onContinue,
    this.continueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onContinue != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                label: continueLabel ?? 'Continue',
                onPressed: onContinue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
