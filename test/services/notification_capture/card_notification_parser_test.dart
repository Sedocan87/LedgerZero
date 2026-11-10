import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/money/money_parser.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';

// The notification texts below are written in the style of common bank,
// card and wallet apps; they are not copies of any app's exact wording.
void main() {
  const parser = CardNotificationParser();
  const germanParser = CardNotificationParser(
    amountParser: MoneyParser(decimalSeparator: ','),
  );

  CardNotificationParse parse(
    String text, {
    String? title,
    String? app,
    CardNotificationParser with_ = parser,
  }) => with_.parse(title: title, text: text, appLabel: app);

  group('purchases', () {
    test('English "spent ... at ... on"', () {
      final r = parse(
        r'You spent $4.50 at Starbucks on your Visa ending in 1234',
        title: 'Card payment',
        app: 'Chase',
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 450);
      expect(r.signedAmount, -450);
      expect(r.currency, r'$');
      expect(r.merchant, 'Starbucks');
    });

    test('German "bei ... bezahlt" with comma decimals', () {
      final r = parse(
        'Du hast 12,50 € bei REWE bezahlt.',
        title: 'Kartenzahlung',
        app: 'N26',
        with_: germanParser,
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 1250);
      expect(r.currency, 'EUR');
      expect(r.merchant, 'REWE');
    });

    test('German comma decimals are read with a dot-decimal parser too', () {
      final r = parse('Kartenzahlung: 12,50 EUR bei REWE Markt GmbH, Berlin');
      expect(r.amount, 1250);
      expect(r.currency, 'EUR');
      expect(r.merchant, 'REWE Markt GmbH');
    });

    test('wallet style: merchant in the title, amount and card in text', () {
      final r = parse(
        '€12.50 with Visa •••• 1234',
        title: 'REWE Markt',
        app: 'Google Wallet',
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 1250);
      expect(r.merchant, 'REWE Markt');
    });

    test('"Payment of ... to ..."', () {
      final r = parse('Payment of £9.99 to Netflix was successful');
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 999);
      expect(r.currency, 'GBP');
      expect(r.merchant, 'Netflix');
    });

    test('"... transaction to X was approved"', () {
      final r = parse(
        r'A $1,234.00 debit card transaction to BEST BUY was approved.',
      );
      expect(r.amount, 123400);
      expect(r.merchant, 'BEST BUY');
    });

    test('signed amount with the merchant after it', () {
      final r = parse(
        'Umsatz -12,50 € REWE SAGT DANKE',
        title: 'Sparkasse',
        app: 'Sparkasse',
        with_: germanParser,
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 1250);
      expect(r.merchant, 'REWE SAGT DANKE');
    });

    test('German thousands grouping', () {
      final r = parse(
        'Zahlung über 1.234,56 EUR an Mediamarkt wurde ausgeführt',
        with_: germanParser,
      );
      expect(r.amount, 123456);
      expect(r.merchant, 'Mediamarkt');
    });

    test('emoji title and currency code prefix', () {
      final r = parse('Paid EUR 7.80', title: '💳 Lidl', app: 'Revolut');
      expect(r.amount, 780);
      expect(r.currency, 'EUR');
      expect(r.merchant, 'Lidl');
    });

    test('merchant with a dot in the name', () {
      final r = parse(r'You paid $23.10 at Amazon.com. Thanks!');
      expect(r.merchant, 'Amazon.com');
    });

    test('no merchant found', () {
      final r = parse(
        'Card payment of €3.20',
        title: 'Revolut',
        app: 'Revolut',
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 320);
      expect(r.merchant, isNull);
    });

    test('the balance amount after the booking is skipped', () {
      final r = parse('You spent €12.50 at REWE. Balance: €230.00');
      expect(r.amount, 1250);
      expect(r.merchant, 'REWE');
    });

    test('a bare amount without currency is used when it is the only one', () {
      final r = parse(
        'Kartenzahlung 12,50 bei Bäckerei Müller',
        with_: germanParser,
      );
      expect(r.amount, 1250);
      expect(r.currency, isNull);
      expect(r.merchant, 'Bäckerei Müller');
    });
  });

  group('inflows', () {
    test('refund from a merchant', () {
      final r = parse('Refund of €19.99 from Zalando');
      expect(r.kind, CaptureKind.inflow);
      expect(r.signedAmount, 1999);
      expect(r.merchant, 'Zalando');
    });

    test('German Gutschrift', () {
      final r = parse(
        'Gutschrift: 50,00 € von Max Mustermann',
        with_: germanParser,
      );
      expect(r.kind, CaptureKind.inflow);
      expect(r.amount, 5000);
      expect(r.merchant, 'Max Mustermann');
    });

    test('an explicit plus sign is an inflow', () {
      final r = parse('+25,00 € Amazon', with_: germanParser);
      expect(r.kind, CaptureKind.inflow);
    });

    test('an explicit minus sign beats inflow words', () {
      final r = parse('−5,00 € Rückerstattung Gebühr', with_: germanParser);
      expect(r.kind, CaptureKind.outflow);
    });
  });

  group('ignored and unreadable', () {
    test('declined payments are ignored', () {
      expect(
        parse(r'Your payment of $50.00 at Shell was declined').kind,
        CaptureKind.ignored,
      );
      expect(
        parse('Zahlung über 20,00 € bei Aral abgelehnt').kind,
        CaptureKind.ignored,
      );
    });

    test('confirmation requests and codes are ignored', () {
      expect(
        parse('Bitte bestätigen Sie die Zahlung über 99,00 € bei Otto').kind,
        CaptureKind.ignored,
      );
      expect(
        parse('Your verification code is 123456').kind,
        CaptureKind.ignored,
      );
    });

    test('a balance notice is ignored', () {
      expect(
        parse('Ihr Kontostand beträgt 1.234,56 €', with_: germanParser).kind,
        CaptureKind.ignored,
      );
      expect(parse('Available balance: €230.00').kind, CaptureKind.ignored);
    });

    test('an ignored notification keeps its reason, amount and merchant', () {
      final declined = parse(r'Your payment of $50.00 at Shell was declined');
      expect(declined.ignoredPhrase, 'declined');
      expect(declined.amount, 5000);
      expect(declined.signedAmount, -5000);
      expect(declined.merchant, 'Shell');

      final code = parse('Your verification code is 123456');
      expect(code.ignoredPhrase, 'verification code');
      expect(code.amount, isNull);

      final balance = parse('Available balance: €230.00');
      expect(balance.kind, CaptureKind.ignored);
      expect(balance.ignoredPhrase, isNull);
      expect(balance.amount, isNull);
    });

    test('statements are ignored', () {
      expect(
        parse(r'Your statement is ready. Minimum payment $25.00').kind,
        CaptureKind.ignored,
      );
    });

    test('no amount is unreadable', () {
      expect(
        parse('You have a new message from your bank').kind,
        CaptureKind.unreadable,
      );
    });

    test('card numbers and dates are not amounts', () {
      expect(
        parse('Card ending 1234 used on 12.10.2026').kind,
        CaptureKind.unreadable,
      );
    });

    test('a day and month or a time is not a bare amount', () {
      expect(
        parse('Kartenzahlung am 18.10 um 09:28', with_: germanParser).kind,
        CaptureKind.unreadable,
      );
      expect(parse('Zahlung um 18.30 Uhr', with_: germanParser).amount, isNull);
      // With a currency the amount still wins.
      final r = parse(
        'Kartenzahlung 3,55 € am 18.10 um 09:28 bei Kiosk',
        with_: germanParser,
      );
      expect(r.amount, 355);
      expect(r.merchant, 'Kiosk');
    });

    test('a status word only counts for the clause with the amount', () {
      final cancelled = parse(
        'Your subscription was cancelled; €9.99 refunded',
      );
      expect(cancelled.kind, CaptureKind.inflow);
      expect(cancelled.amount, 999);

      expect(
        parse('Payment of €9.99 to Netflix failed').kind,
        CaptureKind.ignored,
      );
      expect(
        parse('€9.99 at Netflix', title: 'Payment declined').kind,
        CaptureKind.ignored,
      );
      expect(parse('Payment failed').kind, CaptureKind.ignored);
    });

    test('words that can be part of a merchant name are not ignored', () {
      final thai = parse(
        'Du hast 12,50 € bei Tan Thai Imbiss bezahlt.',
        with_: germanParser,
      );
      expect(thai.kind, CaptureKind.outflow);
      expect(thai.merchant, 'Tan Thai Imbiss');
      expect(parse(r'You spent $8.00 at Otp Grill').kind, CaptureKind.outflow);

      expect(parse('Ihre TAN: 123456').kind, CaptureKind.ignored);
      expect(parse('pushTAN-Freigabe erforderlich').kind, CaptureKind.ignored);
      expect(parse('Your OTP is 123456').kind, CaptureKind.ignored);
      expect(
        parse('New login from Chrome on Windows').kind,
        CaptureKind.ignored,
      );
    });

    test('an authorisation is marked as such', () {
      final r = parse(
        'Zahlung über 25,00 € bei Aral autorisiert',
        with_: germanParser,
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.isAuthorisation, isTrue);
      expect(r.merchant, 'Aral');
      expect(
        parse(
          'Zahlung über 25,00 € bei Aral gebucht',
          with_: germanParser,
        ).isAuthorisation,
        isFalse,
      );
    });
  });

  // An amount alone is not a payment: these came back as outflows while
  // the parser booked everything with a currency amount.
  group('incoming money', () {
    CardNotificationParse german(String text, {String? title}) =>
        parse(text, title: title, with_: germanParser);

    test('German compounds with "eingang" are inflows', () {
      final salary = german(
        '1.500,00 EUR von Arbeitgeber GmbH',
        title: 'Zahlungseingang',
      );
      expect(salary.kind, CaptureKind.inflow);
      expect(salary.signedAmount, 150000);
      expect(salary.merchant, 'Arbeitgeber GmbH');

      final inText = german('Zahlungseingang 1.500,00 EUR Arbeitgeber GmbH');
      expect(inText.kind, CaptureKind.inflow);
      expect(inText.merchant, 'Arbeitgeber GmbH');

      expect(
        german('Gehalt 2.345,67 € ist da', title: 'Gehaltseingang').kind,
        CaptureKind.inflow,
      );
      expect(
        german('Geldeingang: 20,00 € von Anna', title: 'Sparkasse').kind,
        CaptureKind.inflow,
      );
    });

    test('"bekommen", "empfangen" and a returned debit are inflows', () {
      final received = german(
        'Du hast 250,00 € von Max Mustermann bekommen',
        title: 'Geldeingang',
      );
      expect(received.kind, CaptureKind.inflow);
      expect(received.amount, 25000);
      expect(received.merchant, 'Max Mustermann');

      final empfangen = german('Du hast 15,00 € EUR von Lisa Meier empfangen');
      expect(empfangen.kind, CaptureKind.inflow);
      expect(empfangen.merchant, 'Lisa Meier');

      final returned = german(
        'Lastschrift 49,99 € von Vodafone wurde zurückgebucht',
      );
      expect(returned.kind, CaptureKind.inflow);
      expect(returned.merchant, 'Vodafone');
    });

    test('top-ups, cashback and interest are inflows', () {
      expect(parse('You topped up €100.00').kind, CaptureKind.inflow);
      expect(parse('€1.20 cashback from Shell').kind, CaptureKind.inflow);
      expect(german('Zinsen 3,12 € für Oktober').kind, CaptureKind.inflow);
      expect(german('Zinsgutschrift: 3,12 €').kind, CaptureKind.inflow);
      expect(
        german('Erstattung von Zalando: 19,99 €').kind,
        CaptureKind.inflow,
      );
    });

    test('a payment that only names who it came from waits for the user', () {
      final r = german('Zahlung von Max Mustermann: 50,00 €');
      expect(r.kind, CaptureKind.unclear);
      expect(r.amount, 5000);
    });

    test('the inbox is not incoming money', () {
      expect(
        german('Rechnung über 39,99 € im Posteingang').kind,
        isNot(CaptureKind.inflow),
      );
    });
  });

  group('declined and failed payments', () {
    void expectIgnored(String text, {String? title, String? phrase}) {
      final r = parse(text, title: title, with_: germanParser);
      expect(r.kind, CaptureKind.ignored, reason: '$title / $text');
      if (phrase != null) {
        expect(r.ignoredPhrase, phrase, reason: text);
      }
    }

    test('German negations', () {
      expectIgnored(
        'Die Zahlung über 25,00 € bei REWE konnte nicht durchgeführt werden',
        phrase: 'konnte nicht',
      );
      expectIgnored('25,00 € bei REWE', title: 'Zahlung nicht möglich');
      expectIgnored(
        'Die Zahlung über 25,00 € bei REWE wurde nicht autorisiert',
      );
      expectIgnored(
        'Zahlung über 25,00 € bei REWE mangels Deckung nicht möglich',
      );
      expectIgnored('Zahlung nicht abgeschlossen. 12,50 € bei REWE');
      expectIgnored(
        'Die Lastschrift über 49,99 € von Vodafone konnte nicht eingelöst '
        'werden',
      );
      expectIgnored('25,00 € bei REWE', title: 'Zahlung zurückgewiesen');
      expectIgnored('Die Zahlung über 25,00 € bei REWE wurde blockiert');
    });

    test('English wording, also in another sentence than the amount', () {
      expectIgnored(
        'Your card was declined. You tried to pay €25.00 at REWE.',
        phrase: 'declined',
      );
      expectIgnored('Your payment of €25.00 at REWE was not successful');
      expectIgnored('You don’t have enough money to pay €25.00 at REWE');
      expectIgnored('Your payment of €25.00 at REWE was reverted');
      expectIgnored("We couldn't process your payment of €25.00 to Netflix");
      expectIgnored('Insufficient funds for €25.00 at REWE');
    });

    test('a declined payment keeps amount and merchant for the log', () {
      final r = parse(
        'Die Zahlung über 25,00 € bei REWE konnte nicht durchgeführt werden',
        with_: germanParser,
      );
      expect(r.amount, 2500);
      expect(r.merchant, 'REWE');
    });

    test('"not authorised" is not an authorisation', () {
      final r = parse(
        'Die Zahlung über 25,00 € bei REWE wurde nicht autorisiert',
        with_: germanParser,
      );
      expect(r.isAuthorisation, isFalse);
    });

    test('"if this was not you" after a payment does not make it fail', () {
      final r = parse(
        "You spent €50.00 at Shell. If this wasn't you, call us.",
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 5000);
      expect(
        parse(
          'Kartenzahlung 50,00 € bei Shell. Wenn Sie das nicht waren, rufen '
          'Sie uns an.',
          with_: germanParser,
        ).kind,
        CaptureKind.outflow,
      );
    });
  });

  group('notifications that are not payments', () {
    CardNotificationParse german(String text, {String? title}) =>
        parse(text, title: title, with_: germanParser);

    test('a balance anywhere before the amount in the sentence', () {
      expect(
        german(
          'Der Kontostand Ihres Girokontos DE12 3456 beträgt 1.234,56 EUR',
        ).kind,
        CaptureKind.ignored,
      );
      expect(
        german('Neuer Kontostand nach Buchung vom 03.11.: 1.234,56 EUR').kind,
        CaptureKind.ignored,
      );
      expect(
        german('1.234,56 EUR', title: 'Kontostand').kind,
        CaptureKind.ignored,
      );
    });

    test('weekly and monthly summaries are skipped although they say '
        '"spent"', () {
      final week = german('Du hast diese Woche 234,56 € ausgegeben');
      expect(week.kind, CaptureKind.ignored);
      expect(week.ignoredPhrase, 'diese woche');
      expect(
        parse('You spent €234.56 this week, 12% less than last week').kind,
        CaptureKind.ignored,
      );
      expect(
        german('Du hast diesen Monat 1.020,00 € ausgegeben').kind,
        CaptureKind.ignored,
      );
      // A period alone does not make a summary.
      final fee = german('Beitrag für diesen Monat: 9,99 € abgebucht');
      expect(fee.kind, CaptureKind.outflow);
      expect(fee.amount, 999);
    });

    test('promotions are skipped', () {
      expect(
        german('Lade Freunde ein und erhalte 50 € Prämie').kind,
        CaptureKind.ignored,
      );
      expect(
        german(
          'Spare 5 € bei deinem nächsten Einkauf mit dem Code HERBST',
        ).kind,
        CaptureKind.ignored,
      );
      expect(
        parse('Get €20 when you refer a friend').kind,
        CaptureKind.ignored,
      );
    });

    test('price alerts and account notices are skipped', () {
      expect(german('Tesla hat 250,00 € erreicht').kind, CaptureKind.ignored);
      final bitcoin = german('Bitcoin steht bei 60.000 €');
      expect(bitcoin.kind, CaptureKind.ignored);
      expect(bitcoin.ignoredPhrase, 'steht bei');
      expect(
        german('Ihr Konto ist mit 123,45 EUR im Minus').kind,
        CaptureKind.ignored,
      );
      expect(
        german('Deine Rechnung über 39,99 € ist verfügbar').kind,
        CaptureKind.ignored,
      );
    });

    test('an amount with nothing that says payment waits for the user', () {
      final r = german('39,99 € Mobilfunk November', title: 'Vodafone');
      expect(r.kind, CaptureKind.unclear);
      expect(r.amount, 3999);
      expect(r.signedAmount, -3999);
      expect(parse('1.234 €', with_: germanParser).kind, CaptureKind.unclear);
      // The merchant as the title is not enough without the card.
      expect(parse('€250.00', title: 'Tesla').kind, CaptureKind.unclear);
    });

    test('a title that is the app name says nothing', () {
      expect(
        parse('€12.50 REWE', title: 'Payment Buddy', app: 'Payment Buddy').kind,
        CaptureKind.unclear,
      );
      expect(
        parse('€12.50 REWE', title: 'Card payment', app: 'Payment Buddy').kind,
        CaptureKind.outflow,
      );
    });

    test('a store called SPAR or Save Mart is a merchant, not a promotion', () {
      final spar = german('Kartenzahlung 12,50 € bei SPAR Markt');
      expect(spar.kind, CaptureKind.outflow);
      expect(spar.merchant, 'SPAR Markt');
      expect(parse(r'You spent $20.00 at Save Mart').kind, CaptureKind.outflow);
    });
  });

  group('pre-authorisations', () {
    CardNotificationParse german(String text, {String? title}) =>
        parse(text, title: title, with_: germanParser);

    test('a reserved amount is a payment marked as authorisation', () {
      final r = german('150,00 € bei Aral Tankstelle vorgemerkt');
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 15000);
      expect(r.isAuthorisation, isTrue);
      expect(r.merchant, 'Aral Tankstelle');
      expect(parse('Pending: €150.00 at Shell').isAuthorisation, isTrue);
    });

    test('a released authorisation is not another payment', () {
      final r = german('Vormerkung aufgehoben: 150,00 € bei Aral');
      expect(r.kind, CaptureKind.ignored);
      expect(r.isRelease, isTrue);
      expect(r.ignoredPhrase, 'aufgehoben');
      expect(r.amount, 15000);
      expect(r.merchant, 'Aral');
      expect(parse('Hold of €150.00 at Shell released').isRelease, isTrue);
    });

    test('"X statt Y" is the new amount and names the one it replaces', () {
      final r = german('Korrektur: 62,31 € statt 150,00 € bei Aral');
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 6231);
      expect(r.replacesAmount, 15000);
      expect(r.merchant, 'Aral');
      final english = parse('Charged €62.31 instead of €150.00 at Shell');
      expect(english.amount, 6231);
      expect(english.replacesAmount, 15000);
    });
  });

  group('several payments in one notification', () {
    CardNotificationParse german(String text, {String? title}) =>
        parse(text, title: title, with_: germanParser);

    test('one payment per line is split', () {
      final r = german(
        'REWE Markt -12,50 €\nBäckerei Schmidt -3,20 €\nAral -45,00 €',
        title: '3 neue Umsätze',
      );
      expect(r.kind, CaptureKind.several);
      expect(r.amount, isNull);
      expect(r.parts.map((p) => p.signedAmount), [-1250, -320, -4500]);
      expect(r.parts.map((p) => p.merchant), [
        'REWE Markt',
        'Bäckerei Schmidt',
        'Aral',
      ]);
      expect(r.parts.map((p) => p.line), [
        'REWE Markt -12,50 €',
        'Bäckerei Schmidt -3,20 €',
        'Aral -45,00 €',
      ]);
    });

    test('unsigned lines take what they are from the title', () {
      final r = german(
        '12,50 € REWE\n3,20 € Bäckerei Schmidt',
        title: 'Kartenzahlungen',
      );
      expect(r.parts.map((p) => p.kind), [
        CaptureKind.outflow,
        CaptureKind.outflow,
      ]);
      expect(r.parts.map((p) => p.merchant), ['REWE', 'Bäckerei Schmidt']);

      // Nothing says what the lines are: the user sorts it out.
      final unknown = german('12,50 € REWE\n3,20 € Bäckerei Schmidt');
      expect(unknown.kind, CaptureKind.several);
      expect(unknown.parts, isEmpty);
    });

    test('several payments on one line wait for the user', () {
      final r = german(
        '3 neue Umsätze: -12,50 € REWE, -3,20 € Bäcker, -45,00 € Aral',
      );
      expect(r.kind, CaptureKind.several);
      expect(r.parts, isEmpty);
      expect(r.amount, isNull);
    });

    test('a balance, a repeated amount or the title echoing the amount is '
        'still one payment', () {
      expect(
        german(
          'Kartenzahlung 12,50 € bei REWE\nNeuer Kontostand: 230,00 €',
        ).amount,
        1250,
      );
      final echoed = german('12,50 € bei REWE bezahlt', title: '-12,50 €');
      expect(echoed.kind, CaptureKind.outflow);
      expect(echoed.amount, 1250);
      expect(
        german('Kartenzahlung 12,50 € bei REWE. Betrag: 12,50 €').amount,
        1250,
      );
    });
  });

  group('smaller gaps', () {
    const euroAccount = 'EUR';

    test('the creditor of a direct debit is named without "von"/"from"', () {
      final german = germanParser.parse(
        text: 'Lastschrift 49,99 € von Vodafone GmbH',
      );
      expect(german.kind, CaptureKind.outflow);
      expect(german.amount, 4999);
      expect(german.merchant, 'Vodafone GmbH');

      final english = parser.parse(
        text: 'Direct debit €49.99 from Vodafone Ltd',
      );
      expect(english.kind, CaptureKind.outflow);
      expect(english.merchant, 'Vodafone Ltd');

      // "von deinem Konto" is not a merchant.
      final own = germanParser.parse(
        text: 'Abbuchung 49,99 € von deinem Konto',
      );
      expect(own.merchant, isNull);
    });

    test('the amount in the account currency wins over the foreign one', () {
      final german = germanParser.parse(
        text: 'Kartenzahlung 25,00 USD (23,10 €) bei Amazon.com',
        accountCurrency: euroAccount,
      );
      expect(german.kind, CaptureKind.outflow);
      expect(german.amount, 2310);
      expect(german.currency, 'EUR');
      expect(german.merchant, 'Amazon.com');

      final english = parser.parse(
        text: r'Paid $25.00 at Amazon. Converted: €23.10',
        accountCurrency: euroAccount,
      );
      expect(english.amount, 2310);
      expect(english.currency, 'EUR');
      expect(english.merchant, 'Amazon');

      // Without an account the first amount is taken, as before.
      expect(parse(r'Paid $25.00 at Amazon. Converted: €23.10').currency, r'$');
    });

    test('the word "Euro" is a currency', () {
      final r = parse('12,50 Euro belastet (REWE)', with_: germanParser);
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 1250);
      expect(r.currency, 'EUR');
      expect(r.merchant, 'REWE');
      expect(
        parse(
          'Kartenzahlung über 8 Euro bei Kiosk',
          with_: germanParser,
        ).amount,
        800,
      );
    });

    test('an abbreviation dot does not end the merchant', () {
      final r = parse(
        'Kartenzahlung 12,50 € bei Dr. Müller Apotheke.',
        with_: germanParser,
      );
      expect(r.merchant, 'Dr. Müller Apotheke');
      expect(
        parse(r'You paid $23.10 at St. Oberholz. Thanks!').merchant,
        'St. Oberholz',
      );
    });

    test('thousands grouped with a plain or narrow space', () {
      expect(
        parse(
          'Kartenzahlung 1 234,56 € bei Möbelhaus',
          with_: germanParser,
        ).amount,
        123456,
      );
      expect(
        parse(
          'Kartenzahlung 1 234,56 € bei Möbelhaus',
          with_: germanParser,
        ).amount,
        123456,
      );
      // A card number before the amount is not part of it.
      expect(
        parse(
          'Karte 1234 12,50 € bei REWE bezahlt',
          with_: germanParser,
        ).amount,
        1250,
      );
    });
  });

  group('more wording in the style of bank and wallet apps', () {
    CardNotificationParse german(String text, {String? title}) =>
        parse(text, title: title, with_: germanParser);

    test('the wallet layout with the card on a second line', () {
      final r = parse(
        '€12.50 at REWE\nVisa •••• 1234',
        title: 'Google Wallet',
        app: 'Google Wallet',
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 1250);
      expect(r.merchant, 'REWE');

      final card = german('12,50 € · Visa •••• 1234', title: 'REWE');
      expect(card.kind, CaptureKind.outflow);
      expect(card.merchant, 'REWE');
    });

    test('standing orders, direct debits and cash withdrawals', () {
      final rent = german('Dauerauftrag 650,00 € Miete ausgeführt');
      expect(rent.kind, CaptureKind.outflow);
      expect(rent.merchant, 'Miete');
      final debit = german('SEPA-Lastschrift: 49,99 € Vodafone GmbH');
      expect(debit.kind, CaptureKind.outflow);
      expect(debit.merchant, 'Vodafone GmbH');
      final cash = german('Geldautomat: 100,00 € abgehoben');
      expect(cash.kind, CaptureKind.outflow);
      expect(cash.merchant, isNull);
      expect(german('Sollzinsen 12,50 € belastet').kind, CaptureKind.outflow);
    });

    test('a movement word needs a sign or where the money went', () {
      expect(german('Neue Buchung: -12,50 € REWE').kind, CaptureKind.outflow);
      expect(german('Umsatz 12,50 € bei REWE').kind, CaptureKind.outflow);
      expect(
        german('Überweisung an Max Mustermann: 50,00 €').kind,
        CaptureKind.outflow,
      );
      expect(german('Neuer Umsatz: 12,50 € REWE').kind, CaptureKind.unclear);
      expect(
        german('Überweisung von Max Mustermann: 50,00 €').kind,
        CaptureKind.unclear,
      );
    });

    test('a price change in per cent and a subscription offer are not '
        'payments', () {
      final move = german('Tesla +2,50 € (+1,2 %)');
      expect(move.kind, CaptureKind.ignored);
      expect(move.ignoredPhrase, '%');
      expect(
        german('Google One: 100 GB für 1,99 €/Monat').kind,
        CaptureKind.ignored,
      );
    });

    test('a verb after the amount is not the merchant', () {
      final r = parse(
        'Your Netflix subscription payment of €9.99 was successful',
      );
      expect(r.kind, CaptureKind.outflow);
      expect(r.merchant, isNull);
    });
  });

  group('wording seen in the wild', () {
    test('"Sie haben ... erhalten" is an inflow without a merchant', () {
      final r = parse('Sie haben 50,00 € erhalten', with_: germanParser);
      expect(r.kind, CaptureKind.inflow);
      expect(r.amount, 5000);
      expect(r.merchant, isNull);
    });

    test('a transfer to a person ends at "gesendet"', () {
      final r = parse('Du hast 20,00 € an Max gesendet', with_: germanParser);
      expect(r.kind, CaptureKind.outflow);
      expect(r.merchant, 'Max');
      expect(parse(r'You sent $15.00 to Anna').merchant, 'Anna');
    });

    test('a signed amount alone', () {
      final r = parse('-3,55 €', with_: germanParser);
      expect(r.kind, CaptureKind.outflow);
      expect(r.amount, 355);
      expect(r.merchant, isNull);
    });

    test('ambiguous grouping follows the app format', () {
      expect(parse('1.234 €', with_: germanParser).amount, 123400);
      expect(parse('1,234 €').amount, 123400);
    });

    test('Google Wallet tap to pay (Wallet app and Play services)', () {
      final english = parse(
        '€3.55 at H Ratschiller Spezialbro',
        title: 'Google Wallet',
        app: 'Google Wallet',
      );
      expect(english.kind, CaptureKind.outflow);
      expect(english.amount, 355);
      expect(english.currency, 'EUR');
      expect(english.merchant, 'H Ratschiller Spezialbro');

      final german = parse(
        '3,55 € bei H Ratschiller Spezialbro',
        title: 'Google Pay',
        app: 'Google Play services',
        with_: germanParser,
      );
      expect(german.amount, 355);
      expect(german.merchant, 'H Ratschiller Spezialbro');

      final titled = parse(
        '€3.55 with Visa •••• 1234',
        title: 'H Ratschiller Spezialbro',
        app: 'Google Play services',
      );
      expect(titled.merchant, 'H Ratschiller Spezialbro');
    });
  });
}
