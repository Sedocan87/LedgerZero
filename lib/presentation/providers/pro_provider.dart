import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/purchases/play_pro_store.dart';
import 'package:ledger_zero/services/purchases/pro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the Pro screen tells the user after an action.
enum ProMessage {
  /// The purchase went through: Pro is unlocked.
  purchased,

  /// "Restore purchase" found the purchase.
  restored,

  /// "Restore purchase" asked Google Play: this account has not bought Pro.
  nothingToRestore,

  /// Google Play cannot sell anything on this phone right now.
  storeUnavailable,

  /// The purchase failed (the store's error is in the log).
  failed,
}

class ProState {
  /// Pro is unlocked: bought on this store account (or switched on in a
  /// development build).
  final bool unlocked;

  /// Unlocked through the development build's switch, not a purchase.
  final bool unlockedForDevelopment;

  /// Google Play can sell Pro on this phone; null while not checked yet.
  final bool? storeAvailable;

  /// The price as Google Play shows it (for example "€14.99").
  final String? price;

  /// The purchase sheet is open or the store is being asked.
  final bool busy;

  /// Bought, but the payment is not through yet.
  final bool pending;

  /// The outcome of the last action, until the screen shows it.
  final ProMessage? message;

  const ProState({
    this.unlocked = false,
    this.unlockedForDevelopment = false,
    this.storeAvailable,
    this.price,
    this.busy = false,
    this.pending = false,
    this.message,
  });

  ProState copyWith({
    bool? unlocked,
    bool? unlockedForDevelopment,
    bool? storeAvailable,
    String? price,
    bool? busy,
    bool? pending,
    ProMessage? message,
    bool clearMessage = false,
  }) => ProState(
    unlocked: unlocked ?? this.unlocked,
    unlockedForDevelopment:
        unlockedForDevelopment ?? this.unlockedForDevelopment,
    storeAvailable: storeAvailable ?? this.storeAvailable,
    price: price ?? this.price,
    busy: busy ?? this.busy,
    pending: pending ?? this.pending,
    message: clearMessage ? null : message ?? this.message,
  );
}

/// LedgerZero Pro: a one-time purchase on Google Play.
///
/// The unlock is remembered on the phone, so Pro works offline and from
/// the first frame after a start. At every start the controller asks Google
/// Play again: a purchase made while the app was closed unlocks Pro, a
/// refunded one locks it again. When Play cannot answer (offline, no Play
/// Store) the remembered state stays.
class ProController extends StateNotifier<ProState> {
  ProController({
    required SharedPreferences prefs,
    required ProStore store,
    this.developmentBuild = false,
  }) : _prefs = prefs,
       _store = store,
       super(_initialState(prefs, developmentBuild)) {
    _subscription = store.updates.listen(_onUpdate);
  }

  /// The purchase confirmed by Google Play, as last seen.
  static const String unlockedKey = 'pro_unlocked';

  /// The development build's switch.
  static const String developmentKey = 'pro_unlocked_development';

  final SharedPreferences _prefs;
  final ProStore _store;

  /// Development builds have a switch that unlocks Pro without a purchase
  /// (their application id has no Play product).
  final bool developmentBuild;
  StreamSubscription<ProPurchaseUpdate>? _subscription;
  bool _purchased = false;

  /// Purchases the store confirmed while this controller ran. A "not
  /// owned" answer to a question asked before a confirmation is stale.
  int _confirmations = 0;

  static ProState _initialState(SharedPreferences prefs, bool development) {
    final purchased = prefs.getBool(unlockedKey) ?? false;
    final forDevelopment =
        development && (prefs.getBool(developmentKey) ?? false);
    return ProState(
      unlocked: purchased || forDevelopment,
      unlockedForDevelopment: forDevelopment && !purchased,
    );
  }

  bool get _forDevelopment =>
      developmentBuild && (_prefs.getBool(developmentKey) ?? false);

  /// Checks the store: availability, price and whether Pro is owned. Never
  /// throws.
  Future<void> refresh() async {
    try {
      final available = await _store.isAvailable();
      if (!mounted) {
        return;
      }
      state = state.copyWith(storeAvailable: available);
      if (!available) {
        return;
      }
      final asked = _confirmations;
      final owned = await _store.owned();
      if (owned != null && (owned || _confirmations == asked)) {
        await _setPurchased(owned);
      }
      final price = await _store.price();
      if (mounted && price != null) {
        state = state.copyWith(price: price);
      }
    } catch (e, stack) {
      Logger.error('Checking LedgerZero Pro failed', e, stack);
    }
  }

