import '../../../shared/services/supabase_service.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
import 'local_food_index.dart';
import 'off_client.dart';

/// Reads/writes food data. Single entry-point used by Riverpod providers.
///
/// Search merges local custom foods + Open Food Facts results, de-duped
/// by display name. Logging always inserts a `food_logs` row, optionally
/// caching the OFF food into `foods` so it gets a UUID for future linking.
class FoodRepository {
  final OffClient off;
  FoodRepository({OffClient? off}) : off = off ?? OffClient();

  // ── reads ──────────────────────────────────────────────────────────

  Future<List<Food>> search(String query, {int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    // 1) Custom + favorite foods first — user's own data is always most relevant.
    List<Food> userFoods = const [];
    try {
      final local = await SupabaseService.client
          .from('foods')
          .select()
          .ilike('name', '%$q%')
          .limit(10);
      userFoods = (local as List)
          .cast<Map<String, dynamic>>()
          .map(Food.fromJson)
          .toList();
    } catch (_) {
      // Dev mode or offline — no user foods.
    }

    // 2) Bundled Indian foods catalog (in-memory, sub-50ms, free, offline).
    final indianFoods =
        await LocalFoodIndex.instance.search(q, limit: limit);

    // 3) Open Food Facts (network) for branded / packaged items not in the
    //    local catalog. Best-effort: if it fails, the local results still ship.
    List<Food> remote = const [];
    try {
      remote = await off.search(q, limit: limit);
    } catch (_) {}

    // Merge with priority: user > bundled > OFF. Dedup by display name.
    final seen = <String>{};
    final out = <Food>[];
    for (final f in [...userFoods, ...indianFoods, ...remote]) {
      final key = '${f.brand ?? ''}|${f.name.toLowerCase()}';
      if (seen.add(key)) out.add(f);
    }
    return out.take(limit).toList();
  }

  Future<List<Food>> recents({int limit = 20}) async {
    // Distinct foods from the user's most recent food_logs.
    final rows = await SupabaseService.client
        .from('food_logs')
        .select('food_id, meal_name, calories, protein, carbs, fat, unit, created_at')
        .not('food_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit * 3);
    final seen = <String>{};
    final ids = <String>[];
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final id = r['food_id'] as String?;
      if (id != null && seen.add(id)) ids.add(id);
      if (ids.length >= limit) break;
    }
    if (ids.isEmpty) return const [];
    final foods = await SupabaseService.client
        .from('foods')
        .select()
        .inFilter('id', ids);
    final map = {
      for (final f in (foods as List).cast<Map<String, dynamic>>()) f['id'] as String: Food.fromJson(f)
    };
    return [for (final id in ids) if (map[id] != null) map[id]!];
  }

  Future<List<Food>> favorites() async {
    final rows = await SupabaseService.client
        .from('foods')
        .select()
        .eq('is_favorite', true)
        .order('name');
    return (rows as List).cast<Map<String, dynamic>>().map(Food.fromJson).toList();
  }

  // ── writes ─────────────────────────────────────────────────────────

  /// Ensure an OFF food is mirrored into `foods` and return its UUID.
  /// Idempotent on (off_barcode) — won't duplicate.
  Future<String> _materialise(Food f) async {
    if (f.source != 'off' || f.offBarcode == null) {
      // Custom food — caller must have inserted it already; return id.
      return f.id;
    }
    final existing = await SupabaseService.client
        .from('foods')
        .select('id')
        .eq('off_barcode', f.offBarcode!)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final userId = SupabaseService.auth.currentUser!.id;
    final insert = await SupabaseService.client
        .from('foods')
        .insert(f.toInsert()..['user_id'] = userId)
        .select('id')
        .single();
    return insert['id'] as String;
  }

  /// Log a portion of [food] (= [qty] of `food.servingUnit`) at [slot] on [date].
  Future<MealEntry> logFood({
    required Food food,
    required double qty,
    required MealTimeSlot slot,
    required DateTime date,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final foodId = await _materialise(food);

    // Scale = qty ÷ servingQty (both in the same unit).
    final factor = food.servingQty == 0 ? 1.0 : qty / food.servingQty;
    final scaled = food.per.scale(factor);

    final row = MealEntry(
      id: '',
      userId: userId,
      foodId: foodId,
      name: food.displayLine,
      date: date,
      slot: slot,
      qty: qty,
      unit: food.servingUnit,
      totals: scaled,
    );
    final inserted = await SupabaseService.client
        .from('food_logs')
        .insert(row.toInsert())
        .select()
        .single();
    return MealEntry.fromJson(inserted);
  }

  /// Calorie-only quick-add.
  Future<MealEntry> quickAdd({
    required double kcal,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required MealTimeSlot slot,
    required DateTime date,
    String name = 'Quick add',
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final row = MealEntry(
      id: '',
      userId: userId,
      foodId: null,
      name: name,
      date: date,
      slot: slot,
      qty: 1,
      unit: 'serving',
      totals: Nutrients(
        kcal: kcal,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
      ),
    );
    final inserted = await SupabaseService.client
        .from('food_logs')
        .insert(row.toInsert())
        .select()
        .single();
    return MealEntry.fromJson(inserted);
  }

  Future<void> deleteEntry(String id) async {
    await SupabaseService.client.from('food_logs').delete().eq('id', id);
  }

  /// Toggle favorite flag on a food.
  Future<void> toggleFavorite(String foodId, bool value) async {
    await SupabaseService.client
        .from('foods')
        .update({'is_favorite': value})
        .eq('id', foodId);
  }

  /// Copy all entries from [srcSlot] on [srcDate] to [destSlot] on [destDate].
  Future<void> copyMeal({
    required MealTimeSlot srcSlot,
    required DateTime srcDate,
    required MealTimeSlot destSlot,
    required DateTime destDate,
  }) async {
    final entries = await entriesForDate(srcDate);
    final slotEntries = entries.where((e) => e.slot == srcSlot).toList();
    if (slotEntries.isEmpty) return;
    final userId = SupabaseService.auth.currentUser!.id;
    final rows = slotEntries.map((e) {
      final copy = MealEntry(
        id: '',
        userId: userId,
        foodId: e.foodId,
        name: e.name,
        date: destDate,
        slot: destSlot,
        qty: e.qty,
        unit: e.unit,
        totals: e.totals,
      );
      return copy.toInsert();
    }).toList();
    await SupabaseService.client.from('food_logs').insert(rows);
  }

  // ── water log ──────────────────────────────────────────────────────

  Future<int> waterForDate(DateTime d) async {
    final ds = _dateStr(d);
    final rows = await SupabaseService.client
        .from('water_logs')
        .select('ml')
        .eq('date', ds);
    return (rows as List).fold<int>(0, (a, r) => a + ((r['ml'] as num?)?.toInt() ?? 0));
  }

  Future<void> addWater(int ml, DateTime date) async {
    final userId = SupabaseService.auth.currentUser!.id;
    await SupabaseService.client.from('water_logs').insert({
      'user_id': userId,
      'date': _dateStr(date),
      'ml': ml,
    });
  }

  Future<void> removeLastWater(DateTime date) async {
    final ds = _dateStr(date);
    final last = await SupabaseService.client
        .from('water_logs')
        .select('id')
        .eq('date', ds)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (last != null) {
      await SupabaseService.client.from('water_logs').delete().eq('id', last['id']);
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// All entries for a given diary date.
  Future<List<MealEntry>> entriesForDate(DateTime d) async {
    final ds = _dateStr(d);
    final rows = await SupabaseService.client
        .from('food_logs')
        .select()
        .eq('date', ds)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(MealEntry.fromJson).toList();
  }

  /// Entries between [start] and [end] inclusive, bucketed by date-only.
  Future<Map<DateTime, List<MealEntry>>> entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await SupabaseService.client
        .from('food_logs')
        .select()
        .gte('date', _dateStr(start))
        .lte('date', _dateStr(end))
        .order('date');
    final out = <DateTime, List<MealEntry>>{};
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final e = MealEntry.fromJson(r);
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      (out[key] ??= []).add(e);
    }
    return out;
  }

  /// Top-N most-logged foods in [slot] across the last [days] days,
  /// each carrying the most-recent (qty, unit, totals) snapshot for one-shot re-logging.
  Future<List<SlotHistoryItem>> slotHistory(
    MealTimeSlot slot, {
    int days = 30,
    int limit = 3,
  }) async {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: days));
    final rows = await SupabaseService.client
        .from('food_logs')
        .select()
        .eq('meal_time', slot.dbValue)
        .gte('date', _dateStr(start))
        .order('created_at', ascending: false)
        .limit(120);

    final counts = <String, int>{};
    final latest = <String, MealEntry>{};
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final e = MealEntry.fromJson(r);
      // Key by food_id when available, else by name to dedupe quick-adds.
      final key = e.foodId ?? 'name:${e.name.toLowerCase()}';
      counts[key] = (counts[key] ?? 0) + 1;
      latest.putIfAbsent(key, () => e);
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [
      for (final k in keys.take(limit))
        SlotHistoryItem(template: latest[k]!, useCount: counts[k]!),
    ];
  }

  /// One-shot re-log: clone a previous entry's snapshot onto [date]+[slot].
  /// Bypasses the food_materialise path because the source entry already has a foodId.
  Future<MealEntry> relogFromTemplate({
    required MealEntry template,
    required MealTimeSlot slot,
    required DateTime date,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final row = MealEntry(
      id: '',
      userId: userId,
      foodId: template.foodId,
      name: template.name,
      date: date,
      slot: slot,
      qty: template.qty,
      unit: template.unit,
      totals: template.totals,
    );
    final inserted = await SupabaseService.client
        .from('food_logs')
        .insert(row.toInsert())
        .select()
        .single();
    return MealEntry.fromJson(inserted);
  }
}

/// One row in the quick-log chips strip.
class SlotHistoryItem {
  final MealEntry template;
  final int useCount;
  const SlotHistoryItem({required this.template, required this.useCount});
}
