import 'package:ledger_zero/core/money/money_parser.dart';

/// What a captured notification turned out to be.
enum CaptureKind {
  /// Money left the account (card payment, purchase).
  outflow,

  /// Money came in (refund, credit, received payment).
  inflow,

  /// Not a booking: declined payment, confirmation code, balance or
  /// statement notice, weekly summary, promotion, price alert, a released
  /// authorisation. Skipped (see [CardNotificationParse.ignoredPhrase]).
  ignored,

  /// No amount found. Kept for the user to add by hand.
  unreadable,

  /// An amount, but nothing that says a payment was made or money came
  /// in. Never booked on its own; kept for the user.
  unclear,

  /// Several amounts that are not one payment. With
  /// [CardNotificationParse.parts] (one payment per line) each part is
  /// booked; without, the notification is kept for the user.
  several,
}

/// The result of [CardNotificationParser.parse].
class CardNotificationParse {
  const CardNotificationParse(
    this.kind, {
    this.amount,
    this.currency,
    this.merchant,
    this.isInflow = false,
    this.isAuthorisation = false,
    this.isRelease = false,
    this.replacesAmount,
    this.ignoredPhrase,
    this.parts = const [],
    this.line,
  });

  final CaptureKind kind;

  /// Amount in minor units, always positive (see [signedAmount]). Also set
  /// for an [CaptureKind.ignored] or [CaptureKind.unclear] notification
  /// that named one, so the user can still add it. `null` for
  /// [CaptureKind.several].
  final int? amount;

  /// ISO 4217 code, or the symbol when it does not name one currency
  /// (`$`, `¥`); `null` when the notification showed no currency.
  final String? currency;

  /// Merchant or counterparty, when one was found.
  final String? merchant;

  /// Whether money came in (also for an ignored notification).
  final bool isInflow;

  /// The notification announced an authorisation or a reserved amount
  /// ("autorisiert", "vorgemerkt", "pending"), not the final booking: the
  /// bank may notify again when the payment is booked, and the final amount
  /// may differ (fuel pumps, hotels). The capture service books it, marks
  /// the transaction and matches later notifications against it.
  final bool isAuthorisation;

  /// The notification says an authorisation was released ("Vormerkung
  /// aufgehoben"): [kind] is [CaptureKind.ignored] and the capture service
  /// removes the authorisation's transaction.
  final bool isRelease;

  /// The amount this one replaces, when the notification says so
  /// ("62,31 € statt 150,00 €"); minor units, positive.
  final int? replacesAmount;

  /// For [CaptureKind.ignored]: the phrase that marked the notification as
  /// not a booking ("declined", "this week"); `null` for a balance notice.
  final String? ignoredPhrase;

  /// For [CaptureKind.several]: the payments, one per line of the
  /// notification; empty when the lines could not be told apart.
  final List<CardNotificationParse> parts;

  /// For a part of a [CaptureKind.several] notification: its line.
  final String? line;

  /// [amount] with the ledger sign (negative for an outflow).
  int? get signedAmount => switch (amount) {
    null => null,
    final amount => isInflow ? amount : -amount,
  };

  /// Whether the notification positively is a payment or incoming money.
  bool get isBooking =>
      kind == CaptureKind.outflow || kind == CaptureKind.inflow;

  @override
  String toString() =>
      'CardNotificationParse($kind, $amount $currency, $merchant'
      '${ignoredPhrase == null ? '' : ', "$ignoredPhrase"'}'
      '${parts.isEmpty ? '' : ', $parts'})';
}

/// Reads amount, direction and merchant from the text of a bank, card or
/// wallet app notification (English and German wording).
///
/// Heuristic, not per bank. An amount alone does not make a payment:
///
/// * An amount must carry a currency symbol or code (or, failing that, be
///   the only number with two decimals), so card numbers, dates and codes
///   are not taken for amounts. Amounts after "balance", "Kontostand",
///   "verfügbar" etc. in the same sentence are skipped; a notification with
///   only such amounts is a balance notice and [CaptureKind.ignored].
/// * It is an [CaptureKind.outflow] only with a positive sign of a payment:
///   an explicit minus, a payment word ("paid", "Kartenzahlung",
///   "abgebucht", ...) or the wallet layout (the amount first, then "at
///   merchant" or the card, with the merchant in the title). It is an
///   [CaptureKind.inflow] with an explicit plus or an inflow word
///   ("Zahlungseingang", "received", "Erstattung", ...). Anything else with
///   an amount is [CaptureKind.unclear] and never booked on its own.
/// * Words that say the payment did not happen ("declined", "konnte
///   nicht", "not successful", ...) make it [CaptureKind.ignored] wherever
///   they stand; so do summaries, promotions and price alerts.
/// * Several amounts that are not one payment are [CaptureKind.several].
///
/// The merchant is the text after "at", "bei", "to", "an", ... (for an
/// inflow also "from", "von"), else the notification title when it is not
/// the app name or a generic word, else the text after the amount.
class CardNotificationParser {
  const CardNotificationParser({this.amountParser = const MoneyParser()});

