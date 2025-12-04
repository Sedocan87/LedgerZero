import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';

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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      } else if (_columnMapping['Amount'] == null && (h.contains('amount') || h.contains('value') || h == 'amt')) {
        _columnMapping['Amount'] = header;
      } else if (_columnMapping['Payee'] == null && (h.contains('payee') || h.contains('description') || h.contains('merchant') || h.contains('desc'))) {
        _columnMapping['Payee'] = header;
      } else if (_columnMapping['Memo'] == null && (h.contains('memo') || h.contains('note') || h.contains('remark'))) {
        _columnMapping['Memo'] = header;
      } else if (_columnMapping['Category'] == null && (h.contains('category') || h.contains('cat'))) {
        _columnMapping['Category'] = header;
      }
    }
    _autoDetectDateFormat();
  }

  void _autoDetectDateFormat() {
    if (_csvData == null || _columnMapping['Date'] == null) return;

    final dateHeader = _columnMapping['Date']!;
    final dateIndex = _csvData!.headers.indexOf(dateHeader);
    if (dateIndex == -1) return;

    // Check first few non-empty rows
    for (var row in _csvData!.rows.take(5)) {
        if (row.length <= dateIndex) continue;
        final val = row[dateIndex].toString();
        // Try formats
        for (var fmt in _dateFormats) {
            try {
                DateFormat(fmt).parse(val);
                setState(() => _dateFormat = fmt);
                return;
            } catch (e) {}
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importCsv)),
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
                    value: _dateFormat,
                    items: _dateFormats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setState(() => _dateFormat = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: l10n.decimalSeparator),
                    value: _decimalSeparator,
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
              if (field == 'Date') localizedField = l10n.date;
              if (field == 'Amount') localizedField = l10n.amount;
              if (field == 'Payee') localizedField = l10n.payee;
              if (field == 'Memo') localizedField = l10n.memo;
              if (field == 'Category') localizedField = l10n.category;

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
                        onChanged: (v) {
                          setState(() => _columnMapping[field] = v);
                          if (field == 'Date') _autoDetectDateFormat();
                        },
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
    if (_csvData == null) return const SizedBox();

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
    if (_columnMapping['Date'] == null) {
      _showError(l10n.pleaseMapColumn(l10n.date));
      return;
    }
    if (_columnMapping['Amount'] == null) {
      _showError(l10n.pleaseMapColumn(l10n.amount));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.validationPassed)),
    );
  }
}
