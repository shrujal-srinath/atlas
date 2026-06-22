/// Riverpod wiring for the v2.1 leveling system.
///
/// The DB `daily_score_snapshots` table is the source of truth for past-day
/// XP. Today is always live (derived from `homeScoreProvider(today)` so the
/// progression bar moves as the user completes habits during the day).
///
/// v2.1 adds the *confirmed level* (`users.confirmed_level`): cumulative XP
/// only nominates a candidate level — the transition is awarded one step at a
/// time by [persistConfirmedLevel] when both the XP gate and every milestone
/// pre-req pass (see `canLevelUpProvider`). A confirmed level is never lost.
///
/// In dev mode the providers compute everything from the in-memory mock
/// scores so the demo flow works without a Supabase session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../core/utils/streak_engine.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../food/providers/food_providers.dart';
import '../food/scoring/nutrition_score.dart';
import '../home/providers/home_providers.dart';
import 'leveling_engine.dart';

const int _kBackfillDays = 60;

/// How far back the daily-score streak scans the snapshot ledger (real mode).
const int _kStreakScanDays = 365;

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Sum of score_xp + bonus_xp across all past snapshots, plus today's live
/// contribution.
///
/// Today's score-derived XP is clamped at 0 while the day is in progress —
/// a day that's heading below break-even (score < 50) only locks in its
/// negative XP when the snapshot writer persists it after midnight. Without
/// the clamp every morning would open with a -50 dip before the first habit
/// is ticked.
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
    final live = dayXpFromScore(t.score);
    total += live < 0 ? 0 : live;
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

  // Today's live score → today's score_xp (clamped at 0 until day close).
  try {
    final t = await ref.watch(homeScoreProvider(today).future);
    final live = dayXpFromScore(t.score);
    total += live < 0 ? 0 : live;
  } catch (_) {}

  return total;
});

/// Dev-mode stand-in for `users.confirmed_level`. `null` = follow the
/// XP-derived candidate (keeps the demo data looking alive without a flow).
final devConfirmedLevelProvider = StateProvider<int?>((_) => null);

/// The user's awarded level. Persisted in `users.confirmed_level`; advanced
/// one step at a time by [persistConfirmedLevel] when the dual gate passes.
final confirmedLevelProvider = FutureProvider<int>((ref) async {
  if (ref.watch(devModeProvider)) {
    final dev = ref.watch(devConfirmedLevelProvider);
    if (dev != null) return dev;
    final xp = await ref.watch(cumulativeLevelXpProvider.future);
    return levelFromCumulative(xp).level;
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return 1;
  try {
    final row = await SupabaseService.client
        .from('users')
        .select('confirmed_level')
        .eq('id', session.user.id)
        .maybeSingle();
    final lvl = (row?['confirmed_level'] as int?) ?? 1;
    return lvl < 1 ? 1 : lvl;
  } catch (_) {
    // Transient fetch failure — fall back to the XP-derived candidate so the
    // UI doesn't flash L1 for an established user.
    final xp = await ref.watch(cumulativeLevelXpProvider.future);
    return levelFromCumulative(xp).level;
  }
});

/// Current (gated) level info. The level number is the confirmed level; the
/// bar tracks XP within it. While `confirmed_level` is still loading we fall
/// back to the XP-derived candidate so the UI never flashes L1.
final currentLevelProvider = Provider<LevelInfo>((ref) {
  final xp = ref.watch(cumulativeLevelXpProvider).valueOrNull ?? 0;
  final confirmed = ref.watch(confirmedLevelProvider).valueOrNull;
  if (confirmed == null) return levelFromCumulative(xp);
  return gatedLevelInfo(confirmedLevel: confirmed, totalXp: xp);
});

/// Live "today's contribution" ticker shown on the Progression screen.
/// Re-computes whenever the day's score moves. Deliberately *unclamped* —
/// the tile is honest about a sub-50 day even though the cumulative total
/// only takes the hit at midnight.
final todayLevelXpDeltaProvider = Provider<int>((ref) {
  final today = _today();
  final scoreAsync = ref.watch(homeScoreProvider(today));
  final score = scoreAsync.valueOrNull?.score ?? 0;
  return dayXpFromScore(score);
});

/// Canonical daily-score streak: consecutive days at/above the leveling
/// break-even (score ≥ 50), walking back from today. Surfaced on the Score
/// screen, Home ticker, Glance, and the Progression story header — replacing
/// the previously hardcoded `HomeScore.streakDays`.
///
/// Past days come from the `daily_score_snapshots` ledger; today is always
/// live. Rest days (no scheduled tasks → no snapshot row) are skipped, so a
/// genuine off day never breaks the run. Dev mode recomputes from mock scores
/// across the backfill window.
final currentScoreStreakProvider = FutureProvider<int>((ref) async {
  final today = _today();
  final scoreByDate = <DateTime, int>{};

  if (ref.watch(devModeProvider)) {
    for (int i = _kBackfillDays; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final s = await ref.watch(homeScoreProvider(d).future);
      if (s.total > 0) scoreByDate[DateTime(d.year, d.month, d.day)] = s.score;
    }
    return dailyScoreStreak(scoreByDate, today: today);
  }

  final session = ref.watch(sessionProvider);
  if (session == null) return 0;
  try {
    final since = today.subtract(const Duration(days: _kStreakScanDays));
    final rows = await SupabaseService.client
        .from('daily_score_snapshots')
        .select('date, score')
        .eq('user_id', session.user.id)
        .gte('date', _dateStr(since));
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final ds = r['date'] as String?;
      if (ds == null) continue;
      final d = DateTime.tryParse(ds);
      if (d != null) {
        scoreByDate[DateTime(d.year, d.month, d.day)] =
            (r['score'] as int?) ?? 0;
      }
    }
  } catch (_) {
    return 0;
  }
  // Today is never in the ledger — derive it live.
  try {
    final t = await ref.watch(homeScoreProvider(today).future);
    if (t.total > 0) scoreByDate[today] = t.score;
  } catch (_) {}

  return dailyScoreStreak(scoreByDate, today: today);
});

