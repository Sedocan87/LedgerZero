import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ledger_zero/services/import/ynab_data_mapper.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';

enum YnabImportStep { selectMethod, selectFiles, preview, importing, success }

/// What went wrong, shown to the user as a localised message (technical
/// detail goes to the log only).
enum YnabImportError {
  filePickFailed,
  folderPickFailed,
  filesMissing,
  folderMissing,

  /// Register.csv lacks columns; [YnabImportState.errorDetail] lists them.
  missingColumns,
  invalidYnab4Folder,

  /// The picked ZIP holds no YNAB 4 budget.
  invalidYnab4Zip,

  /// The picked ZIP is not YNAB's export (register and budget CSV).
  invalidExportZip,

  /// No date format fits every Register.csv date;
  /// [YnabImportState.errorDetail] is the first value that does not parse.
  invalidDates,

  /// The budget file lacks columns; [YnabImportState.errorDetail] lists
  /// them.
  missingBudgetColumns,

  /// An amount cell is not a number; [YnabImportState.errorDetail] is it.
  invalidAmount,
  unreadableFiles,
  importFailed,
}

enum YnabImportMethod {
  nynabCsv, // nYNAB (CSV)
  ynab4, // YNAB 4 (Classic)
}

class YnabImportState {
  final YnabImportStep currentStep;
  final YnabImportMethod? method;
  final PlatformFile? registerFile;
  final PlatformFile? budgetFile;

  /// The register / budget CSV taken out of YNAB's export ZIP. A file
  /// picked on its own ([registerFile], [budgetFile]) replaces it and the
  /// other way round.
  final YnabZipEntry? registerEntry;
  final YnabZipEntry? budgetEntry;

  /// The YNAB 4 budget: the picked folder, or the picked ZIP of it (the
  /// one picked last).
  final String? ynab4FolderPath;
  final PlatformFile? ynab4Zip;
  final YnabImportData? parsedData;
  final bool isLoading;
  final YnabImportError? error;

  /// Extra text for [error] (the missing column names), or `null`.
  final String? errorDetail;
  final bool isImporting;

  /// Currency of the accounts the import creates (ISO code).
  final String currency;

  /// What the import wrote; set on success.
  final YnabImportSummary? summary;

  /// When this very export was imported before (by content fingerprint),
  /// or `null`.
  final DateTime? previousImportAt;

  const YnabImportState({
    this.currentStep = YnabImportStep.selectMethod,
    this.method,
    this.registerFile,
    this.budgetFile,
    this.registerEntry,
    this.budgetEntry,
    this.ynab4FolderPath,
    this.ynab4Zip,
    this.parsedData,
    this.isLoading = false,
    this.error,
    this.errorDetail,
    this.isImporting = false,
    this.currency = 'USD',
    this.summary,
    this.previousImportAt,
  });

  /// The name of the chosen register / budget file, or `null`.
  String? get registerName => registerFile?.name ?? registerEntry?.name;
  String? get budgetName => budgetFile?.name ?? budgetEntry?.name;

  /// Whether a YNAB 4 budget (folder or ZIP) is chosen.
  bool get hasYnab4Source => ynab4FolderPath != null || ynab4Zip != null;

  YnabImportState copyWith({
    YnabImportStep? currentStep,
    YnabImportMethod? method,
    PlatformFile? registerFile,
    PlatformFile? budgetFile,
    YnabZipEntry? registerEntry,
    YnabZipEntry? budgetEntry,
    String? ynab4FolderPath,
    PlatformFile? ynab4Zip,
    YnabImportData? parsedData,
    bool? isLoading,
    YnabImportError? error,
    String? errorDetail,
    bool? isImporting,
    String? currency,
    YnabImportSummary? summary,
    DateTime? previousImportAt,
    bool clearParsedData = false,
  }) {
    return YnabImportState(
      currentStep: currentStep ?? this.currentStep,
      method: method ?? this.method,
      registerFile: registerEntry != null
          ? null
          : (registerFile ?? this.registerFile),
      budgetFile: budgetEntry != null ? null : (budgetFile ?? this.budgetFile),
      registerEntry: registerFile != null
          ? null
          : (registerEntry ?? this.registerEntry),
      budgetEntry: budgetFile != null
          ? null
          : (budgetEntry ?? this.budgetEntry),
      ynab4FolderPath: ynab4Zip != null
          ? null
          : (ynab4FolderPath ?? this.ynab4FolderPath),
      ynab4Zip: ynab4FolderPath != null ? null : (ynab4Zip ?? this.ynab4Zip),
      parsedData: clearParsedData ? null : (parsedData ?? this.parsedData),
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable to clear error
      errorDetail: error == null ? null : errorDetail,
      isImporting: isImporting ?? this.isImporting,
      currency: currency ?? this.currency,
      summary: summary ?? this.summary,
      previousImportAt: clearParsedData
          ? null
          : (previousImportAt ?? this.previousImportAt),
    );
  }
}
