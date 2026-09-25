import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/onboarding_progress.dart';
import 'package:smart_plate/features/auth/widgets/preference_chips.dart';
import 'package:smart_plate/features/auth/screens/nutritional_goals.dart';

class PreferencesScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const PreferencesScreen({super.key, required this.profileData});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color fieldFill = Color(0xFFF1F5F9);
  static const Color textGrey = Color(0xFF64748B);
  static const Color darkBlue = Color(0xFF334155);

  String? selectedDiet;
  Set<String> tastes = {};
  Set<String> allergens = {};
  Set<String> restrictions = {};
  Set<String> nutritionFocus = {};

  void _goNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NutritionalGoalsScreen(
          profileData: {
            ...widget.profileData,
            'diet': selectedDiet,
            'taste': PreferenceOptions.join(tastes),
            'allergen': PreferenceOptions.join(allergens),
            'food_restriction': PreferenceOptions.join(restrictions),
            'nutrition_focus': PreferenceOptions.join(nutritionFocus),
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
          child: OnboardingProgress(
            step: 2,
            title: 'Preferences & Restrictions',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Section 1: Dietary Preferences
            const Text(
              'DIETARY PREFERENCES',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('DIET'),
            _buildDropdownField(
              hint: 'Select your diet type',
              value: selectedDiet,
              items: PreferenceOptions.diets,
              onChanged: (val) => setState(() => selectedDiet = val),
            ),

            const SizedBox(height: 20),
            _buildLabel('TASTE PREFERENCES (PICK ANY)'),
            PreferenceChips(
              options: PreferenceOptions.tastes,
              allowCustom: true,
              customHint: 'e.g. Garlicky, Tangy',
              selected: tastes,
              onChanged: (v) => setState(() => tastes = v),
            ),

            const SizedBox(height: 20),
            _buildLabel('NUTRITION FOCUS (PICK ANY)'),
            PreferenceChips(
              options: PreferenceOptions.nutritionFocus,
              selected: nutritionFocus,
              onChanged: (v) => setState(() => nutritionFocus = v),
            ),

            const SizedBox(height: 35),

            // Section 2: Allergies & Restrictions
            const Text(
              'ALLERGIES & RESTRICTIONS',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('ALLERGENS (PICK ALL THAT APPLY)'),
            PreferenceChips(
              options: PreferenceOptions.allergens,
              allowCustom: true,
              customHint: 'e.g. Kiwi, Tomato',
              selected: allergens,
              onChanged: (v) => setState(() => allergens = v),
            ),

            const SizedBox(height: 20),
            _buildLabel('FOODS YOU AVOID (PICK ALL THAT APPLY)'),
            PreferenceChips(
              options: PreferenceOptions.restrictions,
              allowCustom: true,
              customHint: 'e.g. Bitter Gourd, Liver',
              selected: restrictions,
              onChanged: (v) => setState(() => restrictions = v),
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
