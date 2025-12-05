import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:file_picker/file_picker.dart';

enum YnabImportStep {
  selectMethod,
  selectFiles,
  preview,
  importing,
  success,
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
  final String? error;
  final bool isImporting;

  const YnabImportState({
    this.currentStep = YnabImportStep.selectMethod,
    this.method,
    this.registerFile,
    this.budgetFile,
    this.ynab4FolderPath,
    this.parsedData,
    this.isLoading = false,
    this.error,
    this.isImporting = false,
  });

  YnabImportState copyWith({
    YnabImportStep? currentStep,
    YnabImportMethod? method,
    PlatformFile? registerFile,
    PlatformFile? budgetFile,
    String? ynab4FolderPath,
    YnabImportData? parsedData,
    bool? isLoading,
    String? error,
    bool? isImporting,
  }) {
    return YnabImportState(
      currentStep: currentStep ?? this.currentStep,
      method: method ?? this.method,
      registerFile: registerFile ?? this.registerFile,
      budgetFile: budgetFile ?? this.budgetFile,
      ynab4FolderPath: ynab4FolderPath ?? this.ynab4FolderPath,
      parsedData: parsedData ?? this.parsedData,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable to clear error
      isImporting: isImporting ?? this.isImporting,
    );
  }
}
