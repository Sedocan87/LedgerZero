import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isBiometricsAvailable = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final securityManager = ref.read(securityManagerProvider);
    // Check if hardware available AND we have a stored key
    final available = await securityManager.isBiometricsAvailable;
    final hasKey = await securityManager.hasKey();

    if (mounted) {
      setState(() {
        _isBiometricsAvailable = available && hasKey;
      });

      if (_isBiometricsAvailable) {
        await _attemptBiometricLogin();
      }
    }
  }

  Future<void> _attemptBiometricLogin() async {
    setState(() => _isLoading = true);
    try {
      final securityManager = ref.read(securityManagerProvider);
      final authenticated = await securityManager.authenticateWithBiometrics();

      if (authenticated) {
        final key = await securityManager.getKey();
        if (key != null) {
          _loginSuccess(key);
        } else {
           _showError('Biometric key not found. Please use password.');
        }
      }
    } catch (e) {
      // Ignore errors, user can fallback to password
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithPassword() async {
    if (_passwordController.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final securityManager = ref.read(securityManagerProvider);
      final salt = await securityManager.getSalt();

      if (salt == null) {
        _showError('Security configuration missing. Please reset app.');
        return;
      }

      final key = securityManager.deriveKeyFromPassword(_passwordController.text, salt);
      final isValid = await securityManager.verifyKey(key);

      if (isValid) {
        _loginSuccess(key);
      } else {
        _showError('Invalid password');
      }
    } catch (e) {
      _showError('Login error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loginSuccess(String key) {
    SecurityManager.setSessionKey(key);
    ref.read(authProvider.notifier).setAuthenticated(true);
    context.go('/');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.teal),
              const SizedBox(height: 32),
              const Text(
                'Welcome Back',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) => _loginWithPassword(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _loginWithPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock Database', style: TextStyle(fontSize: 18)),
              ),
              if (_isBiometricsAvailable) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _isLoading ? null : _attemptBiometricLogin,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use Biometrics'),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _showRecoveryKeyDialog,
                child: const Text('Use Recovery Key'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecoveryKeyDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Recovery Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste your recovery key here',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _loginWithKey(controller.text.trim());
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithKey(String keyInput) async {
    if (keyInput.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final securityManager = ref.read(securityManagerProvider);
      // Verify if this key is valid
      final isValid = await securityManager.verifyKey(keyInput);
      if (isValid) {
        _loginSuccess(keyInput);
      } else {
        _showError('Invalid recovery key');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
