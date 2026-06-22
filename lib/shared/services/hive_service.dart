import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Single source of truth for every Hive box in the app.
///
/// Boxes are opened once at boot via [HiveService.init] and re-used
/// for the lifetime of the process. Box reads return raw `Map<String, dynamic>`
/// (or null) — repositories own serialization to their domain types.
///
/// All values are stored as `dynamic` (Hive types) keyed by string. For lists
/// (e.g. all entries for a date), we use a single key `byDate:<yyyy-mm-dd>` →
/// `List<Map>` so a single read returns everything for that day.
class HiveService {
  HiveService._();

  /// Open Food Facts hits — `barcode → food json` + `_at` timestamp.
  /// TTL: 7 days.
  static const foodsBox = 'foods_cache';

  /// `food_logs` grouped by date.
  /// Key: `byDate:yyyy-mm-dd` → list of log json. TTL: 24h (re-fetched on read).
  static const foodLogsBox = 'food_logs_cache';

  /// `habits` — flat list of all the user's habits.
  /// Key: `all` → list of habit json. Forever (sync-on-mutation).
  static const habitsBox = 'habits_cache';

  /// `habit_logs` keyed by date. Forever.
  static const habitLogsBox = 'habit_logs_cache';

  /// `body_weight_logs` — full series, oldest → newest. Forever.
  static const weightLogsBox = 'weight_logs_cache';

  /// `water_logs` keyed by date. TTL: 24h.
  static const waterLogsBox = 'water_logs_cache';

  /// Outbound sync queue. List of pending mutations.
  /// Key: `pending` → list of `{id, op, table, payload, ts, retries}` maps.
  static const syncQueueBox = 'sync_queue';

  /// TTL keys for the cache freshness check. Repositories should call
  /// [isFresh] before relying on a cache value.
  static const _ttlPrefix = '_at:';

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static const _boxes = <String>[
    foodsBox,
    foodLogsBox,
    habitsBox,
    habitLogsBox,
    weightLogsBox,
    waterLogsBox,
    syncQueueBox,
  ];

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    for (final name in _boxes) {
      try {
        await Hive.openBox(name);
      } catch (e, s) {
        // If a box is corrupt (schema drift, force-quit during write), drop
        // and reopen — better to lose cache than to brick boot.
        if (kDebugMode) debugPrint('Hive box "$name" failed to open: $e\n$s');
        await Hive.deleteBoxFromDisk(name);
        await Hive.openBox(name);
      }
    }
    _initialized = true;
  }

  /// Wipe every cache and the sync queue. Used after sign-out.
  static Future<void> clearAll() async {
    for (final name in _boxes) {
      final box = Hive.box(name);
      await box.clear();
    }
  }

  // ── Read/write helpers ────────────────────────────────────────

  static Box _box(String name) => Hive.box(name);

  static T? get<T>(String boxName, String key) {
    final v = _box(boxName).get(key);
    return v as T?;
  }

  static Future<void> put(String boxName, String key, Object? value) async {
    await _box(boxName).put(key, value);
  }

  static Future<void> delete(String boxName, String key) async {
    await _box(boxName).delete(key);
  }

  /// Mark `key` as fresh as of now.
  static Future<void> stamp(String boxName, String key) async {
    await _box(boxName).put('$_ttlPrefix$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Is `key`'s last write within [ttl]?
  static bool isFresh(String boxName, String key, Duration ttl) {
    final stamp = _box(boxName).get('$_ttlPrefix$key') as int?;
    if (stamp == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - stamp;
    return age < ttl.inMilliseconds;
  }
}
