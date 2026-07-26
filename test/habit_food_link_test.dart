import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/food/domain/food.dart';
import 'package:atlas/features/habits/models/habit_food_link.dart';
import 'package:atlas/shared/models/models.dart';

void main() {
  group('HabitFoodLink.fromRaw', () {
    test('a Fixed link with items parses normally', () {
      final raw = {
        'slot': 'breakfast',
        'items': [
          {'name': 'Oats', 'qty': 1.0, 'unit': 'bowl', 'calories': 300},
        ],
      };
      final link = HabitFoodLink.fromRaw(raw);
      expect(link, isNotNull);
      expect(link!.isFlexible, isFalse);
      expect(link.items, hasLength(1));
      expect(link.slot, MealTimeSlot.breakfast);
    });

    test('a Flexible link (zero items) parses instead of being discarded', () {
      // Regression: fromRaw used to treat items.isEmpty as "no link at all"
      // and return null, silently dropping every Flexible link ever saved.
      final raw = {'slot': 'snack', 'items': const [], 'is_flexible': true};
      final link = HabitFoodLink.fromRaw(raw);
      expect(link, isNotNull);
      expect(link!.isFlexible, isTrue);
      expect(link.items, isEmpty);
      expect(link.slot, MealTimeSlot.snack);
    });

    test('zero items and no is_flexible flag is still "no link"', () {
      final raw = {'slot': 'snack', 'items': const []};
      expect(HabitFoodLink.fromRaw(raw), isNull);
    });

    test('null raw is "no link"', () {
      expect(HabitFoodLink.fromRaw(null), isNull);
    });
  });

  group('HabitFoodLink.toJson round-trip', () {
    test('a Flexible link survives a save/reload cycle', () {
      const link = HabitFoodLink(
        slot: MealTimeSlot.breakfast,
        items: [],
        isFlexible: true,
      );
      final reparsed = HabitFoodLink.fromRaw(link.toJson());
      expect(reparsed, isNotNull);
      expect(reparsed!.isFlexible, isTrue);
      expect(reparsed.items, isEmpty);
      expect(reparsed.slot, MealTimeSlot.breakfast);
    });

    test('a Fixed link does not emit is_flexible', () {
      const link = HabitFoodLink(
        slot: MealTimeSlot.snack,
        items: [
          HabitFoodLinkItem(
            foodId: null,
            name: 'Milkshake',
            qty: 1,
            unit: 'serving',
            totals: Nutrients(kcal: 450),
          ),
        ],
      );
      expect(link.toJson().containsKey('is_flexible'), isFalse);
    });
  });
}
