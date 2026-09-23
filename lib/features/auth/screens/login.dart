import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'signup.dart';
import 'forgot_password.dart';
import 'package:smart_plate/features/auth/screens/client/dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _savePassword = true;
  bool _obscurePassword = true;

  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color errorRed = Color(0xFFE53935);

  bool isLoading = false;

  // Inline error messages
  String? _emailError;
  String? _passwordError;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final savePref = prefs.getBool('save_password') ?? false;

    if (mounted) {
      setState(() {
        _savePassword = savePref;
        if (savedEmail != null) _userController.text = savedEmail;
        if (savedPassword != null) _passController.text = savedPassword;
      });
    }
  }

  bool _validate() {
    final email = _userController.text.trim();
    final password = _passController.text.trim();

    bool valid = true;

    setState(() {
      _emailError = email.isEmpty ? 'Email is required.' : null;
      _passwordError = password.isEmpty ? 'Password is required.' : null;
    });

    if (_emailError != null || _passwordError != null) {
      valid = false;
    }

    return valid;
  }

  Future<void> _handleLogin() async {
    setState(() => _authError = null);

    if (!_validate()) return;

    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _userController.text.trim(),
        password: _passController.text.trim(),
      );

      final user = response.user;

      if (user != null) {
        // Handle saving/clearing credentials
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('save_password', _savePassword);

        if (_savePassword) {
          await prefs.setString('saved_email', _userController.text.trim());
          await prefs.setString('saved_password', _passController.text.trim());
        } else {
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        if (mounted) {
          setState(() => _authError = 'Login failed');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _authError = friendlyError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _authError = friendlyError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        // Min height centres the form; unlike a fixed height it never overflows.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 120,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.restaurant_menu,
                  size: 100,
                  color: brandGreen,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Smart Plate",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: brandGreen,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Plan smart meals. Track healthy habits.\nEat smarter, live healthier.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: brandGreen, height: 1.4),
              ),

              const SizedBox(height: 40),

              // ─── Auth-level error banner ──────────────────────────────────
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
                hint: "Email",
                controller: _userController,
                error: _emailError,
                onClearError: () => setState(() => _emailError = null),
              ),

              const SizedBox(height: 15),

              _buildTextField(
                hint: "Password",
                isPassword: true,
                controller: _passController,
                error: _passwordError,
                onClearError: () => setState(() => _passwordError = null),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _savePassword,
                          activeColor: brandGreen,
                          onChanged: (value) {
                            setState(() {
                              _savePassword = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Save Password",
                        style: TextStyle(
                          color: brandGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password",
                      style: TextStyle(
                        color: brandGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleLogin,
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
                          "Login",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: textGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: brandGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    bool isPassword = false,
    required TextEditingController controller,
    String? error,
    VoidCallback? onClearError,
  }) {
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          onChanged: (_) {
            if (hasError && onClearError != null) onClearError();
            // Rebuild so the eye icon appears once the user starts typing.
            if (isPassword) setState(() {});
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC1C7D0)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
            suffixIcon: isPassword && controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: textGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
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
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }
}
