import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/services/purchases/pro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_pro_store.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late SharedPreferences prefs;
  late FakeProStore store;

  Future<ProController> controller({
    Map<String, Object> initial = const {},
    bool development = false,
    bool refresh = true,
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    final c = ProController(
      prefs: prefs,
      store: store,
      developmentBuild: development,
    );
    addTearDown(c.dispose);
    if (refresh) {
      await c.refresh();
    }
    return c;
  }

  setUp(() => store = FakeProStore());

  test('locked by default; asks the store and shows its price', () async {
    final c = await controller();
    expect(c.state.unlocked, isFalse);
    expect(c.state.storeAvailable, isTrue);
    expect(c.state.price, '€14.99');
    expect(store.ownedCalls, 1);
  });

  test('a remembered purchase unlocks Pro before the store answers '
      '(offline start)', () async {
    store.ownedAnswer = null; // the store cannot answer
    final c = await controller(
      initial: {ProController.unlockedKey: true},
      refresh: false,
    );
    expect(c.state.unlocked, isTrue);
    await c.refresh();
    expect(c.state.unlocked, isTrue, reason: 'no answer keeps the state');
  });

  test('a purchase made elsewhere unlocks at the next check and is '
      'remembered', () async {
    store.ownedAnswer = true;
    final c = await controller();
    expect(c.state.unlocked, isTrue);
    expect(prefs.getBool(ProController.unlockedKey), isTrue);
  });

  test('a refunded purchase locks Pro again', () async {
    store.ownedAnswer = false;
    final c = await controller(initial: {ProController.unlockedKey: true});
    expect(c.state.unlocked, isFalse);
    expect(prefs.getBool(ProController.unlockedKey), isFalse);
  });

  test('buying: the purchase sheet, then the store confirms', () async {
    final c = await controller();
    await c.buy();
    expect(store.buyCalls, 1);
    expect(c.state.busy, isTrue);

    store.push(ProPurchaseStatus.purchased);
    await _settle();
    expect(c.state.unlocked, isTrue);
    expect(c.state.busy, isFalse);
    expect(c.state.message, ProMessage.purchased);
    expect(prefs.getBool(ProController.unlockedKey), isTrue);
  });

  test('a pending payment does not unlock Pro until it is through', () async {
    final c = await controller();
    await c.buy();
    store.push(ProPurchaseStatus.pending);
    await _settle();
    expect(c.state.unlocked, isFalse);
    expect(c.state.pending, isTrue);

    store.push(ProPurchaseStatus.purchased);
    await _settle();
    expect(c.state.unlocked, isTrue);
    expect(c.state.pending, isFalse);
  });

  test(
    'cancelling stays locked without a message; a failure says so',
    () async {
      final c = await controller();
      await c.buy();
      store.push(ProPurchaseStatus.cancelled);
      await _settle();
      expect(c.state.unlocked, isFalse);
      expect(c.state.busy, isFalse);
      expect(c.state.message, isNull);

      await c.buy();
      store.push(ProPurchaseStatus.failed);
      await _settle();
      expect(c.state.unlocked, isFalse);
      expect(c.state.message, ProMessage.failed);
    },
  );

  test('without Google Play nothing can be bought', () async {
    store.available = false;
    final c = await controller();
    await c.buy();
    expect(store.buyCalls, 0);
    expect(c.state.message, ProMessage.storeUnavailable);
    expect(c.state.unlocked, isFalse);
  });

  test('a sheet that cannot open reports a failure', () async {
    store.opens = false;
    final c = await controller();
    await c.buy();
    expect(c.state.busy, isFalse);
    expect(c.state.message, ProMessage.failed);
  });

  test('restore: found, nothing found, no answer', () async {
    final c = await controller();
    await c.restore();
    expect(c.state.message, ProMessage.nothingToRestore);
    expect(c.state.unlocked, isFalse);

    store.ownedAnswer = true;
    await c.restore();
    expect(c.state.message, ProMessage.restored);
    expect(c.state.unlocked, isTrue);

    store.ownedAnswer = null;
    await c.restore();
    expect(c.state.message, ProMessage.failed);
    expect(c.state.unlocked, isTrue);
  });

  test('the development switch works only in development builds', () async {
    final production = await controller();
    await production.setUnlockedForDevelopment(true);
    expect(production.state.unlocked, isFalse);

    final development = await controller(development: true);
    await development.setUnlockedForDevelopment(true);
    expect(development.state.unlocked, isTrue);
    expect(development.state.unlockedForDevelopment, isTrue);
    // The store says nothing was bought: the switch still holds.
    await development.refresh();
    expect(development.state.unlocked, isTrue);

    await development.setUnlockedForDevelopment(false);
    expect(development.state.unlocked, isFalse);
  });

  test('a production build ignores a development unlock left in the '
      'preferences', () async {
    final c = await controller(initial: {ProController.developmentKey: true});
    expect(c.state.unlocked, isFalse);
  });

  group('providers', () {
    test('every gated feature follows the unlock', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          proStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      for (final feature in ProFeature.values) {
        expect(
          container.read(proFeatureAvailableProvider(feature)),
          !ProFeatures.needsPro(feature),
        );
      }
      store.push(ProPurchaseStatus.purchased);
      await _settle();
      for (final feature in ProFeature.values) {
        expect(container.read(proFeatureAvailableProvider(feature)), isTrue);
      }
    });
  });
}
