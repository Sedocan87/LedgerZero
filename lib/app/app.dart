import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/widget_sync_listener.dart';
import 'package:ledger_zero/services/security/auto_lock_service.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLockService = ref.read(autoLockServiceProvider);

    if (state == AppLifecycleState.paused) {
      // Trigger widget update BEFORE auto-lock or app pause to ensure fresh data
      // is written to shared storage while we still have database access.
      ref.read(widgetServiceProvider).updateWidgetData();

      autoLockService.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      autoLockService.onAppResumed();
      // Optionally trigger widget update on resume as well
      ref.read(widgetServiceProvider).updateWidgetData();
    }
  }

  Future<void> _initializeServices() async {
    await ref.read(notificationServiceProvider).initialize();
    await ref.read(scheduledTransactionServiceProvider).processDueTransactions();
    // Update widgets on startup/auth
    await ref.read(widgetServiceProvider).updateWidgetData();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && (previous == null || !previous.isAuthenticated)) {
        _initializeServices();
      }
    });

    return WidgetSyncListener(
      child: MaterialApp.router(
        title: AppConfig.instance.appTitle,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
