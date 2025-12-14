import 'package:flutter/material.dart';

class WelcomeSlide extends StatelessWidget {
  const WelcomeSlide({super.key});

  @override
  Widget build(BuildContext context) {
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
            'A Sovereign Personal Finance Application',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            'Take control of your finances with a private, local-first budgeting app.',
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
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Why LedgerZero?',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          _buildBenefitItem(
            context,
            icon: Icons.attach_money,
            title: 'Economic Sovereignty',
            description: 'One-time purchase. No recurring subscription fees.',
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.storage,
            title: 'Data Sovereignty',
            description:
                'Your data stays on your device. Encrypted and secure.',
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.offline_bolt,
            title: 'Operational Sovereignty',
            description:
                'Works fully offline. Zero latency. No server dependencies.',
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
            'Your Data, Your Device',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'We believe in privacy by default. That means:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          _buildPrivacyItem(
            context,
            icon: Icons.no_accounts,
            text: 'No tracking, analytics, or telemetry.',
          ),
          const SizedBox(height: 16),
          _buildPrivacyItem(
            context,
            icon: Icons.security,
            text: 'All data is AES-256 encrypted on your device.',
          ),
          const SizedBox(height: 16),
          _buildPrivacyItem(
            context,
            icon: Icons.cloud_off,
            text:
                'We never see your financial data. Sync happens via YOUR cloud (Google Drive, iCloud).',
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
