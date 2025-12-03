import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

class SecuritySetupScreen extends ConsumerStatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  ConsumerState<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
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

    try {
      final securityManager = ref.read(securityManagerProvider);
      final password = _passwordController.text;

      // 1. Generate Salt
      final salt = securityManager.generateSecureKey(); // Using as salt

      // 2. Derive Key
      final key = securityManager.deriveKeyFromPassword(password, salt);

      // 3. Store Salt and Verifier
      await securityManager.storeSalt(salt);
      await securityManager.storeVerifier(key);

      // 4. Store Key if Biometrics enabled
      if (_useBiometrics) {
         // Optionally authenticate here to confirm user ownership before storing
         final authenticated = await securityManager.authenticateWithBiometrics();
         if (authenticated) {
           await securityManager.storeKey(key);
         } else {
           // If auth fails, maybe don't store key? Or warn?
           // For now, let's assume we require auth to enable this feature.
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Biometric authentication failed. Key not stored securely.')),
             );
             setState(() => _isLoading = false);
             return;
           }
         }
      } else {
        // Ensure no key is stored if biometrics disabled
        await securityManager.clearKey();
      }

      // 5. Complete Onboarding
      if (mounted) {
        ref.read(authProvider.notifier).setOnboarded(true);
        ref.read(authProvider.notifier).setAuthenticated(true);
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting up security: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect Your Data'),
      ),
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
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
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
                    subtitle: const Text('Unlock the app with Face ID / Fingerprint'),
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
                      : const Text('Save & Continue', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
