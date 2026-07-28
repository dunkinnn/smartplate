import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color fieldFill = Color(0xFFF1F5F9);
  static const Color textGrey = Color(0xFF64748B);

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();

  String? selectedGender;
  String? selectedHeight;
  String? selectedWeight;

  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> heightOptions = List.generate(
    81,
    (i) => '${140 + i}',
  ); // 140cm to 220cm
  final List<String> weightOptions = List.generate(
    121,
    (i) => '${30 + i}',
  ); // 30kg to 150kg

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (fullNameController.text.trim().isEmpty ||
        ageController.text.trim().isEmpty ||
        selectedGender == null ||
        selectedHeight == null ||
        selectedWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields before continuing.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreferencesScreen(
          profileData: {
            'full_name': fullNameController.text.trim(),
            'phone': phoneController.text.trim(),
            'age': int.tryParse(ageController.text.trim()),
            'gender': selectedGender,
            'height_cm': double.tryParse(selectedHeight!),
            'weight_kg': double.tryParse(selectedWeight!),
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
          'Step 1 of 4 - Personal Information',
          style: TextStyle(
            color: Color(0xFF334155),
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
            const SizedBox(height: 10),
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 65,
                    backgroundImage: NetworkImage(
                      'https://via.placeholder.com/150',
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: brandGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildLabel('FULL NAME'),
            _buildTextField(
              hint: 'Enter your full name',
              controller: fullNameController,
            ),

            const SizedBox(height: 20),
            _buildLabel('PHONE NUMBER'),
            _buildTextField(
              hint: 'e.g., 09123456789',
              controller: phoneController,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('AGE'),
                      _buildTextField(
                        hint: 'e.g., 25',
                        controller: ageController,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('GENDER'),
                      _buildDropdownField(
                        hint: 'Select',
                        value: selectedGender,
                        items: genderOptions,
                        onChanged: (val) =>
                            setState(() => selectedGender = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _buildLabel('HEIGHT'),
            _buildDropdownField(
              hint: 'Select height (cm)',
              value: selectedHeight,
              items: heightOptions,
              onChanged: (val) => setState(() => selectedHeight = val),
              suffix: 'cm',
            ),

            const SizedBox(height: 20),
            _buildLabel('WEIGHT'),
            _buildDropdownField(
              hint: 'Select weight (kg)',
              value: selectedWeight,
              items: weightOptions,
              onChanged: (val) => setState(() => selectedWeight = val),
              suffix: 'kg',
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
    bool isEnabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: isEnabled,
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
    String? suffix,
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
                (String val) =>
                    DropdownMenuItem<String>(value: val, child: Text(val)),
              )
              .toList(),
          onChanged: onChanged,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suffix != null)
                Text(suffix, style: const TextStyle(color: Colors.blueGrey)),
              const Icon(Icons.arrow_drop_down, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}
