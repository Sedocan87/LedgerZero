import 'package:flutter/material.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.instance.appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'LedgerZero Home Page'),
    );
  }
}
