import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/models/nutrients.dart';

// One nutrient against its daily guide: a bar that turns red when a limit is passed.
class NutrientGuideRow extends StatelessWidget {
  final Nutrient nutrient;
  final double value;

  const NutrientGuideRow({
    super.key,
    required this.nutrient,
    required this.value,
  });

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color overRed = Color(0xFFF25151);
  static const Color track = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final guide = nutrient.dailyGuide;
    final over = nutrient.isLimit && value > guide;
    final color = over
        ? overRed
        : nutrient.isLimit
        ? darkBlue
        : brandGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                nutrient.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: darkBlue,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                nutrient.isLimit ? 'limit' : 'target',
                style: const TextStyle(fontSize: 11, color: textSecondary),
              ),
              const Spacer(),
              Text(
                '${value.round()} / ${guide.round()} ${nutrient.unit}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: over ? overRed : textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: guide > 0 ? (value / guide).clamp(0.0, 1.0) : 0,
              minHeight: 6,
              color: color,
              backgroundColor: track,
            ),
          ),
        ],
      ),
    );
  }
}
