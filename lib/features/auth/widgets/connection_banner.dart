import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Wraps the whole app and shows a banner at the top while the phone is offline,
// so a screen that cannot load explains why instead of looking broken.
class ConnectionBanner extends StatefulWidget {
  final Widget child;

  const ConnectionBanner({super.key, required this.child});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner>
    with WidgetsBindingObserver {
  static const Color bannerRed = Color(0xFFDC2626);

  // The app's backend; if its name cannot be resolved, nothing will load.
  static const _host = 'supabase.co';

  bool _offline = false;
  bool _checking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Re-check right away when the user comes back to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (kIsWeb || _checking) return;
    _checking = true;

    var online = false;
    try {
      final result = await InternetAddress.lookup(
        _host,
      ).timeout(const Duration(seconds: 5));
      online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    _checking = false;
    if (!mounted) return;
    if (_offline == online) setState(() => _offline = !online);

    // Check often while offline so the banner clears soon after reconnecting.
    _timer?.cancel();
    _timer = Timer(Duration(seconds: _offline ? 4 : 15), _check);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            offset: _offline ? Offset.zero : const Offset(0, -1.5),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Material(
                  color: bannerRed,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No internet connection. Check your Wi-Fi or mobile data.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _check,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
