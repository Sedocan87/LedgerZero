import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/services/security/secure_store.dart';

/// Reading the database while no session is open (before start-up opened
/// it, during a factory reset or restore).
class DatabaseLockedException implements Exception {
  const DatabaseLockedException();
  @override
  String toString() => 'DatabaseLockedException: the database is not open';
}

class SessionState {
  final bool isOpen;

  const SessionState.closed() : isOpen = false;
  const SessionState.open() : isOpen = true;
}

/// Whether the database is open, for services that need it (sync).
///
/// Not the app lock: the app lock only gates the UI
/// ([AuthState.isAuthenticated]); the database stays open behind it.
enum AppLockState { locked, unlocked }

/// Whether the database is open. [databaseProvider] watches it: [open]
/// opens a connection, [close] closes it. The session is opened at
/// start-up (lock screen, or onboarding) and closed only for a factory
/// reset or while onboarding replaces a database.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState.closed();

  /// Opens the database (no-op when it is open).
  void open() {
    if (!state.isOpen) {
      state = const SessionState.open();
    }
  }

  /// Closes the database and emits [AppLockState.locked].
  Future<void> close() async {
    final db = ref.exists(databaseProvider) && state.isOpen
        ? _currentDatabase()
        : null;
    state = const SessionState.closed();
    if (db != null) {
      await closeDatabaseOnce(db);
    }
  }

  AppDatabase? _currentDatabase() {
    try {
      return ref.read(databaseProvider);
    } catch (_) {
      return null;
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Database open/closed state for other services.
///
/// Sync listens to this and pauses on [AppLockState.locked]:
/// `ref.listen(appLockStateProvider, (_, next) { ... })`. While closed any
/// query throws [DatabaseLockedException].
final appLockStateProvider = Provider<AppLockState>((ref) {
  final open = ref.watch(sessionProvider.select((s) => s.isOpen));
  return open ? AppLockState.unlocked : AppLockState.locked;
});

/// The KeyStore-protected storage of the automatic-backup password and the
/// Wi-Fi pairing secret. Not the database: that is a plain file in the
/// app's private storage.
final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore.current(),
);
