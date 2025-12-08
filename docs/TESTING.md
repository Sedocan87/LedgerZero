# Widget Testing Guide

This document outlines the testing patterns and best practices used in the LedgerZero project for verifying UI components.

## 1. Testing Loading States

To test loading states, we mock the providers to return an asynchronous state that hasn't completed yet (or simulate a delay).

**Pattern:**
```dart
testWidgets('Screen shows loading indicator', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
         // Override with a future that doesn't complete immediately
         myProvider.overrideWith((ref) => Future.delayed(const Duration(seconds: 1), () => data)),
         // Or explicitly mock AsyncValue
         // myProvider.overrideWith((ref) => AsyncValue.loading()),
      ],
      child: MaterialApp(home: MyScreen()),
    ),
  );

  // Verify loading indicator is present
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Wait for it to settle if needed
  await tester.pumpAndSettle(const Duration(seconds: 1));
});
```

## 2. Testing Error States

To test error states, override the provider to throw an error or return `AsyncValue.error`.

**Pattern:**
```dart
testWidgets('Screen shows error message', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
         myProvider.overrideWith((ref) => Future.error('Network Error')),
      ],
      child: MaterialApp(home: MyScreen()),
    ),
  );

  // Allow the future to complete (with error)
  await tester.pumpAndSettle();

  expect(find.textContaining('Network Error'), findsOneWidget);
});
```

## 3. Responsive Layout Testing

We verify responsiveness by manipulating `tester.view.physicalSize`.

**Pattern:**
```dart
testWidgets('Adapts to large screens', (tester) async {
  // Set window size to desktop resolution
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(...);

  // Verify layout specific to large screens (e.g. ConstrainedBox max width)
  final constrainedBox = tester.widget<ConstrainedBox>(find.byType(ConstrainedBox));
  expect(constrainedBox.constraints.maxWidth, 800.0);
});
```

## 4. Interaction Testing

Use `tester.tap`, `tester.drag`, and `tester.longPress` to simulate user interactions.

**Pattern:**
```dart
testWidgets('Swipe to delete', (tester) async {
  await tester.pumpWidget(...);

  // Find the dismissible item
  final item = find.byType(Dismissible);

  // Swipe
  await tester.drag(item, const Offset(500.0, 0.0));
  await tester.pumpAndSettle();

  // Verify action (e.g. snackbar or callback)
  expect(find.text('Deleted'), findsOneWidget);
});
```

## 5. Animation Testing

For animations, use `tester.pump(duration)` to advance time incrementally. Note that some animations might be disabled in test environments by default.

**Pattern:**
```dart
testWidgets('Animation updates', (tester) async {
  await tester.pumpWidget(MyAnimatedWidget(value: 0));

  // Update widget
  await tester.pumpWidget(MyAnimatedWidget(value: 100));

  // Advance animation halfway
  await tester.pump(const Duration(milliseconds: 250));

  // Verify intermediate state if possible, or just final state
  await tester.pumpAndSettle();
  expect(find.text('100'), findsOneWidget);
});
```

## 6. Accessibility Testing

Use `meetsGuideline` matchers provided by `flutter_test`.

**Pattern:**
```dart
testWidgets('Meets accessibility guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(...);

  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));

  handle.dispose();
});
```

## 7. Performance Testing

While `integration_test` is better for real performance metrics, `flutter_test` can catch major regressions in render time using `Stopwatch`.

**Pattern:**
```dart
testWidgets('Renders efficiently', (tester) async {
  final stopwatch = Stopwatch()..start();
  await tester.pumpWidget(...);
  stopwatch.stop();

  debugPrint('Render time: ${stopwatch.elapsedMilliseconds}ms');
  expect(stopwatch.elapsedMilliseconds, lessThan(500));
});
```

## 8. Mocking Dependencies

We use `mockito` and `riverpod` overrides to isolate widgets.

**Tips:**
- When mocking Riverpod providers, use `.overrideWith((ref) => ...)`
- For Stream providers, return `Stream.value(data)`.
- Be aware that `StateNotifier` constructors might trigger initial loads; ensure mocks are set up to handle those calls or override the notifier state directly if possible.

## 9. Custom Widget Testing

For custom painters or complex widgets:
- Use `find.bySemanticsLabel` if the widget provides semantics (recommended).
- Verify `shouldRepaint` logic in unit tests for Painters.
- Test edge cases like empty data or null inputs.
