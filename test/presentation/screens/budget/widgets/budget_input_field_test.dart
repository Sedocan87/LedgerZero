import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_input_field.dart';

void main() {
  testWidgets('BudgetInputField initializes with value and submits on done', (tester) async {
    double? submittedValue;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetInputField(
          initialValue: 123.45,
          onSubmitted: (value) {
            submittedValue = value;
          },
        ),
      ),
    ));

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    expect(find.text('123.45'), findsOneWidget);

    await tester.enterText(textField, '500.00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submittedValue, 500.00);
  });
}
