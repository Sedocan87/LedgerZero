import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/domain/entities/import_profile.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:uuid/uuid.dart';

final importProfilesProvider = StreamProvider<List<ImportProfile>>((ref) {
  return ref.watch(importProfileRepositoryProvider).watchAllProfiles();
});

class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  PlatformFile? _selectedFile;
  CsvImportData? _csvData;
  bool _isLoading = false;

  // Configuration
  String _dateFormat = 'yyyy-MM-dd';
  String _decimalSeparator = '.';
  bool _outflowIsNegative = true;

  final Map<String, String?> _columnMapping = {
    'Date': null,
    'Amount': null,
    'Payee': null,
    'Memo': null,
    'Category': null,
  };

  final List<String> _dateFormats = [
    'yyyy-MM-dd',
    'MM/dd/yyyy',
    'dd/MM/yyyy',
    'yyyy.MM.dd',
    'dd.MM.yyyy',
    'MM-dd-yyyy',
  ];

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
          _selectedFile = result.files.first;
        });

        final service = ref.read(csvImportServiceProvider);
        try {
          final data = await service.parseCsvFile(_selectedFile!);
          setState(() {
            _csvData = data;
            _isLoading = false;
            _autoMapColumns(data.headers);
          });
        } on ImportException catch (e) {
          setState(() => _isLoading = false);
          _showError(e.message);
        } catch (e) {
          setState(() => _isLoading = false);
          _showError(l10n.failedToParseCsv(e.toString()));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(l10n.errorPickingFile(e.toString()));
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _autoMapColumns(List<String> headers) {
    _columnMapping.updateAll((key, value) => null);

    for (var header in headers) {
      final h = header.toLowerCase();
      if (_columnMapping['Date'] == null && (h.contains('date') || h == 'dt')) {
      _columnMapping['Date'] = header;
    } else if (_columnMapping['Amount'] == null &&
          (h.contains('amount') || h.contains('value') || h == 'amt')) {
        _columnMapping['Amount'] = header;
      } else if (_columnMapping['Payee'] == null &&
          (h.contains('payee') ||
              h.contains('description') ||
              h.contains('merchant') ||
              h.contains('desc'))) {
        _columnMapping['Payee'] = header;
      } else if (_columnMapping['Memo'] == null &&
          (h.contains('memo') || h.contains('note') || h.contains('remark'))) {
        _columnMapping['Memo'] = header;
      } else if (_columnMapping['Category'] == null &&
          (h.contains('category') || h.contains('cat'))) {
        _columnMapping['Category'] = header;
      }
    }
    _autoDetectDateFormat();
  }

  void _autoDetectDateFormat() {
    if (_csvData == null || _columnMapping['Date'] == null) {
      return;
    }

    final dateHeader = _columnMapping['Date']!;
    final dateIndex = _csvData!.headers.indexOf(dateHeader);
    if (dateIndex == -1) {
      return;
    }

    // Check first few non-empty rows
    for (var row in _csvData!.rows.take(5)) {
      if (row.length <= dateIndex) {
      continue;
    }
      final val = row[dateIndex].toString();
      // Try formats
      for (var fmt in _dateFormats) {
          try {
            DateFormat(fmt).parse(val);
            setState(() => _dateFormat = fmt);
            return;
          } catch (e) {
            // Ignore
          }
        }
    }
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: Text(l10n.saveImportProfile),
          content: TextField(
            decoration: InputDecoration(labelText: l10n.profileName),
            onChanged: (v) => input = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      final profile = ImportProfile(
        id: const Uuid().v4(),
        name: name,
        dateFormat: _dateFormat,
        decimalSeparator: _decimalSeparator,
        outflowIsNegative: _outflowIsNegative,
        dateColumn: _columnMapping['Date'],
        amountColumn: _columnMapping['Amount'],
        payeeColumn: _columnMapping['Payee'],
        memoColumn: _columnMapping['Memo'],
        categoryColumn: _columnMapping['Category'],
        createdAt: DateTime.now(),
      );

      await ref.read(importProfileRepositoryProvider).createProfile(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileSaved)),
        );
      }
    }
  }

  void _loadProfile(ImportProfile profile) {
    setState(() {
      _dateFormat = profile.dateFormat;
      _decimalSeparator = profile.decimalSeparator;
      _outflowIsNegative = profile.outflowIsNegative;

      // Apply mappings if headers exist in current CSV
      if (_csvData != null) {
        if (profile.dateColumn != null && _csvData!.headers.contains(profile.dateColumn)) {
      _columnMapping['Date'] = profile.dateColumn;
    }
        if (profile.amountColumn != null && _csvData!.headers.contains(profile.amountColumn)) {
      _columnMapping['Amount'] = profile.amountColumn;
    }
        if (profile.payeeColumn != null && _csvData!.headers.contains(profile.payeeColumn)) {
      _columnMapping['Payee'] = profile.payeeColumn;
    }
        if (profile.memoColumn != null && _csvData!.headers.contains(profile.memoColumn)) {
      _columnMapping['Memo'] = profile.memoColumn;
    }
        if (profile.categoryColumn != null && _csvData!.headers.contains(profile.categoryColumn)) {
      _columnMapping['Category'] = profile.categoryColumn;
    }
      }
    });
  }

  Future<void> _showLoadProfileDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.loadImportProfile),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer(
              builder: (context, ref, child) {
                final profilesAsync = ref.watch(importProfilesProvider);
                return profilesAsync.when(
                  data: (profiles) {
                    if (profiles.isEmpty) {
      return Center(child: Text(l10n.noTemplates));
    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return ListTile(
                          title: Text(profile.name),
                          subtitle: Text(DateFormat.yMMMd().format(profile.createdAt)),
                          onTap: () {
                            _loadProfile(profile);
                            Navigator.pop(context);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.deleteTemplate),
                                  content: Text(l10n.deleteProfileConfirmation),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
      await ref.read(importProfileRepositoryProvider).deleteProfile(profile.id);
    }
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text(l10n.error),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importCsv),
        actions: [
          IconButton(
             icon: const Icon(Icons.file_upload),
             onPressed: _showLoadProfileDialog,
             tooltip: l10n.loadImportProfile,
          ),
          if (_csvData != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: l10n.saveImportProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFileSelectionCard(theme, l10n),
                  if (_csvData != null) ...[
                    const SizedBox(height: 16),
                    _buildConfigurationCard(theme, l10n),
                    const SizedBox(height: 16),
                    _buildMappingCard(theme, l10n),
                    const SizedBox(height: 16),
                    _buildPreviewCard(theme, l10n),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _validateAndImport,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(l10n.continueToReview),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFileSelectionCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_selectedFile != null) ...[
              const Icon(Icons.description, size: 48, color: Colors.teal),
              const SizedBox(height: 8),
              Text(
                _selectedFile!.name,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.changeFile),
              ),
            ] else ...[
              const Icon(Icons.upload_file, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                l10n.selectFileToImport,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.selectFile),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.configuration, style: theme.textTheme.titleLarge),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: l10n.dateFormat),
                    initialValue: _dateFormat,
                    items: _dateFormats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setState(() => _dateFormat = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: l10n.decimalSeparator),
                    initialValue: _decimalSeparator,
                    items: [
                      DropdownMenuItem(value: '.', child: Text(l10n.dot)),
                      DropdownMenuItem(value: ',', child: Text(l10n.comma)),
                    ],
                    onChanged: (v) => setState(() => _decimalSeparator = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.negativeValuesAreOutflows),
              value: _outflowIsNegative,
              onChanged: (v) => setState(() => _outflowIsNegative = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.columnMapping, style: theme.textTheme.titleLarge),
            const Divider(),
            const SizedBox(height: 8),
            ..._columnMapping.keys.map((field) {
              // Localize field names
              String localizedField = field;
              if (field == 'Date') {
      localizedField = l10n.date;
    }
              if (field == 'Amount') {
      localizedField = l10n.amount;
    }
              if (field == 'Payee') {
      localizedField = l10n.payee;
    }
              if (field == 'Memo') {
      localizedField = l10n.memo;
    }
              if (field == 'Category') {
      localizedField = l10n.category;
    }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        localizedField,
                        style: TextStyle(
                          fontWeight: ['Date', 'Amount'].contains(field) ? FontWeight.bold : FontWeight.normal,
                          color: ['Date', 'Amount'].contains(field) ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text(l10n.selectColumn),
                        value: _columnMapping[field],
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.ignore)),
                          ..._csvData!.headers.map((h) => DropdownMenuItem(value: h, child: Text(h))),
                        ],
                        onChanged: (v) => setState(() {
                            _columnMapping[field] = v;
                            if (field == 'Date') {
      _autoDetectDateFormat();
    }
                          }),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ThemeData theme, AppLocalizations l10n) {
    if (_csvData == null) {
      return const SizedBox();
    }

    final previewRows = _csvData!.rows.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.preview, style: theme.textTheme.titleLarge),
            const Divider(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: _csvData!.headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: previewRows.map((row) {
                  return DataRow(
                    cells: row.map((cell) => DataCell(Text(cell.toString()))).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateAndImport() {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(csvImportServiceProvider);

    final result = service.validateCsvData(
      data: _csvData!,
      columnMapping: _columnMapping,
      dateFormat: _dateFormat,
      decimalSeparator: _decimalSeparator,
    );

    if (!result.isValid) {
      // Show errors (blocking)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.error),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: result.errors.map((e) => Text('• $e')).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.gotIt),
            ),
          ],
        ),
      );
    } else if (result.warnings.isNotEmpty) {
      // Show warnings (cancellable)
       showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.warning),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: result.warnings.map((e) => Text('• $e')).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
             FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _proceedToImport();
              },
              child: Text(l10n.continueToReview),
            ),
          ],
        ),
      );
    } else {
      _proceedToImport();
    }
  }

  Future<void> _proceedToImport() async {
      setState(() => _isLoading = true);
      final l10n = AppLocalizations.of(context)!;
      final service = ref.read(csvImportServiceProvider);
      final repo = ref.read(transactionRepositoryProvider);
      final payeeRepo = ref.read(payeeRepositoryProvider);

      try {
        final transactions = service.convertCsvToTransactions(
          data: _csvData!,
          columnMapping: _columnMapping,
          dateFormat: _dateFormat,
          decimalSeparator: _decimalSeparator,
          outflowIsNegative: _outflowIsNegative,
        );

        if (transactions.isNotEmpty) {
          final minDate = transactions.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
          final maxDate = transactions.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);

          final existing = await repo.getTransactions(
            filter: TransactionFilter(
              startDate: minDate.subtract(const Duration(days: 1)),
              endDate: maxDate.add(const Duration(days: 1)),
            ),
          );

          final payees = await payeeRepo.getAllPayees();
          final payeeMap = {for (var p in payees) p.id: p.name};

          service.checkForDuplicates(
            imported: transactions,
            existing: existing,
            payeeMap: payeeMap,
          );

          if (transactions.any((t) => t.isDuplicate)) {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(l10n.deduplicationComplete(transactions.where((t) => t.isDuplicate).length))),
               );
             }
          }
        }

        if (mounted) {
          await context.pushNamed(
            'import-confirm',
            extra: transactions,
          );
        }
      } catch (e) {
        if (mounted) {
      _showError(l10n.failedToParseCsv(e.toString()));
    }
      } finally {
        if (mounted) {
      setState(() => _isLoading = false);
    }
      }
  }
}
