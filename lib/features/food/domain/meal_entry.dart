import '../../../shared/models/models.dart';
import 'food.dart';

/// A single row in the food diary — one logged food at a meal slot.
/// Mirrors the `food_logs` table.
class MealEntry {
  final String id;
  final String userId;
  final String? foodId;
  final String name;
  final DateTime date;
  final MealTimeSlot slot;
  final double qty;        // logged amount in `unit`
  final String unit;
  final Nutrients totals;  // snapshot for the logged amount

  const MealEntry({
    required this.id,
    required this.userId,
    required this.foodId,
    required this.name,
    required this.date,
    required this.slot,
    required this.qty,
    required this.unit,
    required this.totals,
  });

  factory MealEntry.fromJson(Map<String, dynamic> j) {
    final macros = Nutrients(
      kcal: (j['calories'] as num?)?.toDouble() ?? 0,
      proteinG: (j['protein'] as num?)?.toDouble() ?? 0,
      carbsG: (j['carbs'] as num?)?.toDouble() ?? 0,
      fatG: (j['fat'] as num?)?.toDouble() ?? 0,
    );
    final micros = Nutrients.fromMicrosJson(
      (j['micros'] as Map<String, dynamic>?) ?? const {},
    );
    return MealEntry(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      foodId: j['food_id'] as String?,
      name: j['meal_name'] as String,
      date: DateTime.parse(j['date'] as String),
      slot: _parseSlot(j['meal_time'] as String?),
      qty: (j['quantity'] as num?)?.toDouble() ?? 0,
      unit: j['unit'] as String? ?? 'g',
      totals: macros + micros,
    );
  }

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        if (foodId != null) 'food_id': foodId,
        'meal_name': name,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'meal_time': _slotDb(slot),
        'calories': totals.kcal,
        'protein': totals.proteinG,
        'carbs': totals.carbsG,
        'fat': totals.fatG,
        'quantity': qty,
        'unit': unit,
        'micros': totals.toMicrosJson(),
      };
}

MealTimeSlot _parseSlot(String? s) {
  switch (s) {
    case 'breakfast':    return MealTimeSlot.breakfast;
    case 'pre_workout':  return MealTimeSlot.preWorkout;
    case 'lunch':        return MealTimeSlot.lunch;
    case 'snack':        return MealTimeSlot.snack;
    case 'post_workout': return MealTimeSlot.postWorkout;
    case 'dinner':       return MealTimeSlot.dinner;
    default:             return MealTimeSlot.snack;
  }
}

String _slotDb(MealTimeSlot s) => switch (s) {
      MealTimeSlot.breakfast   => 'breakfast',
      MealTimeSlot.preWorkout  => 'pre_workout',
      MealTimeSlot.lunch       => 'lunch',
      MealTimeSlot.snack       => 'snack',
      MealTimeSlot.postWorkout => 'post_workout',
      MealTimeSlot.dinner      => 'dinner',
    };

extension MealTimeSlotX on MealTimeSlot {
  String get label => switch (this) {
        MealTimeSlot.breakfast   => 'Breakfast',
        MealTimeSlot.preWorkout  => 'Pre-workout',
        MealTimeSlot.lunch       => 'Lunch',
        MealTimeSlot.snack       => 'Snack',
        MealTimeSlot.postWorkout => 'Post-workout',
        MealTimeSlot.dinner      => 'Dinner',
      };

  String get dbValue => _slotDb(this);
}

/// Display order on the diary, top → bottom.
const kDiarySlotOrder = <MealTimeSlot>[
  MealTimeSlot.breakfast,
  MealTimeSlot.preWorkout,
  MealTimeSlot.lunch,
  MealTimeSlot.snack,
  MealTimeSlot.postWorkout,
  MealTimeSlot.dinner,
];
