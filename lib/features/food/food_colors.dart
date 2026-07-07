import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Canonical food-domain colours — ONE source of truth for nutrient + water
/// colours so every food surface (diary, meals, insights, goals, reveal) tells
/// the same visual story.
///
/// Protein = orange, Carbs = amber, Fat = violet, Fiber = green, Water = blue,
/// Calories = ruby. Two prior inconsistencies are resolved here: water used to
/// be orange (clashing with protein) and fat drifted between blue and violet.
extension FoodPalette on AppPalette {
  Color get proteinColor => athletic; // warm orange
  Color get carbsColor => amber;
  Color get fatColor => body; // violet
  Color get fiberColor => positive; // green
  Color get waterColor => mind; // blue
  Color get caloriesColor => accent; // ruby
}
