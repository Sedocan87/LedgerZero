import 'package:ledger_zero/core/money/money_parser.dart';

/// What a captured notification turned out to be.
enum CaptureKind {
  /// Money left the account (card payment, purchase).
  outflow,

  /// Money came in (refund, credit, received payment).
  inflow,

  /// Not a booking: declined payment, confirmation code, balance or
  /// statement notice. Skipped (see [CardNotificationParse.ignoredPhrase]).
  ignored,

  /// No amount found. Kept for the user to add by hand.
  unreadable,
}

/// The result of [CardNotificationParser.parse].
class CardNotificationParse {
  const CardNotificationParse(
    this.kind, {
    this.amount,
    this.currency,
    this.merchant,
    this.isInflow = false,
    this.ignoredPhrase,
  });

  final CaptureKind kind;

  /// Amount in minor units, always positive (see [signedAmount]). Also set
  /// for an [CaptureKind.ignored] notification that named one, so the user
  /// can still add it.
  final int? amount;

  /// ISO 4217 code, or the symbol when it does not name one currency
  /// (`$`, `¥`); `null` when the notification showed no currency.
  final String? currency;

  /// Merchant or counterparty, when one was found.
  final String? merchant;

  /// Whether money came in (also for an ignored notification).
  final bool isInflow;

  /// For [CaptureKind.ignored]: the phrase that marked the notification as
  /// not a booking ("declined"); `null` for a balance notice.
  final String? ignoredPhrase;

  /// [amount] with the ledger sign (negative for an outflow).
  int? get signedAmount => switch (amount) {
    null => null,
    final amount => isInflow ? amount : -amount,
  };

  @override
  String toString() =>
      'CardNotificationParse($kind, $amount $currency, $merchant'
      '${ignoredPhrase == null ? '' : ', "$ignoredPhrase"'})';
}

/// Reads amount, direction and merchant from the text of a bank, card or
/// wallet app notification (English and German wording).
///
/// Heuristic, not per bank: an amount must carry a currency symbol or code
/// (or, failing that, be the only number with two decimals), so card
/// numbers, dates and codes are not taken for amounts. Amounts right after
/// "balance", "Kontostand", "verfügbar" etc. are skipped; a notification
/// with only such amounts is a balance notice and [CaptureKind.ignored].
/// The merchant is the text after "at", "bei", "to", "an", ... (for an
/// inflow also "from", "von"), else the notification title when it is not
/// the app name or a generic word, else the text after the amount.
class CardNotificationParser {
  const CardNotificationParser({this.amountParser = const MoneyParser()});

  /// Resolves ambiguous separators ("1.234") with the app's number format.
  final MoneyParser amountParser;

  CardNotificationParse parse({
    String? title,
    required String text,
    String? appLabel,
  }) {
    final full = [
      if (title != null && title.trim().isNotEmpty) title.trim(),
      if (text.trim().isNotEmpty) text.trim(),
    ].join('\n');

    final ignoredPhrase = _firstContained(full, _ignoredPhrases);
    final amounts = _amounts(full);
    if (amounts.isEmpty && ignoredPhrase == null) {
      return const CardNotificationParse(CaptureKind.unreadable);
    }
    final booking = amounts.where((a) => !a.isBalance).firstOrNull;
    if (booking == null) {
      return CardNotificationParse(
        CaptureKind.ignored,
        ignoredPhrase: ignoredPhrase,
      );
    }

    final inflow = switch (booking.sign) {
      '-' => false,
      '+' => true,
      _ => _containsAny(full, _inflowPhrases),
    };
    final kind = ignoredPhrase != null
        ? CaptureKind.ignored
        : inflow
        ? CaptureKind.inflow
        : CaptureKind.outflow;

    return CardNotificationParse(
      kind,
      amount: booking.amount,
      currency: booking.currency,
      merchant:
          _merchantAfterKeyword(full, inflow: inflow) ??
          _merchantFromTitle(title, appLabel) ??
          _merchantAfterAmount(full, booking),
      isInflow: inflow,
      ignoredPhrase: ignoredPhrase,
    );
  }

  // -------------------------------------------------------------------
  // Amounts
  // -------------------------------------------------------------------

  static const _currencyPattern =
      r'(€|\$|£|¥|₹|(?<![A-Za-z])(?:EUR|USD|GBP|CHF|CAD|AUD|JPY|CNY|SEK|NOK|DKK|PLN|CZK|HUF|TRY)(?![A-Za-z]))';
  static const _numberPattern =
      r"(\d{1,3}(?:[.,'’  ]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)";
  static const _signPattern = r'([+\-−–])?';

  /// "-€12.50", "€ 12,50", "EUR 1.234,56"
  static final _prefixed = RegExp(
    '$_signPattern\\s?$_currencyPattern\\s?$_signPattern\\s?$_numberPattern(?![\\d.,]*\\d)',
  );

  /// "-12,50 €", "12.50 EUR"
  static final _suffixed = RegExp(
    '$_signPattern\\s?(?<![\\d.,])$_numberPattern\\s?$_currencyPattern',
  );

