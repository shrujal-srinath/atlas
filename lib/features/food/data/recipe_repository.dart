import '../../../shared/services/supabase_service.dart';
import '../domain/food.dart';
import '../domain/recipe.dart';

/// CRUD for recipes. A recipe lives in two tables:
///   `foods`  — one row with source='recipe', per-serving nutrients
///   `recipe_ingredients` — one row per ingredient, FK to both recipe & ingredient food
class RecipeRepository {
  /// All recipes owned by the current user.
  Future<List<Food>> listRecipes() async {
    final rows = await SupabaseService.client
        .from('foods')
        .select()
        .eq('source', 'recipe')
        .order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Food.fromJson)
        .toList();
  }

  /// Load full ingredient list for a recipe (by its foods.id).
  Future<List<RecipeIngredient>> loadIngredients(String recipeFoodId) async {
    final rows = await SupabaseService.client
        .from('recipe_ingredients')
        .select('*, ingredient_food:foods!recipe_ingredients_ingredient_food_id_fkey(*)')
        .eq('recipe_food_id', recipeFoodId)
        .order('order_idx');
    return (rows as List).cast<Map<String, dynamic>>().map((r) {
      final foodJson = r['ingredient_food'] as Map<String, dynamic>;
      return RecipeIngredient(
        id: r['id'] as String,
        food: Food.fromJson(foodJson),
        qty: (r['qty'] as num).toDouble(),
        unit: r['unit'] as String? ?? 'g',
      );
    }).toList();
  }

  /// Save a new recipe or update an existing one.
  /// Returns the Food row representing the recipe.
  Future<Food> saveRecipe(Recipe recipe) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final perServing = recipe.perServing;

    if (recipe.id != null) {
      return _updateRecipe(recipe, userId, perServing);
    }
    return _createRecipe(recipe, userId, perServing);
  }

  Future<Food> _createRecipe(
      Recipe recipe, String userId, Nutrients perServing) async {
    // 1. Insert the foods row.
    final foodRow = await SupabaseService.client
        .from('foods')
        .insert({
          'user_id': userId,
          'source': 'recipe',
          'name': recipe.name,
          'serving_qty': recipe.servingGrams,
          'serving_unit': 'g',
          ...perServing.toColumns(),
        })
        .select()
        .single();
    final foodId = foodRow['id'] as String;

    // 2. Insert ingredient rows.
    await _insertIngredients(foodId, recipe.ingredients);

    return Food.fromJson(foodRow);
  }

  Future<Food> _updateRecipe(
      Recipe recipe, String userId, Nutrients perServing) async {
    final foodId = recipe.id!;

    // 1. Update food row nutrients.
    final foodRow = await SupabaseService.client
        .from('foods')
        .update({
          'name': recipe.name,
          'serving_qty': recipe.servingGrams,
          ...perServing.toColumns(),
        })
        .eq('id', foodId)
        .select()
        .single();

    // 2. Replace ingredients: delete old, insert new.
    await SupabaseService.client
        .from('recipe_ingredients')
        .delete()
        .eq('recipe_food_id', foodId);
    await _insertIngredients(foodId, recipe.ingredients);

    return Food.fromJson(foodRow);
  }

  Future<void> _insertIngredients(
      String recipeFoodId, List<RecipeIngredient> ingredients) async {
    if (ingredients.isEmpty) return;
    final userId = SupabaseService.auth.currentUser!.id;

    // Ensure all ingredient foods are materialised (have an id in foods table).
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < ingredients.length; i++) {
      final ing = ingredients[i];
      final ingFoodId = await _ensureFoodExists(ing.food, userId);
      rows.add({
        'recipe_food_id': recipeFoodId,
        'ingredient_food_id': ingFoodId,
        'qty': ing.qty,
        'unit': ing.unit,
        'order_idx': i,
      });
    }
    await SupabaseService.client.from('recipe_ingredients').insert(rows);
  }

  /// Make sure a food exists in the foods table and return its UUID.
  Future<String> _ensureFoodExists(Food food, String userId) async {
    // If it's an OFF food, check by barcode first.
    if (food.source == 'off' && food.offBarcode != null) {
      final existing = await SupabaseService.client
          .from('foods')
          .select('id')
          .eq('off_barcode', food.offBarcode!)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;
      final ins = await SupabaseService.client
          .from('foods')
          .insert(food.toInsert()..['user_id'] = userId)
          .select('id')
          .single();
      return ins['id'] as String;
    }
    // Custom or already-saved food — id should be a valid UUID.
    return food.id;
  }

  /// Delete a recipe and its ingredients.
  Future<void> deleteRecipe(String foodId) async {
    await SupabaseService.client
        .from('recipe_ingredients')
        .delete()
        .eq('recipe_food_id', foodId);
    await SupabaseService.client
        .from('foods')
        .delete()
        .eq('id', foodId);
  }
}