  /// Resolves ambiguous separators ("1.234") with the app's number format.
  final MoneyParser amountParser;

  /// Parses a notification. [accountCurrency] (ISO code of the account the
  /// app books to) picks the amount when the notification names the
  /// payment in two currencies ("25,00 USD (23,10 €)").
  CardNotificationParse parse({
    String? title,
    required String text,
    String? appLabel,
    String? accountCurrency,
  }) => _parse(
    title: title,
    text: text,
    appLabel: appLabel,
    accountCurrency: accountCurrency,
  );

  /// [context] is the rest of the notification when [text] is one line of
  /// a list of payments (its words can say what the lines are).
  CardNotificationParse _parse({
    required String? title,
    required String text,
    required String? appLabel,
    required String? accountCurrency,
    String? context,
  }) {
    final cleanTitle = _tidy(title);
    final body = _tidy(text) ?? '';
    final full = [?cleanTitle, if (body.isNotEmpty) body].join('\n');
    // Where the text starts in [full].
    final textStart = cleanTitle == null
        ? 0
        : body.isEmpty
        ? full.length
        : cleanTitle.length + 1;
    // An app that titles every notification with its own name says nothing
    // with it ("Amazon Pay").
    final signalTitle =
        cleanTitle != null &&
            appLabel != null &&
            cleanTitle.toLowerCase() == appLabel.trim().toLowerCase()
        ? null
        : cleanTitle;

    final amounts = _amounts(full);
    final (:payments, :replaces) = _payments(
      amounts,
      full,
      textStart,
      accountCurrency,
    );
    final booking = payments.firstOrNull;
    final ignoredPhrase = _ignoredPhrase(full, cleanTitle, booking);
    if (amounts.isEmpty && ignoredPhrase == null) {
      return const CardNotificationParse(CaptureKind.unreadable);
    }
    if (booking == null) {
      return CardNotificationParse(
        CaptureKind.ignored,
        ignoredPhrase: ignoredPhrase,
      );
    }

    CardNotificationParse ignored(String? phrase, {bool release = false}) {
      final inflow = switch (booking.sign) {
        '-' => false,
        '+' => true,
        _ => _inflowWords.hasMatch(full),
      };
      return CardNotificationParse(
        CaptureKind.ignored,
        amount: booking.amount,
        currency: booking.currency,
        merchant: _merchant(full, cleanTitle, appLabel, booking, inflow),
        isInflow: inflow,
        isRelease: release,
        ignoredPhrase: phrase,
      );
    }

    if (ignoredPhrase != null) {
      return ignored(ignoredPhrase);
    }
    final released = _releasePhrases.first(full);
    if (released != null) {
      return ignored(released, release: true);
    }
    if (payments.length > 1) {
      return _several(
        payments: payments,
        body: body,
        textStart: textStart,
        signalTitle: signalTitle,
        appLabel: appLabel,
        accountCurrency: accountCurrency,
      );
    }

    // Summaries and promotions use payment words ("You spent €234.56 this
    // week", "Spare 5 € bei deinem nächsten Einkauf").
    final sentence = _spanAround(full, booking, _sentenceEnd);
    final nearby = [?signalTitle, sentence].join('\n');
    final notPayment =
        _notPaymentPhrases.first(nearby) ??
        (_priceMove.hasMatch(sentence) ? '%' : null) ??
        _promotionStart.firstMatch(sentence)?.group(1)?.toLowerCase() ??
        (signalTitle == null
            ? null
            : _promotionStart.firstMatch(signalTitle)?.group(1)?.toLowerCase());
    if (notPayment != null) {
      return ignored(notPayment);
    }

    final signalText = [?signalTitle, if (body.isNotEmpty) body].join('\n');
    final inflow = switch (booking.sign) {
      '-' => false,
      '+' => true,
      _ =>
        _direction(nearby) ??
            _direction(signalText) ??
            (context == null ? null : _direction(context)) ??
            // "62,31 € statt 150,00 €" corrects a payment; the wallet
            // layout is one.
            (replaces != null ||
                    _isWalletLayout(
                      full,
                      cleanTitle,
                      appLabel,
                      booking,
                      textStart,
                    )
                ? false
                : null),
    };
    if (inflow == null) {
      // Nothing says it is a payment. A price alert, an account notice or
      // a balance under a title is skipped; the rest waits for the user.
      final notice = _noticePhrases.first(signalText);
      if (notice != null) {
        return ignored(notice);
      }
      if (_balanceWords.has(full)) {
        return const CardNotificationParse(CaptureKind.ignored);
      }
      return CardNotificationParse(
        CaptureKind.unclear,
        amount: booking.amount,
        currency: booking.currency,
        merchant: _merchant(full, cleanTitle, appLabel, booking, false),
      );
    }

    return CardNotificationParse(
      inflow ? CaptureKind.inflow : CaptureKind.outflow,
      amount: booking.amount,
      currency: booking.currency,
      merchant:
          _merchant(full, cleanTitle, appLabel, booking, inflow) ??
          (context == null ? null : _merchantBeforeAmount(full, booking)),
      isInflow: inflow,
      isAuthorisation: _authorisationPhrases.has(full),
      replacesAmount: replaces,
      line: context == null ? null : body,
    );
  }

