import 'package:flutter/material.dart';

// Animated intro shown on launch: logo pops in, name and tagline rise, then fades
// into the next screen.
class SplashScreen extends StatefulWidget {
  final Widget next;

  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // Each element starts a little later than the one above it.
  late final Animation<double> _logo = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
  );
  late final Animation<double> _title = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(_goNext);
  }

  Future<void> _goNext() async {
    // Short pause so the finished logo registers before moving on.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Fades in while moving up by [offset] pixels.
  Widget _rise(Animation<double> a, Widget child, {double offset = 16}) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, offset * (1 - a.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _logo,
                builder: (context, child) => Opacity(
                  opacity: _logo.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * _logo.value,
                    child: child,
                  ),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.restaurant_menu,
                    size: 100,
                    color: brandGreen,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _rise(
                _title,
                const Text(
                  "Smart Plate",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _rise(
                _tagline,
                const Text(
                  "Eat smarter, live healthier.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