  /// A number with exactly two decimals and no currency: "12,50".
  static final _bare = RegExp(
    r'([+\-−–])?(?<![\d.,])(\d{1,3}(?:\.\d{3})*,\d{2}|\d{1,3}(?:,\d{3})*\.\d{2})(?![\d.,]*\d)',
  );

  static const _balanceWords = [
    'balance',
    'available',
    'remaining',
    'limit',
    'kontostand',
    'saldo',
    'verfügbar',
    'verfügbarer',
    'guthaben',
    'restbetrag',
  ];

  List<_Amount> _amounts(String text) {
    final found = <_Amount>[];
    for (final m in _prefixed.allMatches(text)) {
      final amount = _amount(m.group(4)!);
      if (amount != null) {
        found.add(
          _Amount(
            amount: amount,
            currency: _currencyCode(m.group(2)!),
            sign: _sign(m.group(1) ?? m.group(3)),
            start: m.start,
            end: m.end,
            isBalance: _isBalance(text, m.start),
          ),
        );
      }
    }
    for (final m in _suffixed.allMatches(text)) {
      if (found.any((a) => m.start < a.end && a.start < m.end)) {
        continue;
      }
      final amount = _amount(m.group(2)!);
      if (amount != null) {
        found.add(
          _Amount(
            amount: amount,
            currency: _currencyCode(m.group(3)!),
            sign: _sign(m.group(1)),
            start: m.start,
            end: m.end,
            isBalance: _isBalance(text, m.start),
          ),
        );
      }
    }
    if (found.isEmpty) {
      final bare = _bare.allMatches(text).toList();
      if (bare.length == 1) {
        final m = bare.single;
        final amount = _amount(m.group(2)!);
        if (amount != null) {
          found.add(
            _Amount(
              amount: amount,
              sign: _sign(m.group(1)),
              start: m.start,
              end: m.end,
              isBalance: _isBalance(text, m.start),
            ),
          );
        }
      }
    }
    found.sort((a, b) => a.start.compareTo(b.start));
    return found;
  }

  int? _amount(String number) {
    final minor = amountParser.tryParse(number.replaceAll(RegExp('[  ]'), ''));
    return minor == null || minor <= 0 ? null : minor;
  }

  static String? _sign(String? raw) => switch (raw) {
    null => null,
    '+' => '+',
    _ => '-',
  };

  static String _currencyCode(String token) => switch (token) {
    '€' => 'EUR',
    '£' => 'GBP',
    '₹' => 'INR',
    _ => token,
  };

  /// Whether a balance word comes shortly before [start] in the same
  /// sentence ("Kontostand: 230,00 €").
  static bool _isBalance(String text, int start) {
    var from = start - 30;
    if (from < 0) {
      from = 0;
    }
    var before = text.substring(from, start);
    final sentenceEnd = before.lastIndexOf(RegExp(r'[.!?\n](\s|$)'));
    if (sentenceEnd >= 0) {
      before = before.substring(sentenceEnd + 1);
    }
    return _containsAny(before, _balanceWords);
  }

  // -------------------------------------------------------------------
  // Direction and ignored notifications
  // -------------------------------------------------------------------

  static const _ignoredPhrases = [
    // Not a completed booking.
    'declined',
    'was declined',
    'rejected',
    'failed',
    'unsuccessful',
    'not approved',
    'insufficient funds',
    'abgelehnt',
    'fehlgeschlagen',
    'nicht erfolgreich',
    'nicht ausgeführt',
    'nicht genehmigt',
    'storniert',
    'cancelled',
    'canceled',
    // Codes, confirmations and log-ins.
    'verification code',
    'security code',
    'one-time',
    'otp',
    'passcode',
    'confirm the payment',
    'confirm this payment',
    'confirm your',
    'please confirm',
    'approve this',
    'approve the payment',
    'log in',
    'login',
    'sign-in',
    'bestätigungscode',
    'sicherheitscode',
    'tan',
    'pushtan',
    'bitte bestätigen',
    'bitte freigeben',
    'freigabe',
    'anmeldung',
    // Statements and reminders.
    'statement',
    'minimum payment',
    'payment due',
    'is due',
    'kontoauszug',
    'abrechnung',
    'fällig',
  ];

  static const _inflowPhrases = [
    'refund',
    'refunded',
    'received',
    'credited',
    'deposit',
    'money in',
    'incoming',
    'sent you',
    'paid you',
    'erstattung',
    'erstattet',
    'rückerstattung',
    'gutschrift',
    'gutgeschrieben',
    'erhalten',
    'eingang',
    'eingegangen',
    'hat dir',
    'hat ihnen',
  ];

  // -------------------------------------------------------------------
  // Merchant
  // -------------------------------------------------------------------

  static const _merchantEnd =
      r'(?=\s+(?:on|am|with|mit|using|via|for|für|über|um|was|were|has|have|is|wurde|wurden|ist|card|karte|ending|endet|bezahlt|gezahlt|ausgegeben|belastet|abgebucht|autorisiert|genehmigt|eingelöst|erfolgt|durchgeführt|approved|authori[sz]ed|charged|completed|abgeschlossen|\d{1,2}[./])(?![\p{L}\p{N}])|\s*[,!;:()\n|]|\.(?=\s|$)|\s+[-–—]\s|$)';