/// Raw per-day XP contribution (date → net delta, **negatives preserved**) for
/// the Daily XP bar chart. Past days come from the snapshot ledger's
/// `total_xp_delta` (= `score_xp + bonus_xp`); today is live from
/// [todayLevelXpDeltaProvider] (unclamped, so a sub-50 day shows its honest
/// red bar). Rest days (no scheduled tasks → no snapshot row) are omitted so
/// the chart isn't swamped by −50 bars for off days. Oldest → newest.
final dailyXpDeltaProvider =
    FutureProvider<List<({DateTime date, int delta})>>((ref) async {
  final today = _today();
  final out = <({DateTime date, int delta})>[];

  if (ref.watch(devModeProvider)) {
    for (int i = _kBackfillDays; i >= 1; i--) {
      final d = today.subtract(Duration(days: i));
      final s = await ref.watch(homeScoreProvider(d).future);
      if (s.total == 0) continue; // rest day — neutral, skip
      out.add((date: d, delta: dayXpFromScore(s.score)));
    }
  } else {
    final session = ref.watch(sessionProvider);
    if (session != null) {
      try {
        final rows = await SupabaseService.client
            .from('daily_score_snapshots')
            .select('date, total_xp_delta')
            .eq('user_id', session.user.id)
            .order('date');
        for (final r in (rows as List)) {
          final ds = r['date'] as String?;
          if (ds == null) continue;
          final d = DateTime.tryParse(ds);
          if (d == null) continue;
          if (DateTime(d.year, d.month, d.day) == today) continue; // live below
          out.add((date: d, delta: (r['total_xp_delta'] as int?) ?? 0));
        }
      } catch (_) {}
    }
  }

  // Today live (unclamped — honest about a below-break-even day).
  out.add((date: today, delta: ref.watch(todayLevelXpDeltaProvider)));
  return out;
});

/// One point on the cumulative-XP curve (date → running total).
class XpPoint {
  final DateTime date;
  final int cumulative;
  const XpPoint(this.date, this.cumulative);
}

/// A level threshold the user's cumulative XP first crossed, with the date it
/// happened. Derived from the curve — not stored.
class LevelMilestone {
  final int level;
  final DateTime date;
  const LevelMilestone(this.level, this.date);
}

/// The user's progression "journey" — the cumulative-XP curve plus the dates
/// each level threshold was first crossed.
class XpHistory {
  final List<XpPoint> points;
  final List<LevelMilestone> milestones;
  const XpHistory({required this.points, required this.milestones});
  bool get isEmpty => points.isEmpty;
}

