// The category editor when the category to edit cannot be loaded: the form
// never shows (saving it would create a new category) and Save is disabled.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:mockito/mockito.dart';

import '../../../mocks/repository_mocks.mocks.dart';

void main() {
  late MockCategoryRepository categories;
  late MockTransactionRepository transactions;

  setUp(() {
    categories = MockCategoryRepository();
    transactions = MockTransactionRepository();
    when(
      categories.watchAllCategoryGroups(),
    ).thenAnswer((_) => Stream.value([]));
    when(
      transactions.getTransactions(
        filter: anyNamed('filter'),
        sort: anyNamed('sort'),
        limit: anyNamed('limit'),
      ),
    ).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester, {String? categoryId}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(categories),
          transactionRepositoryProvider.overrideWithValue(transactions),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: AddEditCategoryScreen(categoryId: categoryId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  IconButton saveButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.check));

  testWidgets('an unknown id shows "not found" and disables Save', (
    tester,
  ) async {
    when(categories.getCategoryById('reorder-groups')).thenAnswer((_) async {
      return null;
    });
    await pump(tester, categoryId: 'reorder-groups');
    expect(find.byKey(const Key('category.notFound')), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a failed load shows the error with Retry; Save stays off', (
    tester,
  ) async {
    var calls = 0;
    final existing = Category(
      id: 'c1',
      name: 'Groceries',
      categoryGroupId: 'g1',
      createdAt: DateTime.utc(2026),
    );
    when(categories.getCategoryById('c1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw Exception('db closed');
      }
      return existing;
    });
    await pump(tester, categoryId: 'c1');
    expect(find.byType(LoadErrorView), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(LoadErrorView), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a new category can be saved at once', (tester) async {
    await pump(tester);
    expect(saveButton(tester).onPressed, isNotNull);
  });
}
