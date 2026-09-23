import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/onboarding_progress.dart';
import 'package:smart_plate/features/auth/screens/review_confirm.dart';

class NutritionalGoalsScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const NutritionalGoalsScreen({super.key, required this.profileData});

  @override
  State<NutritionalGoalsScreen> createState() => _NutritionalGoalsScreenState();
}

class _NutritionalGoalsScreenState extends State<NutritionalGoalsScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color fieldFill = Color(0xFFF1F5F9);
  static const Color textGrey = Color(0xFF64748B);
  static const Color darkBlue = Color(0xFF334155);

  final calorieController = TextEditingController();
  final targetWeightController = TextEditingController();
  final proteinController = TextEditingController();
  final carbsController = TextEditingController();
  final fatController = TextEditingController();

  String? selectedWeightGoal;
  String? selectedActivityLevel;

  @override
  void dispose() {
    calorieController.dispose();
    targetWeightController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (calorieController.text.trim().isEmpty ||
        selectedWeightGoal == null ||
        selectedActivityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in calorie target, goal, and activity level.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewConfirmScreen(
          allData: {
            ...widget.profileData,
            'calorie_target': int.tryParse(calorieController.text.trim()),
            'weight_goal': selectedWeightGoal,
            'target_weight': double.tryParse(
              targetWeightController.text.trim(),
            ),
            'activity_level': selectedActivityLevel,
            'protein_goal_g': int.tryParse(proteinController.text.trim()),
            'carbs_goal_g': int.tryParse(carbsController.text.trim()),
            'fat_goal_g': int.tryParse(fatController.text.trim()),
          },
        ),
      ),
    );
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
        titleSpacing: 0,
        toolbarHeight: 84,
        title: const Padding(
          padding: EdgeInsets.only(right: 24),
          child: OnboardingProgress(step: 3, title: 'Nutritional Goals'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            _buildLabel('CALORIE TARGET'),
            _buildTextField(
              hint: 'e.g., 1800 kcal/day',
              controller: calorieController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),
            _buildLabel('WEIGHT GOAL'),
            _buildDropdownField(
              hint: 'Select your goal',
              value: selectedWeightGoal,
              items: [
                'Lose Weight',
                'Maintain Weight',
                'Gain Weight',
                'Build Muscle',
              ],
              onChanged: (val) => setState(() => selectedWeightGoal = val),
            ),

            const SizedBox(height: 20),
            _buildLabel('TARGET WEIGHT'),
            _buildTextField(
              hint: 'Enter target weight (kg)',
              controller: targetWeightController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),
            _buildLabel('ACTIVITY LEVEL'),
            _buildDropdownField(
              hint: 'Select your activity level',
              value: selectedActivityLevel,
              items: [
                'Sedentary',
                'Lightly Active',
                'Moderately Active',
                'Very Active',
              ],
              onChanged: (val) => setState(() => selectedActivityLevel = val),
            ),

            const SizedBox(height: 20),
            _buildLabel('PROTEIN GOAL'),
            _buildTextField(
              hint: 'e.g., 80 (grams)',
              controller: proteinController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),
            _buildLabel('CARBS GOAL'),
            _buildTextField(
              hint: 'e.g., 200 (grams)',
              controller: carbsController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),
            _buildLabel('FAT GOAL'),
            _buildTextField(
              hint: 'e.g., 60 (grams)',
              controller: fatController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textGrey,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
          ),
          items: items
              .map(
                (val) => DropdownMenuItem<String>(value: val, child: Text(val)),
              )
              .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
        ),
      ),
    );
  }
}