  /// A notification listing several payments: one part per line when
  /// every line with an amount holds exactly one and each is clearly a
  /// payment, else nothing (the user sorts it out).
  CardNotificationParse _several({
    required List<_Amount> payments,
    required String body,
    required int textStart,
    required String? signalTitle,
    required String? appLabel,
    required String? accountCurrency,
  }) {
    const unsplit = CardNotificationParse(CaptureKind.several);
    if (payments.any((a) => a.start < textStart)) {
      return unsplit;
    }
    final paymentLines = <String>[];
    final otherLines = <String>[];
    var offset = textStart;
    for (final line in body.split('\n')) {
      final end = offset + line.length;
      final count = payments
          .where((a) => a.start >= offset && a.end <= end)
          .length;
      if (count > 1) {
        return unsplit;
      }
      (count == 1 ? paymentLines : otherLines).add(line);
      offset = end + 1;
    }
    if (paymentLines.length != payments.length) {
      return unsplit;
    }
    final context = [?signalTitle, ...otherLines].join('\n');
    final parts = <CardNotificationParse>[];
    for (final line in paymentLines) {
      final part = _parse(
        title: null,
        text: line,
        appLabel: appLabel,
        accountCurrency: accountCurrency,
        context: context,
      );
      if (!part.isBooking) {
        return unsplit;
      }
      parts.add(part);
    }
    return CardNotificationParse(CaptureKind.several, parts: parts);
  }

  /// Trimmed, with typographic apostrophes made plain ("don’t"); `null`
  /// when empty.
  static String? _tidy(String? value) {
    final tidy = value?.trim().replaceAll('’', "'");
    return tidy == null || tidy.isEmpty ? null : tidy;
  }

  // -------------------------------------------------------------------
  // Amounts
  // -------------------------------------------------------------------

  static const _currencyPattern =
      r'(€|\$|£|¥|₹|(?<![A-Za-z])(?:EUR|USD|GBP|CHF|CAD|AUD|JPY|CNY|SEK|NOK|DKK|PLN|CZK|HUF|TRY|Euros?|EUROS?|euros?)(?![A-Za-z]))';

  /// Thousands may be grouped with `.`, `,`, an apostrophe or a (narrow)
  /// no-break or thin space; with a plain space only when decimals follow
  /// ("1 234,56"), so "card 1234 12,50" stays 12,50.
  static const _numberPattern =
      r"(\d{1,3}(?: \d{3})+[.,]\d{2}|\d{1,3}(?:[.,'\u00A0\u202F\u2009]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)";
  static const _signPattern = r'([+\-−–])?';

  /// "-€12.50", "€ 12,50", "EUR 1.234,56"
  static final _prefixed = RegExp(
    '$_signPattern\\s?$_currencyPattern\\s?$_signPattern\\s?$_numberPattern(?![\\d.,]*\\d)',
  );

  /// "-12,50 €", "12.50 EUR", "12,50 Euro"
  static final _suffixed = RegExp(
    '$_signPattern\\s?(?<![\\d.,])$_numberPattern\\s?$_currencyPattern',
  );