  static final _outflowKeywords = [
    _keyword(r'at|bei|chez|@'),
    _keyword(r'to|an'),
  ];

  static final _inflowKeywords = [_keyword(r'from|von'), _keyword(r'at|bei')];

  static RegExp _keyword(String words) => RegExp(
    '(?<![\\p{L}\\p{N}])(?:$words)\\s+([^\\n]+?)$_merchantEnd',
    caseSensitive: false,
    unicode: true,
  );

  /// Words that cannot start a merchant ("to your account").
  static const _notMerchantStart = {
    'your',
    'you',
    'the',
    'a',
    'an',
    'this',
    'card',
    'account',
    'ihr',
    'ihre',
    'ihrem',
    'ihren',
    'ihrer',
    'dein',
    'deine',
    'deinem',
    'deinen',
    'deiner',
    'karte',
    'konto',
    'with',
    'mit',
    'on',
    'am',
    'using',
    'via',
    'for',
    'für',
    'über',
  };

  /// Titles that describe the notification, not the merchant.
  static const _genericTitleWords = [
    'payment',
    'zahlung',
    'kartenzahlung',
    'transaction',
    'transaktion',
    'purchase',
    'kauf',
    'einkauf',
    'umsatz',
    'card',
    'karte',
    'spent',
    'spending',
    'ausgabe',
    'abbuchung',
    'belastung',
    'lastschrift',
    'refund',
    'erstattung',
    'gutschrift',
    'notification',
    'benachrichtigung',
    'mitteilung',
    'alert',
    'hinweis',
    'info',
    'money',
    'geld',
    'sent',
    'received',
    'erhalten',
    'buchung',
    'konto',
    'account',
    'balance',
    'kontostand',
  ];

  String? _merchantAfterKeyword(String text, {required bool inflow}) {
    for (final keyword in inflow ? _inflowKeywords : _outflowKeywords) {
      for (final m in keyword.allMatches(text)) {
        final merchant = _cleanMerchant(m.group(1)!);
        if (merchant != null) {
          return merchant;
        }
      }
    }
    return null;
  }

  String? _merchantFromTitle(String? title, String? appLabel) {
    if (title == null) {
      return null;
    }
    final merchant = _cleanMerchant(title);
    if (merchant == null || merchant.length > 40) {
      return null;
    }
    final lower = merchant.toLowerCase();
    if (appLabel != null && lower == appLabel.trim().toLowerCase()) {
      return null;
    }
    if (_containsAny(lower, _genericTitleWords) ||
        _prefixed.hasMatch(title) ||
        _suffixed.hasMatch(title)) {
      return null;
    }
    return merchant;
  }

  /// "Umsatz -12,50 € REWE SAGT DANKE" -> "REWE SAGT DANKE".
  String? _merchantAfterAmount(String text, _Amount amount) {
    final rest = text
        .substring(amount.end)
        .replaceFirst(RegExp(r'^[\s:–—-]+'), '');
    final m = RegExp(
      '^([^\\n]+?)$_merchantEnd',
      unicode: true,
      caseSensitive: false,
    ).firstMatch(rest);
    return m == null ? null : _cleanMerchant(m.group(1)!);
  }

  /// Trims symbols and quotes, collapses spaces; `null` when nothing
  /// merchant-like remains (no letter, an amount, too long, or a word
  /// such as "your" first).
  String? _cleanMerchant(String raw) {
    var name = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(
          RegExp(r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}&')]+$", unicode: true),
          '',
        )
        .trim();
    if (name.endsWith(')') && !name.contains('(')) {
      name = name.substring(0, name.length - 1).trim();
    }
    if (name.isEmpty ||
        name.length > 50 ||
        !RegExp(r'\p{L}', unicode: true).hasMatch(name) ||
        _prefixed.hasMatch(name) ||
        _suffixed.hasMatch(name)) {
      return null;
    }
    final firstWord = name.split(' ').first.toLowerCase();
    if (_notMerchantStart.contains(firstWord)) {
      return null;
    }
    return name;
  }

  static bool _containsAny(String text, List<String> phrases) =>
      _firstContained(text, phrases) != null;

  /// The first of [phrases] that occurs in [text] as whole words.
  static String? _firstContained(String text, List<String> phrases) {
    for (final phrase in phrases) {
      if (RegExp(
        '(?<![\\p{L}\\p{N}])${RegExp.escape(phrase)}(?![\\p{L}\\p{N}])',
        caseSensitive: false,
        unicode: true,
      ).hasMatch(text)) {
        return phrase;
      }
    }
    return null;
  }
}

class _Amount {
  const _Amount({
    required this.amount,
    this.currency,
    this.sign,
    required this.start,
    required this.end,
    required this.isBalance,
  });

  final int amount;
  final String? currency;

  /// `-`, `+` or `null` when the amount had no sign.
  final String? sign;
  final int start;
  final int end;
  final bool isBalance;
}
