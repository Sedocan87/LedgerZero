import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BudgetViewMode { standard, comparison }

final budgetViewModeProvider = StateProvider<BudgetViewMode>(
  (ref) => BudgetViewMode.standard,
);
