import 'package:flutter/material.dart';

// Meal icons and colors matching the Home screen, shared by the other tabs.
(IconData, Color) mealStyle(String mealType) {
  switch (mealType.toLowerCase()) {
    case 'breakfast':
      return (Icons.wb_sunny_outlined, Colors.orange);
    case 'lunch':
      return (Icons.restaurant_rounded, const Color(0xFF67A75F));
    case 'dinner':
      return (Icons.nights_stay_outlined, const Color(0xFF1E293B));
    default:
      return (Icons.cookie_outlined, const Color(0xFF64748B));
  }
}

// Tinted rounded icon tile, the same shape Home uses for its meal rows.
class MealBadge extends StatelessWidget {
  final String mealType;
  final double size;

  const MealBadge({super.key, required this.mealType, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = mealStyle(mealType);
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

// Small flame pill showing the logging streak, echoing the Home streak card.
class StreakPill extends StatelessWidget {
  final int days;
  final bool onDark;

  const StreakPill({super.key, required this.days, this.onDark = false});

  static const Color streakColor = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: streakColor.withValues(alpha: onDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.whatshot_rounded, color: streakColor, size: 14),
          const SizedBox(width: 4),
          Text(
            "$days-day streak",
            style: const TextStyle(
              color: streakColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
