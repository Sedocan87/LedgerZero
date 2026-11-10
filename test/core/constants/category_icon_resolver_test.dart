import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
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

  group('colours', colourTests);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void colourTests() {
  final keys = categoryIcons.keys.toList();

  test('every icon has a colour family', () {
    for (final key in keys) {
      expect(
        CategoryIconResolver.iconSwatches.containsKey(key),
        isTrue,
        reason: key,
      );
    }
  });

  for (final (label, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    test('$label theme: every icon colour stands out on its badge (3:1)', () {
      final scheme = theme.colorScheme;
      for (final background in [
        scheme.surface,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
      ]) {
        // Every icon, and the ids of categories with no icon of their own
        // (they get a family by id).
        final tints = [
          for (final key in keys)
            (
              key,
              CategoryIconResolver.tintFor(
                icon: key,
                id: 'x',
                name: '',
                brightness: theme.brightness,
              ),
            ),
          for (var i = 0; i < 40; i++)
            (
              'no icon $i',
              CategoryIconResolver.tintFor(
                id: 'id-$i',
                name: 'Xyz',
                brightness: theme.brightness,
              ),
            ),
        ];
        for (final (name, tint) in tints) {
          // The badge is the tint at 14 % over the row (budget_category_row).
          final badge = Color.alphaBlend(
            tint.withValues(alpha: 0.14),
            background,
          );
          expect(
            _contrast(tint, badge),
            greaterThanOrEqualTo(3.0),
            reason: '$name on $background',
          );
        }
      }
    });
  }

  test('a white icon stays readable on every avatar colour (3:1)', () {
    for (final key in keys) {
      final avatar = CategoryIconResolver.avatarFor(
        icon: key,
        id: 'x',
        name: '',
      );
      expect(
        _contrast(Colors.white, avatar),
        greaterThanOrEqualTo(3.0),
        reason: key,
      );
    }
  });

  test('categories of one seeded group have different colours', () {
    for (final group in DefaultCategories.groups.entries) {
      final swatches = [
        for (final name in group.value)
          CategoryIconResolver.swatchFor(
            id: DeterministicId.defaultCategory(group.key, name),
            name: name,
          ),
      ];
      expect(
        swatches.toSet().length,
        swatches.length,
        reason: '${group.key}: ${group.value}',
      );
    }
  });

  test('a colour the user chose wins', () {
    expect(
      CategoryIconResolver.tintFor(
        color: 0xFF123456,
        icon: 'groceries',
        id: 'x',
        name: 'Lebensmittel',
        brightness: Brightness.light,
      ),
      const Color(0xFF123456),
    );
  });

  test('a category without an icon keeps its colour (by id)', () {
    final a = CategoryIconResolver.swatchFor(id: 'abc', name: 'Xyz');
    final b = CategoryIconResolver.swatchFor(id: 'abc', name: 'Renamed');
    expect(a, b);
  });
}
