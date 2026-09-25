import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/services/meal_log_service.dart';
import 'package:smart_plate/features/auth/widgets/preference_chips.dart';
import 'package:smart_plate/features/auth/widgets/settings_form.dart';

// Edits the diet, taste, allergen and restriction fields the meal plan
// generator reads.
class DietaryPreferencesScreen extends StatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  String? _diet;
  Set<String> _tastes = {};
  Set<String> _allergens = {};
  Set<String> _restrictions = {};
  Set<String> _nutritionFocus = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await supabase
          .from('user_profiles')
          .select('diet, taste, allergen, food_restriction, nutrition_focus')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _diet = row?['diet'] as String?;
        _tastes = PreferenceOptions.split(row?['taste'] as String?);
        _allergens = PreferenceOptions.split(row?['allergen'] as String?);
        _restrictions = PreferenceOptions.split(
          row?['food_restriction'] as String?,
        );
        _nutritionFocus = PreferenceOptions.split(
          row?['nutrition_focus'] as String?,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Could not load your preferences.';
      });
    }
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'diet': _diet,
            'taste': PreferenceOptions.join(_tastes),
            'allergen': PreferenceOptions.join(_allergens),
            'food_restriction': PreferenceOptions.join(_restrictions),
            'nutrition_focus': PreferenceOptions.join(_nutritionFocus),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // Plans made with the old preferences may now include an allergen.
      final upcoming = await MealLogService.reopenUpcomingPlans();

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = upcoming > 0
            ? 'Preferences saved. Regenerate your upcoming meal plans so they match.'
            : 'Preferences saved.';
        _messageIsError = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = friendlyError(e);
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: SettingsScaffold.brandGreen),
        ),
      );
    }

    return SettingsScaffold(
      title: "Dietary Preferences",
      subtitle: "Used when generating your meal plans",
      isSaving: _isSaving,
      message: _message,
      messageIsError: _messageIsError,
      onDismissMessage: () => setState(() => _message = null),
      onSave: _save,
      children: [
        const SettingsLabel('DIET'),
        SettingsDropdown(
          hint: 'Select your diet type',
          value: _diet,
          items: PreferenceOptions.diets,
          onChanged: (v) => setState(() => _diet = v),
        ),
        const SizedBox(height: 20),

        const SettingsLabel('TASTE PREFERENCES (PICK ANY)'),
        PreferenceChips(
          options: PreferenceOptions.tastes,
          allowCustom: true,
          customHint: 'e.g. Garlicky, Tangy',
          selected: _tastes,
          onChanged: (v) => setState(() => _tastes = v),
        ),
        const SizedBox(height: 20),

        const SettingsLabel('NUTRITION FOCUS (PICK ANY)'),
        PreferenceChips(
          options: PreferenceOptions.nutritionFocus,
          selected: _nutritionFocus,
          onChanged: (v) => setState(() => _nutritionFocus = v),
        ),
        const SizedBox(height: 20),

        const SettingsLabel('ALLERGENS (PICK ALL THAT APPLY)'),
        PreferenceChips(
          options: PreferenceOptions.allergens,
          allowCustom: true,
          customHint: 'e.g. Kiwi, Tomato',
          selected: _allergens,
          onChanged: (v) => setState(() => _allergens = v),
        ),
        const SizedBox(height: 8),
        const Text(
          "Meal plans are checked against this and rejected if a listed "
          "allergen appears in any dish or ingredient.",
          style: TextStyle(
            fontSize: 11,
            color: SettingsScaffold.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        const SettingsLabel('FOODS YOU AVOID (PICK ALL THAT APPLY)'),
        PreferenceChips(
          options: PreferenceOptions.restrictions,
          allowCustom: true,
          customHint: 'e.g. Bitter Gourd, Liver',
          selected: _restrictions,
          onChanged: (v) => setState(() => _restrictions = v),
        ),
      ],
    );
  }
}
