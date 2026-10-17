import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/default_category_names.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';

/// One-time card offering budgets created before the Savings & Investments
/// default group existed to add it. New databases are seeded with it, so they
/// never see the card. Adding or declining hides it for good.
class SavingsCategoriesOffer extends ConsumerStatefulWidget {
  const SavingsCategoriesOffer({super.key});

  /// SharedPreferences flag: the offer was accepted or declined.
  static const handledKey = 'savings_categories_offer_handled';

  @override
  ConsumerState<SavingsCategoriesOffer> createState() =>
      _SavingsCategoriesOfferState();
}

class _SavingsCategoriesOfferState
    extends ConsumerState<SavingsCategoriesOffer> {
  late bool _handled;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _handled =
        ref
            .read(sharedPreferencesProvider)
            .getBool(SavingsCategoriesOffer.handledKey) ??
        false;
  }

  Future<void> _markHandled() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(SavingsCategoriesOffer.handledKey, true);
    if (mounted) {
      setState(() => _handled = true);
    }
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      await ref
          .read(categoryServiceProvider)
          .addDefaultGroup(
            DefaultCategories.savingsGroup,
            defaultCategoryNames(l10n),
          );
      await _markHandled();
      messenger.showSnackBar(SnackBar(content: Text(l10n.savingsOfferAdded)));
    } catch (e, st) {
      Logger.error('Adding the savings categories failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_handled) {
      return const SizedBox.shrink();
    }
    final groups = ref.watch(categoryGroupsProvider).valueOrNull;
    final groupId = DeterministicId.defaultGroup(
      DefaultCategories.savingsGroup,
    );
    if (groups == null || groups.any((g) => g.id == groupId)) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.08),
          scheme.surfaceContainerLow,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.savingsOfferTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.savingsOfferBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  AppButton.text(
                    label: l10n.savingsOfferDismiss,
                    onPressed: _adding ? null : _markHandled,
                  ),
                  AppButton.text(
                    label: l10n.savingsOfferAdd,
                    onPressed: _adding ? null : _add,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
