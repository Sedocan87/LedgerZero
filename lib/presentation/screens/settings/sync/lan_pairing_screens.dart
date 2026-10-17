import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows this phone's pairing code as a QR code (and as text for typing),
/// for Settings > Sync > Home Wi-Fi > Pair a phone.
class LanShowCodeScreen extends ConsumerStatefulWidget {
  const LanShowCodeScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const LanShowCodeScreen()));

  @override
  ConsumerState<LanShowCodeScreen> createState() => _LanShowCodeScreenState();
}

class _LanShowCodeScreenState extends ConsumerState<LanShowCodeScreen> {
  String? _code;

  @override
  void initState() {
    super.initState();
    ref.read(syncControllerProvider.notifier).lanPairingCode().then((code) {
      if (mounted) {
        setState(() => _code = code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final code = _code;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lanPairPhone)),
      body: code == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(l10n.lanShowCodeInstructions),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    // Dark modules on white in both themes: scanners need
                    // the contrast.
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      key: const Key('lan_pairing_qr'),
                      data: code,
                      size: 260,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.lanShowCodeWarning,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 24),
                Text(l10n.lanCodeTextLabel),
                const SizedBox(height: 8),
                SelectableText(
                  code,
                  key: const Key('lan_pairing_text'),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
    );
  }
}

/// Scans the other phone's pairing code; "Enter code instead" for when the
/// camera cannot be used. Pops with the code text.
class LanScanCodeScreen extends StatefulWidget {
  const LanScanCodeScreen({super.key});

  /// The scanned or typed code, or null when cancelled. The camera
  /// permission prompt must not trigger the auto-lock.
  static Future<String?> show(BuildContext context) => ExternalUiGuard.run(
    () => Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LanScanCodeScreen()),
    ),
  );

  @override
  State<LanScanCodeScreen> createState() => _LanScanCodeScreenState();
}

class _LanScanCodeScreenState extends State<LanScanCodeScreen> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.startsWith(LanPairingCode.prefix)) {
        _done = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  Future<void> _enterCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _EnterCodeDialog(),
    );
    if (code != null && mounted && !_done) {
      _done = true;
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lanScanTitle)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.lanCameraUnavailable,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                key: const Key('lan_enter_code'),
                onPressed: _enterCode,
                icon: const Icon(Icons.keyboard),
                label: Text(l10n.lanEnterCode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterCodeDialog extends StatefulWidget {
  const _EnterCodeDialog();

  @override
  State<_EnterCodeDialog> createState() => _EnterCodeDialogState();
}

class _EnterCodeDialogState extends State<_EnterCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.lanEnterCodeTitle),
      content: TextField(
        key: const Key('lan_code_field'),
        controller: _controller,
        autocorrect: false,
        enableSuggestions: false,
        maxLines: 4,
        minLines: 2,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: l10n.lanEnterCodeHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('lan_code_submit'),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.continueAction),
        ),
      ],
    );
  }
}
