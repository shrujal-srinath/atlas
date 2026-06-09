/// Riverpod wiring for the v2 leveling system.
///
/// The DB `daily_score_snapshots` table is the source of truth for past-day
/// XP. Today is always live (derived from `homeScoreProvider(today)` so the
/// progression bar moves as the user completes habits during the day).
///
/// In dev mode the providers compute everything from the in-memory mock
/// scores so the demo flow works without a Supabase session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../home/providers/home_providers.dart';
import 'leveling_engine.dart';

const int _kBackfillDays = 60;

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Sum of score_xp + bonus_xp across all past snapshots, plus today's live
/// score-derived XP and today's bonus_xp row (if any).
final cumulativeLevelXpProvider = FutureProvider<int>((ref) async {
  final today = _today();

  // Dev mode: derive from mock scores on the fly.
  if (ref.watch(devModeProvider)) {
    int total = 0;
    for (int i = _kBackfillDays; i >= 1; i--) {
      final d = today.subtract(Duration(days: i));
      final s = await ref.watch(homeScoreProvider(d).future);
      total += dayXpFromScore(s.score);
    }
    final t = await ref.watch(homeScoreProvider(today).future);
    total += dayXpFromScore(t.score);
    return total;
  }

  // Real mode: sum DB snapshots + today's live.
  final session = ref.watch(sessionProvider);
  if (session == null) return 0;

  int total = 0;
  try {
    final rows = await SupabaseService.client
        .from('daily_score_snapshots')
        .select('total_xp_delta, date, bonus_xp')
        .eq('user_id', session.user.id);
    final list = (rows as List).cast<Map<String, dynamic>>();
    for (final r in list) {
      // Today's row contributes its bonus_xp only — score_xp is recomputed live.
      if ((r['date'] as String?) == _dateStr(today)) {
        total += (r['bonus_xp'] as int?) ?? 0;
      } else {
        total += (r['total_xp_delta'] as int?) ?? 0;
      }
    }
  } catch (_) {
    // Schema not yet applied / network blip — treat as zero.
  }

  // Today's live score → today's score_xp
  try {
    final t = await ref.watch(homeScoreProvider(today).future);
    total += dayXpFromScore(t.score);
  } catch (_) {}

  return total;
});

/// Current level derived from the cumulative XP. Falls back to L1 while
/// cumulative is still loading.
final currentLevelProvider = Provider<LevelInfo>((ref) {
  final xp = ref.watch(cumulativeLevelXpProvider).valueOrNull ?? 0;
  return levelFromCumulative(xp);
});

/// Live "today's contribution" ticker shown on the Progression screen.
/// Re-computes whenever the day's score moves.
final todayLevelXpDeltaProvider = Provider<int>((ref) {
  final today = _today();
  final scoreAsync = ref.watch(homeScoreProvider(today));
  final score = scoreAsync.valueOrNull?.score ?? 0;
  return dayXpFromScore(score);
});

/// Fire-and-forget gate that runs [DailySnapshotWriter.runOnce] when first
/// read. Public callers (e.g. `main.dart`) just do `ref.read` after auth
/// settles. The underlying writer guards on dev mode + missing session.
final dailySnapshotBackfillProvider = FutureProvider<void>((ref) async {
  await DailySnapshotWriter.runOnce(ref);
});

/// Backfills missing daily snapshots on app open. Walks back `_kBackfillDays`
/// days and UPSERTs any date that doesn't already have a snapshot row.
/// Today is never written — it's always live.
///
/// No-op in dev mode (no Supabase session).
class DailySnapshotWriter {
  static Future<void> runOnce(Ref ref) async {
    if (ref.read(devModeProvider)) return;
    final session = ref.read(sessionProvider);
    if (session == null) return;

    final today = _today();
    final cutoff = today.subtract(const Duration(days: _kBackfillDays));

    Set<String> existing;
    try {
      final rows = await SupabaseService.client
          .from('daily_score_snapshots')
          .select('date')
          .eq('user_id', session.user.id)
          .gte('date', _dateStr(cutoff))
          .lt('date', _dateStr(today));
      existing = {
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          r['date'] as String,
      };
    } catch (_) {
      return;
    }

    for (var d = cutoff; d.isBefore(today); d = d.add(const Duration(days: 1))) {
      final key = _dateStr(d);
      if (existing.contains(key)) continue;
      try {
        final s = await ref.read(homeScoreProvider(d).future);
        await SupabaseService.client.from('daily_score_snapshots').upsert(
          {
            'user_id': session.user.id,
            'date': key,
            'score': s.score,
            'score_xp': dayXpFromScore(s.score),
          },
          onConflict: 'user_id,date',
        );
      } catch (_) {
        // best-effort; skip on any error
      }
    }
  }

  /// Updates today's `bonus_xp` (upserts the row if needed). Used by the
  /// achievement engine + nutrition listener to grant one-off bonuses.
  static Future<void> addTodayBonus({
    required String userId,
    required int xp,
  }) async {
    final today = _today();
    final key = _dateStr(today);
    try {
      final existing = await SupabaseService.client
          .from('daily_score_snapshots')
          .select('id, bonus_xp, score, score_xp')
          .eq('user_id', userId)
          .eq('date', key)
          .maybeSingle();
      if (existing == null) {
        await SupabaseService.client.from('daily_score_snapshots').insert({
          'user_id': userId,
          'date': key,
          'score': 0,
          'score_xp': 0,
          'bonus_xp': xp,
        });
      } else {
        final current = (existing['bonus_xp'] as int?) ?? 0;
        await SupabaseService.client
            .from('daily_score_snapshots')
            .update({'bonus_xp': current + xp})
            .eq('id', existing['id'] as String);
      }
    } catch (_) {
      // ignore — schema not applied yet
    }
  }
}