  /// A number with exactly two decimals and no currency: "12,50". Not a
  /// day and month after "am"/"on" ("am 18.10 um 09:28") and not a time
  /// ("18.30 Uhr", "18.10 um 9:28").
  static final _bare = RegExp(
    r'([+\-−–])?(?<![\d.,])(?<!\b(?:am|on)\s)(\d{1,3}(?:\.\d{3})*,\d{2}|\d{1,3}(?:,\d{3})*\.\d{2})(?![\d.,]*\d)(?!\s*uhr|\s+um\s|\s*:\d)',
    caseSensitive: false,
    unicode: true,
  );

  static final _balanceWords = _Phrases([
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
  ]);

  /// "62,31 € statt 150,00 €": the second amount is the one replaced.
  static final _insteadOf = RegExp(
    r'^\s*(?:statt|anstatt|anstelle von|instead of|rather than)\s*$',
    caseSensitive: false,
  );

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
            start: _startOf(m),
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
            start: _startOf(m),
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

  /// The amounts that are payments: no balances, the title's amount only
  /// once when the text repeats it, the old amount of "X statt Y" taken out
  /// (returned as `replaces`), one of the two when the payment is named in
  /// two currencies (the one in [accountCurrency], else the first), and
  /// one when the same amount is merely repeated.
  ({List<_Amount> payments, int? replaces}) _payments(
    List<_Amount> amounts,
    String full,
    int textStart,
    String? accountCurrency,
  ) {
    var list = amounts.where((a) => !a.isBalance).toList();
    list = [
      for (final a in list)
        if (!(a.start < textStart &&
            list.any((b) => b.start >= textStart && b.sameValue(a))))
          a,
    ];
    int? replaces;
    for (var i = 0; i + 1 < list.length; i++) {
      if (_insteadOf.hasMatch(full.substring(list[i].end, list[i + 1].start))) {
        replaces = list.removeAt(i + 1).amount;
        break;
      }
    }
    if (list.length == 2 &&
        list[0].currency != null &&
        list[1].currency != null &&
        list[0].currency != list[1].currency) {
      list = [
        accountCurrency == null
            ? list.first
            : list.firstWhere(
                (a) => currencyMatches(a.currency, accountCurrency),
                orElse: () => list.first,
              ),
      ];
    }
    if (list.length > 1 && list.every((a) => a.sameValue(list.first))) {
      list = [list.first];
    }
    return (payments: list, replaces: replaces);
  }

  /// Where the amount of [m] starts (the patterns allow a space before
  /// the currency or the number).
  static int _startOf(RegExpMatch m) {
    final matched = m.group(0)!;
    return m.start + matched.length - matched.trimLeft().length;
  }

  int? _amount(String number) {
    final minor = amountParser.tryParse(
      number.replaceAll(RegExp('[ \u00A0\u202F\u2009]'), ''),
    );
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
    _ => token.toLowerCase().startsWith('euro') ? 'EUR' : token,
  };

  /// Whether a notification [currency] (code, symbol or `null`) can be
  /// booked to an account in [accountCurrency].
  static bool currencyMatches(String? currency, String accountCurrency) {
    if (currency == null) {
      return true;
    }
    final account = accountCurrency.toUpperCase();
    return switch (currency) {
      r'$' => const {
        'USD',
        'CAD',
        'AUD',
        'NZD',
        'SGD',
        'HKD',
        'MXN',
      }.contains(account),
      '¥' => account == 'JPY' || account == 'CNY',
      _ => currency.toUpperCase() == account,
    };
  }

  /// Whether a balance word comes before [start] in the same sentence
  /// ("Der Kontostand Ihres Girokontos DE12 3456 beträgt 1.234,56 EUR").
  static bool _isBalance(String text, int start) {
    var before = text.substring(0, start);
    final sentenceEnd = before.lastIndexOf(_sentenceEnd);
    if (sentenceEnd >= 0) {
      before = before.substring(sentenceEnd + 1);
    }
    return _balanceWords.has(before);
  }

  // -------------------------------------------------------------------
  // Direction and ignored notifications
  // -------------------------------------------------------------------

