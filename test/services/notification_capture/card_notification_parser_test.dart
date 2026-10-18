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
      expect(parse('New login from Chrome on Windows').kind, CaptureKind.ignored);
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
        parse('Zahlung über 25,00 € bei Aral gebucht', with_: germanParser)
            .isAuthorisation,
        isFalse,
      );
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
      final r = parse(
        'Du hast 20,00 € an Max gesendet',
        with_: germanParser,
      );
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
