import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class WelcomeSlide extends StatelessWidget {
  const WelcomeSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 40),
          Text(
            'LedgerZero',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onbWelcomeTagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.onbWelcomeBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class BenefitsSlide extends StatelessWidget {
  const BenefitsSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.onbBenefitsTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          _buildBenefitItem(
            context,
            icon: Icons.attach_money,
            title: l10n.onbBenefitPriceTitle,
            description: l10n.onbBenefitPriceBody,
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.storage,
            title: l10n.onbBenefitDataTitle,
            description: l10n.onbBenefitDataBody,
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.offline_bolt,
            title: l10n.onbBenefitOfflineTitle,
            description: l10n.onbBenefitOfflineBody,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class PrivacySlide extends StatelessWidget {
  const PrivacySlide({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            l10n.onbPrivacyTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.onbPrivacyIntro,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          _buildPrivacyItem(
            context,
            icon: Icons.no_accounts,
            text: l10n.onbPrivacyNoTracking,
          ),
          const SizedBox(height: 16),
          _buildPrivacyItem(
            context,
            icon: Icons.security,
            text: l10n.onbPrivacyEncrypted,
          ),
          const SizedBox(height: 16),
          _buildPrivacyItem(
            context,
            icon: Icons.cloud_off,
            text: l10n.onbPrivacyOwnCloud,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
