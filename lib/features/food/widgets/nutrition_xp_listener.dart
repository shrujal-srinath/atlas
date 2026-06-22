/// Hidden global widget that listens to today's nutrition ratio and fires a
/// one-time XP bonus when it crosses [kNutritionXpThreshold] (0.80). Mounted
/// from `main.dart` alongside the level-up and achievement overlays.
///
/// v2: the bonus is written to today's `daily_score_snapshots.bonus_xp` so
/// the level XP totals stay perfectly aligned with the source-of-truth
/// snapshot table — no more parallel `xp_events` writes.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/supabase_service.dart';
import '../../xp/leveling_providers.dart';
import '../providers/food_providers.dart';
import '../scoring/nutrition_score.dart';

/// Fixed bonus awarded the first time the user crosses the nutrition threshold
/// each day. Picked to match the rough order of magnitude of habit-derived XP
/// contributions on a typical day.
const int _kNutritionBonusXp = 25;

class NutritionXpListener extends ConsumerStatefulWidget {
  final Widget child;
  const NutritionXpListener({super.key, required this.child});

  @override
  ConsumerState<NutritionXpListener> createState() =>
      _NutritionXpListenerState();
}

class _NutritionXpListenerState extends ConsumerState<NutritionXpListener> {
  bool _awarded = false;
  bool _checked = false;
  DateTime? _today;

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    // Best-effort pre-check: if today's snapshot already has a bonus_xp row
    // we set the flag so we don't re-award on next ratio bump. No-op when
    // there's no auth session (dev mode).
    Future.microtask(_loadAwardedFlag);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadAwardedFlag() async {
    try {
      final user = SupabaseService.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _checked = true);
        return;
      }
      // Dedicated flag — `bonus_xp > 0` would also be true after an
      // achievement unlock and silently block the nutrition bonus.
      final row = await SupabaseService.client
          .from('daily_score_snapshots')
          .select('nutrition_bonus_awarded')
          .eq('user_id', user.id)
          .eq('date', _dateStr(_today!))
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _awarded = (row?['nutrition_bonus_awarded'] as bool?) ?? false;
        _checked = true;
      });
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  Future<void> _maybeAward(double ratio) async {
    if (!_checked || _awarded) return;
    if (ratio < kNutritionXpThreshold) return;
    final user = SupabaseService.auth.currentUser;
    if (user == null) return;
    setState(() => _awarded = true); // optimistic guard
    await DailySnapshotWriter.addTodayBonus(
      userId: user.id,
      xp: _kNutritionBonusXp,
      markNutritionAwarded: true,
      nutritionRatio: ratio,
    );
    if (!mounted) return;
    ref.invalidate(cumulativeLevelXpProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Day rollover guard — if the system clock has crossed midnight, reset.
    final today = _dateOnly(DateTime.now());
    if (_today == null || today != _today) {
      _today = today;
      _awarded = false;
      _checked = false;
      Future.microtask(_loadAwardedFlag);
    }

    // Today-pinned ratio — the diary's selected-date ratio must never fire
    // today's bonus while the user browses an old (well-fed) day.
    ref.listen<double>(todayNutritionRatioProvider, (prev, next) {
      // Cross detection — only fire when crossing the threshold upward.
      final crossed =
          (prev == null || prev < kNutritionXpThreshold) &&
              next >= kNutritionXpThreshold;
      if (crossed) {
        _maybeAward(next);
      }
    });

    return widget.child;
  }
}
