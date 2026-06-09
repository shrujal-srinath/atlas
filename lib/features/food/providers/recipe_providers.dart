import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/recipe_repository.dart';
import '../domain/food.dart';

final recipeRepositoryProvider =
    Provider<RecipeRepository>((_) => RecipeRepository());

/// All user recipes (source='recipe').
final userRecipesProvider = FutureProvider.autoDispose<List<Food>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.listRecipes();
});
