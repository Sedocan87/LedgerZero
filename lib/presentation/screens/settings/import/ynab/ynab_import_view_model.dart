import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_state.dart';
import 'package:ledger_zero/services/import/ynab_data_mapper.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';

// Providers
final ynabImportViewModelProvider =
    StateNotifierProvider.autoDispose<YnabImportViewModel, YnabImportState>((
      ref,
    ) {
      return YnabImportViewModel(
        importService: ref.watch(ynabImportServiceProvider),
        dataMapper: ref.watch(ynabDataMapperProvider),
      );
    });

final ynabImportServiceProvider = Provider<YnabImportService>((ref) {
  return YnabImportService();
});

final ynabDataMapperProvider = Provider<YnabDataMapper>((ref) {
  return YnabDataMapper(
    accountRepo: ref.watch(accountRepositoryProvider),
    categoryRepo: ref.watch(categoryRepositoryProvider),
    payeeRepo: ref.watch(payeeRepositoryProvider),
    transactionRepo: ref.watch(transactionRepositoryProvider),
    budgetRepo: ref.watch(budgetRepositoryProvider),
    scheduledTransactionRepo: ref.watch(scheduledTransactionRepositoryProvider),
  );
});

class YnabImportViewModel extends StateNotifier<YnabImportState> {
  final YnabImportService _importService;
  final YnabDataMapper _dataMapper;

  YnabImportViewModel({
    required YnabImportService importService,
    required YnabDataMapper dataMapper,
  }) : _importService = importService,
       _dataMapper = dataMapper,
       super(const YnabImportState());

  void setMethod(YnabImportMethod method) {
    state = state.copyWith(
      method: method,
      currentStep: YnabImportStep.selectFiles,
      error: null,
    );
  }

  void goBack() {
    if (state.currentStep == YnabImportStep.selectFiles) {
      state = state.copyWith(
        currentStep: YnabImportStep.selectMethod,
        error: null,
      );
    } else if (state.currentStep == YnabImportStep.preview) {
      state = state.copyWith(
        currentStep: YnabImportStep.selectFiles,
        error: null,
        parsedData: null,
      );
    }
  }

  void cancel() {
    // Reset state completely
    state = const YnabImportState();
  }

  Future<void> pickRegisterFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null) {
        state = state.copyWith(registerFile: result.files.first, error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick file: $e');
    }
  }

  Future<void> pickBudgetFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null) {
        state = state.copyWith(budgetFile: result.files.first, error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick file: $e');
    }
  }

  Future<void> pickYnab4Folder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        state = state.copyWith(ynab4FolderPath: path, error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick folder: $e');
    }
  }

  Future<void> validateAndParse() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (state.method == YnabImportMethod.nynabCsv) {
        if (state.registerFile == null || state.budgetFile == null) {
          throw Exception(
            'Please select both Register.csv and Budget.csv files.',
          );
        }

        final registerContent = await _readFileContent(state.registerFile!);
        final budgetContent = await _readFileContent(state.budgetFile!);

        final data = await _importService.parseCsvExport(
          registerCsvContent: registerContent,
          budgetCsvContent: budgetContent,
        );

        state = state.copyWith(
          parsedData: data,
          currentStep: YnabImportStep.preview,
        );
      } else {
        if (state.ynab4FolderPath == null) {
          throw Exception('Please select the YNAB4 data folder.');
        }

        final data = await _importService.parseYnab4(state.ynab4FolderPath!);
        state = state.copyWith(
          parsedData: data,
          currentStep: YnabImportStep.preview,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> _readFileContent(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }
    throw Exception('Cannot read file content');
  }

  Future<void> startImport() async {
    if (state.parsedData == null) {
      return;
    }

    state = state.copyWith(
      currentStep: YnabImportStep.importing,
      isImporting: true,
      error: null,
    );

    try {
      await _dataMapper.importData(state.parsedData!);
      state = state.copyWith(
        currentStep: YnabImportStep.success,
        isImporting: false,
      );
    } catch (e) {
      state = state.copyWith(
        currentStep: YnabImportStep.preview, // Go back to preview on error
        isImporting: false,
        error: 'Import failed: $e',
      );
    }
  }
}
