import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/services/security/password_policy.dart';

/// Shows how strong [password] is, using [PasswordPolicy] (local only).
class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final strength = PasswordPolicy.evaluate(password);
    final (value, color, label) = switch (strength) {
      PasswordStrength.tooShort => (
        0.1,
        Colors.red,
        l10n.passwordStrengthTooShort,
      ),
      PasswordStrength.common => (0.1, Colors.red, l10n.passwordStrengthCommon),
      PasswordStrength.weak => (0.3, Colors.orange, l10n.passwordStrengthWeak),
      PasswordStrength.fair => (0.55, Colors.amber, l10n.passwordStrengthFair),
      PasswordStrength.good => (
        0.8,
        Colors.lightGreen,
        l10n.passwordStrengthGood,
      ),
      PasswordStrength.strong => (
        1.0,
        Colors.green,
        l10n.passwordStrengthStrong,
      ),
    };
    return Semantics(
      label: l10n.passwordStrengthTitle(label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: password.isEmpty ? 0 : value,
              minHeight: 6,
              color: color,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text(
              password.isEmpty
                  ? l10n.passwordMinLength(PasswordPolicy.minLength)
                  : l10n.passwordStrengthTitle(label),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Validator for a new master or backup password.
String? validateNewPassword(AppLocalizations l10n, String? value) {
  final password = value ?? '';
  switch (PasswordPolicy.evaluate(password)) {
    case PasswordStrength.tooShort:
      return l10n.passwordMinLength(PasswordPolicy.minLength);
    case PasswordStrength.common:
      return l10n.passwordTooCommon;
    default:
      return null;
  }
}

/// "New password" + "confirm" fields with a strength meter.
class NewPasswordFields extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController confirmController;
  final String label;
  final TextInputAction confirmAction;
  final VoidCallback? onSubmitted;

  const NewPasswordFields({
    super.key,
    required this.controller,
    required this.confirmController,
    required this.label,
    this.confirmAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: !_visible,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: l10n.passwordHint,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _visible ? l10n.hidePassword : l10n.showPassword,
              icon: Icon(_visible ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
          validator: (value) => validateNewPassword(l10n, value),
        ),
        const SizedBox(height: 8),
        PasswordStrengthMeter(password: widget.controller.text),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.confirmController,
          obscureText: !_visible,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: widget.confirmAction,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(
            labelText: l10n.confirmPasswordLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              value != widget.controller.text ? l10n.passwordsDoNotMatch : null,
        ),
      ],
    );
  }
}
