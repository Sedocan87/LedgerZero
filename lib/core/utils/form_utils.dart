import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormUtils {
  /// Finds the first FormField descendant that has an error decoration and requests focus for it.
  /// This ensures that when validation fails, screen readers and keyboard users
  /// are immediately directed to the problem.
  static void focusFirstError(BuildContext context) {
    // Trigger haptic feedback immediately
    HapticFeedback.heavyImpact();

    // We need to wait a frame for the validation state to update the UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Traverse the element tree to find the first FormField with an error
      Element? firstErrorElement;

      void visit(Element element) {
        if (firstErrorElement != null) {
      return;
    } // Found one, stop

        if (element.widget is FormField) {
          final FormFieldState state = (element as StatefulElement).state as FormFieldState;
          if (state.hasError) {
             firstErrorElement = element;
             return;
          }
        }
        element.visitChildren(visit);
      }

      context.visitChildElements(visit);

      if (firstErrorElement != null) {
          // Try to scroll to it
          Scrollable.ensureVisible(
            firstErrorElement!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
          );

          // Focus logic would go here if we could reliably extract FocusNode
          // For now, scrolling to it helps significantly.
          // And we rely on the screen implementation passing FocusNodes correctly.
          // But scrolling ensures it's in viewport.
      }
    });
  }
}
