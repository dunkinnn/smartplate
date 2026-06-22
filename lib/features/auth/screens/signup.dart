import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'profile.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  late final SupabaseClient supabase;

  static const brandGreen = Color(0xFF67A75F);
  static const textGrey = Color(0xFF9E9E9E);
  static const errorRed = Color(0xFFE53935);

  bool isLoading = false;

  // Inline error messages
  String? _fullNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;
  }

  bool isStrongPassword(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{6,}$',
    );
    return regex.hasMatch(password);
  }

  bool _validate() {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    bool valid = true;

    setState(() {
      _fullNameError = fullName.isEmpty ? 'Full name is required.' : null;
      _emailError = email.isEmpty ? 'Email is required.' : null;

      if (password.isEmpty) {
        _passwordError = 'Password is required.';
      } else if (!isStrongPassword(password)) {
        _passwordError = 'Weak password! Example: Angelou@24';
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

    if (_fullNameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmError != null) {
      valid = false;
    }

    return valid;
  }

  Future<void> signUp() async {
    if (!_validate()) return;
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {'full_name': fullNameController.text.trim()},
      );

      final user = response.user;

      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _emailError = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emailError = 'Something went wrong. Please try again.');
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

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
                'Smart Plate',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: brandGreen,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Plan smart meals. Track healthy habits.\nEat smarter, live healthier.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: brandGreen, height: 1.4),
              ),

              const SizedBox(height: 40),

              _buildTextField(
                hint: 'Full Name',
                controller: fullNameController,
                error: _fullNameError,
                onClearError: () => setState(() => _fullNameError = null),
              ),

              const SizedBox(height: 15),

              _buildTextField(
                hint: 'Email',
                controller: emailController,
                error: _emailError,
                onClearError: () => setState(() => _emailError = null),
              ),

              const SizedBox(height: 15),

              _buildTextField(
                hint: 'Password',
                controller: passwordController,
                isPassword: true,
                error: _passwordError,
                onClearError: () => setState(() => _passwordError = null),
              ),

              const SizedBox(height: 15),

              _buildTextField(
                hint: 'Confirm Password',
                controller: confirmController,
                isPassword: true,
                error: _confirmError,
                onClearError: () => setState(() => _confirmError = null),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signUp,
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
                          'Sign Up',
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
                    'Already have an account? ',
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
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Log In',
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

  // Original _buildTextField — UI unchanged, just added error param
  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    String? error,
    VoidCallback? onClearError,
  }) {
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: isPassword,
          onChanged: (_) {
            // Clear this field's error as soon as user starts typing
            if (hasError && onClearError != null) onClearError();
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC1C7D0)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
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

        // Inline error shown directly below the field
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
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }
}
