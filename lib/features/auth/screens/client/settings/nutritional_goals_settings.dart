import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/widgets/settings_form.dart';

// Edits the calorie target, macro goals and weight goal used across the app.
class NutritionalGoalsSettingsScreen extends StatefulWidget {
  const NutritionalGoalsSettingsScreen({super.key});

  @override
  State<NutritionalGoalsSettingsScreen> createState() =>
      _NutritionalGoalsSettingsScreenState();
}

class _NutritionalGoalsSettingsScreenState
    extends State<NutritionalGoalsSettingsScreen> {
  static const weightGoals = [
    'Lose Weight',
    'Maintain Weight',
    'Gain Weight',
    'Build Muscle',
  ];
  static const activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
  ];

  final _calorie = TextEditingController();
  final _targetWeight = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  String? _weightGoal;
  String? _activityLevel;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _calorie.dispose();
    _targetWeight.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  String _text(dynamic value) => value == null ? '' : '$value';

  Future<void> _load() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await supabase
          .from('user_profiles')
          .select(
            'calorie_target, target_weight, weight_goal, activity_level, '
            'protein_goal_g, carbs_goal_g, fat_goal_g',
          )
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _calorie.text = _text(row?['calorie_target']);
        _targetWeight.text = _text(row?['target_weight']);
        _protein.text = _text(row?['protein_goal_g']);
        _carbs.text = _text(row?['carbs_goal_g']);
        _fat.text = _text(row?['fat_goal_g']);
        _weightGoal = row?['weight_goal'] as String?;
        _activityLevel = row?['activity_level'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Could not load your goals.';
      });
    }
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final calories = int.tryParse(_calorie.text.trim());

    // A wildly low target would drive every calculation in the app, so it is
    // worth rejecting rather than storing.
    if (calories == null || calories < 1200 || calories > 5000) {
      setState(() {
        _message = 'Enter a daily calorie target between 1200 and 5000.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'calorie_target': calories,
            'target_weight': double.tryParse(_targetWeight.text.trim()),
            'weight_goal': _weightGoal,
            'activity_level': _activityLevel,
            'protein_goal_g': int.tryParse(_protein.text.trim()),
            'carbs_goal_g': int.tryParse(_carbs.text.trim()),
            'fat_goal_g': int.tryParse(_fat.text.trim()),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = 'Goals saved.';
        _messageIsError = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = e.message;
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
      title: "Nutritional Goals",
      subtitle: "Targets used across Track and Insights",
      isSaving: _isSaving,
      message: _message,
      messageIsError: _messageIsError,
      onDismissMessage: () => setState(() => _message = null),
      onSave: _save,
      children: [
        const SettingsLabel('DAILY CALORIE TARGET'),
        SettingsTextField(
          controller: _calorie,
          hint: 'e.g. 1800',
          keyboardType: TextInputType.number,
          suffix: 'kcal',
        ),
        const SizedBox(height: 20),

        const SettingsLabel('WEIGHT GOAL'),
        SettingsDropdown(
          hint: 'Select your goal',
          value: _weightGoal,
          items: weightGoals,
          onChanged: (v) => setState(() => _weightGoal = v),
        ),
        const SizedBox(height: 20),

        const SettingsLabel('TARGET WEIGHT'),
        SettingsTextField(
          controller: _targetWeight,
          hint: 'e.g. 65',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffix: 'kg',
        ),
        const SizedBox(height: 20),

        const SettingsLabel('ACTIVITY LEVEL'),
        SettingsDropdown(
          hint: 'Select your activity level',
          value: _activityLevel,
          items: activityLevels,
          onChanged: (v) => setState(() => _activityLevel = v),
        ),
        const SizedBox(height: 28),

        const SettingsLabel('MACRO GOALS'),
        SettingsTextField(
          controller: _protein,
          hint: 'Protein, e.g. 80',
          keyboardType: TextInputType.number,
          suffix: 'g',
        ),
        const SizedBox(height: 12),
        SettingsTextField(
          controller: _carbs,
          hint: 'Carbs, e.g. 200',
          keyboardType: TextInputType.number,
          suffix: 'g',
        ),
        const SizedBox(height: 12),
        SettingsTextField(
          controller: _fat,
          hint: 'Fat, e.g. 60',
          keyboardType: TextInputType.number,
          suffix: 'g',
        ),
      ],
    );
  }
}
