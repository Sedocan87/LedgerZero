import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
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

/// Builds the camera view of [LanScanCodeScreen]. It reports the text of
/// every QR code it reads with [onCode], and calls [onCameraError] when the
/// camera cannot be used (permission denied, no camera, camera fault).
typedef LanQrScannerBuilder =
    Widget Function(
      BuildContext context, {
      required ValueChanged<String> onCode,
      required VoidCallback onCameraError,
    });

/// Scans the other phone's pairing code; "Enter code instead" for when the
/// camera cannot be used. Pops with the code text.
class LanScanCodeScreen extends StatefulWidget {
  const LanScanCodeScreen({super.key, this.scannerBuilder = _zxingScanner});

  /// The camera view; replaced in widget tests, where no camera exists.
  final LanQrScannerBuilder scannerBuilder;

  /// The scanned or typed code, or null when cancelled. The camera
  /// permission prompt must not trigger the auto-lock.
  static Future<String?> show(BuildContext context) => ExternalUiGuard.run(
    () => Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LanScanCodeScreen()),
    ),
  );

  /// ZXing (C++ through FFI) on the frames of the camera plugin: it decodes
  /// on the phone and has no Google ML Kit or Play services behind it.
  /// Opening the camera asks for the camera permission; a denial arrives in
  /// `onControllerCreated` as an error.
  static Widget _zxingScanner(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required VoidCallback onCameraError,
  }) => ReaderWidget(
    codeFormat: Format.qrCode,
    // The pairing code is a dense QR code: scan most of the frame so that
    // it does not have to sit exactly in the middle, and look again quickly
    // after a frame without a code.
    cropPercent: 0.8,
    scanDelay: const Duration(milliseconds: 250),
    showGallery: false,
    showToggleCamera: false,
    onScan: (code) {
      final text = code.text;
      if (code.isValid && text != null) {
        onCode(text);
      }
    },
    onControllerCreated: (_, error) {
      if (error != null) {
        onCameraError();
      }
    },
  );

  @override
  State<LanScanCodeScreen> createState() => _LanScanCodeScreenState();
}

class _LanScanCodeScreenState extends State<LanScanCodeScreen> {
  bool _done = false;
  bool _cameraFailed = false;

  void _onCode(String value) {
    if (_done || !mounted) {
      return;
    }
    if (value.startsWith(LanPairingCode.prefix)) {
      _done = true;
      Navigator.of(context).pop(value);
    }
  }

  void _onCameraError() {
    if (mounted && !_cameraFailed) {
      setState(() => _cameraFailed = true);
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
            child: _cameraFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.lanCameraUnavailable,
                        key: const Key('lan_camera_unavailable'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : widget.scannerBuilder(
                    context,
                    onCode: _onCode,
                    onCameraError: _onCameraError,
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
