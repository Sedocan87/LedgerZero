import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/constants/icon_tint.dart';

/// Picks the icon a category is shown with.
///
/// 1. The icon the user chose (the stored `icon` key).
/// 2. For a seeded default category, its own icon (found by its
///    deterministic id, so it does not depend on the display language or a
///    rename).
/// 3. An icon guessed from the name, in English and German ("Lebensmittel"
///    gets the grocery cart), for imported and self-made categories.
/// 4. [defaultCategoryIcon].
///
/// Nothing is written to the database: a category keeps `icon = null` until
/// the user picks one, so rows seeded or imported before icons existed show
/// the same icons as new ones without a migration.
abstract final class CategoryIconResolver {
  /// The icon key of each default category, by its English name.
  static const Map<String, String> defaultIconKeys = {
    'Rent/Mortgage': 'home',
    'Electric': 'electric',
    'Water': 'water',
    'Internet': 'internet',
    'Groceries': 'groceries',
    'Transportation': 'transport',
    'Medical': 'health',
    'Auto Maintenance': 'car_repair',
    'Home Maintenance': 'home_repair',
    'Renter\'s/Home Insurance': 'insurance',
    'Software Subscriptions': 'subscriptions',
    'Student Loan': 'student_loan',
    'Car Payment': 'car_payment',
    'Credit Card': 'credit_card',
    'Vacation': 'vacation',
    'Fitness': 'fitness',
    'Education': 'education',
    'Dining Out': 'food',
    'Entertainment': 'entertainment',
    'Gaming': 'gaming',
    'Music': 'music',
    'Fun Money': 'fun',
    'Savings': 'savings',
    'Stocks & ETFs': 'stocks',
    'Crypto': 'crypto',
    'Bonds': 'bonds',
    'Retirement': 'retirement',
  };

  /// The icon key a new default category [englishName] is seeded with.
  static String? keyForDefault(String englishName) =>
      defaultIconKeys[englishName];

  static final Map<String, String> _byDefaultId = {
    for (final group in DefaultCategories.groups.entries)
      for (final name in group.value)
        DeterministicId.defaultCategory(group.key, name):
            ?defaultIconKeys[name],
  };

