import 'package:file_picker/file_picker.dart';
import 'package:ledger_zero/core/money/currency.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/core/utils/picked_file.dart';
import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
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
        defaultCurrency: ref.read(settingsProvider).currency,
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
    unitOfWork: ref.watch(unitOfWorkProvider),
  );
});

class YnabImportViewModel extends StateNotifier<YnabImportState> {
  final YnabImportService _importService;
  final YnabDataMapper _dataMapper;

  YnabImportViewModel({
    required this._importService,
    required this._dataMapper,
    String defaultCurrency = defaultCurrencyCode,
  }) : super(YnabImportState(currency: defaultCurrency));

  /// Currency of the accounts the import creates (one for the import).
  void setCurrency(String currency) {
    state = state.copyWith(currency: currency, error: null);
  }

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
        clearParsedData: true,
      );
    }
  }

  void cancel() {
    // Reset state completely (the chosen currency is kept).
    state = YnabImportState(currency: state.currency);
  }

  Future<void> pickRegisterFile() async {
    final file = await _pickCsv();
    if (file != null) {
      state = state.copyWith(registerFile: file, error: null);
    }
  }

  Future<void> pickBudgetFile() async {
    final file = await _pickCsv();
    if (file != null) {
      state = state.copyWith(budgetFile: file, error: null);
    }
  }

  Future<PlatformFile?> _pickCsv() async {
    try {
      final result = await ExternalUiGuard.run(
        () => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['csv'],
        ),
      );
      return result;
    } catch (e, stackTrace) {
      Logger.error('YNAB import: picking a CSV file failed', e, stackTrace);
      if (mounted) {
        state = state.copyWith(error: YnabImportError.filePickFailed);
      }
      return null;
    }
  }

  Future<void> pickYnab4Folder() async {
    try {
      final path = await ExternalUiGuard.run(FilePicker.getDirectoryPath);
      if (path != null && mounted) {
        state = state.copyWith(ynab4FolderPath: path, error: null);
      }
    } catch (e, stackTrace) {
      Logger.error(
        'YNAB import: picking the YNAB4 folder failed',
        e,
        stackTrace,
      );
      if (mounted) {
        state = state.copyWith(error: YnabImportError.folderPickFailed);
      }
    }
  }

  Future<void> validateAndParse() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final YnabImportData data;
      if (state.method == YnabImportMethod.nynabCsv) {
        if (state.registerFile == null || state.budgetFile == null) {
          state = state.copyWith(
            isLoading: false,
            error: YnabImportError.filesMissing,
          );
          return;
        }

        final registerContent = await _readFileContent(state.registerFile!);
        final budgetContent = await _readFileContent(state.budgetFile!);

        data = await _importService.parseCsvExport(
          registerCsvContent: registerContent,
          budgetCsvContent: budgetContent,
        );
      } else {
        if (state.ynab4FolderPath == null) {
          state = state.copyWith(
            isLoading: false,
            error: YnabImportError.folderMissing,
          );
          return;
        }

        data = await _importService.parseYnab4(state.ynab4FolderPath!);
      }
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        parsedData: data,
        currentStep: YnabImportStep.preview,
        isLoading: false,
      );
    } on YnabImportException catch (e, stackTrace) {
      Logger.error('YNAB import: invalid export', e, stackTrace);
      if (!mounted) {
        return;
      }
      state = switch (e.failure) {
        YnabImportFailure.missingRegisterColumns => state.copyWith(
          isLoading: false,
          error: YnabImportError.missingColumns,
          errorDetail: e.detail,
        ),
        YnabImportFailure.invalidYnab4Folder => state.copyWith(
          isLoading: false,
          error: YnabImportError.invalidYnab4Folder,
        ),
        YnabImportFailure.invalidDates => state.copyWith(
          isLoading: false,
          error: YnabImportError.invalidDates,
          errorDetail: e.detail,
        ),
      };
    } catch (e, stackTrace) {
      Logger.error('YNAB import: reading the export failed', e, stackTrace);
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: YnabImportError.unreadableFiles,
        );
      }
    }
  }

  Future<String> _readFileContent(PlatformFile file) => file.readAsText();

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
      final summary = await _dataMapper.importData(
        state.parsedData!,
        currency: state.currency,
      );
      if (mounted) {
        state = state.copyWith(
          currentStep: YnabImportStep.success,
          isImporting: false,
          summary: summary,
        );
      }
    } catch (e, stackTrace) {
      // The import runs in one unit of work: nothing was written.
      Logger.error('YNAB import failed', e, stackTrace);
      if (mounted) {
        state = state.copyWith(
          currentStep: YnabImportStep.preview, // Go back to preview on error
          isImporting: false,
          error: YnabImportError.importFailed,
        );
      }
    }
  }
}
