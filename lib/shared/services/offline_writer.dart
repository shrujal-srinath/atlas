import 'package:flutter/foundation.dart';
import 'sync_queue.dart';
import 'supabase_service.dart';

/// Thin convenience around the try-Supabase-else-enqueue pattern.
///
/// Repositories should call these instead of `SupabaseService.client.from(...)`
/// directly for *mutations they want to survive network outages*.
///
/// On insert: returns the row the caller can use to construct the domain
/// object. Always carries a client-generated `id` so retries from the queue
/// are idempotent (the table accepts a client UUID and upserts on duplicate).
///
/// On error after a successful connectivity check we still queue rather than
/// surface — the error might be a transient flake (DNS, captive portal) and
/// the user already saw their data appear locally.
class OfflineWriter {
  OfflineWriter._();

  static Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final online = await SyncQueue.instance.isOnline();
    if (online) {
      try {
        final inserted = await SupabaseService.client
            .from(table)
            .insert(payload)
            .select()
            .single();
        return Map<String, dynamic>.from(inserted);
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('OfflineWriter.insert "$table" fell through to queue: $e\n$s');
        }
        final id = await SyncQueue.instance
            .enqueueInsert(table: table, payload: payload);
        return {...payload, 'id': id};
      }
    }
    final id = await SyncQueue.instance
        .enqueueInsert(table: table, payload: payload);
    return {...payload, 'id': id};
  }

  static Future<void> delete({
    required String table,
    required String id,
  }) async {
    final online = await SyncQueue.instance.isOnline();
    if (online) {
      try {
        await SupabaseService.client.from(table).delete().eq('id', id);
        return;
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('OfflineWriter.delete "$table" fell through to queue: $e\n$s');
        }
      }
    }
    await SyncQueue.instance.enqueueDelete(table: table, id: id);
  }

  static Future<void> update({
    required String table,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final online = await SyncQueue.instance.isOnline();
    if (online) {
      try {
        await SupabaseService.client.from(table).update(payload).eq('id', id);
        return;
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('OfflineWriter.update "$table" fell through to queue: $e\n$s');
        }
      }
    }
    await SyncQueue.instance
        .enqueueUpdate(table: table, id: id, payload: payload);
  }
}