  /// Name rules, most specific first: insurance wins over what is insured
  /// ("Kfz-Versicherung", "Renter's/Home Insurance"), "Autokredit" is a car
  /// payment before it is a car or a debt, "Miete/Kredit" is rent before it
  /// is a debt. A keyword matches anywhere in the name (German compounds:
  /// "Stromkosten"); a keyword starting with `=` only as a whole word.
  static const List<(String, List<String>)> _rules = [
    ('insurance', ['insurance', 'versicherung']),
    ('car_payment', ['car payment', 'car loan', 'autokredit', 'leasing']),
    ('student_loan', ['student loan', 'studienkredit', 'bafög', 'bafoeg']),
    ('credit_card', ['credit card', 'kreditkarte']),
    (
      'car_repair',
      [
        'auto maintenance',
        'car maintenance',
        'car repair',
        'werkstatt',
        '=kfz',
        'tüv',
      ],
    ),
    (
      'home_repair',
      [
        'home maintenance',
        'reparatur',
        'renovier',
        'instandhaltung',
        'handwerk',
        'repair',
      ],
    ),
    (
      'subscriptions',
      [
        'subscription',
        'abonnement',
        '=abo',
        '=abos',
        'streaming',
        'netflix',
        'spotify',
        'software',
      ],
    ),
    (
      'home',
      ['rent', 'mortgage', 'miete', 'hypothek', 'wohnen', 'wohnung', 'housing'],
    ),
    ('electric', ['electric', 'strom', 'energie', 'energy']),
    ('heating', ['heating', 'heizung', '=gas', 'nebenkosten']),
    ('water', ['water', 'wasser']),
    ('internet', ['internet', 'wifi', 'wlan', 'broadband', '=dsl']),
    ('phone', ['phone', 'telefon', 'handy', 'mobilfunk']),
    ('tv', ['rundfunk', '=gez', '=tv', 'fernseh']),
    (
      'groceries',
      ['grocer', 'lebensmittel', 'supermarkt', 'supermarket', 'einkäufe'],
    ),
    (
      'food',
      [
        'dining',
        'restaurant',
        'essen gehen',
        'eating out',
        'takeaway',
        'lieferdienst',
        'lunch',
        'mittagessen',
      ],
    ),
    ('coffee', ['coffee', 'kaffee', '=cafe', '=café']),
    ('drinks', ['drinks', 'getränke', '=bar', '=bars', 'alkohol']),
    ('fuel', ['fuel', 'tanken', 'benzin', 'sprit', 'diesel', 'petrol']),
    ('parking', ['parking', 'parken']),
    (
      'public_transport',
      [
        'public transport',
        'öpnv',
        '=bahn',
        '=bus',
        'train',
        'deutschlandticket',
        'monatskarte',
      ],
    ),
    (
      'transport',
      ['transport', 'mobilität', '=auto', '=car', '=cars', 'fahrzeug'],
    ),
    ('vacation', ['vacation', 'urlaub', 'holiday', 'ferien']),
    ('travel', ['travel', 'reise', 'flug', 'flight']),
    ('pharmacy', ['pharmacy', 'apotheke', 'medikament']),
    (
      'health',
      [
        'medical',
        'health',
        'gesundheit',
        '=arzt',
        'ärzt',
        'zahnarzt',
        'doctor',
        'dental',
        'krankenkasse',
      ],
    ),
    ('fitness', ['fitness', '=gym', 'sport', 'verein']),
    (
      'personal_care',
      [
        'personal care',
        'beauty',
        'friseur',
        'haircut',
        'kosmetik',
        'drogerie',
        'körperpflege',
      ],
    ),
    ('clothing', ['cloth', 'kleidung', 'shoes', 'schuhe', 'fashion']),
    (
      'kids',
      ['=kids', 'kinder', 'child', '=baby', '=kita', 'daycare', 'schulsachen'],
    ),
    ('pets', ['=pet', '=pets', 'haustier', '=hund', '=katze', '=dog', '=cat']),
    (
      'gifts',
      ['gift', 'geschenk', 'birthday', 'geburtstag', 'christmas', 'weihnacht'],
    ),
    ('charity', ['charity', 'spende', 'donation']),
    ('household', ['household', 'haushalt', 'putz', 'cleaning']),
    ('garden', ['garden', 'garten']),
    ('furniture', ['furniture', 'möbel']),
    ('gaming', ['gaming', '=games', 'spiele', 'videospiel']),
    ('music', ['music', 'musik', 'concert', 'konzert']),
    ('books', ['=books', 'bücher', '=buch']),
    (
      'education',
      [
        'education',
        'bildung',
        'school',
        'schule',
        'course',
        '=kurs',
        'kurse',
        'studium',
        'tuition',
      ],
    ),
    (
      'entertainment',
      ['entertainment', 'freizeit', '=kino', 'movie', 'cinema', 'ausgehen'],
    ),
    (
      'fun',
      ['fun money', '=fun', 'taschengeld', 'spaß', 'spass', 'hobby', 'hobbies'],
    ),
    ('shopping', ['shopping', 'amazon', 'online-shop']),
    ('retirement', ['retirement', 'altersvorsorge', 'rente', 'pension']),
    ('crypto', ['crypto', 'krypto', 'bitcoin']),
    ('stocks', ['stock', '=etf', '=etfs', 'aktie', 'depot', 'invest']),
    ('bonds', ['=bond', '=bonds', 'anleihe']),
    (
      'savings',
      [
        'saving',
        'sparen',
        'rücklage',
        'notgroschen',
        'emergency',
        'reserve',
        'erspar',
        'notfall',
      ],
    ),
    ('taxes', ['=tax', '=taxes', 'steuer']),
    (
      'debt',
      [
        '=loan',
        '=loans',
        'kredit',
        'darlehen',
        '=debt',
        'schulden',
        'ratenzahlung',
      ],
    ),
    ('finance', ['bank', 'fees', 'gebühr', 'zinsen']),
    ('work', ['=work', 'arbeit', 'büro', 'office']),
  ];

  static final List<(String, List<RegExp>)> _compiled = [
    for (final (key, words) in _rules)
      (
        key,
        [
          for (final w in words)
            w.startsWith('=')
                ? RegExp(
                    '(?<![\\p{L}\\p{N}])${RegExp.escape(w.substring(1))}(?![\\p{L}\\p{N}])',
                    unicode: true,
                  )
                : RegExp(RegExp.escape(w), unicode: true),
        ],
      ),
  ];

  /// The icon key for a category name, or `null` when no rule fits.
  static String? keyForName(String name) {
    final lower = name.toLowerCase();
    for (final (key, patterns) in _compiled) {
      if (patterns.any((p) => p.hasMatch(lower))) {
        return key;
      }
    }
    return null;
  }

