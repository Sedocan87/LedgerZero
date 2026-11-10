import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';

/// Names, icons and screens of the [ProFeature]s.
extension ProFeatureUi on ProFeature {
  String title(AppLocalizations l10n) => switch (this) {
    ProFeature.wifiSync => l10n.proFeatureWifiSync,
    ProFeature.cardCapture => l10n.proFeatureCardCapture,
    ProFeature.pdfReports => l10n.proFeaturePdfReports,
    ProFeature.budgetTemplates => l10n.proFeatureBudgetTemplates,
    ProFeature.rules => l10n.proFeatureRules,
  };

  String description(AppLocalizations l10n) => switch (this) {
    ProFeature.wifiSync => l10n.proFeatureWifiSyncDescription,
    ProFeature.cardCapture => l10n.proFeatureCardCaptureDescription,
    ProFeature.pdfReports => l10n.proFeaturePdfReportsDescription,
    ProFeature.budgetTemplates => l10n.proFeatureBudgetTemplatesDescription,
    ProFeature.rules => l10n.proFeatureRulesDescription,
  };

  IconData get icon => switch (this) {
    ProFeature.wifiSync => Icons.sync,
    ProFeature.cardCapture => Icons.credit_card,
    ProFeature.pdfReports => Icons.picture_as_pdf,
    ProFeature.budgetTemplates => Icons.content_copy,
    ProFeature.rules => Icons.rule,
  };

  /// The colour family of [icon] (as in Settings).
  MaterialColor get color => switch (this) {
    ProFeature.wifiSync => Colors.lightBlue,
    ProFeature.cardCapture => Colors.purple,
    ProFeature.pdfReports => Colors.red,
    ProFeature.budgetTemplates => Colors.teal,
    ProFeature.rules => Colors.deepPurple,
  };
}

/// The Pro screen's location; [feature] names what led there, [next] is the
/// screen "Continue" opens once Pro is unlocked.
String proLocation({ProFeature? feature, String? next}) => Uri(
  path: '/settings/pro',
  queryParameters: {'feature': ?feature?.name, 'next': ?next},
).toString();

/// For a route of a Pro feature: the Pro screen while Pro is locked.
String? proRedirect(bool available, ProFeature feature, Uri location) =>
    available ? null : proLocation(feature: feature, next: location.toString());

/// Whether [feature] can be used now. A feature that needs Pro opens the
/// Pro screen first; true when Pro was unlocked there.
Future<bool> ensureProFeature(
  BuildContext context,
  WidgetRef ref,
  ProFeature feature,
) async {
  if (ref.read(proFeatureAvailableProvider(feature))) {
    return true;
  }
  await context.push(proLocation(feature: feature));
  if (!context.mounted) {
    return false;
  }
  return ref.read(proFeatureAvailableProvider(feature));
}

/// A small "PRO" badge, shown while [feature] needs Pro and Pro is locked.
class ProBadge extends ConsumerWidget {
  const ProBadge({required this.feature, super.key});

  final ProFeature feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(proFeatureAvailableProvider(feature))) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: l10n.proBadgeSemantics,
      excludeSemantics: true,
      child: Container(
        key: Key('proBadge.${feature.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.proBadge,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// A list tile's trailing widget with the [ProBadge] in front of [child].
class ProTrailing extends ConsumerWidget {
  const ProTrailing({required this.feature, required this.child, super.key});

  final ProFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(proFeatureAvailableProvider(feature))) {
      return child;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProBadge(feature: feature),
        const SizedBox(width: 8),
        child,
      ],
    );
  }
}