/// Reconstructs the cumulative-XP curve and the dates the user first crossed
/// each level threshold from the snapshot ledger (+ today live). Pure read —
/// it never feeds scoring, XP, or the confirmed-level gate.
final xpHistoryProvider = FutureProvider<XpHistory>((ref) async {
  final today = _today();
  final daily = <({DateTime date, int delta})>[];

  if (ref.watch(devModeProvider)) {
    for (int i = _kBackfillDays; i >= 1; i--) {
      final d = today.subtract(Duration(days: i));
      final s = await ref.watch(homeScoreProvider(d).future);
      daily.add((date: d, delta: dayXpFromScore(s.score)));
    }
  } else {
    final session = ref.watch(sessionProvider);
    if (session == null) return const XpHistory(points: [], milestones: []);
    try {
      final rows = await SupabaseService.client
          .from('daily_score_snapshots')
          .select('date, total_xp_delta')
          .eq('user_id', session.user.id)
          .order('date');
      for (final r in (rows as List)) {
        final ds = r['date'] as String?;
        if (ds == null) continue;
        daily.add((
          date: DateTime.parse(ds),
          delta: (r['total_xp_delta'] as int?) ?? 0,
        ));
      }
    } catch (_) {
      return const XpHistory(points: [], milestones: []);
    }
  }

  // Append today's live contribution (clamped ≥0, mirroring the cumulative
  // provider — a sub-50 day only locks in its negative at midnight).
  final todayDelta = ref.watch(todayLevelXpDeltaProvider);
  daily.add((date: today, delta: todayDelta < 0 ? 0 : todayDelta));

  return buildXpHistory(daily);
});

/// Pure reducer: folds a chronological list of `(date, dailyXpDelta)` into the
/// cumulative-XP curve and the first-crossing date of each level threshold.
/// The running total is floored at 0 so a rough patch never reads below L1.
XpHistory buildXpHistory(List<({DateTime date, int delta})> daily) {
  final points = <XpPoint>[];
  final milestones = <LevelMilestone>[];
  int cum = 0;
  int nextLevel = 2;
  for (final e in daily) {
    cum += e.delta;
    if (cum < 0) cum = 0;
    points.add(XpPoint(e.date, cum));
    while (cum >= xpForLevel(nextLevel)) {
      milestones.add(LevelMilestone(nextLevel, e.date));
      nextLevel++;
    }
  }
  return XpHistory(points: points, milestones: milestones);
}

/// Writes `users.confirmed_level = level` (monotonic — the DB row never goes
/// backwards). Callers must invalidate [confirmedLevelProvider] afterwards.
Future<void> persistConfirmedLevel(String userId, int level) async {
  try {
    await SupabaseService.client
        .from('users')
        .update({'confirmed_level': level})
        .eq('id', userId)
        .lt('confirmed_level', level);
  } catch (_) {
    // Best-effort; the overlay will retry on the next canLevelUp flip.
  }
}

/// Fire-and-forget gate that runs [DailySnapshotWriter.runOnce] when first
/// read. Public callers (e.g. `main.dart`) just do `ref.read` after auth
/// settles. The underlying writer guards on dev mode + missing session.
final dailySnapshotBackfillProvider = FutureProvider<void>((ref) async {
  final wrote = await DailySnapshotWriter.runOnce(ref);
  // Snapshots landed after cumulative XP was first computed — refresh it.
  if (wrote) ref.invalidate(cumulativeLevelXpProvider);
});

