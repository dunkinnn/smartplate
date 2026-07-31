import 'dart:ui';

import 'package:flutter/material.dart';

// Frosted header that blurs whatever scrolls beneath it. Place it in a Stack
// above the scrollable, and pad the scrollable by [height] plus the status bar
// so the first item is not hidden.
class GlassHeader extends StatelessWidget {
  final Widget child;
  final double height;

  const GlassHeader({super.key, required this.child, this.height = 64});

  // Status bar plus header, the top padding a scrollable underneath needs.
  static double insetFor(BuildContext context, [double height = 64]) =>
      MediaQuery.of(context).padding.top + height;

  @override
  Widget build(BuildContext context) {
    // Pinned to the top edge so it spans the full width regardless of the
    // constraints the surrounding Stack hands out.
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: _buildBar(),
    );
  }

  Widget _buildBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            // Tinted white so dark text stays legible over busy content.
            color: Colors.white.withValues(alpha: 0.72),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(height: height, child: child),
          ),
        ),
      ),
    );
  }
}
