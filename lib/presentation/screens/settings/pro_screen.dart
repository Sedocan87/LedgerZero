import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/presentation/screens/settings/widgets/settings_icon.dart';
import 'package:ledger_zero/presentation/widgets/common/pro_gate.dart';

/// LedgerZero Pro: what it unlocks, the one-time purchase through Google
/// Play and "Restore purchase".
class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({this.feature, this.next, super.key});

  /// The feature that led here, if any.
  final ProFeature? feature;

  /// The screen "Continue" opens once Pro is unlocked (a Pro feature's
  /// route that redirected here).
  final String? next;

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  @override
  void initState() {
    super.initState();
    final state = ref.read(proControllerProvider);
    if (state.storeAvailable != true || state.price == null) {
      unawaited(ref.read(proControllerProvider.notifier).refresh());
    }
  }

  void _showMessage(ProMessage message) {
    final l10n = AppLocalizations.of(context)!;
    final text = switch (message) {
      // The screen itself shows the unlocked state.
      ProMessage.purchased => null,
      ProMessage.restored => l10n.proRestored,
      ProMessage.nothingToRestore => l10n.proNothingToRestore,
      ProMessage.storeUnavailable => l10n.proStoreUnavailable,
      ProMessage.failed => l10n.proPurchaseFailed,
    };
    if (text != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
    ref.read(proControllerProvider.notifier).clearMessage();
  }

  void _continue() {
    final next = widget.next;
    if (next != null) {
      context.pushReplacement(next);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pro = ref.watch(proControllerProvider);
    final controller = ref.read(proControllerProvider.notifier);
    ref.listen<ProMessage?>(proControllerProvider.select((s) => s.message), (
      _,
      message,
    ) {
      if (message != null) {
        _showMessage(message);
      }
    });
    final feature = widget.feature;
    final semantic =
        theme.extension<AppSemanticColors>() ??
        AppSemanticColors.fromScheme(scheme);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.proTitle)),
      // The purchase stays in view below the list.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pro.unlocked) ...[
                Container(
                  key: const Key('pro.unlocked'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: semantic.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: semantic.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.proUnlocked,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                if (feature != null || widget.next != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('pro.continue'),
                    onPressed: _continue,
                    child: Text(l10n.proContinue),
                  ),
                ],
              ] else ...[
                if (pro.pending)
                  _Note(key: const Key('pro.pending'), text: l10n.proPending),
                if (pro.storeAvailable == false)
                  _Note(
                    key: const Key('pro.unavailable'),
                    text: l10n.proStoreUnavailable,
                  ),
                FilledButton(
                  key: const Key('pro.buy'),
                  onPressed: pro.busy || pro.pending ? null : controller.buy,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: pro.busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          pro.price == null
                              ? l10n.proBuyNoPrice
                              : l10n.proBuy(pro.price!),
                        ),
                ),
              ],
              if (!pro.unlocked || pro.unlockedForDevelopment) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('pro.restore'),
                  onPressed: pro.busy ? null : controller.restore,
                  child: Text(l10n.proRestore),
                ),
              ],
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Icon(Icons.workspace_premium, size: 48, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            l10n.proTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.proTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (feature != null && !pro.unlocked) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('pro.reason'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.proFeatureIsPro(feature.title(l10n)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final f in ProFeature.values)
            if (ProFeatures.needsPro(f))
              ListTile(
                key: Key('pro.feature.${f.name}'),
                contentPadding: EdgeInsets.zero,
                leading: SettingsIcon(f.icon, color: f.color),
                title: Text(f.title(l10n)),
                subtitle: Text(f.description(l10n)),
              ),
          const SizedBox(height: 8),
          Text(
            l10n.proAlwaysFree,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (controller.developmentBuild) ...[
            const Divider(height: 32),
            SwitchListTile(
              key: const Key('pro.developmentUnlock'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.proDevelopmentUnlock),
              value: pro.unlockedForDevelopment,
              onChanged: controller.setUnlockedForDevelopment,
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
