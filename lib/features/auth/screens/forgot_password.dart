import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color errorRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFFA726);
  static const Color successGreen = Color(0xFF4CAF50);

  bool isLoading = false;
  String? _emailError;
  String? _authMessage;

  // Rate limiting for email entries (brute force protection)
  int _emailAttempts = 0;
  final int _maxEmailAttempts = 5;
  bool _isEmailLocked = false;
  int _emailLockoutCountdown = 0;

  // Rate limiting for resend OTP (email spam protection)
  int _resendAttempts = 0;
  final int _maxResendAttempts = 3;
  int _resendCountdown = 0;

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleSendOtp() async {
    // Check if email entry is locked
    if (_isEmailLocked) {
      setState(() {
        _authMessage =
            'Too many attempts. Please try again in ${_emailLockoutCountdown}s';
      });
      return;
    }

    // Check if resend limit reached
    if (_resendAttempts >= _maxResendAttempts && _resendCountdown > 0) {
      setState(() {
        _authMessage =
            'Too many OTP requests. Please wait ${_resendCountdown}s before trying again.';
      });
      return;
    }

    final email = _emailController.text.trim();

    setState(() {
      _authMessage = null;
      if (email.isEmpty) {
        _emailError = 'Email is required.';
      } else if (!_isValidEmail(email)) {
        _emailError = 'Please enter a valid email address.';
      } else {
        _emailError = null;
      }
    });

    if (_emailError != null) {
      // Increment email attempts on validation error
      setState(() {
        _emailAttempts++;
        _checkEmailLockout();
      });
      return;
    }

    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      // IMPORTANT: Use signInWithOtp() for OTP-based password reset
      // This will use the "Magic link or OTP" email template
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Don't create user if they don't exist
      );

      if (mounted) {
        // Increment resend counter on successful send
        setState(() {
          _resendAttempts++;
          _authMessage = 'OTP sent! Check your email for the 6-digit code.';

          // Start resend cooldown if this was the last attempt
          if (_resendAttempts >= _maxResendAttempts) {
            _resendCountdown = 900; // 15 minutes
            _startResendCooldown();
          }
        });

        // Navigate to OTP verification after 1.5 seconds
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(email: email),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        // Increment email attempts on auth error
        setState(() {
          _emailAttempts++;
          _checkEmailLockout();

          if (e.message.toLowerCase().contains('user')) {
            _authMessage = 'No account found with this email address.';
          } else if (e.message.toLowerCase().contains('email')) {
            _authMessage = 'Email service error. Please try again later.';
          } else if (e.message.toLowerCase().contains('rate')) {
            _authMessage =
                'Too many requests. Please wait before trying again.';
            _resendAttempts = _maxResendAttempts;
            _resendCountdown = 300; // 5 minutes
            _startResendCooldown();
          } else {
            _authMessage = 'Error: ${e.message}';
          }
        });
      }
      debugPrint('AuthException: ${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _authMessage = 'Network error. Check your connection and try again.';
        });
      }
      debugPrint('Error sending OTP: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _checkEmailLockout() {
    if (_emailAttempts >= _maxEmailAttempts) {
      _isEmailLocked = true;
      _emailLockoutCountdown = 3600; // 1 hour
      _startEmailLockoutTimer();
    }
  }

  void _startEmailLockoutTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isEmailLocked) {
        setState(() {
          _emailLockoutCountdown--;
          if (_emailLockoutCountdown <= 0) {
            _isEmailLocked = false;
            _emailAttempts = 0;
            _authMessage = 'You can try again now.';
          }
        });
        return _emailLockoutCountdown > 0;
      }
      return false;
    });
  }

  void _startResendCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendCountdown--;
          if (_resendCountdown <= 0) {
            _resendAttempts = 0;
            _authMessage = null;
          }
        });
        return _resendCountdown > 0;
      }
      return false;
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes min ${secs}s';
    }
    return '${secs}s';
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              const Text(
                "Forgot Password",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: brandGreen,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Enter your email address and we'll send you a 6-digit code.",
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 13, color: textGrey, height: 1.4),
              ),

              const SizedBox(height: 40),

              // ─── Auth Message Banner ──────────────────────────────────────
              if (_authMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isEmailLocked
                        ? errorRed.withAlpha(20)
                        : _authMessage!.contains('sent') ||
                              _authMessage!.contains('try again now')
                        ? successGreen.withAlpha(20)
                        : _authMessage!.contains('attempts left') ||
                              _authMessage!.contains('Too many')
                        ? warningOrange.withAlpha(20)
                        : errorRed.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isEmailLocked
                          ? errorRed.withAlpha(80)
                          : _authMessage!.contains('sent') ||
                                _authMessage!.contains('try again now')
                          ? successGreen.withAlpha(80)
                          : _authMessage!.contains('attempts left') ||
                                _authMessage!.contains('Too many')
                          ? warningOrange.withAlpha(80)
                          : errorRed.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isEmailLocked
                            ? Icons.lock_outline
                            : _authMessage!.contains('sent') ||
                                  _authMessage!.contains('try again now')
                            ? Icons.check_circle_outline
                            : _authMessage!.contains('attempts left') ||
                                  _authMessage!.contains('Too many')
                            ? Icons.warning_outlined
                            : Icons.error_outline,
                        color: _isEmailLocked
                            ? errorRed
                            : _authMessage!.contains('sent') ||
                                  _authMessage!.contains('try again now')
                            ? successGreen
                            : _authMessage!.contains('attempts left') ||
                                  _authMessage!.contains('Too many')
                            ? warningOrange
                            : errorRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _authMessage!,
                          style: TextStyle(
                            color: _isEmailLocked
                                ? errorRed
                                : _authMessage!.contains('sent') ||
                                      _authMessage!.contains('try again now')
                                ? successGreen
                                : _authMessage!.contains('attempts left') ||
                                      _authMessage!.contains('Too many')
                                ? warningOrange
                                : errorRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Email Attempt Counter ────────────────────────────────────
              if (!_isEmailLocked && _emailAttempts > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _emailAttempts / _maxEmailAttempts,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _emailAttempts >= 3 ? warningOrange : brandGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Attempts: $_emailAttempts/$_maxEmailAttempts',
                        style: TextStyle(
                          fontSize: 11,
                          color: _emailAttempts >= 3 ? warningOrange : textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Resend OTP Attempt Counter ───────────────────────────────
              if (_resendAttempts > 0 && _resendAttempts < _maxResendAttempts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline, size: 14, color: textGrey),
                      const SizedBox(width: 6),
                      Text(
                        'OTP sends: $_resendAttempts/$_maxResendAttempts',
                        style: const TextStyle(
                          fontSize: 11,
                          color: textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              _buildTextField(
                hint: "Email",
                controller: _emailController,
                error: _emailError,
                onClearError: () => setState(() => _emailError = null),
                enabled: !_isEmailLocked,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      (_isEmailLocked || _resendCountdown > 0 || isLoading)
                      ? null
                      : _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isEmailLocked || _resendCountdown > 0)
                        ? Colors.grey
                        : brandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEmailLocked
                              ? 'Locked - Try in ${_formatTime(_emailLockoutCountdown)}'
                              : _resendCountdown > 0
                              ? 'Wait ${_formatTime(_resendCountdown)}'
                              : "Send OTP",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Info Text ────────────────────────────────────────────────
              if (_resendCountdown > 0 || _emailLockoutCountdown > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: textGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _emailLockoutCountdown > 0
                              ? 'Too many attempts. Please wait before trying again.'
                              : 'You\'ve sent the maximum OTP requests. Please wait before resending.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: textGrey,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
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
    VoidCallback? onClearError,
    bool enabled = true,
  }) {
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: (_) {
            if (hasError && onClearError != null) onClearError();
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC1C7D0)),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
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
    _emailController.dispose();
    super.dispose();
  }
}
