import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/notification_bell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';
import 'package:smart_plate/features/auth/widgets/meal_badge.dart';

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

  // Earliest and latest planned days on the list, for the header label.
  DateTime? _firstDay;
  DateTime? _lastDay;
  bool _isUpdatingAll = false;

  // Meal sections whose bought items are expanded.
  final Set<String> _showBought = {};

  int get _boughtCount => _items.where((i) => i.isBought).length;
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

  // Builds the shopping list from today's plan.
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
          .select('id, plan_date')
          .eq('user_id', user.id)
          .gte('plan_date', _dateKey(today))
          .lte('plan_date', _dateKey(today))
          // Groceries come only from a plan confirmed with "Use this plan".
          .not('saved_at', 'is', null)
          .timeout(const Duration(seconds: 10));

      final planIds = [for (final p in plans) p['id'] as String];
      final planDays = [
        for (final p in plans) DateTime.parse(p['plan_date'] as String),
      ]..sort();

      if (planIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = [];
          _mealCount = 0;
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
        _firstDay = planDays.first;
        _lastDay = planDays.last;
        _hasPlan = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load grocery list: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = friendlyError(e);
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
      bought[key] =
          (bought[key] ?? true) && (r['is_checked'] as bool? ?? false);
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

  // Marks every item bought, or unchecks everything to start over.
  Future<void> _setAll(bool bought) async {
    final targets = _items.where((i) => i.isBought != bought).toList();
    final ids = [for (final i in targets) ...i.ids];
    if (ids.isEmpty || _isUpdatingAll) return;

    setState(() => _isUpdatingAll = true);
    try {
      await Supabase.instance.client
          .from('grocery_items')
          .update({'is_checked': bought})
          .inFilter('id', ids);
      if (mounted) {
        setState(() {
          for (final i in targets) {
            i.isBought = bought;
          }
          if (!bought) _showBought.clear();
        });
      }
    } catch (e) {
      debugPrint('Failed to update grocery list: $e');
    }
    if (mounted) setState(() => _isUpdatingAll = false);
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
                        ...sortedCategories.map(
                          (meal) =>
                              _buildMealSection(meal, groupedItems[meal]!),
                        ),
                        const SizedBox(height: 24),
                        _buildFooter(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
          _buildAppBar(),
        ],
      ),
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
              subtitle: "For today's meal plan",
            ),
          ),
          const NotificationBell(),
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
                "Generate today's meal plan and tap Use this plan. Its ingredients will appear here.",
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

  // "Wed, Sep 23", or a range when several days are planned.
  String _formatDay(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  Widget _buildDateHeader() {
    final first = _firstDay;
    final last = _lastDay;
    final dateLabel = first == null || last == null
        ? ''
        : first == last
        ? _formatDay(first)
        : '${_formatDay(first)} - ${_formatDay(last)}';

    final total = _items.length;
    final progress = total == 0 ? 0.0 : _boughtCount / total;

    final left = total - _boughtCount;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expanded lets a long date range wrap instead of pushing the pill off screen.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "SHOPPING LIST",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: darkBlue,
                      ),
                    ),
                    Text(
                      "$_mealCount meals · $total items",
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  left == 0 ? "All bought" : "$left left",
                  style: const TextStyle(
                    color: brandGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: brandGreen,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$_boughtCount of $total bought",
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // One card per meal: items still to buy first, bought ones folded underneath.
  Widget _buildMealSection(String meal, List<GroceryItem> items) {
    final toBuy = items.where((i) => !i.isBought).toList();
    final bought = items.where((i) => i.isBought).toList();
    final expanded = _showBought.contains(meal);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MealBadge(mealType: meal, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  meal,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                "${bought.length}/${items.length}",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...toBuy.map(_buildGroceryTile),
          if (bought.isNotEmpty)
            InkWell(
              onTap: () => setState(() {
                if (expanded) {
                  _showBought.remove(meal);
                } else {
                  _showBought.add(meal);
                }
              }),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: brandGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Bought (${bought.length})",
                      style: const TextStyle(
                        color: brandGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          if (expanded) ...bought.map(_buildGroceryTile),
          if (toBuy.isEmpty && bought.isEmpty) const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Mark-all button while shopping, or a done card once everything is bought.
  Widget _buildFooter() {
    final left = _items.length - _boughtCount;

    if (left == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: brandGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: brandGreen.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: brandGreen, size: 36),
            const SizedBox(height: 8),
            const Text(
              "Shopping done",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "New items appear here when you plan more days.",
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isUpdatingAll ? null : () => _setAll(false),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Start over"),
              style: TextButton.styleFrom(foregroundColor: brandGreen),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isUpdatingAll ? null : () => _setAll(true),
        style: ElevatedButton.styleFrom(
          backgroundColor: darkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isUpdatingAll
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                "Mark all as bought ($left left)",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  // One ingredient: round check, name and amount, and a small category icon.
  Widget _buildGroceryTile(GroceryItem item) {
    final done = item.isBought;

    return InkWell(
      onTap: () => _toggleItem(item, !done),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: done ? brandGreen : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? brandGreen : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: done ? textSecondary : darkBlue,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.quantity.isNotEmpty)
                    Text(
                      item.quantity,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              _getCategoryIcon(item.category),
              color: done ? const Color(0xFFCBD5E1) : textSecondary,
              size: 18,
            ),
          ],
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
