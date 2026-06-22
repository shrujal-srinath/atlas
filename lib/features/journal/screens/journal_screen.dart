import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../auth/providers/auth_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../domain/journal_entry.dart';
import '../domain/mood_log.dart';
import '../providers/journal_providers.dart';
import '../providers/mood_log_providers.dart';

part 'journal_widgets.dart';

const _moodEmoji = ['😩', '😕', '😐', '🙂', '😄'];

/// Full daily journal + wellness editor for the selected date.
///
/// Auto-saves on field change after a 600ms debounce. Morning (intent + top-3
/// goals), wellness, sleep, and a structured evening reflection (wins /
/// to-improve / gratitude / day-rating / free review) live on one scroll, with
/// today's mood timeline and a recent-entries history at the foot.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late final TextEditingController _intent;
  late final TextEditingController _review;
  late final TextEditingController _sleep;
  late final TextEditingController _wins;
  late final TextEditingController _improve;
  late final TextEditingController _gratitude;
  late final List<TextEditingController> _goals;

  Timer? _debounce;
  JournalEntry? _current;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _intent = TextEditingController();
    _review = TextEditingController();
    _sleep = TextEditingController();
    _wins = TextEditingController();
    _improve = TextEditingController();
    _gratitude = TextEditingController();
    _goals = List.generate(3, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _intent.dispose();
    _review.dispose();
    _sleep.dispose();
    _wins.dispose();
    _improve.dispose();
    _gratitude.dispose();
    for (final g in _goals) {
      g.dispose();
    }
    super.dispose();
  }

  void _hydrate(JournalEntry entry) {
    if (_hydrated) return;
    _hydrated = true;
    _current = entry;
    _intent.text = entry.morningIntent ?? '';
    _review.text = entry.nightReview ?? '';
    _sleep.text = entry.sleepHours?.toString() ?? '';
    _wins.text = entry.wins ?? '';
    _improve.text = entry.improve ?? '';
    _gratitude.text = entry.gratitude ?? '';
    for (int i = 0; i < _goals.length; i++) {
      _goals[i].text = i < entry.goals.length ? entry.goals[i] : '';
    }
  }

  void _queueSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  String? _nullIfBlank(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _flush() async {
    final entry = _current;
    if (entry == null) return;
    final sleep = double.tryParse(_sleep.text.trim());
    final goals =
        _goals.map((g) => g.text.trim()).where((s) => s.isNotEmpty).toList();
    // Build the full entry directly (not copyWith) so clearing a text field
    // actually persists the clear.
    final updated = JournalEntry(
      id: entry.id,
      userId: entry.userId,
      date: entry.date,
      morningIntent: _nullIfBlank(_intent.text),
      goals: goals,
      nightReview: _nullIfBlank(_review.text),
      wins: _nullIfBlank(_wins.text),
      improve: _nullIfBlank(_improve.text),
      gratitude: _nullIfBlank(_gratitude.text),
      dayRating: entry.dayRating,
      mood: entry.mood,
      energy: entry.energy,
      soreness: entry.soreness,
      sleepHours: sleep,
      sleepQuality: entry.sleepQuality,
    );
    _current = updated;
    try {
      final repo = ref.read(journalRepositoryProvider);
      final persisted = await repo.upsert(updated);
      _current = persisted;
      ref.invalidate(journalForSelectedDateProvider);
      ref.invalidate(journalLast30Provider);
    } catch (_) {
      // Offline / dev — keep the local copy; the next open or sync retries.
    }
  }

  Future<void> _setRating(String field, int value) async {
    HapticFeedback.selectionClick();
    var entry = _current;
    if (entry == null) return;
    switch (field) {
      case 'mood':
        entry = entry.copyWith(mood: value);
        break;
      case 'energy':
        entry = entry.copyWith(energy: value);
        break;
      case 'soreness':
        entry = entry.copyWith(soreness: value);
        break;
      case 'sleep_quality':
        entry = entry.copyWith(sleepQuality: value);
        break;
      case 'day_rating':
        entry = entry.copyWith(dayRating: value);
        break;
    }
    setState(() => _current = entry);
    try {
      final repo = ref.read(journalRepositoryProvider);
      final persisted = await repo.upsert(entry);
      _current = persisted;
      ref.invalidate(journalForSelectedDateProvider);
      ref.invalidate(journalLast30Provider);
    } catch (_) {
      // Offline / dev — local state stands; the next open or sync retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final date = ref.watch(selectedDateProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final entryAsync = ref.watch(journalForSelectedDateProvider);
    final streak = ref.watch(journalingStreakProvider);
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text(
          'Journal · ${DateFormat('EEE d MMM').format(date)}',
          style: context.t.h2.copyWith(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () async {
            try {
              await _flush();
            } catch (_) {}
            if (context.mounted) context.pop();
          },
        ),
        actions: [
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _StreakChip(days: streak),
            ),
        ],
      ),
      body: entryAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text(friendlyError(e),
              style: TextStyle(color: c.negative, fontSize: 13)),
        ),
        data: (existing) {
          final base = existing ??
              (user == null ? null : JournalEntry.empty(user.id, date));
          if (base == null) {
            return Center(
                child: Text('Sign in to journal',
                    style: AppType.body.copyWith(color: c.textMuted)));
          }
          _hydrate(base);
          final current = _current ?? base;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 12, AppSpace.screenH, 80),
            children: [
              if (isToday) const _MoodTimeline(),

              _SectionLabel(text: 'Morning intent'),
              const SizedBox(height: 8),
              _Field(
                controller: _intent,
                hint: 'One line. What matters today?',
                onChanged: (_) => _queueSave(),
                icon: LucideIcons.target,
              ),
              const SizedBox(height: 12),
              _SectionLabel(text: "Today's goals"),
              const SizedBox(height: 8),
              for (int i = 0; i < _goals.length; i++) ...[
                _Field(
                  controller: _goals[i],
                  hint: 'Goal ${i + 1}',
                  onChanged: (_) => _queueSave(),
                  icon: i == 0
                      ? LucideIcons.flag
                      : LucideIcons.cornerDownRight,
                ),
                if (i != _goals.length - 1) const SizedBox(height: 6),
              ],
              const SizedBox(height: 20),

              _SectionLabel(text: 'Wellness'),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.smile,
                label: 'Mood',
                value: current.mood,
                onSelect: (v) => _setRating('mood', v),
              ),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.zap,
                label: 'Energy',
                value: current.energy,
                onSelect: (v) => _setRating('energy', v),
              ),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.activity,
                label: 'Soreness',
                value: current.soreness,
                onSelect: (v) => _setRating('soreness', v),
                lowLabel: 'fresh',
                highLabel: 'wrecked',
              ),
              const SizedBox(height: 20),

              _SectionLabel(text: 'Sleep'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _sleep,
                      hint: 'Hours',
                      onChanged: (_) => _queueSave(),
                      icon: LucideIcons.moon,
                      keyboard:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.bedDouble,
                label: 'Quality',
                value: current.sleepQuality,
                onSelect: (v) => _setRating('sleep_quality', v),
              ),
              const SizedBox(height: 20),

              _SectionLabel(text: 'Evening reflection'),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.star,
                label: 'Day rating',
                value: current.dayRating,
                onSelect: (v) => _setRating('day_rating', v),
              ),
              const SizedBox(height: 8),
              _Field(
                controller: _wins,
                hint: 'What went well today?',
                onChanged: (_) => _queueSave(),
                icon: LucideIcons.checkCircle2,
                maxLines: 3,
              ),
              const SizedBox(height: 6),
              _Field(
                controller: _improve,
                hint: 'What to improve tomorrow?',
                onChanged: (_) => _queueSave(),
                icon: LucideIcons.trendingUp,
                maxLines: 3,
              ),
              const SizedBox(height: 6),
              _Field(
                controller: _gratitude,
                hint: 'Grateful for…',
                onChanged: (_) => _queueSave(),
                icon: LucideIcons.heart,
                maxLines: 2,
              ),
              const SizedBox(height: 6),
              _Field(
                controller: _review,
                hint: 'Anything else on your mind',
                onChanged: (_) => _queueSave(),
                icon: LucideIcons.bookOpen,
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              const _HistoryList(),
            ],
          );
        },
      ),
    );
  }
}
