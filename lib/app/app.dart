import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: AppConfig.instance.appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MyHomePage(title: 'LedgerZero Home Page'),
    );
  }
}
