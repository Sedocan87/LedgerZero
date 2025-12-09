import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/pickers/category_selector.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';
import '../../widget_test_helpers.dart';

void main() {
  group('Category Picker Tests', () {
    late MockCategoryRepository mockCategoryRepository;

    setUp(() {
      mockCategoryRepository = MockCategoryRepository();

      // Mock category groups and categories
      when(mockCategoryRepository.watchAllCategoryGroups())
          .thenAnswer((_) => Stream.value([
                const CategoryGroup(id: 'g1', name: 'Group 1', sortOrder: 0),
              ]));

      when(mockCategoryRepository.watchAllCategories())
          .thenAnswer((_) => Stream.value([
                Category(
                  id: 'c1',
                  name: 'Test Category',
                  categoryGroupId: 'g1',
                  isHidden: false,
                  sortOrder: 0,
                  createdAt: DateTime.now(),
                  color: Colors.blue.toARGB32(),
                  icon: 'icon_code',
                ),
              ]));
    });

    testWidgets('CategorySelector displays hint text (or content)', (tester) async {
      await pumpTestWidget(
        tester,
        child: Scaffold(
          body: CategorySelector(
            onSelected: (category) {},
          ),
        ),
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        ],
      );

      // Need to pump enough to resolve the AsyncValue
      await tester.pumpAndSettle();

      // Should show the group name
      expect(find.text('Group 1'), findsOneWidget);
      // Should show the category name
      expect(find.text('Test Category'), findsOneWidget);
    });
  });
}
