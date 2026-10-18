import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/core/money/money_parser.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/csv/bank_csv_presets.dart';
import 'package:ledger_zero/services/csv/csv_date_formats.dart';
import 'package:ledger_zero/services/csv/csv_import_service.dart';
import 'package:ledger_zero/domain/entities/import_profile.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
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
  String _dateFormat = csvDateFormats.first;
  String _decimalSeparator = '.';
  bool _outflowIsNegative = true;

  /// The bank preset in use (chosen by the user or recognised from the
  /// headers), or `null` for the generic keyword mapping.
  BankCsvPreset? _preset;
  bool _presetDetected = false;

  /// What the date-format detection found for the mapped date column.
  CsvDateDetection? _dateDetection;

  Map<String, String?> _columnMapping = {
    for (final field in CsvField.all) field: null,
  };

  /// The app language decides the default decimal separator (German: `,`)
  /// and which day/month order wins when a file fits both.
  String get _localeDecimalSeparator => MoneyParser.forLocale(
    ref.read(appLocaleProvider).languageCode,
  ).decimalSeparator;

  bool get _preferDayFirst => ref.read(appLocaleProvider).languageCode != 'en';

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      // The picker is our own OS screen: do not auto-lock for it.
      final picked = await ExternalUiGuard.run(
        () => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['csv', 'txt'],
        ),
      );

      if (picked != null) {
        setState(() {
          _isLoading = true;
          _selectedFile = picked;
        });

        final service = ref.read(csvImportServiceProvider);
        try {
          final data = await service.parseCsvFile(_selectedFile!);
          setState(() {
            _csvData = data;
            _isLoading = false;
            _applyPreset(data.preset, detected: data.preset != null);
          });
        } on ImportException catch (e) {
          Logger.warning('Reading the CSV failed: $e');
          setState(() => _isLoading = false);
          _showError(switch (e.failure) {
            ImportFailure.empty => l10n.csvFileEmpty,
            ImportFailure.unreadable => l10n.filePickFailedGeneric,
            ImportFailure.malformed => l10n.csvParseFailedGeneric,
          });
        } catch (e, st) {
          Logger.error('Parsing the CSV failed', e, st);
          if (mounted) {
            setState(() => _isLoading = false);
          }
          _showError(l10n.csvParseFailedGeneric);
        }
      }
    } catch (e, st) {
      Logger.error('Picking the CSV failed', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showError(l10n.filePickFailedGeneric);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  /// Applies [preset] (or the generic keyword mapping for `null`) to the
  /// loaded file: column mapping, date format, decimal separator and
  /// outflow sign. Called inside `setState`.
  void _applyPreset(BankCsvPreset? preset, {required bool detected}) {
    final data = _csvData;
    if (data == null) {
      return;
    }
    _preset = preset;
    _presetDetected = detected;
    _columnMapping = CsvImportService.autoMapColumns(
      data.headers,
      preset: preset,
    );
    _outflowIsNegative = preset?.outflowIsNegative ?? true;
    _detectFormats();
  }

  /// Chooses the date format and decimal separator for the current
  /// mapping: the preset's, else detected from the column values (the app
  /// language breaks ties). Called inside `setState`.
  void _detectFormats() {
    final data = _csvData;
    if (data == null) {
      return;
    }
    final service = ref.read(csvImportServiceProvider);
    final detection = service.detectDateFormat(
      data,
      _columnMapping,
      preferDayFirst: _preferDayFirst,
      preset: _preset,
    );
    _dateDetection = _preset == null ? detection : null;
    _dateFormat = detection.format;
    _decimalSeparator = service.detectDecimalSeparator(
      data,
      _columnMapping,
      fallback: _localeDecimalSeparator,
      preset: _preset,
    );
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
        dateColumn: _columnMapping[CsvField.date],
        amountColumn: _columnMapping[CsvField.amount],
        payeeColumn: _columnMapping[CsvField.payee],
        memoColumn: _columnMapping[CsvField.memo],
        categoryColumn: _columnMapping[CsvField.category],
        createdAt: DateTime.now().toUtc(),
      );

      await ref.read(importProfileRepositoryProvider).createProfile(profile);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      }
    }
  }

  void _loadProfile(ImportProfile profile) {
    setState(() {
      _dateFormat = profile.dateFormat;
      _decimalSeparator = profile.decimalSeparator;
      _outflowIsNegative = profile.outflowIsNegative;
      _preset = null;
      _presetDetected = false;
      _dateDetection = null;

      // Apply mappings if headers exist in current CSV
      final headers = _csvData?.headers;
      if (headers != null) {
        for (final (field, column) in [
          (CsvField.date, profile.dateColumn),
          (CsvField.amount, profile.amountColumn),
          (CsvField.payee, profile.payeeColumn),
          (CsvField.memo, profile.memoColumn),
          (CsvField.category, profile.categoryColumn),
        ]) {
          if (column != null && headers.contains(column)) {
            _columnMapping[field] = column;
          }
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
                          subtitle: Text(
                            ref
                                .watch(appFormatterProvider)
                                .formatDate(profile.createdAt.toLocal()),
                          ),
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
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref
                                    .read(importProfileRepositoryProvider)
                                    .deleteProfile(profile.id);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
          const InfoButton(HelpTopic.csvImport),
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
                l10n.fileSizeKb((_selectedFile!.lengthSync() ?? 0) / 1024),
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
              Text(l10n.selectFileToImport, style: theme.textTheme.titleMedium),
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
    final data = _csvData!;
    final detection = _dateDetection;
    final dateFormats = {...csvDateFormats, _dateFormat}.toList();
    final noteStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.configuration, style: theme.textTheme.titleLarge),
            const Divider(),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('csv_bank_preset'),
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.csvBankFormat),
              initialValue: _preset?.id ?? '',
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(l10n.csvBankFormatNone),
                ),
                for (final preset in bankCsvPresets)
                  DropdownMenuItem(value: preset.id, child: Text(preset.name)),
              ],
              onChanged: (id) => setState(() {
                _applyPreset(BankCsvPreset.byId(id), detected: false);
              }),
            ),
            if (_presetDetected && _preset != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.csvBankFormatDetected(_preset!.name),
                  key: const Key('csv_preset_detected'),
                  style: noteStyle,
                ),
              ),
            if (data.headerLineIndex > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.csvHeaderLinesSkipped(data.headerLineIndex),
                  style: noteStyle,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // Fills the half-width column; long values ellipsize
                    // instead of overflowing on narrow phones.
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.dateFormat),
                    initialValue: _dateFormat,
                    items: dateFormats
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _dateFormat = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.decimalSeparator,
                    ),
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
            if (detection != null &&
                detection.ambiguous &&
                detection.candidates.contains(_dateFormat))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.csvDateFormatAmbiguous(
                    _dateFormat,
                    detection.candidates.firstWhere((c) => c != _dateFormat),
                  ),
                  key: const Key('csv_date_ambiguous'),
                  style: noteStyle?.copyWith(color: theme.colorScheme.error),
                ),
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

  String _fieldLabel(AppLocalizations l10n, String field) => switch (field) {
    CsvField.date => l10n.date,
    CsvField.amount => l10n.amount,
    CsvField.payee => l10n.payee,
    CsvField.memo => l10n.memo,
    CsvField.category => l10n.category,
    CsvField.debit => l10n.csvFieldDebit,
    CsvField.credit => l10n.csvFieldCredit,
    CsvField.debitCreditFlag => l10n.csvFieldDebitCreditFlag,
    CsvField.inflowPayee => l10n.csvFieldInflowPayee,
    CsvField.account => l10n.account,
    CsvField.transfer => l10n.csvFieldTransfer,
    CsvField.cleared => l10n.cleared,
    _ => field,
  };

  Widget _buildMappingRow(
    ThemeData theme,
    AppLocalizations l10n,
    String field,
  ) {
    final required = field == CsvField.date || field == CsvField.amount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              _fieldLabel(l10n, field),
              style: TextStyle(
                fontWeight: required ? FontWeight.bold : FontWeight.normal,
                color: required ? theme.colorScheme.primary : null,
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
                ..._csvData!.headers.map(
                  (h) => DropdownMenuItem(value: h, child: Text(h)),
                ),
              ],
              onChanged: (v) => setState(() {
                _columnMapping[field] = v;
                if (field == CsvField.date ||
                    field == CsvField.amount ||
                    field == CsvField.debit ||
                    field == CsvField.credit) {
                  _detectFormats();
                }
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingCard(ThemeData theme, AppLocalizations l10n) {
    final secondary = [
      for (final f in CsvField.all)
        if (!CsvField.primary.contains(f)) f,
    ];
    final secondaryMapped = secondary.any((f) => _columnMapping[f] != null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.columnMapping, style: theme.textTheme.titleLarge),
            const Divider(),
            const SizedBox(height: 8),
            for (final field in CsvField.primary)
              _buildMappingRow(theme, l10n, field),
            ExpansionTile(
              key: const Key('csv_more_columns'),
              title: Text(l10n.csvMoreColumns),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: secondaryMapped,
              children: [
                for (final field in secondary)
                  _buildMappingRow(theme, l10n, field),
              ],
            ),
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
                columns: _csvData!.headers
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: previewRows.map((row) {
                  // Short rows are padded, long ones cut, so every row has
                  // one cell per header.
                  final cells = [
                    for (var i = 0; i < _csvData!.headers.length; i++)
                      i < row.length ? row[i].toString() : '',
                  ];
                  return DataRow(
                    cells: cells.map((cell) => DataCell(Text(cell))).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _issueText(
    AppLocalizations l10n,
    CsvIssue issue, {
    required bool blocking,
  }) => switch (issue.kind) {
    CsvIssueKind.dateColumnNotMapped => l10n.csvIssueDateNotMapped,
    CsvIssueKind.amountColumnNotMapped => l10n.csvIssueAmountNotMapped,
    CsvIssueKind.mappedColumnsMissing => l10n.csvIssueColumnsMissing,
    CsvIssueKind.noRows => l10n.csvIssueNoRows,
    CsvIssueKind.invalidDates =>
      blocking
          ? l10n.csvIssueInvalidDates(
              issue.count,
              issue.dateFormat ?? _dateFormat,
            )
          : l10n.csvIssueInvalidDatesSkipped(
              issue.count,
              issue.dateFormat ?? _dateFormat,
            ),
    CsvIssueKind.invalidAmounts =>
      blocking
          ? l10n.csvIssueInvalidAmountsBlocking(issue.count)
          : l10n.csvIssueInvalidAmounts(issue.count),
    CsvIssueKind.dateOutliers => l10n.csvIssueDateOutliers(issue.count),
    CsvIssueKind.ambiguousDateFormat => l10n.csvDateFormatAmbiguous(
      issue.dateFormat ?? _dateFormat,
      issue.otherFormat ?? '',
    ),
  };

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
            children: [
              for (final issue in result.errors)
                Text(l10n.bulletItem(_issueText(l10n, issue, blocking: true))),
            ],
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
            children: [
              for (final issue in result.warnings)
                Text(l10n.bulletItem(_issueText(l10n, issue, blocking: false))),
            ],
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
    final categoryRepo = ref.read(categoryRepositoryProvider);

    try {
      final transactions = service.convertCsvToTransactions(
        data: _csvData!,
        columnMapping: _columnMapping,
        dateFormat: _dateFormat,
        decimalSeparator: _decimalSeparator,
        outflowIsNegative: _outflowIsNegative,
      );

      // The file's Category column is matched to existing categories.
      // Duplicates are checked on the review screen, against the account
      // the user picks there.
      if (_columnMapping[CsvField.category] != null) {
        service.assignCategories(
          imported: transactions,
          categories: await categoryRepo.getAllCategories(),
          groups: await categoryRepo.getAllCategoryGroups(),
        );
      }

      if (mounted) {
        await context.pushNamed('import-confirm', extra: transactions);
      }
    } catch (e, st) {
      Logger.error('Preparing the CSV import failed', e, st);
      if (mounted) {
        _showError(l10n.csvParseFailedGeneric);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
