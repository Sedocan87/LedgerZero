import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';

class SecuritySetupScreen extends ConsumerStatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  ConsumerState<SecuritySetupScreen> createState() =>
      _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends ConsumerState<SecuritySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isBiometricsAvailable = false;
  bool _useBiometrics = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final securityManager = ref.read(securityManagerProvider);
    final available = await securityManager.isBiometricsAvailable;
    if (mounted) {
      setState(() {
        _isBiometricsAvailable = available;
        _useBiometrics = available; // Default to true if available
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final securityManager = ref.read(securityManagerProvider);
    final password = _passwordController.text;
    String? key;
    String? salt;

    try {
      // 1. Generate Salt
      salt = securityManager.generateSecureKey();

      // 2. Derive Key (now async, runs in isolate)
      key = await securityManager.deriveKeyFromPassword(password, salt);

      // 3. Store Salt and Verifier
      await securityManager.storeSalt(salt);
      await securityManager.storeVerifier(key);
    } catch (e, stack) {
      debugPrint('Security Setup ERROR (salt/verifier): $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting up security: $e')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    // 4. Store Key if Biometrics enabled (optional, non-fatal)
    if (_useBiometrics) {
      try {
        final authenticated = await securityManager
            .authenticateWithBiometrics();
        if (authenticated) {
          await securityManager.storeKey(key);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric auth failed. Key not stored.'),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Biometric key storage failed (non-fatal): $e');
        // Continue anyway - biometrics is optional
      }
    } else {
      try {
        await securityManager.clearKey();
      } catch (e) {
        debugPrint('Clear key failed (non-fatal): $e');
      }
    }

    // Set session key for immediate DB access
    SecurityManager.setSessionKey(key);

    // Reset database instance so it gets created with the new encryption key
    AppDatabase.resetInstance();

    debugPrint('Security Setup: Key derived and stored. Session key set.');

    // 5. Proceed to next step
    if (mounted) {
      debugPrint('Security Setup: Setting authenticated=true');
      ref.read(authProvider.notifier).setAuthenticated(true);
      debugPrint('Security Setup: Scheduling navigation to account-setup');
      setState(() => _isLoading = false);

      // Navigate in the next frame to avoid router state conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('Security Setup: Now navigating to account-setup');
          context.goNamed('account-setup');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Protect Your Data')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set a Master Password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This password will be used to encrypt your financial data. '
                  'If you lose this password, your data cannot be recovered unless you have a backup.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isPasswordVisible,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_isBiometricsAvailable) ...[
                  SwitchListTile(
                    title: const Text('Use Biometrics'),
                    subtitle: const Text(
                      'Unlock the app with Face ID / Fingerprint',
                    ),
                    value: _useBiometrics,
                    onChanged: (value) {
                      setState(() => _useBiometrics = value);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
