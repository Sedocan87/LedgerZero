import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          UserGuideSection(
            title: '1. Getting Started',
            content:
                'LedgerZero is based on the zero-based envelope budgeting method. This means you assign every dollar you earn to a specific job (category) before you spend it.',
          ),
          UserGuideSection(
            title: '2. Setting Up Accounts',
            content:
                'Add your checking, savings, and credit card accounts. Enter their current balances. This forms the pool of money you have "To Be Budgeted".',
          ),
          UserGuideSection(
            title: '3. Budgeting Your Money',
            content:
                'On the Budget screen, you will see your "To Be Budgeted" amount. Tap on categories to assign funds. Your goal is to budget until TBB is zero.',
          ),
          UserGuideSection(
            title: '4. Entering Transactions',
            content:
                'Whenever you spend money, enter a transaction. Select the payee and the category. This deducts from your budgeted "Available" amount.',
          ),
          UserGuideSection(
            title: '5. Dealing with Overspending',
            content:
                'If a category balance turns negative (red), you have overspent. Move money from another category with available funds to cover the overspending.',
          ),
          UserGuideSection(
            title: '6. Reconciliation',
            content:
                'Periodically compare your account balances in LedgerZero with your actual bank balances. Use the "Reconcile" feature to ensure they match.',
          ),
        ],
      ),
    );
  }
}

class UserGuideSection extends StatelessWidget {
  final String title;
  final String content;

  const UserGuideSection({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
