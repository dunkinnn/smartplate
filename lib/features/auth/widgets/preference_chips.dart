import 'package:flutter/material.dart';

// Choices shared by sign-up and Settings so both screens always offer the same options.
class PreferenceOptions {
  static const diets = [
    'None',
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Keto',
    'Low Carb',
    'Paleo',
    'Mediterranean',
    'Halal',
  ];
  static const tastes = [
    'Savory',
    'Sweet',
    'Spicy',
    'Salty',
    'Sour',
    'Bitter',
    'Mild',
  ];
  static const allergens = [
    'None',
    'Peanuts',
    'Tree Nuts',
    'Dairy',
    'Egg',
    'Gluten',
    'Soy',
    'Fish',
    'Shellfish',
    'Mollusks',
    'Sesame',
    'Wheat',
    'Corn',
    'Coconut',
    'Mango',
  ];
  static const restrictions = [
    'None',
    'Pork',
    'Beef',
    'Chicken',
    'Seafood',
    'Red Meat',
    'Organ Meat',
    'Processed Meat',
    'Alcohol',
    'Processed Sugar',
    'Fried Food',
    'Spicy Food',
    'Instant Noodles',
    'White Rice',
    'MSG',
    'Caffeine',
  ];
  static const nutritionFocus = [
    'High Protein',
    'Low Sugar',
    'Low Fat',
    'Low Carb',
    'Low Sodium',
    'High Fiber',
    'Low Cholesterol',
  ];

  // Saved as "Peanuts, Dairy" in one text column; null when nothing is picked.
  static String? join(Set<String> values) =>
      values.isEmpty ? null : values.join(', ');

  static Set<String> split(String? stored) => (stored ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
}

// Tappable chips for picking several options; "None" clears the others and vice versa.
// Tappable chips for picking several options; "None" clears the others and vice versa.
// With allowCustom, users can also type their own entries, shown as extra chips.
class PreferenceChips extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool allowCustom;
  final String customHint;

  const PreferenceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allowCustom = false,
    this.customHint = 'Type your own',
  });

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF64748B);

  static const int maxCustom = 5;

  void _toggle(String option) {
    final next = {...selected};
    if (next.contains(option)) {
      next.remove(option);
    } else if (option == 'None') {
      next
        ..clear()
        ..add('None');
    } else {
      next
        ..remove('None')
        ..add(option);
    }
    onChanged(next);
  }

  // Entries the user typed, i.e. selected values that are not built-in options.
  List<String> get _custom =>
      selected.where((v) => !options.contains(v)).toList();

  // Letters, spaces, hyphens and apostrophes only, 2 to 30 characters, so the
  // saved comma list stays clean and nothing odd reaches the meal planner.
  static String? validate(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length < 2 || text.length > 30) {
      return 'Use 2 to 30 characters.';
    }
    if (!RegExp(r"^[A-Za-z][A-Za-z '\-]*$").hasMatch(text)) {
      return 'Use letters only, for example "Kiwi" or "Bitter gourd".';
    }
    return null;
  }

  static String _titleCase(String text) => text
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  Future<void> _addCustom(BuildContext context) async {
    final controller = TextEditingController();
    String? error;

    final value = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final problem = validate(controller.text);
            if (problem != null) {
              setDialogState(() => error = problem);
              return;
            }
            Navigator.pop(context, _titleCase(controller.text));
          }

          return AlertDialog(
            title: const Text('Add your own'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: customHint,
                errorText: error,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: submit,
                style: TextButton.styleFrom(foregroundColor: brandGreen),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    // Not disposed here: the dialog may still be animating out and using it.
    if (value == null) return;

    // Typing a built-in option just selects that option.
    final builtIn = options.where(
      (o) => o.toLowerCase() == value.toLowerCase(),
    );
    final entry = builtIn.isNotEmpty ? builtIn.first : value;
    final alreadyThere = selected.any(
      (v) => v.toLowerCase() == entry.toLowerCase(),
    );
    if (!alreadyThere) _toggle(entry);
  }

  Widget _chip(String label, {required bool isSelected, VoidCallback? onTap}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onTap == null ? null : (_) => onTap(),
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: brandGreen,
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(color: isSelected ? brandGreen : borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : darkBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custom = _custom;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _chip(
            option,
            isSelected: selected.contains(option),
            onTap: () => _toggle(option),
          ),
        // Typed entries stay selected; tapping one removes it.
        for (final value in custom)
          _chip(value, isSelected: true, onTap: () => _toggle(value)),
        if (allowCustom && custom.length < maxCustom)
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18, color: brandGreen),
            label: const Text('Add your own'),
            onPressed: () => _addCustom(context),
            backgroundColor: Colors.white,
            side: const BorderSide(color: brandGreen),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: brandGreen,
            ),
          ),
      ],
    );
  }
}
