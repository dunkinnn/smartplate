import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'login.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color errorRed = Color(0xFFE53935);

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _passwordError;
  String? _confirmError;
  String? _authError;

  bool _isStrongPassword(String password) {
    return RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{6,}$',
    ).hasMatch(password);
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _authError = null;

      if (password.isEmpty) {
        _passwordError = 'Password is required.';
      } else if (!_isStrongPassword(password)) {
        _passwordError =
            'Must be 6+ chars with uppercase, lowercase, number & symbol.';
      } else {
        _passwordError = null;
      }

      if (confirm.isEmpty) {
        _confirmError = 'Please confirm your password.';
      } else if (confirm != password) {
        _confirmError = 'Passwords do not match.';
      } else {
        _confirmError = null;
      }
    });

    if (_passwordError != null || _confirmError != null) return;
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (mounted) {
        // Sign out automatically after password reset for security, forcing them to log in again
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated successfully! Please log in.'),
              backgroundColor: brandGreen,
            ),
          );

          // Pop all screens and go to Login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _authError = friendlyError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _authError = friendlyError(e));
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/logo.png',
                height: 100,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.restaurant_menu,
                  size: 80,
                  color: brandGreen,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "New Password",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: brandGreen,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Create a new, strong password that you don't use for other websites.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textGrey, height: 1.4),
              ),
              const SizedBox(height: 40),

              if (_authError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: errorRed.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: errorRed.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: errorRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _authError!,
                          style: const TextStyle(color: errorRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildTextField(
                hint: "New Password",
                controller: _passwordController,
                error: _passwordError,
                isPassword: true,
                obscure: _obscurePassword,
                onToggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onClearError: () => setState(() => _passwordError = null),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                hint: "Confirm Password",
                controller: _confirmController,
                error: _confirmError,
                isPassword: true,
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                onClearError: () => setState(() => _confirmError = null),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Update Password",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    String? error,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    VoidCallback? onClearError,
  }) {
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: isPassword ? obscure : false,
          onChanged: (_) {
            if (hasError && onClearError != null) onClearError();
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC1C7D0)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFFC1C7D0),
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? errorRed : const Color(0xFFD1D5DB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? errorRed : brandGreen,
                width: 2,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(
              error,
              style: const TextStyle(color: errorRed, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
