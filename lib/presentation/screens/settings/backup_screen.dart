import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/picked_file.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/security/password_strength_meter.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/filtered_export_dialog.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';

/// How often the app reminds the user to back up (stored by name under
/// `backup_frequency`, read by BackupScheduler; weekly by default).
enum _ReminderFrequency {
  daily,
  weekly,
  monthly,
  never;

  static _ReminderFrequency fromName(String? name) =>
      values.where((f) => f.name == name).firstOrNull ?? weekly;
}

/// Encrypted backups (always password-protected), restore, and the
/// plaintext exports (CSV, JSON).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _uploadToCloud = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createBackup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final target = ref.read(backupCloudTargetProvider);
    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final files = ref.read(exportFileServiceProvider);
      final file = await backupService.createBackup(
        password: _passwordController.text,
      );
      _passwordController.clear();
      _confirmPasswordController.clear();

      if (_uploadToCloud && target != null) {
        try {
          await ExternalUiGuard.run(
            () => backupService.uploadBackupToCloud(file, target),
          );
          messenger.showSnackBar(SnackBar(content: Text(l10n.backupUploaded)));
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.backupUploadFailed)),
          );
        }
      }
      // Hand the encrypted file to the share sheet; it is deleted after.
      await files.shareAndDelete(file, subject: l10n.backupShareSubject);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<File?> _pickBackupFile() async {
    final picked = await ExternalUiGuard.run(FilePicker.pickFile);
    return picked?.toLocalFile();
  }

  Future<String?> _askBackupPassword(AppLocalizations l10n) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restorePasswordTitle),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l10n.backupPasswordLabel),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.ok),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  String _restoreError(AppLocalizations l10n, Object error) {
    return switch (error) {
      BackupAuthenticationException() => l10n.restoreWrongPassword,
      BackupTooNewException() => l10n.restoreNewerVersion,
      BackupFormatException() => l10n.restoreInvalidFile,
      _ => l10n.restoreFailed,
    };
  }

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final file = await _pickBackupFile();
    if (file == null || !mounted) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restoreAction),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    final password = await _askBackupPassword(l10n);
    if (password == null || password.isEmpty || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await ref
          .read(restoreServiceProvider)
          .restoreBackup(file, password: password);
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(l10n.restoreSuccessTitle),
          content: Text(l10n.restoreSuccessMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_restoreError(l10n, e))));
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectiveRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final file = await _pickBackupFile();
    if (file == null || !mounted) {
      return;
    }
    final password = await _askBackupPassword(l10n);
    if (password == null || password.isEmpty || !mounted) {
      return;
    }
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (dateRange == null || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await ref
          .read(restoreServiceProvider)
          .selectiveRestore(
            file,
            DateTime.utc(
              dateRange.start.year,
              dateRange.start.month,
              dateRange.start.day,
            ),
            DateTime.utc(
              dateRange.end.year,
              dateRange.end.month,
              dateRange.end.day,
            ),
            password: password,
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.selectiveRestoreSuccess)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_restoreError(l10n, e))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Runs an export and reports a failure without exception details.
  Future<void> _runExport(Future<void> Function() export) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await export();
    } catch (e, st) {
      Logger.error('Export failed', e, st);
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailedGeneric)));
    }
  }

  Future<void> _exportAllCsv() => _runExport(() async {
    final shareText = AppLocalizations.of(context)!.transactionsShareText;
    final transactions = await ref
        .read(transactionRepositoryProvider)
        .getAllTransactions();
    final payees = await ref.read(payeeRepositoryProvider).getAllPayees();
    final categories = await ref
        .read(categoryRepositoryProvider)
        .getAllCategories();
    final accounts = await ref.read(accountRepositoryProvider).getAllAccounts();
    await TransactionExportService(
      files: ref.read(exportFileServiceProvider),
    ).exportTransactionsToCsv(
      transactions: transactions,
      payeeNames: {for (final p in payees) p.id: p.name},
      categoryNames: {for (final c in categories) c.id: c.name},
      accountNames: {for (final a in accounts) a.id: a.name},
      shareText: shareText,
    );
  });

  Future<void> _exportJson() => _runExport(
    () => ref
        .read(dataPortabilityServiceProvider)
        .exportAllDataToJson(
          shareText: AppLocalizations.of(context)!.dataExportShareText,
        ),
  );

  Future<void> _chooseReminderFrequency() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<_ReminderFrequency>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.backupReminderFrequency),
        children: [
          for (final f in _ReminderFrequency.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_frequencyLabel(l10n, f)),
              ),
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      await ref.read(backupSchedulerProvider).setFrequency(selected.name);
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _frequencyLabel(AppLocalizations l10n, _ReminderFrequency f) =>
      switch (f) {
        _ReminderFrequency.daily => l10n.daily,
        _ReminderFrequency.weekly => l10n.weekly,
        _ReminderFrequency.monthly => l10n.monthly,
        _ReminderFrequency.never => l10n.never,
      };

  Widget _buildExportSection(AppLocalizations l10n) {
    final frequency = _ReminderFrequency.fromName(
      ref.read(sharedPreferencesProvider).getString('backup_frequency'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.export, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.exportPlaintextWarning),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: Text(l10n.exportAllCsv),
                subtitle: Text(l10n.exportAllCsvSubtitle),
                onTap: _isLoading ? null : _exportAllCsv,
              ),
              ListTile(
                leading: const Icon(Icons.filter_list),
                title: Text(l10n.exportFilteredCsv),
                subtitle: Text(l10n.exportFilteredCsvSubtitle),
                onTap: _isLoading
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (context) => const FilteredExportDialog(),
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.data_object),
                title: Text(l10n.exportAllJson),
                subtitle: Text(l10n.exportAllJsonSubtitle),
                onTap: _isLoading ? null : _exportJson,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          l10n.backupReminderFrequency,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l10n.backupReminderFrequency),
            subtitle: Text(_frequencyLabel(l10n, frequency)),
            onTap: _chooseReminderFrequency,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cloudTarget = ref.watch(backupCloudTargetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupAndExport)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.backupCreateTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.backupCreateExplanation),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NewPasswordFields(
                        controller: _passwordController,
                        confirmController: _confirmPasswordController,
                        label: l10n.backupPasswordLabel,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.backupUploadToCloud),
                        subtitle: cloudTarget == null
                            ? Text(l10n.backupUploadNotConfigured)
                            : null,
                        value: _uploadToCloud && cloudTarget != null,
                        onChanged: cloudTarget == null
                            ? null
                            : (value) => setState(() => _uploadToCloud = value),
                      ),
                      const SizedBox(height: 16),
                      AppButton.primary(
                        label: _isLoading
                            ? l10n.backupCreating
                            : l10n.backupExport,
                        onPressed: _isLoading ? null : _createBackup,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.restoreTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.restoreExplanation),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton.secondary(
                      label: l10n.restoreFromFile,
                      onPressed: _isLoading ? null : _restoreBackup,
                    ),
                    const SizedBox(height: 16),
                    AppButton.secondary(
                      label: l10n.restoreSelective,
                      onPressed: _isLoading ? null : _selectiveRestore,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildExportSection(l10n),
          ],
        ),
      ),
    );
  }
}
