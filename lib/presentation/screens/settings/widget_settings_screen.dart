import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_bar.dart';
import 'package:ledger_zero/presentation/widgets/widget_preview.dart';

class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() =>
      _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen> {
  // Mock settings for preview
  bool _showGraph = true;
  String? _selectedAccountId;
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    // Watch actual data for selection
    final accounts = ref.watch(accountRepositoryProvider).watchAllAccounts();
    final categories = ref
        .watch(categoryRepositoryProvider)
        .watchAllCategories();

    return Scaffold(
      appBar: const AppAppBar(title: 'Widget Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Configure how your home screen widgets appear.'),
          const SizedBox(height: 20),

          // Preview Section
          const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Center(
            child: Consumer(
              builder: (context, ref, child) {
                // Mock data for preview
                final mockCategories = [
                  const Category(
                    id: '1',
                    name: 'Groceries',
                    color: 0,
                    icon: '0',
                    createdAt: null,
                  ),
                  const Category(
                    id: '2',
                    name: 'Rent',
                    color: 0,
                    icon: '0',
                    createdAt: null,
                  ),
                ];
                final mockPerformance = {
                  '1': {'available': 150.0},
                  '2': {'available': 0.0},
                };

                return WidgetPreview(
                  tbbAmount: 1250.50,
                  categories: mockCategories,
                  categoryPerformance: mockPerformance,
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Configuration
          SwitchListTile(
            title: const Text('Show Graph'),
            value: _showGraph,
            onChanged: (val) => setState(() => _showGraph = val),
          ),

          // Account Selection
          StreamBuilder<List<Account>>(
            stream: accounts,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final list = snapshot.data!;
                return DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Default Account',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Accounts'),
                    ),
                    ...list.map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                );
              }
              return const CircularProgressIndicator();
            },
          ),

          const SizedBox(height: 10),

          // Category Selection
          StreamBuilder<List<Category>>(
            stream: categories,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final list = snapshot.data!;
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Focus Category',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...list.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                );
              }
              return const CircularProgressIndicator();
            },
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Save to widget service/shared prefs
              ref
                  .read(widgetServiceProvider)
                  .updateWidgetConfiguration(
                    showGraph: _showGraph,
                    accountId: _selectedAccountId,
                    categoryId: _selectedCategoryId,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Widget settings saved')),
              );
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
