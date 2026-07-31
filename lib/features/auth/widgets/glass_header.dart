import 'dart:ui';

import 'package:flutter/material.dart';

// Stacked title and description with the tight spacing used on the dashboard.
// Shared so every header sits identically.
class HeaderTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  // Gap between the two lines.
  final double titleGap;

  // Space under the description, which lifts the whole block within the bar.
  final double bottomSpacing;

  const HeaderTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleGap = 2,
    this.bottomSpacing = 6,
  });

  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: darkBlue,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          SizedBox(height: titleGap),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

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
