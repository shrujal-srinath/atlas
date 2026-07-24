import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/services/hive_service.dart';
import '../../../shared/services/offline_writer.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/sync_queue.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
import 'off_client.dart';

/// Reads/writes food data. Single entry-point used by Riverpod providers.
///
/// Search merges the user's own foods + the curated `food_catalog`
/// (IFCT/USDA, fuzzy + full micros, via the `search_foods` RPC) + Open Food
/// Facts (branded/packaged). Logging always inserts a `food_logs` row,
/// optionally mirroring the source food into `foods` so it gets a UUID.
/// Normalized cache key for a search call — case-insensitive, trimmed, and
/// limit-aware so a wider request never reuses a narrower cached result.
String searchCacheKey(String query, int limit) =>
    '${query.trim().toLowerCase()}|$limit';

/// Tiny bounded LRU. Most-recently-used entries survive; the oldest is evicted
/// once [capacity] is exceeded.
class _LruCache<K, V> {
  _LruCache(this.capacity);
  final int capacity;
  final _map = <K, V>{};

  V? get(K key) {
    final v = _map.remove(key);
    if (v == null) return null;
    _map[key] = v; // reinsert → marks most-recently-used
    return v;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > capacity) _map.remove(_map.keys.first);
  }
}

class FoodRepository {
  final OffClient off;
  FoodRepository({OffClient? off}) : off = off ?? OffClient();

  static const _uuid = Uuid();

  // Session caches over the *immutable* search layers — the curated catalog RPC
  // and Open Food Facts. Repeat / backspace queries return instantly without a
  // round-trip. The user's own foods are intentionally NOT cached here (they're
  // merged live in [searchCatalog]) so a newly added food shows up immediately.
  final _catalogCache = _LruCache<String, List<Food>>(30);
  final _brandedCache = _LruCache<String, List<Food>>(30);

  // ── reads ──────────────────────────────────────────────────────────

  /// Primary, fast result set: the user's own foods + the curated catalog,
  /// fetched in parallel (~one indexed DB round-trip each, well under ~150 ms).
  /// Deliberately excludes the slow Open Food Facts call so the UI can render
  /// instantly; branded results stream in afterwards via [searchBranded].
  Future<List<Food>> searchCatalog(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final results = await Future.wait<List<Food>>([
      _userFoods(q),
      _catalog(q, limit),
    ]);
    return _dedup([...results[0], ...results[1]]).take(limit).toList();
  }

  /// Branded / packaged items from Open Food Facts. Remote and slow, so the
  /// search UI loads this as a second pass and appends it below the catalog.
  Future<List<Food>> searchBranded(String query, {int limit = 15}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final key = searchCacheKey(q, limit);
    final cached = _brandedCache.get(key);
    if (cached != null) return cached;
    final res = await off.search(q, limit: limit);
    _brandedCache.put(key, res);
    return res;
  }

  Future<List<Food>> _userFoods(String q) async {
    try {
      final local = await SupabaseService.client
          .from('foods')
          .select()
          .ilike('name', '%$q%')
          .limit(8);
      return (local as List)
          .cast<Map<String, dynamic>>()
          .map(Food.fromJson)
          .toList();
    } catch (_) {
      return const []; // dev mode / offline
    }
  }

  Future<List<Food>> _catalog(String q, int limit) async {
    try {
      return await catalogSearch(q, limit: limit);
    } catch (e, s) {
      // A failure here silently degrades to OFF-only results, so be loud.
      if (kDebugMode) debugPrint('catalog search RPC failed: $e\n$s');
      return const [];
    }
  }

  static List<Food> _dedup(List<Food> foods) {
    final seen = <String>{};
    final out = <Food>[];
    for (final f in foods) {
      if (seen.add('${f.brand ?? ''}|${f.name.toLowerCase()}')) out.add(f);
    }
    return out;
  }

