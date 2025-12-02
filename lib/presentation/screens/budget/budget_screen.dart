import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.budget),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: AppLocalizations.of(context)!.manageCategories,
            onPressed: () => context.pushNamed('categories'),
          ),
        ],
      ),
      body: const Center(
        child: Text('Budget Screen'),
      ),
    );
  }
}
