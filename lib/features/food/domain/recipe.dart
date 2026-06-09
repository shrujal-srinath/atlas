import 'food.dart';

/// A recipe ingredient — links a food item with a quantity.
class RecipeIngredient {
  final String? id;           // null when building locally before save
  final Food food;
  final double qty;           // in food.servingUnit
  final String unit;

  const RecipeIngredient({
    this.id,
    required this.food,
    required this.qty,
    required this.unit,
  });

  /// Nutrients contributed by this ingredient.
  Nutrients get nutrients {
    final factor = food.servingQty == 0 ? 1.0 : qty / food.servingQty;
    return food.per.scale(factor);
  }

  RecipeIngredient copyWith({double? qty, String? unit}) => RecipeIngredient(
        id: id,
        food: food,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
      );
}

/// In-memory recipe being built / edited.
/// Stored in DB as a `foods` row (source='recipe') + `recipe_ingredients` rows.
class Recipe {
  final String? id;           // foods.id — null before first save
  final String name;
  final int servings;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    this.id,
    required this.name,
    required this.servings,
    required this.ingredients,
  });

  /// Sum of all ingredient nutrients (total batch).
  Nutrients get totalNutrients => ingredients.fold<Nutrients>(
        Nutrients.zero,
        (acc, ing) => acc + ing.nutrients,
      );

  /// Per-serving nutrients (what gets stored on the foods row).
  Nutrients get perServing =>
      servings <= 0 ? totalNutrients : totalNutrients.scale(1 / servings);

  /// Total weight of the batch in grams (approximate).
  double get totalGrams =>
      ingredients.fold<double>(0, (acc, ing) => acc + ing.qty);

  /// Per-serving weight.
  double get servingGrams => servings <= 0 ? totalGrams : totalGrams / servings;

  Recipe copyWith({
    String? name,
    int? servings,
    List<RecipeIngredient>? ingredients,
  }) =>
      Recipe(
        id: id,
        name: name ?? this.name,
        servings: servings ?? this.servings,
        ingredients: ingredients ?? this.ingredients,
      );
}
