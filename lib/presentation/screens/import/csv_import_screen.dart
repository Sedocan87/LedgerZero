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
import 'package:ledger_zero/services/import/import_undo_service.dart';
import 'package:ledger_zero/presentation/screens/import/import_undo_dialog.dart';
import 'package:ledger_zero/domain/entities/import_profile.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:uuid/uuid.dart';

final importProfilesProvider = StreamProvider<List<ImportProfile>>((ref) {
  return ref.watch(importProfileRepositoryProvider).watchAllProfiles();
});

class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key, this.initialFile});

  /// A file to open right away instead of waiting for the picker (widget
  /// tests).
  @visibleForTesting
  final PlatformFile? initialFile;

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

  /// The signs of the amounts in the mapped amount column(s), for the
  /// "everything would be income" warning; `null` until analysed.
  CsvColumnAnalysis? _analysis;

  /// Counts [_analyze] runs so a slow one never overwrites a newer one.
  int _analysisRun = 0;

  Map<String, String?> _columnMapping = {
    for (final field in CsvField.all) field: null,
  };

  /// The app language decides the default decimal separator (German: `,`)
  /// and which day/month order wins when a file fits both.
  String get _localeDecimalSeparator => MoneyParser.forLocale(
    ref.read(appLocaleProvider).languageCode,
  ).decimalSeparator;

  bool get _preferDayFirst => ref.read(appLocaleProvider).languageCode != 'en';

  @override
  void initState() {
    super.initState();
    final file = widget.initialFile;
    if (file != null) {
      _selectedFile = file;
      _isLoading = true;
      _loadFile(file);
    }
  }

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

        try {
          await _loadFile(picked);
        } on ImportException catch (e) {
          Logger.warning('Reading the CSV failed: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
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

  /// Parses [file] and presets mapping and formats from it. [hasHeader]
  /// overrides the detection (the "no header row" switch).
  Future<void> _loadFile(PlatformFile file, {bool? hasHeader}) async {
    final service = ref.read(csvImportServiceProvider);
    final data = await service.parseCsvFile(file, hasHeader: hasHeader);
    if (!mounted) {
      return;
    }
    setState(() {
      _csvData = data;
      _applyPreset(data.preset, detected: data.preset != null);
    });
    // Still loading: the screen appears with the detected formats.
    await _analyze();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setHasHeader(bool hasHeader) async {
    final file = _selectedFile;
    if (file == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await _loadFile(file, hasHeader: hasHeader);
    } catch (e, st) {
      Logger.error('Parsing the CSV failed', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showError(l10n.csvParseFailedGeneric);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  /// Applies [preset] (or the generic mapping for `null`) to the loaded
  /// file: column mapping and outflow sign. Called inside `setState`;
  /// follow it with [_analyze] for the date format and decimal separator.
  void _applyPreset(BankCsvPreset? preset, {required bool detected}) {
    final data = _csvData?.withPreset(preset);
    if (data == null) {
      return;
    }
    _csvData = data;
    _preset = preset;
    _presetDetected = detected;
    _columnMapping = CsvImportService.initialMapping(data, preset: preset);
    _outflowIsNegative = preset?.outflowIsNegative ?? true;
  }

  /// Chooses the date format and decimal separator for the current
  /// mapping: the preset's, else detected from the column values (the app
  /// language breaks ties), and counts the amount signs. The pass over
  /// the file runs off the UI thread; a run that a newer one overtook is
  /// dropped.
  Future<void> _analyze() async {
    final data = _csvData;
    if (data == null) {
      return;
    }
    final run = ++_analysisRun;
    final preset = _preset;
    try {
      final analysis = await ref
          .read(csvImportServiceProvider)
          .analyzeColumns(
            data,
            Map.of(_columnMapping),
            preferDayFirst: _preferDayFirst,
            fallbackSeparator: _localeDecimalSeparator,
            preset: preset,
          );
      if (!mounted || run != _analysisRun) {
        return;
      }
      setState(() {
        _analysis = analysis;
        _dateDetection = preset == null ? analysis.dateDetection : null;
        _dateFormat = analysis.dateDetection.format;
        _decimalSeparator = analysis.decimalSeparator;
      });
    } catch (e, st) {
      Logger.error('Analysing the CSV columns failed', e, st);
    }
  }

  /// Lets the user type a date pattern the list does not offer.
  Future<void> _enterDateFormat() async {
    final pattern = await showDialog<String>(
      context: context,
      builder: (context) => _DateFormatDialog(initial: _dateFormat),
    );
    if (pattern != null && mounted) {
      setState(() => _dateFormat = pattern);
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
      _analysis = null;
      _analysisRun++; // A running analysis must not overwrite the profile.
      _csvData = _csvData?.withPreset(null);

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
                  _buildUndoCard(l10n),
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

  /// "Undo last import", while the last CSV import is on record.
  Widget _buildUndoCard(AppLocalizations l10n) {
    final batch = ref.read(lastImportStoreProvider).read();
    if (batch == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: ListTile(
          key: const Key('csv_undo_last_import'),
          leading: const Icon(Icons.undo),
          title: Text(l10n.importUndoLast),
          subtitle: Text(
            l10n.importUndoLastInfo(
              batch.fingerprints.length,
              ref
                  .watch(appFormatterProvider)
                  .formatDate(batch.importedAt.toLocal()),
            ),
          ),
          onTap: () async {
            await confirmAndUndoLastImport(context, ref);
            if (mounted) {
              setState(() {}); // The record is gone: hide the card.
            }
          },
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
              onChanged: (id) {
                setState(() {
                  _applyPreset(BankCsvPreset.byId(id), detected: false);
                });
                _analyze();
              },
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
            SwitchListTile(
              key: const Key('csv_no_header_row'),
              title: Text(l10n.csvNoHeaderRow),
              subtitle: data.hasHeader ? null : Text(l10n.csvNoHeaderRowHint),
              value: !data.hasHeader,
              onChanged: (noHeader) => _setHasHeader(!noHeader),
              contentPadding: EdgeInsets.zero,
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
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const Key('csv_other_date_format'),
                onPressed: _enterDateFormat,
                child: Text(l10n.csvCustomDateFormat),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.negativeValuesAreOutflows),
              value: _outflowIsNegative,
              onChanged: (v) => setState(() => _outflowIsNegative = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_analysis?.allInflows(outflowIsNegative: _outflowIsNegative) ??
                false)
              Text(
                l10n.csvIssueAllInflows(
                  _analysis!.inflowCount(outflowIsNegative: _outflowIsNegative),
                ),
                key: const Key('csv_all_inflows'),
                style: noteStyle?.copyWith(color: theme.colorScheme.error),
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
    CsvField.approved => l10n.csvFieldApproved,
    CsvField.fee => l10n.csvFieldFee,
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
              onChanged: (v) {
                setState(() => _columnMapping[field] = v);
                if (field == CsvField.date ||
                    field == CsvField.amount ||
                    field == CsvField.debit ||
                    field == CsvField.credit ||
                    field == CsvField.debitCreditFlag) {
                  _analyze();
                }
              },
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
    CsvIssueKind.allInflows => l10n.csvIssueAllInflows(issue.count),
    CsvIssueKind.voidRows => l10n.csvIssueVoidRows(issue.count),
  };

  /// Validates and converts the file off the UI thread, then shows what
  /// validation found or goes on to the review.
  Future<void> _validateAndImport() async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(csvImportServiceProvider);

    setState(() => _isLoading = true);
    final CsvPreparedImport prepared;
    try {
      prepared = await service.prepareImport(
        data: _csvData!,
        columnMapping: Map.of(_columnMapping),
        dateFormat: _dateFormat,
        decimalSeparator: _decimalSeparator,
        outflowIsNegative: _outflowIsNegative,
      );
    } catch (e, st) {
      Logger.error('Preparing the CSV import failed', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(l10n.csvParseFailedGeneric);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
    final result = prepared.validation;

    if (!result.isValid) {
      // Show errors (blocking)
      await showDialog<void>(
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
      await showDialog<void>(
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
                _proceedToImport(prepared.transactions);
              },
              child: Text(l10n.continueToReview),
            ),
          ],
        ),
      );
    } else {
      await _proceedToImport(prepared.transactions);
    }
  }

  Future<void> _proceedToImport(List<ImportTransaction> transactions) async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(csvImportServiceProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);

    try {
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

/// Asks for a date pattern; pops with it once [isUsableCsvDateFormat]
/// accepts it.
class _DateFormatDialog extends StatefulWidget {
  const _DateFormatDialog({required this.initial});

  final String initial;

  @override
  State<_DateFormatDialog> createState() => _DateFormatDialogState();
}

class _DateFormatDialogState extends State<_DateFormatDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (isUsableCsvDateFormat(text)) {
      Navigator.pop(context, text);
    } else {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.dateFormat),
      content: TextField(
        key: const Key('csv_custom_date_format'),
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          helperText: l10n.csvCustomDateFormatHelp,
          helperMaxLines: 3,
          errorText: _invalid ? l10n.csvCustomDateFormatInvalid : null,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
