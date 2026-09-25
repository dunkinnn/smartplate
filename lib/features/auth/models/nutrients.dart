// Nutrients tracked beyond calories and macros, with general daily guides
// for adults. Guides are reference values for display, not medical advice.
class Nutrient {
  final String column;
  final String label;
  final String unit;
  final double dailyGuide;

  // True when the guide is a maximum to stay under, false when it is a target.
  final bool isLimit;

  const Nutrient(
    this.column,
    this.label,
    this.unit,
    this.dailyGuide, {
    required this.isLimit,
  });

  static const sugar = Nutrient('sugar_g', 'Sugar', 'g', 50, isLimit: true);
  static const fiber = Nutrient('fiber_g', 'Fiber', 'g', 25, isLimit: false);
  static const saturatedFat = Nutrient(
    'saturated_fat_g',
    'Saturated fat',
    'g',
    20,
    isLimit: true,
  );
  static const sodium = Nutrient(
    'sodium_mg',
    'Sodium',
    'mg',
    2000,
    isLimit: true,
  );
  static const cholesterol = Nutrient(
    'cholesterol_mg',
    'Cholesterol',
    'mg',
    300,
    isLimit: true,
  );

  static const all = [sugar, fiber, saturatedFat, sodium, cholesterol];

  // Sum of this nutrient over rows from meal_plan_items or food_logs.
  double sumOf(Iterable<Map<String, dynamic>> rows) =>
      rows.fold(0.0, (s, r) => s + ((r[column] as num?)?.toDouble() ?? 0));

  String format(double value) => '${value.round()} $unit';
}
