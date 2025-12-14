import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_state.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_view_model.dart';

class YnabImportScreen extends ConsumerWidget {
  const YnabImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ynabImportViewModelProvider);
    final viewModel = ref.read(ynabImportViewModelProvider.notifier);

    return PopScope(
      canPop: !state.isImporting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('YNAB Migration'),
          leading:
              state.currentStep != YnabImportStep.selectMethod &&
                  state.currentStep != YnabImportStep.success
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: state.isImporting ? null : viewModel.goBack,
                )
              : null,
          actions: [
            if (!state.isImporting &&
                state.currentStep != YnabImportStep.success)
              TextButton(
                onPressed: () {
                  viewModel.cancel();
                  context.pop();
                },
                child: const Text('Cancel'),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(child: _buildStepContent(context, state, viewModel)),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    YnabImportState state,
    YnabImportViewModel viewModel,
  ) {
    switch (state.currentStep) {
      case YnabImportStep.selectMethod:
        return _buildMethodSelection(context, viewModel);
      case YnabImportStep.selectFiles:
        return _buildFileSelection(context, state, viewModel);
      case YnabImportStep.preview:
        return _buildPreview(context, state, viewModel);
      case YnabImportStep.importing:
        return _buildImporting(context);
      case YnabImportStep.success:
        return _buildSuccess(context, state);
    }
  }

  Widget _buildMethodSelection(
    BuildContext context,
    YnabImportViewModel viewModel,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Select your YNAB version',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => viewModel.setMethod(YnabImportMethod.nynabCsv),
          icon: const Icon(Icons.table_chart),
          label: const Text('nYNAB (CSV Export)'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => viewModel.setMethod(YnabImportMethod.ynab4),
          icon: const Icon(Icons.folder),
          label: const Text('YNAB 4 (Classic)'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'For nYNAB: Export your budget as CSV from the web app.\n'
          'For YNAB 4: Select your budget folder (ending in .ynab4).',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFileSelection(
    BuildContext context,
    YnabImportState state,
    YnabImportViewModel viewModel,
  ) {
    if (state.method == YnabImportMethod.nynabCsv) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload CSV Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Register.csv'),
            subtitle: Text(state.registerFile?.name ?? 'Not selected'),
            leading: const Icon(Icons.receipt_long),
            trailing: const Icon(Icons.upload_file),
            onTap: viewModel.pickRegisterFile,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Budget.csv'),
            subtitle: Text(state.budgetFile?.name ?? 'Not selected'),
            leading: const Icon(Icons.pie_chart),
            trailing: const Icon(Icons.upload_file),
            onTap: viewModel.pickBudgetFile,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.grey),
            ),
          ),
          const Spacer(),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed:
                  (state.registerFile != null && state.budgetFile != null)
                  ? viewModel.validateAndParse
                  : null,
              child: const Text('Next: Preview'),
            ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select YNAB4 Folder',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Budget Folder'),
            subtitle: Text(state.ynab4FolderPath ?? 'Not selected'),
            leading: const Icon(Icons.folder_open),
            trailing: const Icon(Icons.folder),
            onTap: viewModel.pickYnab4Folder,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.grey),
            ),
          ),
          const Spacer(),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: state.ynab4FolderPath != null
                  ? viewModel.validateAndParse
                  : null,
              child: const Text('Next: Preview'),
            ),
        ],
      );
    }
  }

  Widget _buildPreview(
    BuildContext context,
    YnabImportState state,
    YnabImportViewModel viewModel,
  ) {
    final data = state.parsedData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import Preview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review the data found in your import files.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Accounts'),
                    Tab(text: 'Categories'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Accounts Tab
                      ListView.builder(
                        itemCount: data.accounts.length,
                        itemBuilder: (context, index) {
                          final acc = data.accounts[index];
                          return ListTile(
                            leading: const Icon(Icons.account_balance_wallet),
                            title: Text(acc.name),
                            subtitle: Text(
                              '${acc.type.name.toUpperCase()} • ${acc.isClosed ? 'Closed' : 'Active'}',
                            ),
                          );
                        },
                      ),
                      // Categories Tab
                      ListView.builder(
                        itemCount: data.categoryGroups.length,
                        itemBuilder: (context, index) {
                          final group = data.categoryGroups[index];
                          final cats = data.categories
                              .where((c) => c.groupId == group.id)
                              .toList();

                          if (cats.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return ExpansionTile(
                            title: Text(group.name),
                            subtitle: Text('${cats.length} categories'),
                            children: cats
                                .map(
                                  (c) => ListTile(
                                    title: Text(c.name),
                                    dense: true,
                                    leading: const Icon(
                                      Icons.category,
                                      size: 16,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildStatRow(
                context,
                'Total Transactions',
                data.transactions.length,
              ),
              _buildStatRow(
                context,
                'Budget Entries',
                data.budgetEntries.length,
              ),
              if (data.scheduledTransactions.isNotEmpty)
                _buildStatRow(
                  context,
                  'Scheduled Txns',
                  data.scheduledTransactions.length,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: viewModel.startImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Confirm & Import'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildImporting(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(strokeWidth: 6),
        ),
        SizedBox(height: 32),
        Text(
          'Migrating your budget...',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text(
          'This may take a moment depending on the size of your history.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        SizedBox(height: 48),
        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 32),
        SizedBox(height: 8),
        Text(
          'Please do not close the app or switch screens.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context, YnabImportState state) {
    final data = state.parsedData;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome Home!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your YNAB data has been successfully migrated.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: [
                _buildSuccessStat(
                  context,
                  Icons.account_balance,
                  '${data?.accounts.length ?? 0}',
                  'Accounts',
                ),
                const Divider(height: 24),
                _buildSuccessStat(
                  context,
                  Icons.category,
                  '${data?.categories.length ?? 0}',
                  'Categories',
                ),
                const Divider(height: 24),
                _buildSuccessStat(
                  context,
                  Icons.receipt_long,
                  '${data?.transactions.length ?? 0}',
                  'Transactions',
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // Go to budget screen or home
              context.go('/budget');
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Budgeting'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStat(
    BuildContext context,
    IconData icon,
    String count,
    String label,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}
