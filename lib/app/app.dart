import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/widgets/security/privacy_shield.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/security/auto_lock_service.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  StreamSubscription<void>? _capturedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Exports that outlived a crash or a killed process.
    ref.read(exportFileServiceProvider).sweepStale();
    // Sync lives for the whole app session: it follows the lock state
    // (paused while locked) and syncs on unlock, resume and local changes.
    ref.read(syncControllerProvider.notifier);
    _initializeNotifications();
    // A card notification captured while the app is open and unlocked is
    // booked at once; otherwise after the next unlock or resume.
    _capturedSubscription = ref
        .read(notificationCaptureChannelProvider)
        .captured
        .listen((_) => _processCapturedNotifications());
  }

  /// Notification taps (including the one that launched the app) go to the
  /// tap router, which waits for the unlock before navigating.
  void _initializeNotifications() {
    final notifications = ref.read(notificationServiceProvider);
    final tapRouter = ref.read(notificationTapRouterProvider);
    notifications.tapHandler = (payload) {
      unawaited(tapRouter.handleTap(payload));
    };
    unawaited(notifications.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capturedSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(autoLockServiceProvider).didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.read(exportFileServiceProvider).sweepStale();
      ref.read(syncControllerProvider.notifier).onAppResumed();
      _processCapturedNotifications();
    }
  }

  /// Books card notifications captured since the last run (needs the
  /// unlocked database; a locked app retries after the next unlock).
  Future<void> _processCapturedNotifications() async {
    if (!ref.read(authProvider).isAuthenticated) {
      return;
    }
    final capture = ref.read(notificationCaptureServiceProvider);
    if (!capture.isSupported) {
      return;
    }
    try {
      await capture.processPending();
    } on DatabaseLockedException {
      // Locked meanwhile; runs again after the next unlock.
    } catch (e, stackTrace) {
      Logger.error('Booking captured card notifications failed', e, stackTrace);
    }
  }

  Future<void> _initializeServices() async {
    unawaited(ref.read(notificationTapRouterProvider).onUnlocked());
    unawaited(_processCapturedNotifications());
    final notifications = ref.read(notificationServiceProvider);
    await notifications.initialize();
    final settings = ref.read(settingsProvider);
    if (settings.scheduledTransactionNotifications ||
        settings.budgetAlertNotifications ||
        settings.syncStatusNotifications) {
      await notifications.requestPermissions();
    }
    try {
      final scheduled = ref.read(scheduledTransactionServiceProvider);
      await scheduled.processDueTransactions(
        fallbackMemo: _scheduledFallbackMemo(),
      );
      // New or edited schedules and a changed reminder toggle take effect.
      await scheduled.rescheduleReminders();
    } on DatabaseLockedException {
      // Locked while starting up; runs again after the next unlock.
    }
  }

  /// Localised memo for generated scheduled occurrences without memo and
  /// payee, in the app language (Settings, else the device locale).
  String _scheduledFallbackMemo() =>
      ref.read(appLocalizationsProvider).scheduledTransactionDefaultMemo;

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated &&
          (previous == null || !previous.isAuthenticated)) {
        _initializeServices();
      }
    });
    ref.listen<SyncState>(
      syncControllerProvider,
      ref.read(syncFailureNotificationsProvider).onSyncState,
    );

    final lightTheme = themeState.isHighContrast
        ? AppTheme.highContrastLightTheme
        : AppTheme.lightTheme;
    final darkTheme = themeState.isHighContrast
        ? AppTheme.highContrastDarkTheme
        : AppTheme.darkTheme;

    return MaterialApp.router(
      title: AppConfig.instance.appTitle,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeState.mode,
      routerConfig: router,
      // Language chosen in Settings; null follows the device.
      locale: ref.watch(settingsProvider).language,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          PrivacyShield(child: child ?? const SizedBox.shrink()),
    );
  }
}