  /// Fuzzy search over the curated `food_catalog` via the `search_foods` RPC.
  /// Typo-tolerant (pg_trgm), alias-aware, ranked by relevance + popularity.
  /// Public-read, so this works in dev mode (anon) too.
  Future<List<Food>> catalogSearch(String query, {int limit = 25}) async {
    final key = searchCacheKey(query, limit);
    final cached = _catalogCache.get(key);
    if (cached != null) return cached;
    final res = await SupabaseService.client.rpc(
      'search_foods',
      params: {'q': query, 'lim': limit},
    );
    final foods = (res as List)
        .cast<Map<String, dynamic>>()
        .map(Food.fromCatalog)
        .toList();
    _catalogCache.put(key, foods);
    return foods;
  }

  /// Resolve a scanned [code]: our catalog first (instant — bulk-imported OFF
  /// India products + previously-cached scans), then a live Open Food Facts
  /// lookup whose result is written back into the catalog so the next scan of
  /// the same product is instant and branded coverage compounds with use.
  Future<Food?> foodByBarcode(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;
    // 1) local catalog — fast, offline-friendly.
    try {
      final row = await SupabaseService.client
          .from('food_catalog')
          .select()
          .eq('barcode', clean)
          .limit(1)
          .maybeSingle();
      if (row != null) return Food.fromCatalog(row);
    } catch (_) {}
    // 2) live Open Food Facts fallback.
    final hit = await off.byBarcode(clean);
    // 3) write-through cache (best-effort; needs auth — RLS limits to off rows).
    if (hit != null) {
      try {
        await _cacheBranded(hit);
      } catch (_) {}
    }
    return hit;
  }

  /// Cache a freshly-scanned branded product into the shared catalog via the
  /// `cache_branded_food` RPC (SECURITY DEFINER — see
  /// `20260724_food_catalog_rpc.sql`). `food_catalog` is a table every
  /// user's search reads from; a direct client upsert let any authenticated
  /// user overwrite any other user's cached row with unvalidated values, so
  /// the id/source/barcode/search_text are now derived server-side and
  /// every numeric field is range-clamped there — this call just forwards
  /// what the client saw.
  Future<void> _cacheBranded(Food f) async {
    final code = f.offBarcode;
    if (code == null || code.isEmpty) return;
    await SupabaseService.client.rpc(
      'cache_branded_food',
      params: {
        'payload': {
          'barcode': code,
          'name': f.name,
          if (f.brand != null) 'brand': f.brand,
          'serving_qty': 100,
          'serving_unit': 'g',
          ...f.per.toColumns(),
          // Persist the food's own measures (parsed from OFF's serving size) so the
          // cached row defaults to the same "1 Serving"/"1 Pack" as the live scan.
          'measures': f.measures.isNotEmpty
              ? [
                  for (final m in f.measures)
                    {'label': m.label, 'g': m.grams},
                ]
              : const [
                  {'label': 'g', 'g': 1},
                  {'label': 'Pack', 'g': 50},
                ],
        },
      },
    );
  }

