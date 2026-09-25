// A single food item, either staged in Log Meal or loaded from food_logs.
class FoodEntry {
  final String? id;
  final String name;
  final String quantity;
  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarG;
  final double fiberG;
  final double saturatedFatG;
  final double sodiumMg;
  final double cholesterolMg;
  final String source;

  const FoodEntry({
    this.id,
    required this.name,
    required this.quantity,
    required this.kcal,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.sugarG = 0,
    this.fiberG = 0,
    this.saturatedFatG = 0,
    this.sodiumMg = 0,
    this.cholesterolMg = 0,
    this.source = 'custom',
  });

  static double _num(Map<String, dynamic> row, String key) =>
      (row[key] as num?)?.toDouble() ?? 0;

  factory FoodEntry.fromRow(Map<String, dynamic> row) => FoodEntry(
    id: row['id'] as String?,
    name: row['name'] as String? ?? '',
    quantity: row['quantity'] as String? ?? '',
    kcal: (row['kcal'] as num?)?.round() ?? 0,
    proteinG: (row['protein_g'] as num?)?.toDouble() ?? 0,
    carbsG: (row['carbs_g'] as num?)?.toDouble() ?? 0,
    fatG: (row['fat_g'] as num?)?.toDouble() ?? 0,
    sugarG: _num(row, 'sugar_g'),
    fiberG: _num(row, 'fiber_g'),
    saturatedFatG: _num(row, 'saturated_fat_g'),
    sodiumMg: _num(row, 'sodium_mg'),
    cholesterolMg: _num(row, 'cholesterol_mg'),
    source: row['source'] as String? ?? 'custom',
  );

  // A dish from meal_plan_items, logged as one serving from the plan.
  factory FoodEntry.fromPlanItem(Map<String, dynamic> item) => FoodEntry(
    name: item['name'] as String? ?? '',
    quantity: '1 serving',
    kcal: (item['kcal'] as num?)?.round() ?? 0,
    proteinG: (item['protein_g'] as num?)?.toDouble() ?? 0,
    carbsG: (item['carbs_g'] as num?)?.toDouble() ?? 0,
    fatG: (item['fat_g'] as num?)?.toDouble() ?? 0,
    sugarG: _num(item, 'sugar_g'),
    fiberG: _num(item, 'fiber_g'),
    saturatedFatG: _num(item, 'saturated_fat_g'),
    sodiumMg: _num(item, 'sodium_mg'),
    cholesterolMg: _num(item, 'cholesterol_mg'),
    source: 'plan',
  );

  // Row shape for inserting into food_logs.
  Map<String, dynamic> toRow({
    required String userId,
    required DateTime date,
    required String mealType,
  }) => {
    'user_id': userId,
    'logged_date': _dateOnly(date),
    'meal_type': mealType,
    'name': name,
    'quantity': quantity,
    'kcal': kcal,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'sugar_g': sugarG,
    'fiber_g': fiberG,
    'saturated_fat_g': saturatedFatG,
    'sodium_mg': sodiumMg,
    'cholesterol_mg': cholesterolMg,
    'source': source,
  };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
