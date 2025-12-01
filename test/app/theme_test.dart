import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';

void main() {
  group('AppTheme', () {
    test('Light theme should have correct brightness and colors', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, true);
      expect(theme.colorScheme.primary, AppColors.primaryLight);
      expect(theme.colorScheme.secondary, AppColors.secondaryLight);
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundLight);
    });

    test('Dark theme should have correct brightness and colors', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, true);
      expect(theme.colorScheme.primary, AppColors.primaryDark);
      expect(theme.colorScheme.secondary, AppColors.secondaryDark);
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundDark);
    });
  });

  group('AppColors', () {
    test('Light mode colors should be correct', () {
      expect(AppColors.primaryLight, const Color(0xFF00796B));
      expect(AppColors.secondaryLight, const Color(0xFF455A64));
    });

    test('Dark mode colors should be correct', () {
      expect(AppColors.primaryDark, const Color(0xFF80CBC4));
      expect(AppColors.secondaryDark, const Color(0xFFB0BEC5));
    });
  });
}
