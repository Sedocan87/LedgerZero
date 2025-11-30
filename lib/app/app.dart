import 'package:flutter/material.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.instance.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'LedgerZero Home Page'),
    );
  }
}
