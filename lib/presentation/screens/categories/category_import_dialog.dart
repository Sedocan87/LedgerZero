import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:uuid/uuid.dart';

class CategoryImportDialog extends ConsumerStatefulWidget {
  const CategoryImportDialog({super.key});

  @override
  ConsumerState<CategoryImportDialog> createState() => _CategoryImportDialogState();
}

class _CategoryImportDialogState extends ConsumerState<CategoryImportDialog> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (!directory.existsSync()) {
        setState(() {
          _files = [];
          _isLoading = false;
        });
        return;
      }

      final files = directory.listSync().where((e) => e.path.endsWith('.csv')).toList();
      // Sort by modified date descending
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error loading files: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importFile(File file) async {
    setState(() {
      _isLoading = true;
      _status = 'Importing...';
    });

    try {
      final content = await file.readAsString();
      final List<List<dynamic>> rows =
          const CsvToListConverter().convert(content, eol: '\n');

      if (rows.isEmpty) {
        throw 'Empty file';
      }

      // Validate Header (simple heuristic)
      int groupIdx = -1;
      int catIdx = -1;
      int hiddenIdx = -1;

      final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

      if (header.contains('group')) {
        groupIdx = header.indexOf('group');
      }
      if (header.contains('category')) {
        catIdx = header.indexOf('category');
      }
      if (header.contains('hidden')) {
        hiddenIdx = header.indexOf('hidden');
      }

      // Fallback
      if (groupIdx == -1 || catIdx == -1) {
         if (rows.first.length >= 2) {
            // Assume no header, just columns
            // But if first row contains "Group" string, treat as header
            if (rows.first[0].toString().toLowerCase().contains('group')) {
               // Header present but maybe different case or spaces?
               // We logic above covered it.
               // Assume malformed header or standard positions 0, 1, 2
               groupIdx = 0; catIdx = 1; hiddenIdx = 2;
            } else {
               // No header, data starts at 0
               groupIdx = 0; catIdx = 1; hiddenIdx = 2;
            }
         } else {
            throw 'Invalid CSV format. Expected columns: Group, Category';
         }
      }

      final catRepo = ref.read(categoryRepositoryProvider);
      final existingGroups = await catRepo.getAllCategoryGroups();
      final existingCats = await catRepo.getAllCategories();
      const uuid = Uuid();
      final now = DateTime.now();

      int importedCount = 0;

      // Determine start index
      final hasHeader =
          rows.first[groupIdx].toString().toLowerCase().contains('group');
      final startIndex = hasHeader ? 1 : 0;

      for (int i = startIndex; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= groupIdx || row.length <= catIdx) {
          continue;
        }

        final groupName = row[groupIdx].toString().trim();
        final catName = row[catIdx].toString().trim();
        bool isHidden = false;
        if (hiddenIdx != -1 && row.length > hiddenIdx) {
          final val = row[hiddenIdx].toString().toLowerCase();
          isHidden = val == 'true' || val == '1' || val == 'yes';
        }

        if (groupName.isEmpty || catName.isEmpty) {
          continue;
        }

        // Find or Create Group
        var group = existingGroups.firstWhere(
          (g) => g.name.toLowerCase() == groupName.toLowerCase(),
          orElse: () => CategoryGroup(id: 'placeholder', name: ''),
        );

        if (group.id == 'placeholder') {
           group = CategoryGroup(
             id: uuid.v4(),
             name: groupName,
             createdAt: now,
           );
           await catRepo.createCategoryGroup(group);
           existingGroups.add(group);
        }

        // Find or Create Category
        var category = existingCats.firstWhere(
          (c) => c.name.toLowerCase() == catName.toLowerCase() && c.categoryGroupId == group.id,
          orElse: () => Category(id: 'placeholder', name: ''),
        );

        if (category.id == 'placeholder') {
           category = Category(
             id: uuid.v4(),
             name: catName,
             categoryGroupId: group.id,
             isHidden: isHidden,
             createdAt: now,
           );
           await catRepo.createCategory(category);
           existingCats.add(category);
           importedCount++;
        }
      }

      if (mounted) {
        setState(() {
          _status = 'Imported $importedCount new categories.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Categories'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status != null) ...[
              Text(_status!, style: TextStyle(color: _status!.startsWith('Error') ? Colors.red : Colors.green)),
              const SizedBox(height: 16),
            ],
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_files.isEmpty)
              const Text(
                  'No CSV files found in Documents directory.\n\nExport categories first to see how it works, or place a .csv file in the app documents folder.')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index] as File;
                    final name = file.path.split('/').last;
                    return ListTile(
                      title: Text(name),
                      leading: const Icon(Icons.description),
                      onTap: () => _importFile(file),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
