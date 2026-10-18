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
import 'package:ledger_zero/services/import/ynab_import_history.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';

// Providers
final ynabImportViewModelProvider =
    StateNotifierProvider.autoDispose<YnabImportViewModel, YnabImportState>((
      ref,
    ) {
      return YnabImportViewModel(
        importService: ref.watch(ynabImportServiceProvider),
        dataMapper: ref.watch(ynabDataMapperProvider),
        history: ref.watch(ynabImportHistoryProvider),
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
  final YnabImportHistory _history;

  YnabImportViewModel({
    required YnabImportService importService,
    required YnabDataMapper dataMapper,
    YnabImportHistory? history,
    String defaultCurrency = defaultCurrencyCode,
  }) : this._(
         importService,
         dataMapper,
         history ?? InMemoryYnabImportHistory(),
         defaultCurrency,
       );

  YnabImportViewModel._(
    this._importService,
    this._dataMapper,
    this._history,
    String defaultCurrency,
  ) : super(YnabImportState(currency: defaultCurrency));

  /// Marks the account [accountId] of the parsed data as a tracking
  /// (off-budget) account or a budget account.
  void setTracking(String accountId, bool tracking) {
    final data = state.parsedData;
    if (data == null) {
      return;
    }
    state = state.copyWith(
      parsedData: data.copyWith(
        accounts: [
          for (final a in data.accounts)
            a.id == accountId ? a.copyWith(onBudget: !tracking) : a,
        ],
      ),
    );
  }

  /// Reads the register again with [format] (one of
  /// `YnabImportData.dateFormatCandidates`); nYNAB CSV only. Tracking
  /// choices made in the preview are kept.
  Future<void> setRegisterDateFormat(String format) async {
    final data = state.parsedData;
    if (data == null || state.method != YnabImportMethod.nynabCsv) {
      return;
    }
    final tracking = {
      for (final a in data.accounts)
        if (!a.onBudget) a.id,
    };
    await validateAndParse(dateFormat: format);
    final reparsed = state.parsedData;
    if (reparsed != null && reparsed != data) {
      state = state.copyWith(
        parsedData: reparsed.copyWith(
          accounts: [
            for (final a in reparsed.accounts)
              a.copyWith(onBudget: !tracking.contains(a.id)),
          ],
        ),
      );
    }
  }

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
      selectFiles(register: file);
    }
  }

  Future<void> pickBudgetFile() async {
    final file = await _pickCsv();
    if (file != null) {
      selectFiles(budget: file);
    }
  }

  /// Uses the given nYNAB files (the pickers call this; tests too).
  void selectFiles({PlatformFile? register, PlatformFile? budget}) {
    state = state.copyWith(
      registerFile: register,
      budgetFile: budget,
      error: null,
    );
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

  Future<void> validateAndParse({String? dateFormat}) async {
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
          dateFormat: dateFormat,
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
      final fingerprint = data.fingerprint;
      final previous = fingerprint == null
          ? null
          : await _history.importedAt(fingerprint);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        parsedData: data,
        currentStep: YnabImportStep.preview,
        isLoading: false,
        previousImportAt: previous,
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
      final fingerprint = state.parsedData!.fingerprint;
      if (fingerprint != null) {
        await _history.record(fingerprint, DateTime.now().toUtc());
      }
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
