import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/settings_defaults_guard.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/budget_currency_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/new_month_fill_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/widgets/security/lock_overlay.dart';
import 'package:ledger_zero/presentation/widgets/security/privacy_shield.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart'
    show cardPaymentHealStamp;
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
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
    // Sync lives for the whole app session: it follows the database session
    // (opened at start-up, also behind the app lock) and syncs when it
    // opens, on resume and on local changes.
    ref.read(syncControllerProvider.notifier);
    _initializeNotifications();
    // A card notification captured while the app runs is booked at once;
    // otherwise at the next start or resume.
    _capturedSubscription = ref
        .read(notificationCaptureChannelProvider)
        .captured
        .listen((_) => _processCapturedNotifications());
  }

  /// Notification taps (including the one that launched the app) go to the
  /// tap router, which waits for the unlock before navigating. The
  /// permission is asked for when a notification is first needed
  /// ([NotificationPermissionGate]).
  void _initializeNotifications() {
    final notifications = ref.read(notificationServiceProvider);
    final tapRouter = ref.read(notificationTapRouterProvider);
    notifications.tapHandler = (payload) {
      unawaited(tapRouter.handleTap(payload));
    };
    notifications.beforeUse = ref
        .read(notificationPermissionGateProvider)
        .onUse;
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
      // A payday or a new month may have come while the app was in the
      // background.
      if (ref.read(sessionProvider).isOpen) {
        unawaited(_bookDueThenFill());
        unawaited(ref.read(autoBackupServiceProvider).runIfDue());
      }
      // A notification that came up in the background still needs the
      // permission.
      unawaited(ref.read(notificationPermissionGateProvider).onUiReady());
    }
    if (state == AppLifecycleState.paused) {
      ref.read(syncControllerProvider.notifier).onAppPaused();
      unawaited(_checkpointDatabase());
    }
  }

  /// Leaves the committed data in `db.sqlite` itself before Android may
  /// stop the process or copy the files for its backup or a transfer to a
  /// new phone ([AppDatabase.checkpointWal]). Never fails.
  Future<void> _checkpointDatabase() async {
    if (!ref.read(sessionProvider).isOpen) {
      return;
    }
    try {
      await ref.read(databaseProvider).checkpointWal();
    } catch (e) {
      Logger.warning('WAL checkpoint failed: $e');
    }
  }

  /// Books card notifications captured since the last run (needs the open
  /// database, not the unlocked UI) and keeps the outcome, the listener
  /// state and what is waiting for Home and Settings to show.
  Future<void> _processCapturedNotifications() =>
      ref.read(captureAttentionProvider.notifier).process();

  /// How long booking due schedules waits for the sync that is under way
  /// (see [_afterSyncPull]). Offline nothing runs and nothing is waited
  /// for; on a slow connection the schedules book after this at the
  /// latest.
  static const Duration _syncWait = Duration(seconds: 10);

  /// Lets the sync that started with this session or this resume finish
  /// first, so that the catch-up sees what the partner's phone already
  /// booked, edited, deleted or skipped instead of booking the same
  /// occurrences again from an older state. Returns at once when no sync
  /// runs (none set up, manual, offline). The catch-up is also safe
  /// without it (`ScheduleStamps`); this keeps it from writing rows only
  /// to lose them.
  Future<void> _afterSyncPull() async {
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .syncSettled()
          .timeout(_syncWait);
    } catch (_) {
      // Timed out: book with what this phone has.
    }
  }

  /// After a resume: books the scheduled occurrences that are due by today,
  /// then fills the new month. In this order, like at start-up: scheduled
  /// income is booked before the fill looks at To Be Budgeted
  /// (docs/BUDGET_INTERACTIONS.md).
  Future<void> _bookDueThenFill() async {
    await _afterSyncPull();
    if (!mounted) {
      return;
    }
    try {
      await ref
          .read(scheduledTransactionServiceProvider)
          .processDueTransactions(fallbackMemo: _scheduledFallbackMemo());
      await ref.read(newMonthFillProvider.notifier).runIfDue();
    } on DatabaseLockedException {
      // Closed meanwhile; runs again when it reopens.
    } catch (e, stackTrace) {
      Logger.error(
        'Booking due schedules or filling the new month failed',
        e,
        stackTrace,
      );
    }
  }

  /// Runs when the database session opens (start-up, before the app lock).
  Future<void> _initializeServices() async {
    unawaited(_processCapturedNotifications());
    final notifications = ref.read(notificationServiceProvider);
    await notifications.initialize();
    // With sync, after the first pull of the session (see there).
    await _afterSyncPull();
    if (!mounted) {
      return;
    }
    unawaited(_healCardPaymentCategories());
    try {
      final scheduled = ref.read(scheduledTransactionServiceProvider);
      await scheduled.processDueTransactions(
        fallbackMemo: _scheduledFallbackMemo(),
      );
      // New or edited schedules and a changed reminder toggle take effect.
      await scheduled.rescheduleReminders();
      await ref.read(newMonthFillProvider.notifier).runIfDue();
    } on DatabaseLockedException {
      // Closed while starting up; runs again when it reopens.
    }
    // The daily automatic backup, after the books are up to date.
    unawaited(ref.read(autoBackupServiceProvider).runIfDue());
  }

  /// Self-heal at start-up: every budget credit card has its payment
  /// category, named like the card and hidden while it is closed (stamped
  /// with the fixed old [cardPaymentHealStamp]: two phones healing at once
  /// write identical rows, and every real edit wins).
  Future<void> _healCardPaymentCategories() async {
    try {
      await ref
          .read(categoryRepositoryProvider)
          .syncCardPaymentCategories(stampedAt: cardPaymentHealStamp);
    } on DatabaseLockedException {
      // Closed while starting up; runs again when it reopens.
    } catch (e, st) {
      Logger.error('Healing the card payment categories failed', e, st);
    }
  }

  /// Runs when the UI is ready ([uiReadyProvider]): things the user sees
  /// wait for the app lock and the end of onboarding (the permission prompt
  /// would otherwise cover them). The permission is asked for only if a
  /// notification needed it meanwhile (e.g. the reminders scheduled at
  /// start-up), not at the end of onboarding.
  Future<void> _onUiUnlocked() async {
    unawaited(ref.read(notificationTapRouterProvider).onUnlocked());
    await ref.read(notificationPermissionGateProvider).onUiReady();
  }

  /// Localised memo for generated scheduled occurrences without memo and
  /// payee, in the app language (Settings, else the device locale).
  String _scheduledFallbackMemo() =>
      ref.read(appLocalizationsProvider).scheduledTransactionDefaultMemo;

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);
    // Drops a default account/category that was deleted, closed or hidden.
    ref.watch(settingsDefaultsGuardProvider);
    // Keeps Settings > Currency equal to the currency of the accounts in
    // the budget (at start-up, after a sync run, after any account change).
    ref.watch(budgetCurrencyGuardProvider);

    // Start-up work needs the database, not the unlocked UI: it runs as soon
    // as the lock screen has opened the session.
    ref.listen<AppLockState>(appLockStateProvider, (previous, next) {
      if (next == AppLockState.unlocked && previous != AppLockState.unlocked) {
        _initializeServices();
      }
    });
    // Each unlock of an onboarded app, and the end of onboarding (the
    // permission prompt mid-onboarding interrupted the setup steps).
    ref.listen<bool>(uiReadyProvider, (previous, next) {
      if (next && previous != true) {
        _onUiUnlocked();
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
      debugShowCheckedModeBanner: false,
      title: AppConfig.instance.appTitle,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeState.mode,
      routerConfig: router,
      // Settings, else the device locales: the same resolution as the
      // formatter and the notifications (resolveAppLocale).
      locale: ref.watch(appLocaleProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => PrivacyShield(
        child: LockOverlay(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
