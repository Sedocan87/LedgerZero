import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/money/currency.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_state.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_view_model.dart';

class YnabImportScreen extends ConsumerWidget {
  const YnabImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ynabImportViewModelProvider);
    final viewModel = ref.read(ynabImportViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !state.isImporting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.ynabImportTitle),
          leading:
              state.currentStep != YnabImportStep.selectMethod &&
                  state.currentStep != YnabImportStep.success
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
                child: Text(l10n.cancel),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: _buildStepContent(context, l10n, state, viewModel),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _errorText(l10n, state),
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

  static String _errorText(AppLocalizations l10n, YnabImportState state) {
    switch (state.error!) {
      case YnabImportError.filePickFailed:
        return l10n.ynabImportErrorFilePick;
      case YnabImportError.folderPickFailed:
        return l10n.ynabImportErrorFolderPick;
      case YnabImportError.filesMissing:
        return l10n.ynabImportErrorFilesMissing;
      case YnabImportError.folderMissing:
        return l10n.ynabImportErrorFolderMissing;
      case YnabImportError.missingColumns:
        return l10n.ynabImportErrorMissingColumns(state.errorDetail ?? '');
      case YnabImportError.invalidYnab4Folder:
        return l10n.ynabImportErrorInvalidYnab4;
      case YnabImportError.invalidDates:
        return l10n.ynabImportErrorInvalidDates(state.errorDetail ?? '');
      case YnabImportError.unreadableFiles:
        return l10n.ynabImportErrorUnreadable;
      case YnabImportError.importFailed:
        return l10n.ynabImportErrorImportFailed;
    }
  }

  static String _accountTypeLabel(AppLocalizations l10n, AccountType type) {
    switch (type) {
      case AccountType.checking:
        return l10n.ynabImportAccountTypeChecking;
      case AccountType.savings:
        return l10n.ynabImportAccountTypeSavings;
      case AccountType.credit:
        return l10n.ynabImportAccountTypeCredit;
      case AccountType.cash:
        return l10n.ynabImportAccountTypeCash;
    }
  }

  Widget _buildStepContent(
    BuildContext context,
    AppLocalizations l10n,
    YnabImportState state,
    YnabImportViewModel viewModel,
  ) {
    switch (state.currentStep) {
      case YnabImportStep.selectMethod:
        return _buildMethodSelection(context, l10n, viewModel);
      case YnabImportStep.selectFiles:
        return _buildFileSelection(context, l10n, state, viewModel);
      case YnabImportStep.preview:
        return _buildPreview(context, l10n, state, viewModel);
      case YnabImportStep.importing:
        return _buildImporting(context, l10n);
      case YnabImportStep.success:
        return _buildSuccess(context, l10n, state);
    }
  }

  Widget _buildMethodSelection(
    BuildContext context,
    AppLocalizations l10n,
    YnabImportViewModel viewModel,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.ynabImportSelectVersion,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => viewModel.setMethod(YnabImportMethod.nynabCsv),
          icon: const Icon(Icons.table_chart),
          label: Text(l10n.ynabImportMethodCsv),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => viewModel.setMethod(YnabImportMethod.ynab4),
          icon: const Icon(Icons.folder),
          label: Text(l10n.ynabImportMethodYnab4),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          l10n.ynabImportMethodHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFileSelection(
    BuildContext context,
    AppLocalizations l10n,
    YnabImportState state,
    YnabImportViewModel viewModel,
  ) {
    if (state.method == YnabImportMethod.nynabCsv) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.ynabImportUploadCsvTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Register.csv'),
            subtitle: Text(
              state.registerFile?.name ?? l10n.ynabImportNotSelected,
            ),
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
            subtitle: Text(
              state.budgetFile?.name ?? l10n.ynabImportNotSelected,
            ),
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
              child: Text(l10n.ynabImportNextPreview),
            ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.ynabImportSelectFolderTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: Text(l10n.ynabImportBudgetFolder),
            subtitle: Text(state.ynab4FolderPath ?? l10n.ynabImportNotSelected),
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
              child: Text(l10n.ynabImportNextPreview),
            ),
        ],
      );
    }
  }

  Widget _buildPreview(
    BuildContext context,
    AppLocalizations l10n,
    YnabImportState state,
    YnabImportViewModel viewModel,
  ) {
    final data = state.parsedData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ynabImportPreviewTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.ynabImportPreviewSubtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: l10n.accounts),
                    Tab(text: l10n.categories),
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
                              acc.onBudget
                                  ? l10n.ynabImportAccountSubtitle(
                                      _accountTypeLabel(l10n, acc.type),
                                      acc.isClosed
                                          ? l10n.ynabImportAccountClosed
                                          : l10n.ynabImportAccountActive,
                                    )
                                  : l10n.ynabImportTrackingAccount,
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
                            subtitle: Text(
                              l10n.ynabImportCategoryCount(cats.length),
                            ),
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
        DropdownButtonFormField<String>(
          key: const Key('ynab_import_currency'),
          initialValue: state.currency,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.ynabImportCurrency),
          items: [
            for (final code in {...supportedCurrencyCodes, state.currency})
              DropdownMenuItem(value: code, child: Text(code)),
          ],
          onChanged: (code) {
            if (code != null) {
              viewModel.setCurrency(code);
            }
          },
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
                l10n.ynabImportTotalTransactions,
                data.transactions.length,
              ),
              _buildStatRow(
                context,
                l10n.ynabImportBudgetEntries,
                data.budgetEntries.length,
              ),
              if (data.scheduledTransactions.isNotEmpty)
                _buildStatRow(
                  context,
                  l10n.ynabImportScheduledTransactions,
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
            child: Text(l10n.ynabImportConfirm),
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
          Text(
            AppLocalizations.of(context)!.integerValue(count),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildImporting(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(strokeWidth: 6),
        ),
        const SizedBox(height: 32),
        Text(
          l10n.ynabImportInProgressTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.ynabImportInProgressBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 48),
        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 32),
        const SizedBox(height: 8),
        Text(
          l10n.ynabImportDoNotClose,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(
    BuildContext context,
    AppLocalizations l10n,
    YnabImportState state,
  ) {
    final summary = state.summary;
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
          Text(
            l10n.ynabImportSuccessTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.ynabImportSuccessBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
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
                  l10n.integerValue(summary?.accounts ?? 0),
                  l10n.accounts,
                ),
                const Divider(height: 24),
                _buildSuccessStat(
                  context,
                  Icons.category,
                  l10n.integerValue(summary?.categories ?? 0),
                  l10n.categories,
                ),
                const Divider(height: 24),
                _buildSuccessStat(
                  context,
                  Icons.receipt_long,
                  l10n.integerValue(summary?.transactions ?? 0),
                  l10n.transactions,
                ),
              ],
            ),
          ),
          if ((summary?.trackingAccountsSkipped ?? 0) > 0) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                l10n.ynabImportTrackingSkipped(
                  summary!.trackingAccountsSkipped,
                ),
                key: const Key('ynab_tracking_skipped'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // Go to budget screen or home
              context.go('/budget');
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(l10n.ynabImportStartBudgeting),
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
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
