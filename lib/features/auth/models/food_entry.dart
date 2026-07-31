// A single food item, either staged in Log Meal or loaded from food_logs.
class FoodEntry {
  final String? id;
  final String name;
  final String quantity;
  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String source;

  const FoodEntry({
    this.id,
    required this.name,
    required this.quantity,
    required this.kcal,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.source = 'custom',
  });

  factory FoodEntry.fromRow(Map<String, dynamic> row) => FoodEntry(
    id: row['id'] as String?,
    name: row['name'] as String? ?? '',
    quantity: row['quantity'] as String? ?? '',
    kcal: (row['kcal'] as num?)?.round() ?? 0,
    proteinG: (row['protein_g'] as num?)?.toDouble() ?? 0,
    carbsG: (row['carbs_g'] as num?)?.toDouble() ?? 0,
    fatG: (row['fat_g'] as num?)?.toDouble() ?? 0,
    source: row['source'] as String? ?? 'custom',
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
    'source': source,
  };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
