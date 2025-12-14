import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';
import 'package:ledger_zero/services/import/mint_migration_service.dart';

class MintImportScreen extends ConsumerStatefulWidget {
  const MintImportScreen({super.key});

  @override
  ConsumerState<MintImportScreen> createState() => _MintImportScreenState();
}

class _MintImportScreenState extends ConsumerState<MintImportScreen> {
  bool _isLoading = false;
  double _progress = 0.0;
  String? _error;
  String? _fileName;
  File? _selectedFile;

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _isLoading = false;
      _progress = 0.0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      Logger.error('Error picking file', e);
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _importData() async {
    if (_selectedFile == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _error = null;
    });

    try {
      final content = await _selectedFile!.readAsString();
      final migrationService = ref.read(mintMigrationServiceProvider);

      final result = await migrationService.importFile(
        content,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (mounted) {
        _showSuccessDialog(result);
      }
    } catch (e) {
      Logger.error('Error executing Mint import', e);
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(MintMigrationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Import Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transactions Imported: ${result.transactionsImported}'),
            Text('Accounts Created: ${result.accountsCreated}'),
            Text('Categories Created: ${result.categoriesCreated}'),
            Text('Payees Created: ${result.payeesCreated}'),
            if (result.duplicatesSkipped > 0)
              Text(
                'Duplicates Skipped: ${result.duplicatesSkipped}',
                style: const TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop(); // Close dialog
              context.pop(); // Go back to settings
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Mint')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select your Mint "transactions.csv" export file.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (_fileName == null)
              AppButton.primary(
                label: 'Select File',
                onPressed: _isLoading ? null : _pickFile,
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(_fileName!),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _fileName = null;
                        _selectedFile = null;
                        _error = null;
                      });
                    },
                  ),
                ),
              ),

            if (_isLoading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                textAlign: TextAlign.center,
              ),
            ],

            if (_error != null)
              Expanded(
                child: ErrorView(
                  title: 'Import Error',
                  message: _error!,
                  onRetry: _pickFile,
                ),
              ),

            if (_selectedFile != null && !_isLoading) ...[
              const Spacer(),
              AppButton.primary(label: 'Start Import', onPressed: _importData),
            ],
          ],
        ),
      ),
    );
  }
}
