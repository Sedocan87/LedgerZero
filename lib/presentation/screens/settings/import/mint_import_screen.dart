import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';
import 'package:ledger_zero/services/import/mint_data_mapper.dart';
import 'package:ledger_zero/services/import/mint_import_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

class MintImportScreen extends ConsumerStatefulWidget {
  const MintImportScreen({super.key});

  @override
  ConsumerState<MintImportScreen> createState() => _MintImportScreenState();
}

class _MintImportScreenState extends ConsumerState<MintImportScreen> {
  bool _isLoading = false;
  String? _error;
  String? _fileName;
  MintMappedData? _previewData;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        _fileName = result.files.single.name;

        final content = await file.readAsString();
        final parser = MintImportService();
        final importData = parser.parseCsvExport(content);

        final mapper = MintDataMapper();
        final mapped = mapper.mapData(importData);

        setState(() {
          _previewData = mapped;
        });
      }
    } catch (e) {
      Logger.error('Error picking/parsing Mint file', error: e);
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importData() async {
    if (_previewData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Import Accounts
      final accountRepo = ref.read(accountRepositoryProvider);
      // Fetch existing accounts to check for duplicates by name
      final existingAccounts = await accountRepo.getAllAccounts();
      final accountNameMap = {for (var a in existingAccounts) a.name.toLowerCase(): a.id};
      final importedAccountIdMap = <String, String>{}; // Map imported ID -> Real/Existing ID

      for (final acc in _previewData!.accounts) {
        final existingId = accountNameMap[acc.name.toLowerCase()];
        if (existingId != null) {
           importedAccountIdMap[acc.id] = existingId;
        } else {
           await accountRepo.createAccount(acc);
           importedAccountIdMap[acc.id] = acc.id;
        }
      }

      // 2. Import Categories & Groups
      final categoryRepo = ref.read(categoryRepositoryProvider);
      // Fetch existing categories to deduplicate by name
      // This requires helper in repo or we scan.
      // Since repo interfaces are async, and we might not have getAllCategories exposed as simple list (often it's Stream),
      // we'll try to rely on unique name constraints or careful ID management.
      // However, Mint categories are simple strings.
      // Let's assume for now we create new ones. BUT we must track IDs if we fail to create (e.g. duplicate name).
      // Note: Repository implementation details matter. If create throws on duplicate name, we need to find the existing one.

      // Better approach:
      // Try to create. If fails, we assume it exists? No, we need the ID.
      // We will try to fetch all categories first (if possible) or just proceed.
      // Given constraints, let's try to map names.
      // Wait, CategoryRepository usually exposes `watchCategories` or `getAllCategories`?
      // Let's assume we can't easily get all efficiently without potentially big query.
      // We will try to create. If it fails, we risk broken FKs in transactions.

      // To be robust:
      // 1. Fetch all groups/categories.
      final existingGroups = await categoryRepo.getAllCategoryGroups(); // Assuming this method exists or similar
      final groupNameMap = {for (var g in existingGroups) g.name.toLowerCase(): g.id};
      final importedGroupIdMap = <String, String>{};

      for (final group in _previewData!.categoryGroups) {
         final existingId = groupNameMap[group.name.toLowerCase()];
         if (existingId != null) {
           importedGroupIdMap[group.id] = existingId;
         } else {
           try {
             await categoryRepo.createCategoryGroup(group);
             importedGroupIdMap[group.id] = group.id;
           } catch (_) {
             // If creation fails (e.g. race condition), skip mapping?
           }
         }
      }

      // Categories
      // categoryGroupsWithCategoriesProvider usually gives full tree.
      // We'll use getAllCategories if available.
      // If not, we risk it. But let's try to use what we have.
      // Actually, standard `categoryRepository` often has `getAllCategories`.
      final existingCategories = await categoryRepo.getAllCategories();
      final catNameMap = {for (var c in existingCategories) c.name.toLowerCase(): c.id};
      final importedCategoryIdMap = <String, String>{};

      for (final cat in _previewData!.categories) {
        final existingId = catNameMap[cat.name.toLowerCase()];

        // Also need to update group ID if we remapped group
        final mappedGroupId = importedGroupIdMap[cat.categoryGroupId] ?? cat.categoryGroupId;
        final catToCreate = (mappedGroupId != cat.categoryGroupId)
            ? cat.copyWith(categoryGroupId: mappedGroupId)
            : cat;

        if (existingId != null) {
          importedCategoryIdMap[cat.id] = existingId;
        } else {
          try {
            await categoryRepo.createCategory(catToCreate);
            importedCategoryIdMap[cat.id] = cat.id;
          } catch (_) {
             // If failed, we don't map. Transaction might have invalid FK.
          }
        }
      }

      // 3. Import Payees
      final payeeRepo = ref.read(payeeRepositoryProvider);
      final existingPayees = await payeeRepo.getAllPayees();
      final payeeNameMap = {for (var p in existingPayees) p.name.toLowerCase(): p.id};
      final importedPayeeIdMap = <String, String>{};

      for (final payee in _previewData!.payees) {
        final existingId = payeeNameMap[payee.name.toLowerCase()];
        if (existingId != null) {
          importedPayeeIdMap[payee.id] = existingId;
        } else {
           try {
             await payeeRepo.createPayee(payee);
             importedPayeeIdMap[payee.id] = payee.id;
           } catch (_) {}
        }
      }

      // 4. Import Transactions
      final transactionRepo = ref.read(transactionRepositoryProvider);

      // Remap transactions to correct account/category/payee IDs
      final transactionsToImport = _previewData!.transactions.map((t) {
         String accountId = t.accountId;
         if (importedAccountIdMap.containsKey(t.accountId)) {
           accountId = importedAccountIdMap[t.accountId]!;
         }

         String? categoryId = t.categoryId;
         if (categoryId != null && importedCategoryIdMap.containsKey(categoryId)) {
            categoryId = importedCategoryIdMap[categoryId]!;
         }

         String? payeeId = t.payeeId;
         if (payeeId != null && importedPayeeIdMap.containsKey(payeeId)) {
            payeeId = importedPayeeIdMap[payeeId]!;
         }

         return t.copyWith(
           accountId: accountId,
           categoryId: categoryId,
           payeeId: payeeId,
         );
      }).toList();

      await transactionRepo.batchCreateTransactions(transactionsToImport);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mint import successful!')),
        );
        context.pop();
      }
    } catch (e) {
      Logger.error('Error executing Mint import', error: e);
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Mint'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select your Mint "transactions.csv" export file.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (_fileName == null)
              AppButton(
                text: 'Select File',
                onPressed: _isLoading ? null : _pickFile,
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(_fileName!),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _fileName = null;
                        _previewData = null;
                        _error = null;
                      });
                    },
                  ),
                ),
              ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator())),

            if (_error != null)
              Expanded(child: ErrorView(message: _error!, onRetry: _pickFile)),

            if (_previewData != null && !_isLoading) ...[
              const SizedBox(height: 24),
              Text('Preview:', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    _buildSummaryItem('Accounts', _previewData!.accounts.length),
                    _buildSummaryItem('Transactions', _previewData!.transactions.length),
                    _buildSummaryItem('Categories', _previewData!.categories.length),
                    _buildSummaryItem('Payees', _previewData!.payees.length),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Import Data',
                onPressed: _importData,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count) {
    return ListTile(
      title: Text(label),
      trailing: Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
