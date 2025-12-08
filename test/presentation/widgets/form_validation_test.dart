import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('Form Validation Tests', () {
    testWidgets('AppTextField displays error text', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpTestWidget(
        tester,
        child: Scaffold(
          body: Form(
            key: formKey,
            child: AppTextField(
              label: 'Field',
              validator: (value) => 'Error Message',
            ),
          ),
        ),
      );

      // Trigger validation
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Error Message'), findsOneWidget);
    });
  });
}
