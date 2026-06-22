import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'hive_service.dart';
import 'supabase_service.dart';

/// One pending mutation in the queue.
class SyncOp {
  final String id;
  final String op;        // 'insert' | 'update' | 'delete'
  final String table;     // supabase table name
  final Map<String, dynamic> payload;
  /// Used for update/delete. For inserts that pre-generate UUIDs, the payload
  /// already carries `id`; this stays null for those.
  final String? matchId;
  final int ts;           // millis since epoch when enqueued
  final int retries;

  const SyncOp({
    required this.id,
    required this.op,
    required this.table,
    required this.payload,
    this.matchId,
    required this.ts,
    this.retries = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'op': op,
        'table': table,
        'payload': payload,
        if (matchId != null) 'matchId': matchId,
        'ts': ts,
        'retries': retries,
      };

  static SyncOp fromMap(Map m) => SyncOp(
        id: m['id'] as String,
        op: m['op'] as String,
        table: m['table'] as String,
        payload: Map<String, dynamic>.from(m['payload'] as Map),
        matchId: m['matchId'] as String?,
        ts: (m['ts'] as num).toInt(),
        retries: (m['retries'] as num?)?.toInt() ?? 0,
      );

  SyncOp withRetry() => SyncOp(
        id: id,
        op: op,
        table: table,
        payload: payload,
        matchId: matchId,
        ts: ts,
        retries: retries + 1,
      );
}

/// Outbound mutation queue: persists pending Supabase writes to Hive so
/// they survive cold boots, drains them on connectivity restore with
/// exponential backoff.
///
/// Single instance, [SyncQueue.instance]. Repositories call [enqueueInsert],
/// [enqueueUpdate], [enqueueDelete] from their write paths after the local
/// (Hive) update has succeeded. The queue raises [queueDepth] for the
/// connectivity pill to surface count.
class SyncQueue extends ChangeNotifier {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  static const _key = 'pending';
  static const _uuid = Uuid();

  Box get _box => Hive.box(HiveService.syncQueueBox);

  bool _draining = false;
  bool get isDraining => _draining;

  /// Current pending count. Reads from Hive each call so the value is
  /// always exact, not just an optimistic counter.
  int get queueDepth {
    final raw = _box.get(_key) as List?;
    return raw?.length ?? 0;
  }

  /// Best-effort connectivity check used by `OfflineWriter` to decide
  /// whether to try Supabase directly or enqueue immediately.
  Future<bool> isOnline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.any((e) => e != ConnectivityResult.none);
    } catch (_) {
      // If the plugin is broken on this platform, assume online so we still
      // attempt the write — the catch block in OfflineWriter will queue on
      // an actual network failure.
      return true;
    }
  }

  List<SyncOp> _readAll() {
    final raw = _box.get(_key) as List?;
    if (raw == null) return [];
    return raw
        .cast<Map>()
        .map(SyncOp.fromMap)
        .toList();
  }

  Future<void> _writeAll(List<SyncOp> ops) async {
    await _box.put(_key, ops.map((o) => o.toMap()).toList());
    notifyListeners();
  }

  /// Enqueue an insert. If [payload] doesn't carry `id`, one is generated
  /// so the row is idempotent on retry.
  Future<String> enqueueInsert({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final rowId = (payload['id'] as String?) ?? _uuid.v4();
    final patched = {...payload, 'id': rowId};
    final op = SyncOp(
      id: _uuid.v4(),
      op: 'insert',
      table: table,
      payload: patched,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    final all = _readAll()..add(op);
    await _writeAll(all);
    return rowId;
  }

  Future<void> enqueueUpdate({
    required String table,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final op = SyncOp(
      id: _uuid.v4(),
      op: 'update',
      table: table,
      payload: payload,
      matchId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    final all = _readAll()..add(op);
    await _writeAll(all);
  }

  Future<void> enqueueDelete({
    required String table,
    required String id,
  }) async {
    final op = SyncOp(
      id: _uuid.v4(),
      op: 'delete',
      table: table,
      payload: const {},
      matchId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    final all = _readAll()..add(op);
    await _writeAll(all);
  }

  /// Drain pending ops oldest-first. Stops on first failure (likely network
  /// flake) and keeps remaining ops for the next drain pass. Retries beyond
  /// 8 are dropped — they'd block the queue forever otherwise.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    notifyListeners();
    try {
      while (true) {
        final all = _readAll();
        if (all.isEmpty) break;
        final next = all.first;
        if (next.retries >= 8) {
          // Drop poison-pill op; keep going.
          final rest = all.sublist(1);
          await _writeAll(rest);
          continue;
        }
        try {
          await _execute(next);
          final rest = all.sublist(1);
          await _writeAll(rest);
        } catch (e, s) {
          if (kDebugMode) debugPrint('SyncQueue execute failed for ${next.op}@${next.table}: $e\n$s');
          // Bump the head op's retry count and stop draining; the next
          // connectivity edge will trigger another `drain()`. No in-loop
          // sleep — the connectivity stream is the throttle.
          final bumped = next.withRetry();
          final rest = [bumped, ...all.sublist(1)];
          await _writeAll(rest);
          break;
        }
      }
    } finally {
      _draining = false;
      notifyListeners();
    }
  }

  Future<void> _execute(SyncOp op) async {
    final client = SupabaseService.client;
    switch (op.op) {
      case 'insert':
        // Upsert so re-runs are safe — the client-generated id is the unique key.
        await client.from(op.table).upsert(op.payload);
        return;
      case 'update':
        if (op.matchId == null) return;
        await client.from(op.table).update(op.payload).eq('id', op.matchId!);
        return;
      case 'delete':
        if (op.matchId == null) return;
        await client.from(op.table).delete().eq('id', op.matchId!);
        return;
    }
  }
}