/// Backfills missing daily snapshots on app open. Walks back from the later
/// of `_kBackfillDays` ago and the user's first habit log, and UPSERTs any
/// past date that doesn't already have a real snapshot row. Today is never
/// written — it's always live.
///
/// Rules that keep the ledger honest:
/// - Days before the user's first habit log are never written (a fresh
///   account must not open 60 days in the XP hole).
/// - Days with zero scheduled tasks are neutral: no row, 0 XP — a rest day
///   is not a bad day.
/// - Placeholder rows created intra-day by [addTodayBonus] (score 0 AND
///   score_xp 0, a combination a real close-out can never produce) get their
///   score filled in retroactively, preserving bonus_xp.
/// - Every written day caches `nutrition_ratio` so `nutrition_days`
///   milestones can derive from the snapshot table.
///
/// No-op in dev mode (no Supabase session). Returns true if any row was
/// written or repaired.
class DailySnapshotWriter {
  static Future<bool> runOnce(Ref ref) async {
    if (ref.read(devModeProvider)) return false;
    final session = ref.read(sessionProvider);
    if (session == null) return false;
    final uid = session.user.id;

    final today = _today();
    var cutoff = today.subtract(const Duration(days: _kBackfillDays));

    // Never reach back before the user's first habit log.
    try {
      final first = await SupabaseService.client
          .from('habit_logs')
          .select('date')
          .eq('user_id', uid)
          .order('date', ascending: true)
          .limit(1)
          .maybeSingle();
      final firstStr = first?['date'] as String?;
      if (firstStr == null) return false; // no activity yet — nothing to score
      final firstDate = DateTime.tryParse(firstStr);
      if (firstDate != null && firstDate.isAfter(cutoff)) {
        cutoff = DateTime(firstDate.year, firstDate.month, firstDate.day);
      }
    } catch (_) {
      return false;
    }

    // Existing rows in the window: skip real ones, repair placeholders.
    final placeholders = <String>{};
    final existing = <String>{};
    try {
      final rows = await SupabaseService.client
          .from('daily_score_snapshots')
          .select('date, score, score_xp')
          .eq('user_id', uid)
          .gte('date', _dateStr(cutoff))
          .lt('date', _dateStr(today));
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final date = r['date'] as String;
        existing.add(date);
        final isPlaceholder =
            ((r['score'] as int?) ?? 0) == 0 && ((r['score_xp'] as int?) ?? 0) == 0;
        if (isPlaceholder) placeholders.add(date);
      }
    } catch (_) {
      return false;
    }

    bool wrote = false;
    for (var d = cutoff; d.isBefore(today); d = d.add(const Duration(days: 1))) {
      final key = _dateStr(d);
      final needsRepair = placeholders.contains(key);
      if (existing.contains(key) && !needsRepair) continue;
      try {
        final s = await ref.read(homeScoreProvider(d).future);
        // Rest day (nothing scheduled): neutral. Leave repaired placeholders
        // at score_xp 0; never create new rows for empty days.
        if (s.total == 0 && !needsRepair) continue;
        final scoreXp = s.total == 0 ? 0 : dayXpFromScore(s.score);
        await SupabaseService.client.from('daily_score_snapshots').upsert(
          {
            'user_id': uid,
            'date': key,
            'score': s.total == 0 ? 0 : s.score,
            'score_xp': scoreXp,
            'nutrition_ratio': await _nutritionRatioFor(ref, d),
          },
          onConflict: 'user_id,date',
        );
        wrote = true;
      } catch (_) {
        // best-effort; skip on any error
      }
    }
    return wrote;
  }

  /// Day's nutrition adherence from the food log, using the user's current
  /// targets + phase. 0.0 when nothing was logged.
  static Future<double> _nutritionRatioFor(Ref ref, DateTime date) async {
    try {
      final repo = ref.read(foodRepositoryProvider);
      final entries = await repo.entriesForDate(date);
      if (entries.isEmpty) return 0.0;
      var kcal = 0.0, protein = 0.0;
      for (final e in entries) {
        kcal += e.totals.kcal;
        protein += e.totals.proteinG;
      }
      final targets = ref.read(dailyTargetsProvider);
      final phase = ref.read(bodyPhaseProvider);
      return nutritionDayScore(
        currentKcal: kcal,
        targetKcal: targets.kcal,
        currentProteinG: protein,
        targetProteinG: targets.proteinG,
        phase: phase,
      );
    } catch (_) {
      return 0.0;
    }
  }

  /// Updates today's `bonus_xp` (upserts the row if needed). Used by the
  /// achievement engine + nutrition listener to grant one-off bonuses.
  ///
  /// [markNutritionAwarded] additionally flips the once-per-day
  /// `nutrition_bonus_awarded` flag and caches [nutritionRatio] so the
  /// snapshot row reflects the state that earned the bonus.
  static Future<void> addTodayBonus({
    required String userId,
    required int xp,
    bool markNutritionAwarded = false,
    double? nutritionRatio,
  }) async {
    final today = _today();
    final key = _dateStr(today);
    final extras = <String, dynamic>{
      if (markNutritionAwarded) 'nutrition_bonus_awarded': true,
      'nutrition_ratio': ?nutritionRatio,
    };
    try {
      final existing = await SupabaseService.client
          .from('daily_score_snapshots')
          .select('id, bonus_xp')
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
          ...extras,
        });
      } else {
        final current = (existing['bonus_xp'] as int?) ?? 0;
        await SupabaseService.client
            .from('daily_score_snapshots')
            .update({'bonus_xp': current + xp, ...extras})
            .eq('id', existing['id'] as String);
      }
    } catch (_) {
      // ignore — schema not applied yet
    }
  }
}
