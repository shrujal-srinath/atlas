import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../domain/journal_entry.dart';
import '../providers/journal_providers.dart';
import '../providers/mood_log_providers.dart';

/// 1..5 mood faces, shared by the inline row and the collapsed chip.
const _moodEmoji = ['😩', '😕', '😐', '🙂', '😄'];

/// Inline daily check-in. Prompts for mood + energy on a **fixed 2-hour clock**
/// — slots at 05:00, 07:00, … 21:00 (every two hours from 5am through 9pm). The
/// card appears at the top of each slot and, the moment you answer both, slides
/// off the page until the next slot is due. Outside 5am–9pm it stays away.
/// Each answer appends a `mood_logs` timeseries row and updates `daily_journal`
/// with the day's latest value. Past dates always show the full rows for edit.
class WellnessCheckInCard extends ConsumerStatefulWidget {
  /// When true, the card omits the screen-horizontal padding so it can sit
  /// flush inside a parent with its own gutter (e.g. the BENTO home).
  final bool flush;
  const WellnessCheckInCard({super.key, this.flush = false});

  @override
  ConsumerState<WellnessCheckInCard> createState() =>
      _WellnessCheckInCardState();
}

class _WellnessCheckInCardState extends ConsumerState<WellnessCheckInCard> {
  // Check-in schedule: every [_slotStepHours] from [_slotStartHour] through
  // [_slotEndHour], each prompt living for a [_slotWindowHours] window.
  static const int _slotStartHour = 5; // first prompt 5am
  static const int _slotEndHour = 21; // last prompt 9pm
  static const int _slotStepHours = 2;
  static const int _slotWindowHours = 2;

  // Optimistic copy of today's entry so taps feel instant even when the
  // upsert RPC takes a beat to round-trip.
  JournalEntry? _local;

  /// Optimistic completion time so the card hides instantly once both mood and
  /// energy are set — works even in dev/offline where the `mood_logs` re-query
  /// would come back empty.
  DateTime? _committedAt;

