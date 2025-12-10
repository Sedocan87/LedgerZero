import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ledger_zero/presentation/screens/login_screen.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([SecurityManager])
import 'authentication_test.mocks.dart';

void main() {
  late MockSecurityManager mockSecurityManager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    mockSecurityManager = MockSecurityManager();

    // Default mocks
    when(mockSecurityManager.getSalt()).thenAnswer((_) async => 'salt');
    when(mockSecurityManager.deriveKeyFromPassword(any, any)).thenReturn('derived_key');
    when(mockSecurityManager.verifyKey(any)).thenAnswer((_) async => true);
    when(mockSecurityManager.isBiometricsAvailable).thenAnswer((_) async => false);
    when(mockSecurityManager.hasKey()).thenAnswer((_) async => false);
  });

  Widget createLoginScreen() {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('Home Screen'))),
      ],
      initialLocation: '/login',
    );

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        return ProviderScope(
          overrides: [
            securityManagerProvider.overrideWithValue(mockSecurityManager),
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        );
      }
    );
  }

  testWidgets('Login with correct password sets session key and navigates', (tester) async {
    await tester.pumpWidget(createLoginScreen());
    await tester.pumpAndSettle(); // Wait for FutureBuilder

    // Enter password
    await tester.enterText(find.byType(TextField), 'password123');
    await tester.pump();

    // Tap login
    await tester.tap(find.text('Unlock Database'));
    await tester.pumpAndSettle(); // Wait for async

    // Debug SnackBar if present
    final snackBarFinder = find.byType(SnackBar);
    if (snackBarFinder.evaluate().isNotEmpty) {
      // Try to find text inside snackbar
      final textFinder = find.descendant(
        of: snackBarFinder,
        matching: find.byType(Text),
      );
      if (textFinder.evaluate().isNotEmpty) {
        // final text = tester.widget<Text>(textFinder.first);
        // print('DEBUG: SnackBar detected with text: "${text.data}"');
      }
    }

    // Verify logic
    verify(mockSecurityManager.getSalt()).called(1);
    verify(mockSecurityManager.deriveKeyFromPassword('password123', 'salt')).called(1);
    verify(mockSecurityManager.verifyKey('derived_key')).called(1);

    // Verify navigation success (SnackBar should NOT be present)
    expect(find.byType(SnackBar), findsNothing);

    // Verify we are at Home Screen
    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('Login with incorrect password shows error', (tester) async {
    when(mockSecurityManager.verifyKey(any)).thenAnswer((_) async => false);

    await tester.pumpWidget(createLoginScreen());
    await tester.pumpAndSettle(); // Wait for FutureBuilder

    await tester.enterText(find.byType(TextField), 'wrongpassword');
    await tester.tap(find.text('Unlock Database'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid password'), findsOneWidget);
    // Should still be on login screen
    expect(find.text('Unlock Database'), findsOneWidget);
  });
}
