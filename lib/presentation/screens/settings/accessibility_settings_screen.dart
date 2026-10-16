import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/app_card.dart';

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accessibility)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.accessibilityVisualSection,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.highContrastTitle),
                  subtitle: Text(l10n.highContrastSubtitle),
                  value: themeState.isHighContrast,
                  onChanged: (value) {
                    ref.read(themeProvider.notifier).toggleHighContrast(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