  /// The icon key a category is shown with, or `null` for
  /// [defaultCategoryIcon]. [icon] is the stored key, [id] and [name] the
  /// category's.
  static String? keyFor({
    String? icon,
    required String id,
    required String name,
  }) {
    if (icon != null && categoryIcons.containsKey(icon)) {
      return icon;
    }
    return _byDefaultId[id] ?? keyForName(name);
  }

  /// The icon a category is shown with.
  static IconData iconFor({
    String? icon,
    required String id,
    required String name,
  }) {
    final key = keyFor(icon: icon, id: id, name: name);
    return key == null ? defaultCategoryIcon : categoryIcons[key]!;
  }

  /// The colour family of each icon: what the icon stands for (groceries
  /// green, electricity amber, water light blue, health red, ...).
  static const Map<String, MaterialColor> iconSwatches = {
    'home': Colors.brown,
    'home_repair': Colors.orange,
    'furniture': Colors.brown,
    'household': Colors.cyan,
    'garden': Colors.green,
    'electric': Colors.amber,
    'water': Colors.lightBlue,
    'heating': Colors.deepOrange,
    'internet': Colors.indigo,
    'phone': Colors.blueGrey,
    'tv': Colors.deepPurple,
    'utilities': Colors.amber,
    'insurance': Colors.cyan,
    'subscriptions': Colors.purple,
    'groceries': Colors.green,
    'food': Colors.orange,
    'coffee': Colors.brown,
    'drinks': Colors.purple,
    'transport': Colors.blue,
    'car_repair': Colors.blueGrey,
    'car_payment': Colors.indigo,
    'fuel': Colors.deepOrange,
    'parking': Colors.blue,
    'public_transport': Colors.teal,
    'travel': Colors.lightBlue,
    'vacation': Colors.cyan,
    'health': Colors.red,
    'pharmacy': Colors.pink,
    'fitness': Colors.lightGreen,
    'personal_care': Colors.pink,
    'clothing': Colors.purple,
    'kids': Colors.orange,
    'pets': Colors.brown,
    'gifts': Colors.pink,
    'charity': Colors.red,
    'entertainment': Colors.deepPurple,
    'gaming': Colors.indigo,
    'music': Colors.purple,
    'books': Colors.brown,
    'education': Colors.blue,
    'fun': Colors.pink,
    'shopping': Colors.orange,
    'savings': Colors.teal,
    'stocks': Colors.green,
    'crypto': Colors.amber,
    'bonds': Colors.blueGrey,
    'retirement': Colors.lime,
    'credit_card': Colors.pink,
    'student_loan': Colors.deepPurple,
    'debt': Colors.red,
    'taxes': Colors.grey,
    'finance': Colors.green,
    'work': Colors.blueGrey,
    'other': Colors.grey,
  };

  /// Families for a category with no icon of its own, picked by its id so
  /// it keeps its colour.
  static const List<MaterialColor> _fallbackSwatches = [
    Colors.blue,
    Colors.teal,
    Colors.purple,
    Colors.orange,
    Colors.indigo,
    Colors.pink,
    Colors.green,
    Colors.deepOrange,
    Colors.cyan,
    Colors.brown,
  ];

  /// The colour family a category is shown in.
  static MaterialColor swatchFor({
    String? icon,
    required String id,
    required String name,
  }) {
    final key = keyFor(icon: icon, id: id, name: name);
    if (key != null) {
      return iconSwatches[key] ?? Colors.grey;
    }
    // FNV-1a: stable across runs and devices, unlike String.hashCode.
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return _fallbackSwatches[hash % _fallbackSwatches.length];
  }

  /// The colour of the icon on a faint badge of the same colour (budget
  /// rows, pickers): the colour the user chose ([color]), otherwise a shade
  /// of [swatchFor] that stands out on the [brightness] theme's surface.
  static Color tintFor({
    int? color,
    String? icon,
    required String id,
    required String name,
    required Brightness brightness,
  }) {
    if (color != null) {
      return Color(color);
    }
    final swatch = swatchFor(icon: icon, id: id, name: name);
    return IconTint.of(swatch, brightness);
  }

  /// The background of a round avatar with a white icon (category list):
  /// the colour the user chose, otherwise a dark enough shade of
  /// [swatchFor].
  static Color avatarFor({
    int? color,
    String? icon,
    required String id,
    required String name,
  }) {
    if (color != null) {
      return Color(color);
    }
    return IconTint.of(
      swatchFor(icon: icon, id: id, name: name),
      Brightness.light,
    );
  }
}
