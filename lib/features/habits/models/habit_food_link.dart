import '../../../shared/models/models.dart';
import '../../food/domain/food.dart';
import '../../food/domain/meal_entry.dart';

/// A saved food link on a habit/todo. When the task is completed, each item is
/// auto-logged to the food diary at [slot]; un-completing removes them.
///
/// Persisted as the `food_link` jsonb on the habit row (see
/// `Habit.foodLinkRaw`). Item nutrients are stored as an already-scaled
/// snapshot for the chosen quantity, so auto-logging never has to refetch the
/// source food — it works offline and is immune to later edits of that food.
class HabitFoodLink {
  final MealTimeSlot slot;
  final List<HabitFoodLinkItem> items;
  /// A Flexible meal habit has no preset items — completing it opens a
  /// decision gate (enter calories / log food / skip) instead of auto-logging
  /// anything. Always paired with empty [items]; mutually exclusive in
  /// practice with a Fixed link (which always has 1+ items).
  final bool isFlexible;

  const HabitFoodLink({
    required this.slot,
    required this.items,
    this.isFlexible = false,
  });

  /// An empty link, defaulting to the Snack slot.
  static const empty = HabitFoodLink(slot: MealTimeSlot.snack, items: []);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  double get totalKcal =>
      items.fold<double>(0, (sum, i) => sum + i.totals.kcal);

  HabitFoodLink copyWith({
    MealTimeSlot? slot,
    List<HabitFoodLinkItem>? items,
    bool? isFlexible,
  }) =>
      HabitFoodLink(
        slot: slot ?? this.slot,
        items: items ?? this.items,
        isFlexible: isFlexible ?? this.isFlexible,
      );

  /// Parse the raw `food_link` jsonb stored on a habit row. Returns null when
  /// absent or malformed so callers can treat "no link" uniformly. A link is
  /// valid with either 1+ items (Fixed) or `is_flexible: true` (Flexible,
  /// always zero items) — empty items alone used to be treated as "no link
  /// at all", which silently discarded every Flexible link ever saved.
  static HabitFoodLink? fromRaw(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final isFlexible = raw['is_flexible'] as bool? ?? false;
    final itemsJson = (raw['items'] as List?) ?? const [];
    final items = itemsJson
        .whereType<Map<String, dynamic>>()
        .map(HabitFoodLinkItem.fromJson)
        .toList();
    if (items.isEmpty && !isFlexible) return null;
    return HabitFoodLink(
      slot: _slotFromDb(raw['slot'] as String?),
      items: items,
      isFlexible: isFlexible,
    );
  }

  Map<String, dynamic> toJson() => {
        'slot': slot.dbValue,
        'items': items.map((i) => i.toJson()).toList(),
        if (isFlexible) 'is_flexible': true,
      };
}

class HabitFoodLinkItem {
  final String? foodId;
  final String name;
  final double qty;
  final String unit;
  final Nutrients totals; // already scaled for [qty] [unit]

  const HabitFoodLinkItem({
    required this.foodId,
    required this.name,
    required this.qty,
    required this.unit,
    required this.totals,
  });

  factory HabitFoodLinkItem.fromJson(Map<String, dynamic> j) {
    final macros = Nutrients(
      kcal: (j['calories'] as num?)?.toDouble() ?? 0,
      proteinG: (j['protein'] as num?)?.toDouble() ?? 0,
      carbsG: (j['carbs'] as num?)?.toDouble() ?? 0,
      fatG: (j['fat'] as num?)?.toDouble() ?? 0,
    );
    final micros = Nutrients.fromMicrosJson(
      (j['micros'] as Map<String, dynamic>?) ?? const {},
    );
    return HabitFoodLinkItem(
      foodId: j['food_id'] as String?,
      name: j['name'] as String? ?? 'Food',
      qty: (j['qty'] as num?)?.toDouble() ?? 1,
      unit: j['unit'] as String? ?? 'g',
      totals: macros + micros,
    );
  }

  Map<String, dynamic> toJson() => {
        if (foodId != null) 'food_id': foodId,
        'name': name,
        'qty': qty,
        'unit': unit,
        'calories': totals.kcal,
        'protein': totals.proteinG,
        'carbs': totals.carbsG,
        'fat': totals.fatG,
        'micros': totals.toMicrosJson(),
      };

  /// "1 Katori" / "120 g" — the portion summary shown in the editor.
  String get portionLabel {
    final q = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    return '$q $unit';
  }
}

MealTimeSlot _slotFromDb(String? s) => switch (s) {
      'breakfast' => MealTimeSlot.breakfast,
      'pre_workout' => MealTimeSlot.preWorkout,
      'lunch' => MealTimeSlot.lunch,
      'post_workout' => MealTimeSlot.postWorkout,
      'dinner' => MealTimeSlot.dinner,
      _ => MealTimeSlot.snack,
    };
