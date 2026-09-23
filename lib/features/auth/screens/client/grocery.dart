import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';

// --- MODEL ---
// One ingredient on the week's list, backed by one grocery_items row per plan.
class GroceryItem {
  final List<String> ids;
  final String name;
  final String quantity;
  final String category;
  final String mealType;
  bool isBought;

  GroceryItem({
    this.ids = const [],
    required this.name,
    required this.quantity,
    required this.category,
    this.mealType = 'Other',
    this.isBought = false,
  });
}

class GroceryScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const GroceryScreen({super.key, required this.onBackToHome});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  static const mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Other'];

  static const categoryOrder = [
    'Protein',
    'Vegetables',
    'Fruits',
    'Grains',
    'Dairy',
    'Pantry',
  ];

  List<GroceryItem> _items = [];
  int _mealCount = 0;
  int _dayCount = 0;
  bool _isLoading = true;
  bool _hasPlan = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Builds one shopping list from the plans for today and the next six days.
  Future<void> _loadList() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Not signed in.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final today = DateTime.now();

      // Without a timeout a stalled request leaves the spinner up forever.
      final plans = await supabase
          .from('meal_plans')
          .select('id')
          .eq('user_id', user.id)
          .gte('plan_date', _dateKey(today))
          .lte('plan_date', _dateKey(today.add(const Duration(days: 6))))
          .timeout(const Duration(seconds: 10));

      final planIds = [for (final p in plans) p['id'] as String];

      if (planIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = [];
          _mealCount = 0;
          _dayCount = 0;
          _hasPlan = false;
          _isLoading = false;
        });
        return;
      }

      final planItems = await supabase
          .from('meal_plan_items')
          .select('plan_id, meal_type, ingredients')
          .inFilter('plan_id', planIds);

      var rows = await _fetchRows(user.id, planIds);

      // Lists built before meal grouping have no meal; rebuild them by meal.
      final stale = {
        for (final r in rows)
          if (r['meal_type'] == null) r['plan_id'] as String,
      };
      if (stale.isNotEmpty) {
        await supabase
            .from('grocery_items')
            .delete()
            .eq('user_id', user.id)
            .inFilter('plan_id', stale.toList());
        rows = rows.where((r) => !stale.contains(r['plan_id'])).toList();
      }

      final listed = {for (final r in rows) r['plan_id'] as String?};

      // Plans without a list yet (new or regenerated) get one built now.
      final missing = planIds.where((id) => !listed.contains(id)).toList();
      if (missing.isNotEmpty) {
        for (final id in missing) {
          await _buildListFromPlan(user.id, id, [
            for (final i in planItems)
              if (i['plan_id'] == id) i,
          ]);
        }
        rows = await _fetchRows(user.id, planIds);
      }

      if (!mounted) return;
      setState(() {
        _items = _merge(rows);
        _mealCount = planItems.length;
        _dayCount = planIds.length;
        _hasPlan = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load grocery list: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRows(
    String userId,
    List<String> planIds,
  ) => Supabase.instance.client
      .from('grocery_items')
      .select()
      .eq('user_id', userId)
      .inFilter('plan_id', planIds);

  // Combines the same ingredient from different days into one row.
  List<GroceryItem> _merge(List<Map<String, dynamic>> rows) {
    final byName = <String, _Aggregate>{};
    final ids = <String, List<String>>{};
    final bought = <String, bool>{};

    for (final r in rows) {
      final name = (r['name'] as String? ?? '').trim();
      final meal = r['meal_type'] as String? ?? 'Other';
      final key = '$meal|${name.toLowerCase()}';
      final agg = byName.putIfAbsent(
        key,
        () => _Aggregate(name, r['category'] as String? ?? 'Pantry', meal),
      );
      for (final part in (r['quantity'] as String? ?? '').split(' + ')) {
        agg.add(part);
      }
      ids.putIfAbsent(key, () => []).add(r['id'] as String);
      bought[key] = (bought[key] ?? true) && (r['is_checked'] as bool? ?? false);
    }

    return [
      for (final e in byName.entries)
        GroceryItem(
          ids: ids[e.key]!,
          name: e.value.name,
          quantity: e.value.formatted,
          category: e.value.category,
          mealType: e.value.mealType,
          isBought: bought[e.key]!,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  // Merges the same ingredient across meals, summing quantities that share a
  // unit. Mismatched units are listed side by side rather than guessed at.
  Future<void> _buildListFromPlan(
    String userId,
    String planId,
    List planItems,
  ) async {
    final merged = <String, _Aggregate>{};

    for (final item in planItems) {
      final ingredients = (item as Map)['ingredients'];
      if (ingredients is! List) continue;
      final meal = item['meal_type'] as String? ?? 'Other';

      for (final raw in ingredients) {
        if (raw is! Map) continue;
        final name = (raw['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        merged
            .putIfAbsent(
              '$meal|${name.toLowerCase()}',
              () => _Aggregate(
                name,
                raw['category'] as String? ?? 'Pantry',
                meal,
              ),
            )
            .add(raw['quantity'] as String? ?? '');
      }
    }

    if (merged.isEmpty) return;

    await Supabase.instance.client
        .from('grocery_items')
        .insert(
          merged.values
              .map(
                (agg) => {
                  'user_id': userId,
                  'plan_id': planId,
                  'meal_type': agg.mealType,
                  'name': agg.name,
                  'quantity': agg.formatted,
                  'category': categoryOrder.contains(agg.category)
                      ? agg.category
                      : 'Pantry',
                },
              )
              .toList(),
        );
  }

  // Checks off everything left, then confirms the trip is done.
  Future<void> _finishShopping() async {
    final remaining = _items.where((i) => !i.isBought).toList();
    final ids = [for (final i in remaining) ...i.ids];

    if (ids.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('grocery_items')
            .update({'is_checked': true})
            .inFilter('id', ids);
        if (mounted) {
          setState(() {
            for (final i in remaining) {
              i.isBought = true;
            }
          });
        }
      } catch (e) {
        debugPrint('Failed to finish shopping: $e');
        return;
      }
    }

    if (mounted) _showSuccessModal();
  }

  Future<void> _toggleItem(GroceryItem item, bool value) async {
    setState(() => item.isBought = value);
    if (item.ids.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('grocery_items')
          .update({'is_checked': value})
          .inFilter('id', item.ids);
    } catch (e) {
      debugPrint('Failed to update item: $e');
      if (mounted) setState(() => item.isBought = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sections follow the meal each ingredient is for.
    final groupedItems = <String, List<GroceryItem>>{};
    for (final item in _items) {
      groupedItems.putIfAbsent(item.mealType, () => []).add(item);
    }

    final sortedCategories = groupedItems.keys.toList()
      ..sort((a, b) {
        final ai = mealOrder.indexOf(a);
        final bi = mealOrder.indexOf(b);
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        // Every child is positioned, so the Stack needs an explicit size.
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _isLoading
                ? Padding(
                    padding: EdgeInsets.only(
                      top: GlassHeader.insetFor(context),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: brandGreen),
                    ),
                  )
                : _error != null
                ? _buildErrorState()
                : !_hasPlan
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadList,
                    color: brandGreen,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        // Content scrolls under the glass header.
                        top: GlassHeader.insetFor(context),
                      ),
                      children: [
                        _buildDateHeader(),
                        ...sortedCategories.map((category) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 30,
                                  bottom: 12,
                                  left: 4,
                                ),
                                child: Text(
                                  category.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: textSecondary,
                                    fontSize: 12,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                              ...groupedItems[category]!.map(
                                (item) => _buildGroceryTile(item),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 100), // Space for button
                      ],
                    ),
                  ),
          ),
          _buildAppBar(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (_hasPlan && _items.isNotEmpty)
          ? _buildCompleteButton()
          : null,
    );
  }

  Widget _buildAppBar() {
    return GlassHeader(
      child: Row(
        children: [
          const SizedBox(width: 56), // Matches trailing icon plus padding
          const Expanded(
            child: HeaderTitle(
              title: "Grocery",
              subtitle: "For your next 7 days of meals",
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: textSecondary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationScreen(
                    onBackToHome: () => Navigator.pop(context),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // Surfaces the real failure instead of leaving a spinner running.
  Widget _buildErrorState() {
    return Padding(
      padding: EdgeInsets.only(top: GlassHeader.insetFor(context)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: Color(0xFFF25151),
              ),
              const SizedBox(height: 14),
              const Text(
                "Could not load your list",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _loadList,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Try again"),
                style: TextButton.styleFrom(foregroundColor: brandGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      // Centre within the area below the header, not behind it.
      padding: EdgeInsets.only(top: GlassHeader.insetFor(context)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_basket_outlined,
                size: 48,
                color: Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 16),
              const Text(
                "No grocery list yet",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Plan meals for today or the coming days and their ingredients will appear here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final end = DateTime.now().add(const Duration(days: 6));
    final dateLabel =
        'Today to ${days[end.weekday - 1]}, ${months[end.month - 1]} ${end.day}';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                ),
              ),
              Text(
                "$_mealCount meals across $_dayCount planned days",
                style: const TextStyle(color: textSecondary, fontSize: 13),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: brandGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${_items.length} Items",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryTile(GroceryItem item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isBought ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isBought ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
        boxShadow: item.isBought
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Theme(
        data: ThemeData(
          checkboxTheme: CheckboxThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          value: item.isBought,
          activeColor: brandGreen,
          onChanged: (bool? value) => _toggleItem(item, value ?? false),
          title: Text(
            item.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: item.isBought ? textSecondary : darkBlue,
              decoration: item.isBought ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            item.quantity,
            style: TextStyle(
              fontSize: 13,
              color: item.isBought
                  ? textSecondary.withValues(alpha: 0.5)
                  : textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.isBought
                  ? Colors.white.withValues(alpha: 0.5)
                  : brandGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(item.category),
              color: item.isBought ? textSecondary : brandGreen,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Protein":
        return Icons.restaurant_menu_rounded;
      case "Fruits":
        return Icons.apple_rounded;
      case "Vegetables":
        return Icons.eco_rounded;
      case "Grains":
        return Icons.bakery_dining_rounded;
      case "Dairy":
        return Icons.water_drop_rounded;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _buildCompleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                darkBlue, // Changed to Dark Blue for "Executive" feel
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: darkBlue.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: _finishShopping,
          child: const Text(
            "Finish Shopping",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: brandGreen,
                  size: 45,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "All Set!",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Your pantry is restocked and you're ready for your healthy meal plan.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onBackToHome();
                  },
                  child: const Text(
                    "Back to Dashboard",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Collects one ingredient for one meal as it appears across several days.
class _Aggregate {
  final String name;
  final String category;
  final String mealType;
  final Map<String, double> _byUnit = {};
  final List<String> _unparsed = [];

  _Aggregate(this.name, this.category, [this.mealType = 'Other']);

  void add(String quantity) {
    final match = RegExp(r'^\s*([\d.]+)\s*(.*)$').firstMatch(quantity.trim());

    if (match == null) {
      if (quantity.trim().isNotEmpty) _unparsed.add(quantity.trim());
      return;
    }

    final value = double.tryParse(match.group(1)!);
    if (value == null) return;

    final unit = match.group(2)!.trim().toLowerCase();
    _byUnit[unit] = (_byUnit[unit] ?? 0) + value;
  }

  // "300 g", or "2 pcs + 300 g" when the units differ.
  String get formatted {
    final parts = _byUnit.entries.map((e) {
      final value = e.value % 1 == 0
          ? e.value.toStringAsFixed(0)
          : e.value.toStringAsFixed(1);
      return e.key.isEmpty ? value : '$value ${e.key}';
    }).toList();

    parts.addAll(_unparsed);
    return parts.isEmpty ? '' : parts.join(' + ');
  }
}
