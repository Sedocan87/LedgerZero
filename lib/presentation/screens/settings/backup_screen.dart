import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:share_plus/share_plus.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _restorePasswordController = TextEditingController();
  bool _isEncrypting = true;
  bool _isLoading = false;
  bool _uploadToCloud = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _restorePasswordController.dispose();
    super.dispose();
  }

  Future<void> _createBackup() async {
    final password = _passwordController.text;
    if (_isEncrypting) {
      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a password for encryption.')),
        );
        return;
      }
      if (password.length < 8) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 8 characters long.')),
        );
        return;
      }
      if (password != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
        return;
      }
    } else {
       // Warn about unencrypted backup
       final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unencrypted Backup Warning'),
          content: const Text('You are creating an unencrypted backup. This file can be opened by anyone. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final backupService = ref.read(backupServiceProvider);
      // If not encrypting, pass null. If encrypting, pass password.
      final file = await backupService.createBackup(
        password: _isEncrypting ? password : null,
      );

      if (_uploadToCloud) {
        try {
          await backupService.uploadBackupToCloud(file);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Backup uploaded to cloud successfully.')),
            );
          }
        } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cloud upload failed: $e')),
            );
          }
        }
      }

      if (mounted) {
        // Use share_plus to export the file
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'LedgerZero Backup',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    // 1. Pick File
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;
    final file = File(path);

    // 2. Ask for password if needed (check extension or just ask)
    String? password;
    if (path.endsWith('.lzbk')) {
      password = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter Backup Password'),
          content: TextField(
            controller: _restorePasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _restorePasswordController.text),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (password == null) return; // User cancelled
    } else {
      // Confirm unencrypted restore
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text('This will overwrite your current database. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final restoreService = ref.read(restoreServiceProvider);
      await restoreService.restoreBackup(file, password: password);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restore Successful'),
            content: const Text('The database has been restored. Please restart the app to apply changes.'),
            actions: [
              TextButton(
                onPressed: () {
                  // Exit app or just pop? Exit is drastic.
                  // Ideally we reload, but "restart" is safer.
                  exit(0);
                },
                child: const Text('Exit App'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Backup',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a full backup of your database. You can encrypt it with a password for security.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Encrypt Backup'),
                      subtitle: const Text('Protect your data with a password'),
                      value: _isEncrypting,
                      onChanged: (value) {
                        setState(() {
                          _isEncrypting = value;
                        });
                      },
                    ),
                    if (_isEncrypting) ...[
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Backup Password',
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        obscureText: true,
                      ),
                    ],
                    SwitchListTile(
                      title: const Text('Upload to Cloud'),
                      subtitle: const Text('Save copy to configured cloud storage (Drive/iCloud)'),
                      value: _uploadToCloud,
                      onChanged: (value) {
                         setState(() {
                           _uploadToCloud = value;
                         });
                      },
                    ),
                    const SizedBox(height: 24),
                    AppButton.primary(
                      label: _isLoading ? 'Creating Backup...' : 'Export Backup',
                      onPressed: _isLoading ? null : _createBackup,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Restore Backup',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Restore your database from a backup file. This will replace all current data.',
            ),
            const SizedBox(height: 16),
             Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    AppButton.secondary(
                      label: 'Restore from File',
                      onPressed: _isLoading ? null : _restoreBackup,
                    ),
                    const SizedBox(height: 16),
                    AppButton.secondary(
                      label: 'Selective Restore (Date Range)',
                      onPressed: _isLoading ? null : _selectiveRestore,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectiveRestore() async {
    // 1. Pick File
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;
    final file = File(path);

    // 2. Ask for password if needed
    String? password;
    if (path.endsWith('.lzbk')) {
      password = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter Backup Password'),
          content: TextField(
            controller: _restorePasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _restorePasswordController.text),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (password == null) return;
    }

    // 3. Pick Date Range
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (dateRange == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final restoreService = ref.read(restoreServiceProvider);
      await restoreService.selectiveRestore(file, dateRange.start, dateRange.end, password: password);

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions merged successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selective restore failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
