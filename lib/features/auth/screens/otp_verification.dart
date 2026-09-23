import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'update_password.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color errorRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFFA726);

  bool isLoading = false;
  String? _otpError;
  String? _authMessage;
  int _resendCountdown = 0;

  // Rate limiting
  int _verifyAttempts = 0;
  final int _maxVerifyAttempts = 5;
  bool _isLocked = false;
  int _lockoutCountdown = 0;

  Future<void> _verifyOtp() async {
    // Check if locked out
    if (_isLocked) {
      setState(() {
        _authMessage =
            'Too many attempts. Please try again in ${_lockoutCountdown}s';
      });
      return;
    }

    final code = _otpController.text.trim();

    setState(() {
      _authMessage = null;
      if (code.isEmpty) {
        _otpError = 'Verification code is required.';
      } else if (code.length < 6) {
        _otpError = 'Code must be 6 digits.';
      } else {
        _otpError = null;
      }
    });

    if (_otpError != null) return;
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      // Verify OTP for password recovery
      final AuthResponse response = await Supabase.instance.client.auth
          .verifyOTP(email: widget.email, token: code, type: OtpType.recovery);

      if (response.user != null) {
        if (mounted) {
          // OTP verified successfully, proceed to password update
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const UpdatePasswordScreen(),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        // Increment attempt counter
        setState(() {
          _verifyAttempts++;

          // Check if max attempts reached
          if (_verifyAttempts >= _maxVerifyAttempts) {
            _isLocked = true;
            _lockoutCountdown = 900; // 15 minutes
            _authMessage =
                'Too many failed attempts. Please try again in 15 minutes.';

            // Start lockout countdown
            _startLockoutTimer();
          } else {
            final remainingAttempts = _maxVerifyAttempts - _verifyAttempts;

            if (e.message.toLowerCase().contains('invalid')) {
              _authMessage =
                  'Invalid or expired code. ($remainingAttempts attempts left)';
            } else if (e.message.toLowerCase().contains('expired')) {
              _authMessage =
                  'Code has expired. Request a new OTP. ($remainingAttempts attempts left)';
            } else if (e.message.toLowerCase().contains('too many')) {
              _authMessage = 'Too many attempts. Please try again later.';
              _isLocked = true;
              _lockoutCountdown = 300; // 5 minutes from Supabase
              _startLockoutTimer();
            } else {
              _authMessage =
                  '${friendlyError(e)} ($remainingAttempts attempts left)';
            }
          }
        });
      }
      debugPrint('AuthException in OTP verify: ${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _authMessage = 'Network error. Please try again.');
      }
      debugPrint('Error verifying OTP: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _startLockoutTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isLocked) {
        setState(() {
          _lockoutCountdown--;
          if (_lockoutCountdown <= 0) {
            _isLocked = false;
            _verifyAttempts = 0;
            _authMessage = 'You can try again now.';
          }
        });
        return _lockoutCountdown > 0;
      }
      return false;
    });
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: widget.email,
        shouldCreateUser: false,
      );

      if (mounted) {
        setState(() {
          _authMessage = 'New OTP sent to your email!';
          _resendCountdown = 60;
          _otpController.clear();
        });

        // Countdown timer
        for (int i = 60; i > 0; i--) {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            setState(() => _resendCountdown = i - 1);
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _authMessage = friendlyError(e);
        });
      }
      debugPrint('Error resending OTP: ${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _authMessage = 'Network error. Please try again.');
      }
      debugPrint('Error resending OTP: $e');
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
                "Verify Code",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: brandGreen,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "We sent a 6-digit code to\n${widget.email}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: textGrey,
                  height: 1.4,
                ),
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
                    color: _isLocked
                        ? errorRed.withAlpha(20)
                        : _authMessage!.contains('sent') ||
                              _authMessage!.contains('try again now')
                        ? const Color(0xFF4CAF50).withAlpha(20)
                        : _authMessage!.contains('attempts left')
                        ? warningOrange.withAlpha(20)
                        : errorRed.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isLocked
                          ? errorRed.withAlpha(80)
                          : _authMessage!.contains('sent') ||
                                _authMessage!.contains('try again now')
                          ? const Color(0xFF4CAF50).withAlpha(80)
                          : _authMessage!.contains('attempts left')
                          ? warningOrange.withAlpha(80)
                          : errorRed.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isLocked
                            ? Icons.lock_outline
                            : _authMessage!.contains('sent') ||
                                  _authMessage!.contains('try again now')
                            ? Icons.check_circle_outline
                            : _authMessage!.contains('attempts left')
                            ? Icons.warning_outlined
                            : Icons.error_outline,
                        color: _isLocked
                            ? errorRed
                            : _authMessage!.contains('sent') ||
                                  _authMessage!.contains('try again now')
                            ? const Color(0xFF4CAF50)
                            : _authMessage!.contains('attempts left')
                            ? warningOrange
                            : errorRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _authMessage!,
                          style: TextStyle(
                            color: _isLocked
                                ? errorRed
                                : _authMessage!.contains('sent') ||
                                      _authMessage!.contains('try again now')
                                ? const Color(0xFF4CAF50)
                                : _authMessage!.contains('attempts left')
                                ? warningOrange
                                : errorRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Attempt Counter ──────────────────────────────────────────
              if (!_isLocked && _verifyAttempts > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _verifyAttempts / _maxVerifyAttempts,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _verifyAttempts >= 3 ? warningOrange : brandGreen,
                      ),
                    ),
                  ),
                ),

              _buildTextField(
                hint: "6-Digit Code",
                controller: _otpController,
                error: _otpError,
                onClearError: () => setState(() => _otpError = null),
                enabled: !_isLocked,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLocked || isLoading) ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLocked ? Colors.grey : brandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLocked
                              ? 'Locked - Try again later'
                              : "Verify Code",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Resend OTP Button ────────────────────────────────────────
              TextButton(
                onPressed: (_isLocked || _resendCountdown > 0)
                    ? null
                    : _resendOtp,
                child: Text(
                  _isLocked
                      ? 'Locked - Cannot resend'
                      : _resendCountdown > 0
                      ? 'Resend code in ${_resendCountdown}s'
                      : "Didn't receive code? Resend",
                  style: TextStyle(
                    color: (_isLocked || _resendCountdown > 0)
                        ? textGrey
                        : brandGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          onChanged: (_) {
            if (hasError && onClearError != null) onClearError();
          },
          decoration: InputDecoration(
            counterText: "",
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFC1C7D0),
              fontSize: 16,
              letterSpacing: 0,
              fontWeight: FontWeight.normal,
            ),
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
    _otpController.dispose();
    super.dispose();
  }
}
