import 'package:flutter/material.dart';
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
  String? selectedTaste;
  String? selectedAllergen;
  String? selectedRestriction;

  void _goNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NutritionalGoalsScreen(
              profileData: {
                ...widget.profileData,
                'diet': selectedDiet,
                'taste': selectedTaste,
                'allergen': selectedAllergen,
                'food_restriction': selectedRestriction,
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
        title: const Text(
          'Step 2 of 4 – Preferences & Restrictions',
          style: TextStyle(
            color: darkBlue,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
              items: ['Vegan', 'Keto', 'Paleo', 'Vegetarian', 'None'],
              onChanged: (val) => setState(() => selectedDiet = val),
            ),

            const SizedBox(height: 20),
            _buildLabel('TASTE PREFERENCES'),
            _buildDropdownField(
              hint: 'Select your preferred taste(s)',
              value: selectedTaste,
              items: ['Sweet', 'Spicy', 'Salty', 'Bitter', 'Savory'],
              onChanged: (val) => setState(() => selectedTaste = val),
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
            _buildLabel('ALLERGENS'),
            _buildDropdownField(
              hint: 'Select allergens you have',
              value: selectedAllergen,
              items: ['None', 'Peanuts', 'Dairy', 'Gluten', 'Shellfish'],
              onChanged: (val) => setState(() => selectedAllergen = val),
            ),

            const SizedBox(height: 20),
            _buildLabel('FOOD RESTRICTIONS'),
            _buildDropdownField(
              hint: 'Select foods you avoid',
              value: selectedRestriction,
              items: [
                'None',
                'Pork',
                'Beef',
                'Alcohol',
                'Processed Sugar',
              ],
              onChanged: (val) => setState(() => selectedRestriction = val),
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
          items:
              items
                  .map(
                    (val) =>
                        DropdownMenuItem<String>(value: val, child: Text(val)),
                  )
                  .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
        ),
      ),
    );
  }
}
