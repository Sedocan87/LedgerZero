import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  String? _recoveryKey;
  bool _isLoading = false;
  final _passwordController = TextEditingController();

  Future<void> _revealKey() async {
    setState(() => _isLoading = true);
    try {
      final securityManager = ref.read(securityManagerProvider);

      // 1. Try Biometrics first if available
      final biometricsAvailable = await securityManager.isBiometricsAvailable;
      if (biometricsAvailable) {
        final authenticated = await securityManager
            .authenticateWithBiometrics();
        if (authenticated) {
          final storedKey = await securityManager.getKey();
          if (storedKey != null) {
            setState(() {
              _recoveryKey = storedKey;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 2. Fallback to Password
      if (mounted) {
        await _showPasswordDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted && _recoveryKey == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPasswordDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Master Password'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _deriveAndVerifyKey();
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deriveAndVerifyKey() async {
    setState(() => _isLoading = true);
    try {
      final securityManager = ref.read(securityManagerProvider);
      final password = _passwordController.text;
      final salt = await securityManager.getSalt();

      if (salt == null) {
        throw Exception('Security setup not found');
      }

      final derivedKey = await securityManager.deriveKeyFromPassword(
        password,
        salt,
      );
      final isValid = await securityManager.verifyKey(derivedKey);

      if (isValid) {
        setState(() {
          _recoveryKey = derivedKey;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid password')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _passwordController.clear();
      }
    }
  }

  void _copyToClipboard() {
    if (_recoveryKey != null) {
      Clipboard.setData(ClipboardData(text: _recoveryKey!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery key copied to clipboard')),
      );
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup Recovery Key')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.amber),
            const SizedBox(height: 24),
            const Text(
              'Your Recovery Key is the only way to restore your data if you forget your password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Store this key in a safe place (like a password manager). Do not share it with anyone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            if (_recoveryKey == null)
              ElevatedButton(
                onPressed: _isLoading ? null : _revealKey,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Reveal Recovery Key',
                        style: TextStyle(fontSize: 18),
                      ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: SelectableText(
                  _recoveryKey!,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 16,
                    color: Colors.amberAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('Copy to Clipboard'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
