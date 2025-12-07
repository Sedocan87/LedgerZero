import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';

// Helper to calculate relative luminance
double luminance(Color color) {
  return color.computeLuminance();
}

// Helper to calculate contrast ratio
double contrastRatio(Color c1, Color c2) {
  final l1 = luminance(c1);
  final l2 = luminance(c2);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Accessibility - Color Contrast', () {
    test('Light Theme Primary Colors should meet WCAG AA (4.5:1)', () {
      expect(
        contrastRatio(AppColors.onPrimaryLight, AppColors.primaryLight),
        greaterThanOrEqualTo(4.5),
        reason: 'onPrimaryLight vs primaryLight',
      );
      expect(
        contrastRatio(AppColors.onPrimaryContainerLight, AppColors.primaryContainerLight),
        greaterThanOrEqualTo(4.5),
        reason: 'onPrimaryContainerLight vs primaryContainerLight',
      );
    });

    test('Dark Theme Primary Colors should meet WCAG AA (4.5:1)', () {
      expect(
        contrastRatio(AppColors.onPrimaryDark, AppColors.primaryDark),
        greaterThanOrEqualTo(4.5),
        reason: 'onPrimaryDark vs primaryDark',
      );
      expect(
        contrastRatio(AppColors.onPrimaryContainerDark, AppColors.primaryContainerDark),
        greaterThanOrEqualTo(4.5),
        reason: 'onPrimaryContainerDark vs primaryContainerDark',
      );
    });

    test('Background/Surface Text Contrast (Light)', () {
      expect(
        contrastRatio(AppColors.onSurfaceLight, AppColors.surfaceLight),
        greaterThanOrEqualTo(4.5),
        reason: 'onSurfaceLight vs surfaceLight',
      );
      expect(
         contrastRatio(AppColors.onSurfaceLight, AppColors.backgroundLight),
         greaterThanOrEqualTo(4.5),
         reason: 'onSurfaceLight vs backgroundLight',
      );
    });

    test('Background/Surface Text Contrast (Dark)', () {
      expect(
        contrastRatio(AppColors.onSurfaceDark, AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5),
        reason: 'onSurfaceDark vs surfaceDark',
      );
       expect(
         contrastRatio(AppColors.onSurfaceDark, AppColors.backgroundDark),
         greaterThanOrEqualTo(4.5),
         reason: 'onSurfaceDark vs backgroundDark',
      );
    });

    test('Semantic Colors Contrast', () {
       // Assuming white text on error color in light mode
       expect(
         contrastRatio(AppColors.onErrorLight, AppColors.errorLight),
         greaterThanOrEqualTo(4.5),
         reason: 'onErrorLight vs errorLight',
       );
       // Assuming black text on error color in dark mode (usually error is lighter in dark mode)
       expect(
         contrastRatio(AppColors.onErrorDark, AppColors.errorDark),
         greaterThanOrEqualTo(4.5),
         reason: 'onErrorDark vs errorDark',
       );
    });
  });
}
