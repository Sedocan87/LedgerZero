import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';

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
    // We don't call _initializeServices here anymore; relying on ref.listen below.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Lock database on background
      SecurityManager.setSessionKey(null);

      // Only lock if we are currently authenticated to avoid loops or weird states
      // (though setAuthenticated(false) is safe even if already false)
      if (ref.read(authProvider).isAuthenticated) {
        ref.read(authProvider.notifier).setAuthenticated(false);
      }
    }
  }

  Future<void> _initializeServices() async {
    await ref.read(notificationServiceProvider).initialize();
    await ref.read(scheduledTransactionServiceProvider).processDueTransactions();
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

    return MaterialApp.router(
      title: AppConfig.instance.appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
