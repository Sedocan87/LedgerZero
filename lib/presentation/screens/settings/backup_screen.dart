import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/picked_file.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/security/password_strength_meter.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/filtered_export_dialog.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/services/backup/auto_backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart'
    show SyncEngineConfig;
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
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _uploadToCloud = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
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

      var completed = false;
      if (_uploadToCloud && target != null) {
        try {
          await ExternalUiGuard.run(
            () => backupService.uploadBackupToCloud(file, target),
          );
          completed = true;
          messenger.showSnackBar(SnackBar(content: Text(l10n.backupUploaded)));
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.backupUploadFailed)),
          );
        }
      }
      // Hand the encrypted file to the share sheet; it is deleted after.
      final shared = await files.shareAndDelete(
        file,
        subject: l10n.backupShareSubject,
      );
      // "Last backup" counts only when the file actually left the phone.
      if (shared || completed) {
        await backupService.recordBackupCompleted();
      }
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
    final file = await _pickBackupFile();
    if (file == null || !mounted) {
      return;
    }
    await _restoreFile(file);
  }

  /// Replaces the data with [file] after the confirmation, the password
  /// and the warnings a backup may need.
  Future<void> _restoreFile(File file) async {
    final l10n = AppLocalizations.of(context)!;
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
      final prepared = await ref
          .read(restoreServiceProvider)
          .prepareRestore(file, password: password);
      if (!mounted || !await _confirmRestoreWarnings(prepared.info)) {
        await prepared.discard();
        return;
      }
      await prepared.commit();
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

  // ---- Automatic backups -------------------------------------------------

  void _autoBackupChanged() {
    ref.read(autoBackupGenerationProvider.notifier).state++;
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  /// Asks for a new backup password (typed twice, checked like every new
  /// password) and returns it, or null when cancelled.
  Future<String?> _askNewBackupPassword(
    AppLocalizations l10n, {
    required String title,
    required String action,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NewBackupPasswordDialog(
        title: title,
        action: action,
        explanation: l10n.autoBackupPasswordExplanation,
        label: l10n.backupPasswordLabel,
        cancel: l10n.cancel,
      ),
    );
  }

  Future<void> _toggleAutoBackup(bool on) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(autoBackupServiceProvider);
    if (!on) {
      await service.disable();
      _autoBackupChanged();
      return;
    }
    final password = await _askNewBackupPassword(
      l10n,
      title: l10n.autoBackupPasswordTitle,
      action: l10n.autoBackupTurnOn,
    );
    if (password == null || !mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await service.enable(password);
      messenger.showSnackBar(SnackBar(content: Text(l10n.autoBackupSaved)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.autoBackupFailed(_errorText(e)))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _autoBackupChanged();
    }
  }

  Future<void> _autoBackupNow() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await ref.read(autoBackupServiceProvider).runNow();
      messenger.showSnackBar(SnackBar(content: Text(l10n.autoBackupSaved)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.autoBackupFailed(_errorText(e)))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _autoBackupChanged();
    }
  }

  Future<void> _changeAutoBackupPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final password = await _askNewBackupPassword(
      l10n,
      title: l10n.autoBackupPasswordTitle,
      action: l10n.save,
    );
    if (password == null || !mounted) {
      return;
    }
    await ref.read(autoBackupServiceProvider).changePassword(password);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.autoBackupPasswordChanged)),
    );
  }

  Future<void> _restoreAutoBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final formatter = ref.read(appFormatterProvider);
    final backups = await ref.read(autoBackupServiceProvider).listBackups();
    if (!mounted) {
      return;
    }
    if (backups.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.autoBackupNone)));
      return;
    }
    final chosen = await showDialog<AutoBackupFile>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.autoBackupRestoreTitle),
        children: [
          for (final backup in backups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, backup),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(formatter.formatDateTime(backup.createdAt)),
                subtitle: Text(
                  l10n.autoBackupFileSize(
                    ((backup.sizeBytes + 1023) ~/ 1024).toString(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }
    await _restoreFile(chosen.file);
  }

  Future<void> _deleteAutoBackups(int count) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.autoBackupDeleteAll),
        content: Text(l10n.autoBackupDeleteAllConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    await ref.read(autoBackupServiceProvider).deleteAll();
    messenger.showSnackBar(SnackBar(content: Text(l10n.autoBackupDeleted)));
    _autoBackupChanged();
  }

  Widget _buildAutoBackupSection(AppLocalizations l10n) {
    ref.watch(autoBackupGenerationProvider);
    final service = ref.watch(autoBackupServiceProvider);
    final formatter = ref.watch(appFormatterProvider);
    final files = ref.watch(autoBackupFilesProvider).value ?? const [];
    final folder = ref.watch(autoBackupFolderProvider).value;
    final enabled = service.isEnabled;
    final error = service.lastError;
    final last = service.lastSuccess;
    final String status;
    if (!enabled) {
      status = l10n.autoBackupStatusOff;
    } else if (error != null) {
      status = l10n.autoBackupStatusFailed(
        formatter.formatDateTime(service.lastAttempt ?? DateTime.now()),
        error,
      );
    } else if (last == null) {
      status = l10n.autoBackupStatusPending;
    } else {
      status = l10n.autoBackupStatusLast(formatter.formatDateTime(last));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.autoBackupTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.autoBackupExplanation(service.keep)),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('autoBackup.enabled'),
                title: Text(l10n.autoBackupSwitch),
                subtitle: Text(status, key: const Key('autoBackup.status')),
                value: enabled,
                onChanged: _isLoading ? null : _toggleAutoBackup,
              ),
              if (enabled) ...[
                ListTile(
                  key: const Key('autoBackup.now'),
                  leading: const Icon(Icons.backup),
                  title: Text(l10n.autoBackupNow),
                  onTap: _isLoading ? null : _autoBackupNow,
                ),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text(l10n.autoBackupChangePassword),
                  onTap: _isLoading ? null : _changeAutoBackupPassword,
                ),
              ],
              if (files.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.autoBackupDeleteAll),
                  onTap: _isLoading
                      ? null
                      : () => _deleteAutoBackups(files.length),
                ),
            ],
          ),
        ),
        if (folder != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.autoBackupFolder(folder.path),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  /// Warnings a backup needs before it replaces the data: another
  /// member's backup swaps who owns the personal accounts; a backup older
  /// than the sync retention can bring back rows deleted elsewhere.
  Future<bool> _confirmRestoreWarnings(RestoreInfo info) async {
    final l10n = AppLocalizations.of(context)!;
    final warnings = <(String, String)>[
      if (info.changesMember)
        (l10n.restoreMemberWarningTitle, l10n.restoreMemberWarningMessage),
      if (info.isOlderThan(const SyncEngineConfig().tombstoneRetention))
        (
          l10n.restoreOldBackupWarningTitle,
          l10n.restoreOldBackupWarningMessage(
            const SyncEngineConfig().tombstoneRetention.inDays,
          ),
        ),
    ];
    for (final (title, message) in warnings) {
      if (!mounted) {
        return false;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              key: const Key('restore_anyway'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.restoreAnywayAction),
            ),
          ],
        ),
      );
      if (go != true) {
        return false;
      }
    }
    return true;
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
    final personal = ref.watch(ownPersonalAccountsProvider).value ?? false;
    final nudge = ref.watch(backupNudgeProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupAndExport)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nudge) ...[
              Card(
                key: const ValueKey('backupNudge'),
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(l10n.backupNudgeTitle),
                  subtitle: Text(l10n.backupNudgeMessage),
                  trailing: TextButton(
                    onPressed: () => _passwordFocus.requestFocus(),
                    child: Text(l10n.backupNudgeTitle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildAutoBackupSection(l10n),
            const SizedBox(height: 32),
            Text(
              l10n.backupCreateTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.backupCreateExplanation),
            const SizedBox(height: 8),
            Text(l10n.restoreSyncKeyNote),
            if (personal) ...[
              const SizedBox(height: 8),
              Text(
                l10n.backupPersonalNote,
                key: const ValueKey('backupPersonalNote'),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Focus(
                        focusNode: _passwordFocus,
                        child: NewPasswordFields(
                          controller: _passwordController,
                          confirmController: _confirmPasswordController,
                          label: l10n.backupPasswordLabel,
                        ),
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
                      key: const Key('autoBackup.restore'),
                      label: l10n.autoBackupRestore,
                      onPressed: _isLoading ? null : _restoreAutoBackup,
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

/// The password dialog of the automatic backups; owns its controllers so
/// they outlive the closing animation.
class _NewBackupPasswordDialog extends StatefulWidget {
  const _NewBackupPasswordDialog({
    required this.title,
    required this.action,
    required this.explanation,
    required this.label,
    required this.cancel,
  });

  final String title;
  final String action;
  final String explanation;
  final String label;
  final String cancel;

  @override
  State<_NewBackupPasswordDialog> createState() =>
      _NewBackupPasswordDialogState();
}

class _NewBackupPasswordDialogState extends State<_NewBackupPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.explanation),
              const SizedBox(height: 16),
              NewPasswordFields(
                controller: _controller,
                confirmController: _confirm,
                label: widget.label,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancel),
        ),
        TextButton(
          key: const Key('autoBackup.confirmPassword'),
          onPressed: _submit,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
