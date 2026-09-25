import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'login.dart';
import 'profile.dart';
import 'legal.dart';

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
  bool agreedToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Inline error messages
  String? _fullNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;

    // Re-check form validity on every keystroke so the Sign Up button
    // enables/disables in real time.
    for (final controller in [
      fullNameController,
      emailController,
      passwordController,
      confirmController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  // Live email error shown while typing: anything non-empty that isn't a
  // complete "name@gmail.com" address is flagged right away.
  String? get _liveEmailError {
    final email = emailController.text.trim();
    if (email.isEmpty) return null;

    const suffix = '@gmail.com';
    final lower = email.toLowerCase();
    return lower.endsWith(suffix) && lower.length > suffix.length
        ? null
        : 'Email must be a @gmail.com address.';
  }

  // Individual password checks, reused by isStrongPassword and the live
  // requirements checklist so both stay in sync.
  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p);
  bool _hasLower(String p) => RegExp(r'[a-z]').hasMatch(p);
  bool _hasDigit(String p) => RegExp(r'\d').hasMatch(p);
  // Matches Supabase's allowed symbol set so the app never rejects a password
  // the backend would accept.
  bool _hasSpecial(String p) =>
      RegExp(r'''[!@#$%^&*()_+\-=\[\]{};'\\:"|<>?,./`~]''').hasMatch(p);

  bool isStrongPassword(String password) {
    return _hasMinLength(password) &&
        _hasUpper(password) &&
        _hasLower(password) &&
        _hasDigit(password) &&
        _hasSpecial(password);
  }

  bool _validate() {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    bool valid = true;

    setState(() {
      _fullNameError = fullName.isEmpty ? 'Full name is required.' : null;

      if (email.isEmpty) {
        _emailError = 'Email is required.';
      } else if (!email.toLowerCase().endsWith('@gmail.com')) {
        _emailError = 'Email must be a @gmail.com address.';
      } else {
        _emailError = null;
      }

      if (password.isEmpty) {
        _passwordError = 'Password is required.';
      } else if (!isStrongPassword(password)) {
        _passwordError =
            'Password must contain at least 8 characters, including an uppercase letter, a lowercase letter, a number, and a special character.';
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

      _termsError = agreedToTerms
          ? null
          : 'You must agree to the Terms and Privacy Policy.';
    });

    if (_fullNameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmError != null ||
        _termsError != null) {
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
        setState(() => _emailError = friendlyError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emailError = friendlyError(e));
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  // Opens the Terms or Privacy Policy; tapping Accept ticks the agreement box.
  Future<void> _openLegal(String title, String text, IconData icon) async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LegalScreen(title: title, text: text, icon: icon),
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        agreedToTerms = true;
        _termsError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Container(
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
                  style: TextStyle(
                    fontSize: 12,
                    color: brandGreen,
                    height: 1.4,
                  ),
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
                  error: _emailError ?? _liveEmailError,
                  onClearError: () => setState(() => _emailError = null),
                ),

                const SizedBox(height: 15),

                _buildTextField(
                  hint: 'Password',
                  controller: passwordController,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  error: passwordController.text.isEmpty
                      ? _passwordError
                      : null,
                  onClearError: () => setState(() => _passwordError = null),
                ),
                _buildPasswordChecklist(),

                const SizedBox(height: 15),

                _buildTextField(
                  hint: 'Confirm Password',
                  controller: confirmController,
                  isPassword: true,
                  obscureText: _obscureConfirm,
                  onToggleObscure: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  error: confirmController.text.isEmpty ? _confirmError : null,
                  onClearError: () => setState(() => _confirmError = null),
                ),
                _buildConfirmHint(),

                const SizedBox(height: 20),

                _buildTermsCheckbox(),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGreen,
                      disabledBackgroundColor: brandGreen.withValues(
                        alpha: 0.4,
                      ),
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

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Live checklist of unmet password requirements. Each line disappears as
  // soon as it's satisfied, and the whole checklist hides once all are met.
  Widget _buildPasswordChecklist() {
    final password = passwordController.text;
    if (password.isEmpty) return const SizedBox.shrink();

    final requirements = <String, bool>{
      'At least 8 characters': _hasMinLength(password),
      'An uppercase letter': _hasUpper(password),
      'A lowercase letter': _hasLower(password),
      'A number': _hasDigit(password),
      'A special character': _hasSpecial(password),
    };

    final allMet = requirements.values.every((met) => met);
    if (allMet) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: requirements.entries.map((entry) {
          final met = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(
                  met ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: met ? brandGreen : textGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    color: met ? brandGreen : textGrey,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Hint below confirm password; only shown while it doesn't match yet,
  // disappears once the passwords match.
  Widget _buildConfirmHint() {
    final password = passwordController.text;
    final confirm = confirmController.text;
    if (confirm.isEmpty || confirm == password) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 4),
      child: Text(
        'Passwords do not match',
        style: TextStyle(color: errorRed, fontSize: 12),
      ),
    );
  }

  // Checkbox row with tappable Terms/Privacy links that open the legal screens.
  Widget _buildTermsCheckbox() {
    final hasError = _termsError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: agreedToTerms,
                activeColor: brandGreen,
                onChanged: (value) {
                  setState(() {
                    agreedToTerms = value ?? false;
                    if (agreedToTerms) _termsError = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'I agree to the ',
                    style: TextStyle(color: textGrey),
                  ),
                  GestureDetector(
                    onTap: () => _openLegal(
                      'Terms of Service',
                      termsOfServiceText,
                      Icons.gavel_rounded,
                    ),
                    child: const Text(
                      'Terms of Service',
                      style: TextStyle(
                        color: brandGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(' and ', style: TextStyle(color: textGrey)),
                  GestureDetector(
                    onTap: () => _openLegal(
                      'Privacy Policy',
                      privacyPolicyText,
                      Icons.shield_outlined,
                    ),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: brandGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 34),
            child: Text(
              _termsError!,
              style: const TextStyle(color: errorRed, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // Original _buildTextField — UI unchanged, just added error param
  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? error,
    VoidCallback? onClearError,
  }) {
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: isPassword && obscureText,
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
            suffixIcon: isPassword && controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: textGrey,
                    ),
                    onPressed: onToggleObscure,
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
