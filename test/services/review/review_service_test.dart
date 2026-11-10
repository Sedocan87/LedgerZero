import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/review/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReview implements ReviewClient {
  bool available = true;
  int requests = 0;
  int listings = 0;
  bool listingFails = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;

  @override
  Future<void> openStoreListing() async {
    if (listingFails) {
      throw Exception('no store');
    }
    listings++;
  }
}

void main() {
  late SharedPreferences prefs;
  late _FakeReview client;
  late DateTime now;
  late ReviewPrompter prompter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    client = _FakeReview();
    now = DateTime(2026, 11, 1, 9);
    prompter = ReviewPrompter(prefs: prefs, client: client, clock: () => now);
  });

  /// Opens the app on [days] consecutive days from [now].
  Future<void> useFor(int days) async {
    for (var i = 0; i < days; i++) {
      await prompter.recordActiveDay();
      await prompter.recordActiveDay(); // twice a day counts once
      now = now.add(const Duration(days: 1));
    }
  }

  test('never in the first week or before five days of use', () async {
    expect(await prompter.goodMoment(), isFalse);
    await useFor(4);
    now = now.add(const Duration(days: 10));
    expect(await prompter.goodMoment(), isFalse, reason: 'only four days');
    expect(client.requests, 0);

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    prompter = ReviewPrompter(prefs: prefs, client: client, clock: () => now);
    await useFor(6);
    expect(await prompter.goodMoment(), isFalse, reason: 'six days installed');
    expect(client.requests, 0);
  });

  test('after a week with five days of use a good moment asks once; then '
      'not again for four months, and at most three times', () async {
    await useFor(7);
    expect(prompter.isDue, isTrue);
    expect(await prompter.goodMoment(), isTrue);
    expect(client.requests, 1);

    expect(await prompter.goodMoment(), isFalse);
    now = now.add(const Duration(days: ReviewPrompter.minDaysBetween - 1));
    expect(await prompter.goodMoment(), isFalse);
    now = now.add(const Duration(days: 1));
    expect(await prompter.goodMoment(), isTrue);
    now = now.add(const Duration(days: ReviewPrompter.minDaysBetween));
    expect(await prompter.goodMoment(), isTrue);
    now = now.add(const Duration(days: ReviewPrompter.minDaysBetween));
    expect(await prompter.goodMoment(), isFalse, reason: 'three asks');
    expect(client.requests, 3);
  });

  test('without Google Play nothing is asked and nothing is counted', () async {
    client.available = false;
    await useFor(8);
    expect(await prompter.goodMoment(), isFalse);
    expect(prefs.getInt(ReviewPrompter.askCountKey), isNull);
    client.available = true;
    expect(await prompter.goodMoment(), isTrue);
  });

  test('Rate LedgerZero opens the listing and reports a failure', () async {
    expect(await prompter.openStoreListing(), isTrue);
    expect(client.listings, 1);
    client.listingFails = true;
    expect(await prompter.openStoreListing(), isFalse);
  });
}
