// The frequency selector with real font metrics: "Monthly" (selected) wrapped
// to "Mont / hly" on the owner's POCO F3 (392 dp) once Inter replaced
// Roboto. Every label must stay on one line, in English and German, at
// 360 dp and 392 dp.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/recurrence/recurrence_selector.dart';

import '../../helpers/real_fonts.dart';

void main() {
  setUpAll(loadInter);

  for (final (locale, labels) in [
    (const Locale('en'), ['Daily', 'Weekly', 'Monthly', 'Yearly']),
    (const Locale('de'), null),
  ]) {
    for (final width in [360.0, 392.0]) {
      for (final selected in RecurrenceFrequency.values) {
        testWidgets('${locale.languageCode}, $width dp, ${selected.name} '
            'selected: every frequency label is one line', (tester) async {
          tester.view.physicalSize = Size(width * 2.75, 1600 * 2.75);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appFormatterProvider.overrideWithValue(
                  AppFormatter(
                    locale: locale.languageCode,
                    currency: 'EUR',
                    decimalSeparator: locale.languageCode == 'de' ? ',' : '.',
                  ),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Padding(
                    // The bottom sheet's horizontal padding.
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RecurrenceSelector(
                      frequency: selected,
                      onFrequencyChanged: (_) {},
                      interval: 1,
                      onIntervalChanged: (_) {},
                      endDate: null,
                      onEndDateChanged: (_) {},
                      occurrenceCount: null,
                      onOccurrenceCountChanged: (_) {},
                      nextDate: DateTime.utc(2026, 11, 10),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(locale);
          final names =
              labels ?? [l10n.daily, l10n.weekly, l10n.monthly, l10n.yearly];
          final heights = <String, double>{};
          for (final name in names) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text(name),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: name);
            heights[name] = paragraph.size.height;
          }
          // One line each: all labels have the height of one line.
          final oneLine = heights.values.reduce((a, b) => a < b ? a : b);
          for (final MapEntry(key: name, value: h) in heights.entries) {
            expect(h, closeTo(oneLine, 0.5), reason: '$name wraps');
          }
        });
      }
    }
  }
}
