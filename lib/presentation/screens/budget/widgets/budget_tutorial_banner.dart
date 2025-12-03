import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/common/buttons.dart';

class BudgetTutorialBanner extends ConsumerStatefulWidget {
  const BudgetTutorialBanner({super.key});

  @override
  ConsumerState<BudgetTutorialBanner> createState() => _BudgetTutorialBannerState();
}

class _BudgetTutorialBannerState extends ConsumerState<BudgetTutorialBanner> {
  static const String _dismissKey = 'budget_tutorial_dismissed';
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_dismissKey) == true) {
      _isVisible = false;
    }
  }

  Future<void> _dismiss() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_dismissKey, true);
    if (mounted) {
      setState(() {
        _isVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: MaterialBanner(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.budgetTutorialTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.budgetTutorialDescription),
          ],
        ),
        actions: [
          AppButton.text(
            label: AppLocalizations.of(context)!.gotIt,
            onPressed: _dismiss,
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        elevation: 0,
      ),
    );
  }
}