  /// Phrases that mark a notification as not a booking wherever they
  /// occur (codes, confirmations, log-ins, statements). Words that could
  /// be part of a merchant name ("Tan Thai Imbiss") are only matched in a
  /// form a merchant name does not take ("TAN:", "pushTAN").
  static final _ignoredPhrases = _Phrases([
    // Codes, confirmations and log-ins.
    'verification code',
    'security code',
    'one-time',
    'otp:',
    'otp code',
    'otp is',
    'your otp',
    'passcode',
    'confirm the payment',
    'confirm this payment',
    'confirm your',
    'please confirm',
    'approve this',
    'approve the payment',
    'log in',
    'login code',
    'login attempt',
    'login request',
    'new login',
    'sign-in',
    'bestätigungscode',
    'sicherheitscode',
    'tan:',
    'tan-code',
    'tan code',
    'tan lautet',
    'ihre tan',
    'deine tan',
    'pushtan',
    'chiptan',
    'smstan',
    'sms-tan',
    'phototan',
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
  ]);

  /// Phrases that say the payment did not happen, wherever they stand
  /// ("Your card was declined. You tried to pay €25.00 at REWE."). A bare
  /// "not" is not one: "If this was not you, call us" follows real
  /// payments.
  static final _failurePhrases = _Phrases([
    'declined',
    'rejected',
    'failed',
    'unsuccessful',
    'denied',
    'refused',
    'blocked',
    'reverted',
    'reversed',
    'not approved',
    'not successful',
    'not authorised',
    'not authorized',
    'not completed',
    'not processed',
    'not possible',
    'not go through',
    'not gone through',
    "didn't go through",
    'could not be',
    "couldn't be",
    'could not complete',
    "couldn't complete",
    'could not process',
    "couldn't process",
    'unable to process',
    'unable to complete',
    'insufficient funds',
    'insufficient balance',
    'not enough money',
    'not enough funds',
    'not have enough',
    "don't have enough",
    'abgelehnt',
    'fehlgeschlagen',
    'gescheitert',
    'zurückgewiesen',
    'verweigert',
    'blockiert',
    'gesperrt',
    'abgebrochen',
    'rückgängig',
    'nicht erfolgreich',
    'nicht ausgeführt',
    'nicht genehmigt',
    'nicht autorisiert',
    'nicht möglich',
    'nicht durchgeführt',
    'nicht abgeschlossen',
    'nicht eingelöst',
    'nicht gebucht',
    'nicht belastet',
    'nicht ausreichend',
    'nicht gedeckt',
    'nicht genug',
    'konnte nicht',
    'konnten nicht',
    'kann nicht',
    'mangels deckung',
    'unzureichende deckung',
  ]);

  /// A cancellation can be the reason for a refund ("Your subscription
  /// was cancelled; €9.99 refunded"), so these count only when they refer
  /// to the amount: in the title, in the same clause as the amount, or
  /// anywhere when there is no amount at all.
  static final _cancelPhrases = _Phrases([
    'storniert',
    'cancelled',
    'canceled',
  ]);

  /// An authorisation was taken back; no money moved.
  static final _releasePhrases = _Phrases([
    'aufgehoben',
    'released',
    'hold removed',
  ]);

  /// The payment is authorised or reserved, not booked yet.
  static final _authorisationPhrases = _Phrases([
    'autorisiert',
    'autorisierung',
    'vorautorisiert',
    'vorgemerkt',
    'vormerkung',
    'reserviert',
    'reservierung',
    'pending',
    'authorised',
    'authorized',
    'authorisation',
    'authorization',
    'pre-authorised',
    'pre-authorized',
    'preauthorised',
    'preauthorized',
    'on hold',
  ]);

  /// Summaries and promotions; they win over payment words in the title or
  /// in the sentence of the amount.
  static final _notPaymentPhrases = _Phrases([
    'this week',
    'last week',
    'this month',
    'last month',
    'this year',
    'weekly summary',
    'monthly summary',
    'diese woche',
    'dieser woche',
    'letzte woche',
    'letzter woche',
    'diesen monat',
    'diesem monat',
    'letzten monat',
    'letztem monat',
    'dieses jahr',
    'wochenübersicht',
    'monatsübersicht',
    'wochenrückblick',
    'monatsrückblick',
    'zusammenfassung',
    'refer a friend',
    'invite a friend',
    'invite friends',
    'freunde ein',
    'freunde werben',
    'next purchase',
    'next order',
    'nächsten einkauf',
    'nächste bestellung',
  ]);

