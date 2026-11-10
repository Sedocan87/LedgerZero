// The pairing scan screen around the camera view: which scanned codes it
// accepts, what it shows when the camera cannot be used, and the "enter
// code" fallback. The camera view itself (flutter_zxing) needs a real camera
// and is replaced by a stand-in here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/settings/sync/lan_pairing_screens.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';

import '../../../widget_test_helpers.dart';

void main() {
  late ValueChanged<String> scan;
  late VoidCallback failCamera;

  Widget fakeScanner(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required VoidCallback onCameraError,
  }) {
    scan = onCode;
    failCamera = onCameraError;
    return const ColoredBox(key: Key('fake_camera'), color: Colors.black);
  }

  /// Opens the scan screen from a button and records what it pops with.
  Future<List<String?>> openScanner(WidgetTester tester) async {
    final results = <String?>[];
    await pumpTestWidget(
      tester,
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            results.add(
              await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) =>
                      LanScanCodeScreen(scannerBuilder: fakeScanner),
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake_camera')), findsOneWidget);
    return results;
  }

  testWidgets('a scanned pairing code closes the screen with the code', (
    tester,
  ) async {
    final results = await openScanner(tester);
    const code = '${LanPairingCode.prefix}abc';

    scan(code);
    await tester.pumpAndSettle();

    expect(results, [code]);
    expect(find.byType(LanScanCodeScreen), findsNothing);
  });

  testWidgets('a QR code that is not a pairing code is ignored', (
    tester,
  ) async {
    final results = await openScanner(tester);

    scan('https://example.com/not-a-pairing-code');
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(find.byType(LanScanCodeScreen), findsOneWidget);

    // The scanner keeps running: the right code is still taken afterwards,
    // and only once.
    const code = '${LanPairingCode.prefix}abc';
    scan(code);
    scan('${LanPairingCode.prefix}other');
    await tester.pumpAndSettle();
    expect(results, [code]);
  });

  testWidgets(
    'a camera that cannot be used (permission denied) shows the hint and '
    'the code can still be typed',
    (tester) async {
      final results = await openScanner(tester);

      failCamera();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fake_camera')), findsNothing);
      expect(find.byKey(const Key('lan_camera_unavailable')), findsOneWidget);
      expect(
        find.text('The camera is not available. Enter the code instead.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('lan_enter_code')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('lan_code_field')),
        '  ${LanPairingCode.prefix}typed  ',
      );
      await tester.tap(find.byKey(const Key('lan_code_submit')));
      await tester.pumpAndSettle();

      expect(results, ['${LanPairingCode.prefix}typed']);
    },
  );

  testWidgets('"Enter code instead" works while the camera is running', (
    tester,
  ) async {
    final results = await openScanner(tester);

    await tester.tap(find.byKey(const Key('lan_enter_code')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lan_code_field')),
      '${LanPairingCode.prefix}typed',
    );
    await tester.tap(find.byKey(const Key('lan_code_submit')));
    await tester.pumpAndSettle();

    expect(results, ['${LanPairingCode.prefix}typed']);
  });
}