  // Re-evaluates visibility as the wall clock crosses a slot boundary, so the
  // card appears at 07:00/09:00/… without needing a manual refresh.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _setField({int? mood, int? energy}) async {
    HapticFeedback.selectionClick();
    final user = ref.read(appUserProvider).valueOrNull;
    final date = ref.read(selectedDateProvider);
    final current = _local ??
        ref.read(journalForSelectedDateProvider).valueOrNull ??
        (user == null ? null : JournalEntry.empty(user.id, date));
    if (current == null) return; // no auth, nothing to persist
    final updated = current.copyWith(mood: mood, energy: energy);
    setState(() => _local = updated);
    // Decide completion against the local copy *now* so the exit animation
    // begins on the same frame as the tap — the network write trails behind.
    _commitIfComplete(updated);
    try {
      final repo = ref.read(journalRepositoryProvider);
      final persisted = await repo.upsert(updated);
      if (!mounted) return;
      setState(() => _local = persisted);
      ref.invalidate(journalForSelectedDateProvider);
    } catch (_) {
      // Dev mode / offline — local state stands. The next sync will retry.
    }
  }

  Future<void> _setMood(int v) => _setField(mood: v);
  Future<void> _setEnergy(int v) => _setField(energy: v);

  /// Once **both** mood and energy exist for today's active slot, optimistically
  /// hide the card and append a single combined `mood_logs` point. Skips past
  /// dates and avoids a duplicate write inside the same slot.
  void _commitIfComplete(JournalEntry e) {
    final now = DateTime.now();
    if (!DateUtils.isSameDay(ref.read(selectedDateProvider), now)) return;
    if (e.mood == null || e.energy == null) return; // need both

    final slot = _currentSlotStart(now);
    final lastFull = _lastFullCheckinTime();
    if (slot != null && lastFull != null && !lastFull.isBefore(slot)) {
      if (mounted) setState(() {}); // already logged this slot — keep hidden
      return;
    }
    if (!mounted) return;
    setState(() => _committedAt = now); // hide on this frame
    // Fire-and-forget the timeseries write; the optimistic hide already landed.
    () async {
      try {
        await ref
            .read(moodLogRepositoryProvider)
            .add(mood: e.mood!, energy: e.energy!);
        if (mounted) ref.invalidate(moodTodayLogsProvider);
      } catch (_) {/* offline / dev */}
    }();
  }

  /// Start of the slot currently accepting a check-in, or null when we're
  /// outside prompting hours (before 5am, or past the 9pm slot's window).
  DateTime? _currentSlotStart(DateTime now) {
    if (now.hour < _slotStartHour) return null;
    final steps = (now.hour - _slotStartHour) ~/ _slotStepHours;
    final slotHour = _slotStartHour + steps * _slotStepHours;
    if (slotHour > _slotEndHour) {
      // Past the final (9pm) slot — only still active inside its window.
      final last =
          DateTime(now.year, now.month, now.day, _slotEndHour);
      return now.difference(last) < const Duration(hours: _slotWindowHours)
          ? last
          : null;
    }
    return DateTime(now.year, now.month, now.day, slotHour);
  }

  /// Newest *complete* (mood + energy) check-in today, from the optimistic
  /// commit or the persisted logs. Null when there is none.
  DateTime? _lastFullCheckinTime() {
    DateTime? at = _committedAt;
    final logs = ref.read(moodTodayLogsProvider).valueOrNull ?? const [];
    for (final l in logs) {
      if (l.mood != null && l.energy != null) at = l.loggedAt; // newest last
    }
    return at;
  }

  /// Whether the prompt should be on screen right now (today only): inside an
  /// active slot whose check-in hasn't been completed yet.
  bool _shouldShow(DateTime now) {
    final slot = _currentSlotStart(now);
    if (slot == null) return false;
    final lastFull = _lastFullCheckinTime();
    return lastFull == null || lastFull.isBefore(slot);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final entry = _local ??
        ref.watch(journalForSelectedDateProvider).valueOrNull;

    // Visibility — today follows the fixed 2-hour slot clock; past dates always
    // show the full rows for editing. Re-watch the logs so an external write
    // (or invalidation) rebuilds the card.
    final now = DateTime.now();
    final selected = ref.watch(selectedDateProvider);
    final isToday = DateUtils.isSameDay(selected, now);
    ref.watch(moodTodayLogsProvider);
    final hidden = isToday && !_shouldShow(now);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'CHECK-IN',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: c.textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/journal'),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open journal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 13, color: c.textMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MoodRow(
            selected: entry?.mood,
            onSelect: _setMood,
          ),
          const SizedBox(height: 8),
          _EnergyRow(
            selected: entry?.energy,
            onSelect: _setEnergy,
          ),
          if (entry?.sleepHours != null || entry?.sleepQuality != null) ...[
            const SizedBox(height: 8),
            _SleepRow(entry: entry!),
          ],
          if ((entry?.morningIntent ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _IntentPill(text: entry!.morningIntent!.trim(), t: t),
          ],
        ],
      ),
    );

    final content = widget.flush
        ? card
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
            child: card,
          );

    // Slot open → grow + fade in; answered (or slot over) → collapse + fade out.
    // Both directions ride the same AnimatedSwitcher so the home column reflows
    // smoothly either way.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axisAlignment: -1,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: hidden
          ? const SizedBox.shrink(key: ValueKey('mood-hidden'))
          : KeyedSubtree(key: const ValueKey('mood-card'), child: content),
    );
  }
}

// ── Mood emoji row ──────────────────────────────────────────────────

class _MoodRow extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelect;
  const _MoodRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            'Mood',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
        for (int i = 0; i < 5; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i + 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.symmetric(horizontal: i == 0 || i == 4 ? 0 : 3),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: selected == i + 1
                      ? c.accent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  border: Border.all(
                    color: selected == i + 1
                        ? c.accent.withValues(alpha: 0.55)
                        : Colors.transparent,
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _moodEmoji[i],
                  style: TextStyle(
                    fontSize: 18,
                    color: selected == null || selected == i + 1
                        ? null
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Energy bars row ─────────────────────────────────────────────────

class _EnergyRow extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelect;
  const _EnergyRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            'Energy',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
        for (int i = 0; i < 5; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: EdgeInsets.symmetric(horizontal: i == 0 || i == 4 ? 0 : 3),
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  height: 6.0 + i * 3.0,
                  decoration: BoxDecoration(
                    color: selected != null && i + 1 <= selected!
                        ? c.accent
                        : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: selected != null && i + 1 <= selected!
                          ? c.accent
                          : c.border,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Sleep row (only when data exists) ───────────────────────────────

class _SleepRow extends StatelessWidget {
  final JournalEntry entry;
  const _SleepRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hrs = entry.sleepHours;
    final q = entry.sleepQuality;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            'Sleep',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
        if (hrs != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Text(
              '${hrs.toStringAsFixed(hrs % 1 == 0 ? 0 : 1)}h',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
        if (q != null) ...[
          const SizedBox(width: 8),
          for (int i = 0; i < 5; i++) ...[
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < q ? c.accent : c.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: i < q ? c.accent : c.border,
                  width: 0.5,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ── Intent pill ─────────────────────────────────────────────────────

class _IntentPill extends StatelessWidget {
  final String text;
  final AppTextStyles t;
  const _IntentPill({required this.text, required this.t});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.target, size: 12, color: c.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.meta.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
