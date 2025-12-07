# Performance Best Practices

## Overview
LedgerZero is a "Local-First" application, meaning all processing happens on the user's device. To ensure a smooth experience, especially on older devices, we adhere to strict performance guidelines.

## 1. Widget Rebuilds
*   **Use `const` Constructors:** Always use `const` for widgets and value objects where possible. This allows Flutter to short-circuit rebuilds.
    *   *Bad:* `Padding(padding: EdgeInsets.all(8.0), ...)`
    *   *Good:* `Padding(padding: const EdgeInsets.all(8.0), ...)`
*   **Riverpod `select`:** When watching a provider that returns a complex object, use `.select()` to listen only to the specific field you need.
    *   *Bad:* `final budget = ref.watch(budgetViewModelProvider);` (Rebuilds on any change)
    *   *Good:* `final available = ref.watch(budgetViewModelProvider.select((vm) => vm.available));`
*   **Extract Widgets:** Break down large `build` methods into smaller, separate `StatelessWidget` classes (not just helper methods). This ensures only the modified subtree rebuilds.

## 2. Rendering & Animations
*   **`RepaintBoundary`:** Wrap complex painting widgets (like Charts) or widgets that animate frequently (like progress bars) in a `RepaintBoundary`. This creates a separate display list, preventing the parent from repainting when the child updates, and vice-versa.
*   **`AnimatedBuilder`:** Use `AnimatedBuilder` to scope animation rebuilds to the smallest possible part of the tree.

## 3. Database & Logic
*   **Avoid N+1 Queries:** Do not execute database queries inside loops. Use batch fetching or SQL `JOIN`s.
*   **Main Thread:** Heavy calculations should not block the UI thread. While Dart is single-threaded, `Future`s help, but for CPU-intensive work (like parsing 10k CSV rows), use `compute()` to spawn an Isolate.
*   **Indexes:** Ensure database columns used in `WHERE` and `ORDER BY` clauses are indexed. Check `DATABASE_SCHEMA.md` for existing indexes.

## 4. Testing on Low-End Devices
Since we cannot always physically test on low-end hardware, use the following techniques:
*   **Android Emulator Throttling:** Open Extended Controls > settings and reduce the number of CPU cores or throttle the CPU speed.
*   **iOS Simulator:** Use "Debug > Slow Animations" to catch jank, though it doesn't simulate CPU load perfectly.
*   **Performance Overlay:** Enable the performance overlay in Flutter DevTools to identify raster thread or UI thread jank.

## 5. Memory Management
*   **Dispose:** Always dispose `Controllers` (AnimationController, TextEditingController, etc.) in `dispose()`.
*   **Image Caching:** Use `cached_network_image` (if fetching from web) or `resizeImage` to load images at the display size, not full resolution.
*   **Leak Detection:** Use the `leak_tracker` package in tests to catch objects that are not garbage collected.

## 6. Monitoring
*   **Local Monitoring:** The app includes a `PerformanceMonitor` (in debug/profile mode) that logs warnings to the console if a frame takes longer than 16ms to build.
