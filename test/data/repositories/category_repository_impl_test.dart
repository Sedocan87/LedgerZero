import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';

import '../../helpers/test_database.dart';

// CategoryRepositoryImpl mapping on a real in-memory database.

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  test('colour and icon survive create, read and update', () async {
    const category = Category(
      id: 'cat-colour',
      name: 'Hobbies',
      color: 0xFF4CAF50,
      icon: 'sports_esports',
    );
    await t.categories.createCategory(category);

    final created = await t.categories.getCategoryById('cat-colour');
    expect(created!.color, 0xFF4CAF50);
    expect(created.icon, 'sports_esports');

    await t.categories.updateCategory(
      created.copyWith(color: 0xFFE91E63, icon: 'pets'),
    );
    final updated = await t.categories.getCategoryById('cat-colour');
    expect(updated!.color, 0xFFE91E63);
    expect(updated.icon, 'pets');

    // An unrelated update (rename) keeps them.
    await t.categories.updateCategory(updated.copyWith(name: 'Pets'));
    final renamed = (await t.categories.getAllCategories()).singleWhere(
      (c) => c.id == 'cat-colour',
    );
    expect(renamed.name, 'Pets');
    expect(renamed.color, 0xFFE91E63);
    expect(renamed.icon, 'pets');
  });
}