  /// The user's most-logged foods over the last [days] days, with their log
  /// counts — powers personalised ranking (your frequent picks float to the
  /// top of matching searches). Empty in dev mode / when nothing's logged.
  Future<List<FrequentFood>> frequentFoods({
    int days = 90,
    int limit = 40,
  }) async {
    final start = _dateStr(DateTime.now().subtract(Duration(days: days)));
    final rows = await SupabaseService.client
        .from('food_logs')
        .select('food_id')
        .not('food_id', 'is', null)
        .gte('date', start);
    final counts = <String, int>{};
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final id = r['food_id'] as String?;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return const [];
    final top =
        (counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!)))
            .take(limit)
            .toList();
    final foods = await SupabaseService.client
        .from('foods')
        .select()
        .inFilter('id', top);
    final map = {
      for (final f in (foods as List).cast<Map<String, dynamic>>())
        f['id'] as String: Food.fromJson(f),
    };
    return [
      for (final id in top)
        if (map[id] != null) FrequentFood(map[id]!, counts[id]!),
    ];
  }

  Future<List<Food>> recents({int limit = 20}) async {
    // Distinct foods from the user's most recent food_logs.
    final rows = await SupabaseService.client
        .from('food_logs')
        .select(
          'food_id, meal_name, calories, protein, carbs, fat, unit, created_at',
        )
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
      for (final f in (foods as List).cast<Map<String, dynamic>>())
        f['id'] as String: Food.fromJson(f),
    };
    return [
      for (final id in ids)
        if (map[id] != null) map[id]!,
    ];
  }

  Future<List<Food>> favorites() async {
    final rows = await SupabaseService.client
        .from('foods')
        .select()
        .eq('is_favorite', true)
        .order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Food.fromJson)
        .toList();
  }

  // ── writes ─────────────────────────────────────────────────────────

  /// Ensure a non-custom food (OFF or catalog) is mirrored into `foods` and
  /// return its UUID, so logs can reference a real `food_id` and the food shows
  /// up in Recents/Favorites. Custom foods/recipes already live in `foods`.
  /// Idempotent per user on `off_barcode` (OFF) or `catalog_id` (IFCT/USDA).
  Future<String> _materialise(Food f) async {
    final isOff = f.source == 'off' && f.offBarcode != null;
    final isCatalog = f.catalogId != null;
    if (!isOff && !isCatalog) {
      // Custom food — caller already inserted it; its id is a real UUID.
      return f.id;
    }
    final userId = SupabaseService.auth.currentUser!.id;
    try {
      final dedup = SupabaseService.client
          .from('foods')
          .select('id')
          .eq('user_id', userId);
      final existing =
          await (isOff
                  ? dedup.eq('off_barcode', f.offBarcode!)
                  : dedup.eq('catalog_id', f.catalogId!))
              .maybeSingle();
      if (existing != null) return existing['id'] as String;

      final insert = await SupabaseService.client
          .from('foods')
          .insert(f.toInsert()..['user_id'] = userId)
          .select('id')
          .single();
      return insert['id'] as String;
    } catch (_) {
      // Offline / transient: mint a client UUID and queue the foods row so the
      // food_logs row below can still reference it. Dedup is skipped while
      // offline (worst case: a duplicate foods cache row on reconnect).
      final id = _uuid.v4();
      await OfflineWriter.insert(
        table: 'foods',
        payload: f.toInsert()
          ..['user_id'] = userId
          ..['id'] = id,
      );
      return id;
    }
  }

  /// Resolve [food] to a real `foods` UUID (mirroring catalog/OFF foods into
  /// `foods` if needed). Used when building a habit food link so the snapshot
  /// references a real `food_id` and still feeds Recents/frequent ranking.
  /// Returns null if resolution fails (link still logs by name + snapshot).
  Future<String?> ensureFoodId(Food food) async {
    try {
      return await _materialise(food);
    } catch (_) {
      return null;
    }
  }

  /// Log a portion of [food] at [slot] on [date]. [qty] is the amount in grams
  /// (it scales the nutrients). [displayQty]/[displayUnit] are the human-facing
  /// portion to store and show in the diary (e.g. 1 "Cup") — defaulting to the
  /// gram amount so callers that don't care keep the old behaviour.
  Future<MealEntry> logFood({
    required Food food,
    required double qty,
    required MealTimeSlot slot,
    required DateTime date,
    double? displayQty,
    String? displayUnit,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final foodId = await _materialise(food);

    // Scale = qty ÷ servingQty (both in grams).
    final factor = food.servingQty == 0 ? 1.0 : qty / food.servingQty;
    final scaled = food.per.scale(factor);

    final row = MealEntry(
      id: '',
      userId: userId,
      foodId: foodId,
      name: food.displayLine,
      date: date,
      slot: slot,
      qty: displayQty ?? qty,
      unit: displayUnit ?? food.servingUnit,
      totals: scaled,
    );
    final inserted = await OfflineWriter.insert(
      table: 'food_logs',
      payload: row.toInsert(),
    );
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
    final inserted = await OfflineWriter.insert(
      table: 'food_logs',
      payload: row.toInsert(),
    );
    return MealEntry.fromJson(inserted);
  }

  Future<void> deleteEntry(String id) async {
    await OfflineWriter.delete(table: 'food_logs', id: id);
  }

  /// Edit a logged entry's [newQty] and/or [newSlot]. Macros + micros are
  /// recomputed proportionally from the stored per-quantity snapshot (no need
  /// to refetch the source food). Offline-safe via [OfflineWriter].
  Future<MealEntry> updateEntry({
    required MealEntry entry,
    required double newQty,
    required MealTimeSlot newSlot,
  }) async {
    final factor = entry.qty == 0 ? 1.0 : newQty / entry.qty;
    final scaled = entry.totals.scale(factor);
    await OfflineWriter.update(
      table: 'food_logs',
      id: entry.id,
      payload: {
        'meal_time': newSlot.dbValue,
        'quantity': newQty,
        'calories': scaled.kcal,
        'protein': scaled.proteinG,
        'carbs': scaled.carbsG,
        'fat': scaled.fatG,
        'micros': scaled.toMicrosJson(),
      },
    );
    return MealEntry(
      id: entry.id,
      userId: entry.userId,
      foodId: entry.foodId,
      name: entry.name,
      date: entry.date,
      slot: newSlot,
      qty: newQty,
      unit: entry.unit,
      totals: scaled,
    );
  }

  /// Toggle favorite flag on a food already in `foods` (by id).
  Future<void> toggleFavorite(String foodId, bool value) async {
    await SupabaseService.client
        .from('foods')
        .update({'is_favorite': value})
        .eq('id', foodId);
  }

  /// Favourite/unfavourite any [food]. Catalog (IFCT/USDA/dish) and OFF foods
  /// are first mirrored into `foods` so they have a row to flag (and then show
  /// up in Favourites + Recents). Works for every source — no need to log first.
  Future<void> setFavorite(Food food, bool value) async {
    final id = await _materialise(food);
    await SupabaseService.client
        .from('foods')
        .update({'is_favorite': value})
        .eq('id', id);
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
    // Per-row offline-aware inserts so a copy made offline survives an outage.
    for (final e in slotEntries) {
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
      await OfflineWriter.insert(table: 'food_logs', payload: copy.toInsert());
    }
  }

  // ── habit food links ───────────────────────────────────────────────

  /// Auto-log a task's food link onto [date]. Reads the raw `food_link` jsonb
  /// (`{ slot, items: [{food_id?, name, qty, unit, calories, protein, carbs,
  /// fat, micros}] }`) — item nutrients are an already-scaled snapshot, so this
  /// is just an insert (mirrors [MealBundleRepository.logBundle]).
  ///
  /// Idempotent: any prior auto-logs for this habit+date are cleared first, so
  /// double-completing never duplicates rows.
  Future<void> logHabitLink({
    required String habitId,
    required Map<String, dynamic> link,
    required DateTime date,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final ds = _dateStr(date);
    final slot = link['slot'] as String? ?? 'snack';
    final items =
        (link['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    final rows = items.map((it) {
      final micros =
          (it['micros'] as Map?)?.cast<String, dynamic>() ?? const {};
      return {
        'user_id': userId,
        if (it['food_id'] != null) 'food_id': it['food_id'],
        'meal_name': it['name'] as String? ?? 'Food',
        'date': ds,
        'meal_time': slot,
        'calories': (it['calories'] as num?)?.toDouble() ?? 0,
        'protein': (it['protein'] as num?)?.toDouble() ?? 0,
        'carbs': (it['carbs'] as num?)?.toDouble() ?? 0,
        'fat': (it['fat'] as num?)?.toDouble() ?? 0,
        'quantity': (it['qty'] as num?)?.toDouble() ?? 1,
        'unit': it['unit'] as String? ?? 'g',
        'logged_via': 'habit',
        'source_habit_id': habitId,
        'micros': micros,
      };
    }).toList();

    await removeHabitLink(habitId: habitId, date: date);
    if (rows.isNotEmpty) {
      await SupabaseService.client.from('food_logs').insert(rows);
    }
  }

  /// Remove the food entries a task auto-logged on [date] (on un-complete).
  Future<void> removeHabitLink({
    required String habitId,
    required DateTime date,
  }) async {
    await SupabaseService.client
        .from('food_logs')
        .delete()
        .eq('source_habit_id', habitId)
        .eq('date', _dateStr(date));
  }

  // ── water log ──────────────────────────────────────────────────────

  Future<int> waterForDate(DateTime d) async {
    final ds = _dateStr(d);
    final rows = await SupabaseService.client
        .from('water_logs')
        .select('ml')
        .eq('date', ds);
    return (rows as List).fold<int>(
      0,
      (a, r) => a + ((r['ml'] as num?)?.toInt() ?? 0),
    );
  }

  Future<void> addWater(int ml, DateTime date) async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return; // no session (demo/offline) — nothing to persist
    await OfflineWriter.insert(
      table: 'water_logs',
      payload: {'user_id': user.id, 'date': _dateStr(date), 'ml': ml},
    );
  }

  /// Best-effort removal of the most recent water entry today. Reads the
  /// latest entry (online only — offline removal of an unsynced row is
  /// out of scope), then offline-aware deletes it.
  Future<void> removeLastWater(DateTime date) async {
    final ds = _dateStr(date);
    try {
      final last = await SupabaseService.client
          .from('water_logs')
          .select('id')
          .eq('date', ds)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (last != null) {
        await OfflineWriter.delete(
          table: 'water_logs',
          id: last['id'] as String,
        );
      }
    } catch (_) {
      // Offline — silently no-op. User can remove from their offline log on next reconnect.
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// All entries for a given diary date.
  ///
  /// Read-through the `food_logs_cache` Hive box + the pending `SyncQueue`
  /// (SR-1): a fetch failure (offline) falls back to the last-good cached
  /// rows instead of surfacing an error/empty diary, and — success or
  /// failure — any not-yet-synced insert/update/delete for this date is
  /// merged in, so a meal logged (or removed) while offline never
  /// "vanishes" until the queue happens to drain.
  Future<List<MealEntry>> entriesForDate(DateTime d) async {
    final ds = _dateStr(d);
    final cacheKey = 'byDate:$ds';
    List<Map<String, dynamic>> rows;
    try {
      final fetched = await SupabaseService.client
          .from('food_logs')
          .select()
          .eq('date', ds)
          .order('created_at');
      rows = (fetched as List).cast<Map<String, dynamic>>();
      unawaited(HiveService.put(HiveService.foodLogsBox, cacheKey, rows));
      unawaited(HiveService.stamp(HiveService.foodLogsBox, cacheKey));
    } catch (_) {
      final cached = HiveService.get<List>(HiveService.foodLogsBox, cacheKey);
      rows = cached == null
          ? const []
          : cached
              .cast<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
    }
    final merged = _mergePendingFoodLogOps(rows, ds);
    return merged.map(MealEntry.fromJson).toList();
  }

  /// Overlays pending `food_logs` [SyncQueue] ops onto [base] rows for date
  /// [ds]: unsynced inserts appear, unsynced updates patch in place, unsynced
  /// deletes are hidden — whether [base] came from a live fetch or the cache.
  List<Map<String, dynamic>> _mergePendingFoodLogOps(
    List<Map<String, dynamic>> base,
    String ds,
  ) {
    final ops = SyncQueue.instance.pendingOpsFor('food_logs');
    if (ops.isEmpty) return base;
    final byId = {
      for (final r in base)
        if (r['id'] is String) r['id'] as String: r,
    };
    for (final op in ops) {
      switch (op.op) {
        case 'insert':
          if (op.payload['date'] == ds) {
            final id = op.payload['id'] as String?;
            if (id != null) byId[id] = op.payload;
          }
        case 'update':
          final id = op.matchId;
          if (id != null && byId.containsKey(id)) {
            byId[id] = {...byId[id]!, ...op.payload};
          }
        case 'delete':
          if (op.matchId != null) byId.remove(op.matchId);
      }
    }
    return byId.values.toList();
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
    final inserted = await OfflineWriter.insert(
      table: 'food_logs',
      payload: row.toInsert(),
    );
    return MealEntry.fromJson(inserted);
  }
}

/// One row in the quick-log chips strip.
class SlotHistoryItem {
  final MealEntry template;
  final int useCount;
  const SlotHistoryItem({required this.template, required this.useCount});
}

/// A food the user logs often, with its recent log count — used to personalise
/// search ranking (frequent picks are pinned above generic catalog matches).
class FrequentFood {
  final Food food;
  final int count;
  const FrequentFood(this.food, this.count);
}
