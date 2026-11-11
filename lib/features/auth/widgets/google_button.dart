import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/services/google_auth.dart';
import 'package:smart_plate/features/auth/screens/profile.dart';
import 'package:smart_plate/features/auth/screens/client/dashboard.dart';

// "Continue with Google" for Login and Signup; new accounts go to profile setup.
class GoogleButton extends StatefulWidget {
  final ValueChanged<String> onError;

  const GoogleButton({super.key, required this.onError});

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final needsProfile = await signInWithGoogle();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              needsProfile ? const ProfileScreen() : const DashboardScreen(),
        ),
        (route) => false,
      );
      return;
    // Error: the user closed the Google account picker (Google Sign-In).
    } on GoogleSignInException catch (e) {
      debugPrint('[Google Sign-In] Google sign-in stopped: $e');
      if (e.code != GoogleSignInExceptionCode.canceled) {
        widget.onError(
          kDebugMode ? 'Google: $e' : 'Google sign-in failed. Please try again.',
        );
      }
    // Error: Supabase rejected the Google token or the network failed (Google Sign-In).
    } catch (e) {
      debugPrint('[Google Sign-In] Failed to sign in: $e');
      // Debug builds show the raw error so setup problems are easy to spot.
      widget.onError(kDebugMode ? 'Google: $e' : friendlyError(e));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(color: Color(0xFF9E9E9E)),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            ],
          ),
        ),
        _buildButton(),
      ],
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF67A75F),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image(
                    image: AssetImage('assets/images/google-logo.png'),
                    height: 20,
                    width: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
