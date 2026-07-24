import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_queue.dart';
import '../../features/food/providers/food_providers.dart';

/// True when the device has *any* working network interface.
/// Folds the `connectivity_plus` result list (Android/iOS report multiple
/// active transports) into a single boolean.
final connectivityProvider = StreamProvider<bool>((ref) {
  final ctrl = StreamController<bool>();
  final conn = Connectivity();

  bool isOnline(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  // Seed with current state.
  conn.checkConnectivity().then((r) {
    if (!ctrl.isClosed) ctrl.add(isOnline(r));
  });

  bool wasOnline = false;
  final sub = conn.onConnectivityChanged.listen((results) {
    final online = isOnline(results);
    if (!ctrl.isClosed) ctrl.add(online);
    // Edge from offline → online triggers a sync-queue drain.
    if (online && !wasOnline) {
      SyncQueue.instance.drain();
    }
    wasOnline = online;
  });

  ref.onDispose(() {
    sub.cancel();
    ctrl.close();
  });

  return ctrl.stream;
});

/// Convenience: `true` while we know we're offline. Defaults to `false`
/// (assume online) while the first connectivity check is in flight, so the
/// pill doesn't flash on cold boot.
final isOfflineProvider = Provider<bool>((ref) {
  final v = ref.watch(connectivityProvider).valueOrNull;
  return v == false;
});

/// Wires [SyncQueue.onDrained] to invalidate the readers that would
/// otherwise stay stale after a successful drain (SR-2): a queued food/water
/// write only shows up once its provider is invalidated, and nothing did
/// that before this. Read once from a bootstrap spot (`main.dart`) so the
/// callback is registered for the life of the app; safe to read repeatedly
/// (`Provider` caches after the first build).
final syncDrainInvalidatorProvider = Provider<void>((ref) {
  SyncQueue.instance.onDrained = () {
    ref.invalidate(diaryEntriesProvider);
    ref.invalidate(waterIntakeProvider);
  };
  ref.onDispose(() => SyncQueue.instance.onDrained = null);
});

/// Current sync-queue depth — used by the pill to show "N pending".
/// Rebuilds when [SyncQueue] notifies listeners (after enqueue or drain).
final syncQueueDepthProvider = StreamProvider<int>((ref) {
  final ctrl = StreamController<int>();
  void emit() {
    if (!ctrl.isClosed) ctrl.add(SyncQueue.instance.queueDepth);
  }
  emit();
  SyncQueue.instance.addListener(emit);
  ref.onDispose(() {
    SyncQueue.instance.removeListener(emit);
    ctrl.close();
  });
  return ctrl.stream;
});
