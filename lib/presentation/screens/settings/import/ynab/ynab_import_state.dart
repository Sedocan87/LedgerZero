import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ledger_zero/services/import/ynab_data_mapper.dart';

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

  /// No date format fits every Register.csv date;
  /// [YnabImportState.errorDetail] is the first value that does not parse.
  invalidDates,
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
  final String? ynab4FolderPath;
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

  const YnabImportState({
    this.currentStep = YnabImportStep.selectMethod,
    this.method,
    this.registerFile,
    this.budgetFile,
    this.ynab4FolderPath,
    this.parsedData,
    this.isLoading = false,
    this.error,
    this.errorDetail,
    this.isImporting = false,
    this.currency = 'USD',
    this.summary,
  });

  YnabImportState copyWith({
    YnabImportStep? currentStep,
    YnabImportMethod? method,
    PlatformFile? registerFile,
    PlatformFile? budgetFile,
    String? ynab4FolderPath,
    YnabImportData? parsedData,
    bool? isLoading,
    YnabImportError? error,
    String? errorDetail,
    bool? isImporting,
    String? currency,
    YnabImportSummary? summary,
    bool clearParsedData = false,
  }) {
    return YnabImportState(
      currentStep: currentStep ?? this.currentStep,
      method: method ?? this.method,
      registerFile: registerFile ?? this.registerFile,
      budgetFile: budgetFile ?? this.budgetFile,
      ynab4FolderPath: ynab4FolderPath ?? this.ynab4FolderPath,
      parsedData: clearParsedData ? null : (parsedData ?? this.parsedData),
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable to clear error
      errorDetail: error == null ? null : errorDetail,
      isImporting: isImporting ?? this.isImporting,
      currency: currency ?? this.currency,
      summary: summary ?? this.summary,
    );
  }
}