  /// A sentence that starts by telling the reader to save or get money.
  static final _promotionStart = RegExp(
    r'^[^\p{L}\p{N}]*(spare|sparen sie|sichere dir|sichern sie sich|hol dir|'
    r'holen sie sich|erhalte|erhalten sie|gewinne|gewinnen sie|verdiene|'
    r'save|get|win|earn)(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  );

  /// A change in per cent next to the amount ("Tesla +2,50 € (+1,2 %)").
  static final _priceMove = RegExp(r'[+\-−▲▼]\s?\d+(?:[.,]\d+)?\s?%');

  /// Price alerts and account notices. They decide only when nothing says
  /// a payment was made (the notification is then skipped instead of
  /// waiting for the user).
  static final _noticePhrases = _Phrases([
    'erreicht',
    'steht bei',
    'liegt bei',
    'notiert',
    'kurs',
    'kursalarm',
    'preisalarm',
    'reached',
    'is now at',
    'trading at',
    'price alert',
    'im minus',
    'überzogen',
    'overdrawn',
    'ist verfügbar',
    'jetzt verfügbar',
    'is available',
    'is ready',
    'steht bereit',
    'prämie',
    'bonus',
    'angebot',
    'offer',
    'voucher',
    'coupon',
    'promo code',
    'gutschein',
    'rabattcode',
    '/monat',
    '/jahr',
    '/month',
    '/year',
    'pro monat',
    'pro jahr',
    'per month',
    'per year',
  ]);

  /// Money came in. German stems also match inside compounds
  /// ("Zahlungseingang", "Gehaltseingang", "Zinsgutschrift"), but not
  /// "Posteingang".
  static final _inflowWords = _words([
    r'refund(?:ed|s)?',
    'received',
    'credited',
    r'deposit(?:ed)?',
    'money in',
    'incoming',
    'sent you',
    'paid you',
    'topped up',
    r'top[- ]?up',
    r'cash ?back',
    'interest earned',
    'salary',
    r'\p{L}*erstattung',
    r'\p{L}*erstattet',
    r'\p{L}*gutschrift',
    'gutgeschrieben',
    'erhalten',
    'bekommen',
    'empfangen',
    r'(?!post)\p{L}*eing(?:ang|änge)',
    'eingegangen',
    'zurückgebucht',
    r'\p{L}*rückbuchung',
    'zurückgezahlt',
    r'\p{L}*rückzahlung',
    r'\p{L}*einzahlung',
    'eingezahlt',
    'aufgeladen',
    r'\p{L}*aufladung',
    'hat dir',
    'hat ihnen',
    r'gehalt(?:s\p{L}*)?',
    'zinsen',
    'habenzinsen',
  ]);

  /// Money left: what a card, a wallet or a bank says about a payment.
  /// Authorisations count ("150,00 € bei Aral vorgemerkt").
  static final _outflowWords = _words([
    'paid',
    'spent',
    r'purchased?',
    'bought',
    r'charged?',
    r'debit(?:ed)?',
    'direct debit',
    'card payment',
    r'withdr(?:ew|awn|awal)',
    'sent',
    'bezahlt',
    'gezahlt',
    r'\p{L}+zahlung(?:en)?',
    'ausgegeben',
    'gekauft',
    r'(?:ein|online|karten)?kauf',
    r'\p{L}*lastschrift(?:en)?',
    'abgebucht',
    r'\p{L}*abbuchung(?:en)?',
    'belastet',
    r'\p{L}*belastung(?:en)?',
    'überwiesen',
    'gesendet',
    'abgehoben',
    r'\p{L}*abhebung',
    'dauerauftrag',
    'autorisiert',
    'vorautorisiert',
    'vorgemerkt',
    'reserviert',
    'pending',
    'vormerkung',
    'autorisierung',
    r'(?:pre-?)?authori[sz](?:ed|ation)',
  ]);

  /// "Payment", "Zahlung": a payment made unless the text only says who
  /// it came from ("Zahlung von Max Mustermann: 50,00 €").
  static final _paymentWords = _words([r'payments?', r'zahlung(?:en)?']);

  /// Words for a movement in either direction; a payment only with where
  /// it went ("transaction to BEST BUY", "Umsatz bei REWE").
  static final _movementWords = _words([
    r'transactions?',
    r'transaktion(?:en)?',
    r'transfer(?:red)?',
    'umsatz',
    'umsätze',
    r'\p{L}*buchung(?:en)?',
    'gebucht',
    r'\p{L}*überweisung(?:en)?',
  ]);

  /// Whether [scope] says money came in (`true`) or a payment was made
  /// (`false`); `null` when it says neither. Inflow words win: refunds and
  /// returned debits name the payment they undo.
  bool? _direction(String scope) {
    if (_inflowWords.hasMatch(scope)) {
      return true;
    }
    if (_outflowWords.hasMatch(scope)) {
      return false;
    }
    final target = _merchantAfterKeyword(scope, inflow: false) != null;
    if (_paymentWords.hasMatch(scope)) {
      final from = _fromKeyword
          .allMatches(scope)
          .any((m) => _cleanMerchant(m.group(1)!) != null);
      return from && !target ? null : false;
    }
    if (target && _movementWords.hasMatch(scope)) {
      return false;
    }
    return null;
  }

  /// What a tap-to-pay wallet posts: only the amount and where
  /// ("€3.55 at Kiosk"), or the merchant as the title and the amount with
  /// the card as the text ("€12.50 with Visa •••• 1234"). Further lines
  /// may only name the card.
  bool _isWalletLayout(
    String full,
    String? title,
    String? appLabel,
    _Amount booking,
    int textStart,
  ) {
    if (booking.start < textStart) {
      return false;
    }
    final lineStart = booking.start == 0
        ? 0
        : full.lastIndexOf('\n', booking.start - 1) + 1;
    final nextBreak = full.indexOf('\n', booking.end);
    final lineEnd = nextBreak < 0 ? full.length : nextBreak;
    if (full.substring(lineStart, booking.start).trim().isNotEmpty) {
      return false;
    }
    final otherLines = [
      ...full.substring(textStart, lineStart).split('\n'),
      ...full.substring(lineEnd).split('\n'),
    ].where((l) => l.trim().isNotEmpty).toList();
    if (otherLines.any((l) => l.length > 40 || !_cardWords.hasMatch(l))) {
      return false;
    }
    final rest = full
        .substring(booking.end, lineEnd)
        .replaceAll(_prefixed, '')
        .replaceAll(_suffixed, '');
    if (RegExp(
      r'^[\s()/=≈~]*(?:at|bei|@)\s+\S',
      caseSensitive: false,
    ).hasMatch(rest)) {
      return _merchantAfterKeyword(
            full.substring(lineStart, lineEnd),
            inflow: false,
          ) !=
          null;
    }
    if (_merchantFromTitle(title, appLabel) == null) {
      return false;
    }
    return rest.trim().isEmpty
        ? otherLines.isNotEmpty
        : RegExp(
                r'^[\s·•|,–—-]*(?:with|mit)\s+\S',
                caseSensitive: false,
              ).hasMatch(rest) ||
              _cardWords.hasMatch(rest);
  }

  /// A card brand or masked card number ("Visa •••• 1234").
  static final _cardWords = RegExp(
    r'visa|master|maestro|amex|american express|girocard|karte|card|'
    r'[•*·]{2,}\s?\d{3,4}',
    caseSensitive: false,
  );

  // -------------------------------------------------------------------
  // Merchant
  // -------------------------------------------------------------------

  /// Words after which a merchant name is over ("at REWE on your card",
  /// "an Max gesendet").
  static const _endWords = [
    'on',
    'am',
    'with',
    'mit',
    'using',
    'via',
    'for',
    'für',
    'über',
    'um',
    'was',
    'were',
    'has',
    'have',
    'is',
    'wurde',
    'wurden',
    'ist',
    'konnte',
    'konnten',
    'card',
    'karte',
    'ending',
    'endet',
    'bezahlt',
    'gezahlt',
    'ausgegeben',
    'belastet',
    'abgebucht',
    'gebucht',
    'autorisiert',
    'vorgemerkt',
    'reserviert',
    'genehmigt',
    'eingelöst',
    'erfolgt',
    'durchgeführt',
    'gesendet',
    'überwiesen',
    'ausgeführt',
    'abgehoben',
    'erhalten',
    'bekommen',
    'empfangen',
    'eingegangen',
    'gutgeschrieben',
    'erstattet',
    'zurückgebucht',
    'approved',
    'authorised',
    'authorized',
    'charged',
    'completed',
    'abgeschlossen',
    'sent',
    'transferred',
    'received',
    'paid',
  ];

  /// A name ends at one of [_endWords], a date, punctuation or the end of
  /// a sentence; the dot of an abbreviation does not end it ("Dr. Müller
  /// Apotheke").
  static final _merchantEnd =
      '(?=\\s+(?:${_endWords.join('|')}|\\d{1,2}[./])(?![\\p{L}\\p{N}])|\\s*[,!;:()\\n|]'
      '|(?<!(?<![\\p{L}\\p{N}])(?:dr|st|fa|co|inh|gebr|mr|mrs|ms|prof|dipl|ing))\\.(?=\\s|\$)'
      '|\\s+[-–—]\\s|\$)';

  static final _outflowKeywords = [
    _keyword(r'at|bei|chez|@'),
    _keyword(r'to|an'),
  ];

  static final _fromKeyword = _keyword(r'from|von');

  static final _inflowKeywords = [_fromKeyword, _keyword(r'at|bei')];

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
  static final _genericTitleWords = _Phrases([
    'payment',
    'zahlung',
    'kartenzahlung',
    'transaction',
    'transaktion',
    'purchase',
    'kauf',
    'einkauf',
    'umsatz',
    'umsätze',
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
  ]);

  String? _merchant(
    String full,
    String? title,
    String? appLabel,
    _Amount booking,
    bool inflow,
  ) =>
      _merchantAfterKeyword(full, inflow: inflow) ??
      _merchantFromTitle(title, appLabel) ??
      _merchantAfterAmount(full, booking) ??
      _merchantInParentheses(full, booking);

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
    if (_genericTitleWords.has(lower) ||
        _inflowWords.hasMatch(lower) ||
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

  /// "12,50 Euro belastet (REWE)" -> "REWE".
  String? _merchantInParentheses(String text, _Amount amount) {
    final m = RegExp(
      r'\(([^()\d\n]{2,40})\)',
    ).firstMatch(text.substring(amount.end));
    return m == null ? null : _cleanMerchant(m.group(1)!);
  }

  /// A line of a list of payments: "Bäckerei Schmidt -3,20 €" ->
  /// "Bäckerei Schmidt".
  String? _merchantBeforeAmount(String line, _Amount amount) {
    final merchant = _cleanMerchant(line.substring(0, amount.start));
    return merchant == null ||
            _genericTitleWords.has(merchant) ||
            _outflowWords.hasMatch(merchant) ||
            _inflowWords.hasMatch(merchant)
        ? null
        : merchant;
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
    if (_notMerchantStart.contains(firstWord) ||
        _endWords.contains(firstWord)) {
      return null;
    }
    return name;
  }

  /// The phrase that marks the notification as not a booking, if any (see
  /// [_ignoredPhrases], [_failurePhrases] and [_cancelPhrases]).
  static String? _ignoredPhrase(String full, String? title, _Amount? booking) =>
      _ignoredPhrases.first(full) ??
      _failurePhrases.first(full) ??
      (title == null ? null : _cancelPhrases.first(title)) ??
      _cancelPhrases.first(
        booking == null ? full : _spanAround(full, booking, _clauseEnd),
      );

  static final _sentenceEnd = RegExp(r'[.!?](?=\s|$)|\n');
  static final _clauseEnd = RegExp(r'[.!?;](?=\s|$)|\n');

  /// The sentence or clause of [text] (between matches of [boundary])
  /// that contains [amount].
  static String _spanAround(String text, _Amount amount, RegExp boundary) {
    var start = 0;
    for (final m in boundary.allMatches(text)) {
      if (m.start < amount.start) {
        start = m.end;
      } else {
        break;
      }
    }
    final after = boundary.firstMatch(text.substring(amount.end));
    final end = after == null ? text.length : amount.end + after.start;
    return text.substring(start, end);
  }

  /// One pattern for [alternatives] (regular expression sources) as whole
  /// words.
  static RegExp _words(List<String> alternatives) => RegExp(
    '(?<![\\p{L}\\p{N}])(?:${alternatives.join('|')})(?![\\p{L}\\p{N}])',
    caseSensitive: false,
    unicode: true,
  );
}

/// Literal phrases matched as whole words, case-insensitively.
class _Phrases {
  _Phrases(List<String> phrases)
    : _pattern = RegExp(
        '(?<![\\p{L}\\p{N}])(?:${phrases.map(RegExp.escape).join('|')})'
        '(?![\\p{L}\\p{N}])',
        caseSensitive: false,
        unicode: true,
      );

  final RegExp _pattern;

  bool has(String text) => _pattern.hasMatch(text);

  /// The phrase that occurs first in [text], in lower case.
  String? first(String text) =>
      _pattern.firstMatch(text)?.group(0)?.toLowerCase();
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

  /// The same amount in the same currency (wherever it stands).
  bool sameValue(_Amount other) =>
      amount == other.amount && currency == other.currency;
}
