import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/core/constants/category_icon_resolver.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';

import '../../helpers/test_database.dart';

/// The German display name of each default category, read from the ARB
/// files (English value -> German value of the same key).
Map<String, String> _germanSeedNames() {
  final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
  final de = jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync()) as Map;
  return {
    for (final MapEntry(:key, :value) in en.entries)
      if (key is String &&
          key.startsWith('seedCat') &&
          value is String &&
          de[key] is String)
        value: de[key] as String,
  };
}

void main() {
  final defaultNames = [
    for (final group in DefaultCategories.groups.entries)
      for (final name in group.value) (group.key, name),
  ];

  group('default categories', () {
    test('every default category has its own icon, and the icon exists', () {
      final keys = <String>[];
      for (final (_, name) in defaultNames) {
        final key = CategoryIconResolver.keyForDefault(name);
        expect(key, isNotNull, reason: name);
        expect(categoryIcons.containsKey(key), isTrue, reason: '$name: $key');
        keys.add(key!);
      }
      expect(keys.toSet().length, keys.length, reason: 'icons repeat: $keys');
      final icons = keys.map((k) => categoryIcons[k]).toSet();
      expect(icons.length, keys.length, reason: 'two keys share an icon');
    });

    test('a seeded category gets its icon by id, whatever its name', () {
      final id = DeterministicId.defaultCategory('Just for Fun', 'Fun Money');
      // Renamed to something no rule knows.
      expect(CategoryIconResolver.keyFor(id: id, name: 'Xyz'), 'fun');
    });

    test('the name rules give each default category its own icon, in English '
        'and in German', () {
      final german = _germanSeedNames();
      for (final (_, name) in defaultNames) {
        final expected = CategoryIconResolver.keyForDefault(name);
        expect(
          CategoryIconResolver.keyForName(name),
          expected,
          reason: 'English "$name"',
        );
        final de = german[name];
        expect(de, isNotNull, reason: 'no German name for $name');
        expect(
          CategoryIconResolver.keyForName(de!),
          expected,
          reason: 'German "$de"',
        );
      }
    });

    test(
      'a new database seeds the default categories with their icons',
      () async {
        final t = TestDatabase();
        addTearDown(t.close);
        final categories = await t.categories.getAllCategories();
        final seeded = {
          for (final (group, name) in defaultNames)
            DeterministicId.defaultCategory(group, name): name,
        };
        final found = categories
            .where((c) => seeded.containsKey(c.id))
            .toList();
        expect(found, hasLength(seeded.length));
        for (final c in found) {
          expect(
            c.icon,
            CategoryIconResolver.keyForDefault(seeded[c.id]!),
            reason: c.name,
          );
        }
      },
    );
  });

  group('categories of the user or an import', () {
    String? key(String name) =>
        CategoryIconResolver.keyFor(id: 'some-id', name: name);

    test('get an icon from their name', () {
      expect(key('Stromkosten'), 'electric');
      expect(key('Kfz-Versicherung'), 'insurance');
      expect(key('Car insurance'), 'insurance');
      expect(key('Netflix'), 'subscriptions');
      expect(key('Haustier'), 'pets');
      expect(key('Dog food'), 'pets');
      expect(key('Geschenke'), 'gifts');
      expect(key('Kleidung'), 'clothing');
      expect(key('Tanken'), 'fuel');
      expect(key('Deutschlandticket'), 'public_transport');
      expect(key('Kita'), 'kids');
      expect(key('Notgroschen'), 'savings');
      expect(key('Steuern'), 'taxes');
      expect(key('Kaffee'), 'coffee');
      expect(key('Rundfunkbeitrag'), 'tv');
    });

    test('whole-word keywords do not match inside other words', () {
      // "car" is not in "Card", "cat" not in "Education", "abo" not in
      // "Labor", "bar" not in "Barber".
      expect(key('Gift card'), 'gifts');
      expect(key('Laborkosten'), isNull);
      expect(key('Barber'), isNull);
    });

    test('a name no rule knows has no icon of its own', () {
      expect(key('Xyz'), isNull);
      expect(
        CategoryIconResolver.iconFor(id: 'some-id', name: 'Xyz'),
        defaultCategoryIcon,
      );
    });

    test('the icon the user chose wins over the name', () {
      expect(
        CategoryIconResolver.keyFor(icon: 'pets', id: 'some-id', name: 'Strom'),
        'pets',
      );
      expect(
        CategoryIconResolver.iconFor(icon: 'pets', id: 'x', name: 'Strom'),
        Icons.pets,
      );
    });

    test('an unknown stored key falls back to the name', () {
      expect(
        CategoryIconResolver.keyFor(icon: 'gone', id: 'some-id', name: 'Strom'),
        'electric',
      );
    });
  });
}
