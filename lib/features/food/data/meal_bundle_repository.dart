import '../../../shared/services/supabase_service.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_bundle.dart';
import '../domain/meal_entry.dart';

/// Reads/writes meal bundles — saved combos of food items that can be re-logged
/// as a group.
class MealBundleRepository {
  /// All bundles for the current user, most recent first.
  Future<List<MealBundle>> list() async {
    final rows = await SupabaseService.client
        .from('meal_bundles')
        .select('*, items:meal_bundle_items(*, food:foods!meal_bundle_items_food_id_fkey(*))')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>().map(_parseBundle).toList();
  }

  MealBundle _parseBundle(Map<String, dynamic> row) {
    final itemsJson = (row['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return MealBundle(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      items: itemsJson.map((r) {
        final food = r['food'] as Map<String, dynamic>?;
        return MealBundleItem(
          id: r['id'] as String,
          foodId: r['food_id'] as String,
          foodName: food?['name'] as String? ?? 'Unknown',
          qty: (r['qty'] as num).toDouble(),
          unit: r['unit'] as String? ?? 'g',
          perServing: food != null ? Nutrients.fromColumns(food) : Nutrients.zero,
          servingQty: (food?['serving_qty'] as num?)?.toDouble() ?? 100,
        );
      }).toList(),
    );
  }

  /// Save current slot entries as a named bundle.
  Future<MealBundle> saveFromEntries({
    required String name,
    required List<MealEntry> entries,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;

    // 1. Create bundle header.
    final bundle = await SupabaseService.client
        .from('meal_bundles')
        .insert({'user_id': userId, 'name': name})
        .select()
        .single();
    final bundleId = bundle['id'] as String;

    // 2. Insert items.
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.foodId == null) continue; // skip quick-adds
      items.add({
        'bundle_id': bundleId,
        'food_id': e.foodId,
        'qty': e.qty,
        'unit': e.unit,
        'order_idx': i,
      });
    }
    if (items.isNotEmpty) {
      await SupabaseService.client.from('meal_bundle_items').insert(items);
    }

    // Reload the full bundle with food joins.
    final full = await SupabaseService.client
        .from('meal_bundles')
        .select('*, items:meal_bundle_items(*, food:foods!meal_bundle_items_food_id_fkey(*))')
        .eq('id', bundleId)
        .single();
    return _parseBundle(full);
  }

  /// Log all items in a bundle as food_logs at the given slot and date.
  Future<void> logBundle({
    required MealBundle bundle,
    required MealTimeSlot slot,
    required DateTime date,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final ds = _dateStr(date);
    final rows = bundle.items.map((item) {
      final scaled = item.scaledNutrients;
      return {
        'user_id': userId,
        'food_id': item.foodId,
        'meal_name': item.foodName,
        'date': ds,
        'meal_time': slot.dbValue,
        'calories': scaled.kcal,
        'protein': scaled.proteinG,
        'carbs': scaled.carbsG,
        'fat': scaled.fatG,
        'quantity': item.qty,
        'unit': item.unit,
        'logged_via': 'bundle',
        'micros': scaled.toMicrosJson(),
      };
    }).toList();
    if (rows.isNotEmpty) {
      await SupabaseService.client.from('food_logs').insert(rows);
    }
  }

  /// Delete a bundle and its items.
  Future<void> delete(String bundleId) async {
    await SupabaseService.client
        .from('meal_bundle_items')
        .delete()
        .eq('bundle_id', bundleId);
    await SupabaseService.client
        .from('meal_bundles')
        .delete()
        .eq('id', bundleId);
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
