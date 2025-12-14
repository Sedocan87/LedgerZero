import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage which category is currently being edited in the budget screen.
/// Stores the ID of the category being edited, or null if none.
final editingCategoryProvider = StateProvider<String?>((ref) => null);

enum BudgetViewMode { standard, comparison }

final budgetViewModeProvider = StateProvider<BudgetViewMode>(
  (ref) => BudgetViewMode.standard,
);
