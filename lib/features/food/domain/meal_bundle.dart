import 'food.dart';

/// A saved meal bundle — a named set of food items with quantities that can
/// be logged in one tap.
class MealBundle {
  final String id;
  final String name;
  final List<MealBundleItem> items;
  final DateTime createdAt;

  const MealBundle({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  /// Total nutrients across all items.
  Nutrients get totalNutrients => items.fold<Nutrients>(
        Nutrients.zero,
        (acc, item) => acc + item.scaledNutrients,
      );

  double get totalKcal => totalNutrients.kcal;
}

class MealBundleItem {
  final String id;
  final String foodId;
  final String foodName;
  final double qty;
  final String unit;
  final Nutrients perServing; // per servingQty of the food
  final double servingQty;

  const MealBundleItem({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.qty,
    required this.unit,
    required this.perServing,
    required this.servingQty,
  });

  Nutrients get scaledNutrients {
    final factor = servingQty == 0 ? 1.0 : qty / servingQty;
    return perServing.scale(factor);
  }
}
