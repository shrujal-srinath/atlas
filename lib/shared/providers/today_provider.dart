import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current date-only value, then re-emits at every local midnight.
///
/// SR-3 (SHIP_READINESS.md): every "is this today" decision used to be a raw
/// `DateTime.now()` call inside a provider that only recomputes when a
/// *watched* dependency changes — since `DateTime.now()` isn't a watched
/// dependency, an app left open across 00:00 kept computing scores, the week
/// strip's today-highlight, and the nutrition blend against the date it was
/// *last rebuilt* at, not the real day. Watching this provider instead makes
/// midnight itself the trigger.
final todayProvider = StreamProvider<DateTime>((ref) {
  final ctrl = StreamController<DateTime>();
  Timer? timer;
  void emitAndScheduleNext() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!ctrl.isClosed) ctrl.add(today);
    final nextMidnight = DateTime(today.year, today.month, today.day + 1);
    // +1s buffer so the timer never fires a hair early on backends with
    // coarse timer resolution.
    final delay = nextMidnight.difference(DateTime.now()) + const Duration(seconds: 1);
    timer = Timer(delay, emitAndScheduleNext);
  }

  emitAndScheduleNext();
  ref.onDispose(() {
    timer?.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});

/// Convenience: today's date-only value, synchronous (no `AsyncValue`
/// unwrapping at every call site). Falls back to a fresh computation before
/// [todayProvider]'s first emission has landed, which is instant in
/// practice (the timer fires synchronously on subscribe) but keeps this
/// provider correct even on the very first read of the very first frame.
final todayDateProvider = Provider<DateTime>((ref) {
  final fromStream = ref.watch(todayProvider).valueOrNull;
  if (fromStream != null) return fromStream;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