  /// Opens Google Play's purchase sheet.
  Future<void> buy() async {
    if (state.unlocked && !state.unlockedForDevelopment) {
      return;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    final available = state.storeAvailable ?? await _store.isAvailable();
    if (!available) {
      state = state.copyWith(
        busy: false,
        storeAvailable: false,
        message: ProMessage.storeUnavailable,
      );
      return;
    }
    final opened = await _store.buy();
    if (!opened && mounted) {
      state = state.copyWith(busy: false, message: ProMessage.failed);
    }
    // Otherwise the outcome arrives through the store's updates.
  }

  /// "Restore purchase": asks Google Play whether this account owns Pro.
  Future<void> restore() async {
    state = state.copyWith(busy: true, clearMessage: true);
    final asked = _confirmations;
    final available = await _store.isAvailable();
    var owned = available ? await _store.owned() : null;
    if (owned == false && _confirmations != asked) {
      owned = true; // bought while the store was being asked
    }
    if (!mounted) {
      return;
    }
    if (owned == null) {
      state = state.copyWith(
        busy: false,
        storeAvailable: available,
        message: available ? ProMessage.failed : ProMessage.storeUnavailable,
      );
      return;
    }
    await _setPurchased(owned);
    state = state.copyWith(
      busy: false,
      storeAvailable: true,
      message: owned ? ProMessage.restored : ProMessage.nothingToRestore,
    );
  }

  /// The development build's switch; ignored in other builds.
  Future<void> setUnlockedForDevelopment(bool unlocked) async {
    if (!developmentBuild) {
      return;
    }
    await _prefs.setBool(developmentKey, unlocked);
    _publish();
  }

  /// The screen showed [ProState.message].
  void clearMessage() => state = state.copyWith(clearMessage: true);

  Future<void> _onUpdate(ProPurchaseUpdate update) async {
    switch (update.status) {
      case ProPurchaseStatus.pending:
        state = state.copyWith(busy: false, pending: true);
      case ProPurchaseStatus.purchased:
        _confirmations++;
        await _setPurchased(true);
        if (mounted) {
          state = state.copyWith(
            busy: false,
            pending: false,
            message: ProMessage.purchased,
          );
        }
      case ProPurchaseStatus.cancelled:
        state = state.copyWith(busy: false);
      case ProPurchaseStatus.failed:
        Logger.warning('Pro purchase failed: ${update.error}');
        state = state.copyWith(busy: false, message: ProMessage.failed);
    }
  }

  Future<void> _setPurchased(bool purchased) async {
    _purchased = purchased;
    if ((_prefs.getBool(unlockedKey) ?? false) != purchased) {
      Logger.info(purchased ? 'Pro unlocked' : 'Pro purchase not found');
      await _prefs.setBool(unlockedKey, purchased);
    }
    _publish();
  }

  void _publish() {
    if (!mounted) {
      return;
    }
    final purchased = _purchased || (_prefs.getBool(unlockedKey) ?? false);
    final forDevelopment = _forDevelopment;
    state = state.copyWith(
      unlocked: purchased || forDevelopment,
      unlockedForDevelopment: forDevelopment && !purchased,
      pending: purchased ? false : null,
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

/// Whether this is the development flavour (false in tests that do not set
/// up [AppConfig]).
final isDevelopmentBuildProvider = Provider<bool>((ref) {
  try {
    return AppConfig.instance.environment == AppEnvironment.development;
  } catch (_) {
    return false;
  }
});

/// Google Play on Android; nothing to buy elsewhere (and in tests).
final proStoreProvider = Provider<ProStore>((ref) {
  final store = Platform.isAndroid
      ? PlayProStore()
      : const UnavailableProStore();
  ref.onDispose(store.dispose);
  return store;
});

final proControllerProvider = StateNotifierProvider<ProController, ProState>((
  ref,
) {
  final controller = ProController(
    prefs: ref.watch(sharedPreferencesProvider),
    store: ref.watch(proStoreProvider),
    developmentBuild: ref.watch(isDevelopmentBuildProvider),
  );
  unawaited(controller.refresh());
  return controller;
});

/// Whether Pro is unlocked.
final proUnlockedProvider = Provider<bool>(
  (ref) => ref.watch(proControllerProvider.select((s) => s.unlocked)),
);

/// Whether [feature] can be used: free, or Pro is unlocked.
final proFeatureAvailableProvider = Provider.family<bool, ProFeature>(
  (ref, feature) =>
      !ProFeatures.needsPro(feature) || ref.watch(proUnlockedProvider),
);
