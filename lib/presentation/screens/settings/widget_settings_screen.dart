import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/app_app_bar.dart';
import 'package:ledger_zero/presentation/widgets/widget_preview.dart';

class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen> {
  static const String _kPinnedCategoriesKey = 'widget_pinned_categories';
  List<String> _selectedCategoryIds = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _selectedCategoryIds = prefs.getStringList(_kPinnedCategoriesKey) ?? [];
    });
  }

  Future<void> _savePreferences(List<String> ids) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_kPinnedCategoriesKey, ids);
    setState(() {
      _selectedCategoryIds = ids;
    });
    // Trigger update immediately so widget reflects changes
    ref.read(widgetServiceProvider).updateWidgetData();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final widgetDataAsync = ref.watch(widgetPreviewDataProvider);

    return Scaffold(
      appBar: const AppAppBar(title: 'Widget Settings'),
      body: categoriesAsync.when(
        data: (categories) {
          // Filter out hidden categories
          final activeCategories = categories.where((c) => !c.isHidden).toList();
          // Sort by name
          activeCategories.sort((a, b) => a.name.compareTo(b.name));

          return ListView(
            children: [
              // Preview Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: widgetDataAsync.when(
                  data: (data) {
                    final tbb = data.tbb;
                    final performance = data.performance;

                    // Determine which categories to show in preview
                    List<Category> previewCategories;
                    if (_selectedCategoryIds.isNotEmpty) {
                       previewCategories = activeCategories.where((c) => _selectedCategoryIds.contains(c.id)).toList();
                       // Sort by selection order
                       previewCategories.sort((a, b) {
                         return _selectedCategoryIds.indexOf(a.id).compareTo(_selectedCategoryIds.indexOf(b.id));
                       });
                    } else {
                       // Default top 4 by available amount
                       final sorted = List<Category>.from(activeCategories);
                       sorted.sort((a, b) {
                         final availA = performance[a.id]?['available'] ?? 0.0;
                         final availB = performance[b.id]?['available'] ?? 0.0;
                         return availB.compareTo(availA);
                       });
                       previewCategories = sorted.take(4).toList();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text(
                          "Preview",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                         ),
                         const SizedBox(height: 8),
                         WidgetPreview(
                           tbbAmount: tbb,
                           categories: previewCategories,
                           categoryPerformance: performance,
                         ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text("Preview error: $e"),
                ),
              ),

              const Divider(),

              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select up to 4 categories to pin to your widget. If none are selected, the widget will show your top active categories.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              ...activeCategories.map((category) {
                final isSelected = _selectedCategoryIds.contains(category.id);
                return CheckboxListTile(
                  title: Text(category.name),
                  value: isSelected,
                  onChanged: (bool? checked) {
                    final newSelection = List<String>.from(_selectedCategoryIds);
                    if (checked == true) {
                      if (newSelection.length >= 4) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('You can only pin up to 4 categories')),
                         );
                         return;
                      }
                      newSelection.add(category.id);
                    } else {
                      newSelection.remove(category.id);
                    }
                    _savePreferences(newSelection);
                  },
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

final allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories();
});

class WidgetPreviewData {
  final double tbb;
  final Map<String, Map<String, double>> performance;
  WidgetPreviewData(this.tbb, this.performance);
}

final widgetPreviewDataProvider = FutureProvider<WidgetPreviewData>((ref) async {
  final budgetingService = ref.watch(budgetingServiceProvider);
  final currentMonth = DateTime.now();

  final tbb = await budgetingService.calculateTBB(currentMonth);
  final performance = await budgetingService.calculateBatchCategoryPerformance(currentMonth);

  return WidgetPreviewData(tbb, performance);
});
