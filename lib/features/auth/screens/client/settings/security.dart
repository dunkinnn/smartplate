import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/widgets/settings_form.dart';

// Password change. Supabase handles hashing; nothing is stored by the app.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _isSaving = false;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    for (final c in [_newPassword, _confirmPassword]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // Same rules as the signup screen, so the two cannot drift apart.
  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p);
  bool _hasLower(String p) => RegExp(r'[a-z]').hasMatch(p);
  bool _hasDigit(String p) => RegExp(r'\d').hasMatch(p);
  bool _hasSpecial(String p) =>
      RegExp(r'''[!@#$%^&*()_+\-=\[\]{};'\\:"|<>?,./`~]''').hasMatch(p);

  bool _isStrong(String p) =>
      _hasMinLength(p) &&
      _hasUpper(p) &&
      _hasLower(p) &&
      _hasDigit(p) &&
      _hasSpecial(p);

  Future<void> _save() async {
    final password = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();

    if (!_isStrong(password)) {
      setState(() {
        _message = 'Password does not meet all the requirements below.';
        _messageIsError = true;
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _message = 'Passwords do not match.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() {
        _isSaving = false;
        _message = 'Password updated.';
        _messageIsError = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = e.message;
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Security",
      subtitle: "Change your password",
      isSaving: _isSaving,
      message: _message,
      messageIsError: _messageIsError,
      onDismissMessage: () => setState(() => _message = null),
      onSave: _save,
      children: [
        const SettingsLabel('NEW PASSWORD'),
        SettingsTextField(
          controller: _newPassword,
          hint: 'Enter a new password',
          obscure: true,
        ),
        _buildChecklist(),
        const SizedBox(height: 20),

        const SettingsLabel('CONFIRM NEW PASSWORD'),
        SettingsTextField(
          controller: _confirmPassword,
          hint: 'Re-enter the new password',
          obscure: true,
        ),
        if (_confirmPassword.text.isNotEmpty &&
            _confirmPassword.text != _newPassword.text)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Passwords do not match',
              style: TextStyle(color: Color(0xFFF25151), fontSize: 12),
            ),
          ),
      ],
    );
  }

  // Mirrors the signup checklist: every rule stays visible, ticking green as
  // it is met, and the whole list disappears once all are satisfied.
  Widget _buildChecklist() {
    final password = _newPassword.text;
    if (password.isEmpty) return const SizedBox.shrink();

    final requirements = <String, bool>{
      'At least 8 characters': _hasMinLength(password),
      'An uppercase letter': _hasUpper(password),
      'A lowercase letter': _hasLower(password),
      'A number': _hasDigit(password),
      'A special character': _hasSpecial(password),
    };

    if (requirements.values.every((met) => met)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: requirements.entries.map((entry) {
          final met = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Icon(
                  met ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: met
                      ? SettingsScaffold.brandGreen
                      : SettingsScaffold.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    color: met
                        ? SettingsScaffold.brandGreen
                        : SettingsScaffold.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
