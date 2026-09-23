import 'package:flutter/material.dart';

// Step label, title and a segmented progress bar for the sign-up setup screens.
class OnboardingProgress extends StatelessWidget {
  final int step;
  final String title;
  final int totalSteps;

  const OnboardingProgress({
    super.key,
    required this.step,
    required this.title,
    this.totalSteps = 4,
  });

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'STEP $step OF $totalSteps',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: brandGreen,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= totalSteps; i++) ...[
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= step ? brandGreen : borderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < totalSteps) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}
