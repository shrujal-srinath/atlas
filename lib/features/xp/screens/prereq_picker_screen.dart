/// One-shot setup screen where the user picks the milestones that gate the
/// next level transition. Shown:
/// - after onboarding (first launch) for L1 → L2
/// - after a level-up overlay for L_current+1's pre-reqs
///
/// The user can skip entirely (XP alone gates the transition) or pick up to
/// ~5 items. Pre-reqs are interlinked with daily habit logs — no manual
/// tracking is needed once chosen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/dev/dev_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../models/level_prereq.dart';
import '../prereq_providers.dart';

class PrereqPickerScreen extends ConsumerWidget {
  /// The target level (e.g., `2` for L1→L2 pre-reqs).
  final int level;
  const PrereqPickerScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final prereqsAsync = ref.watch(userPrereqsProvider(level));
    final habitsAsync = ref.watch(habitsProvider);
    final habits = habitsAsync.valueOrNull ?? const <Habit>[];
    final chosen = prereqsAsync.valueOrNull ?? const <LevelPrereq>[];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(fallback: '/stats/progression'),
        title: Text('Set milestones', style: t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 12, AppSpace.screenH, 24),
                children: [
                  _HeroCard(level: level),
                  const SizedBox(height: 18),
                  Text(
                    'PICK YOUR MILESTONES',
                    style: AppType.overline.copyWith(
                      color: c.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose 0–5 things that mark this chapter for you. '
                    'Or skip — XP alone (2,100 pts) still works.',
                    style: AppType.meta.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 14),
                  _SuggestionsRow(
                    level: level,
                    onPick: (k) => _addFromSuggestion(context, ref, habits, k),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'CHOSEN (${chosen.length})',
                    style: AppType.overline.copyWith(
                      color: c.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (chosen.isEmpty)
                    _EmptyChosen()
                  else
                    Column(
                      children: [
                        for (final p in chosen) ...[
                          _ChosenRow(
                            prereq: p,
                            label: describePrereq(p, habits),
                            onRemove: () => _remove(ref, p),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  const SizedBox(height: 10),
                  _AddCustomButton(
                    onTap: () => _openCustomSheet(context, ref, habits),
                  ),
                ],
              ),
            ),
            _BottomBar(level: level, chosen: chosen.length),
          ],
        ),
      ),
    );
  }

  void _addFromSuggestion(BuildContext context, WidgetRef ref,
      List<Habit> habits, _SuggestionKind k) async {
    LevelPrereq? built;
    switch (k) {
      case _SuggestionKind.gymSessions:
      case _SuggestionKind.gym25:
      case _SuggestionKind.gym50:
        final h = _pickFirstAthletic(habits);
        if (h == null) {
          _toast(context, 'No athletic habit found — add one first.');
          return;
        }
        final count = switch (k) {
          _SuggestionKind.gym25 => 25,
          _SuggestionKind.gym50 => 50,
          _ => 5,
        };
        built = _make(PrereqKind.habitCompletions, {
          'habitId': h.id,
          'targetCount': count,
        });
        break;
      case _SuggestionKind.streak21:
      case _SuggestionKind.streak30:
      case _SuggestionKind.streak60:
      case _SuggestionKind.streak100:
        final days = switch (k) {
          _SuggestionKind.streak30 => 30,
          _SuggestionKind.streak60 => 60,
          _SuggestionKind.streak100 => 100,
          _ => 21,
        };
        final h = await showHabitPickerSheet(context, habits,
            title: 'Pick a task to streak ($days days)');
        if (h == null) return;
        built = _make(PrereqKind.streakDays, {
          'habitId': h.id,
          'targetDays': days,
        });
        break;
      case _SuggestionKind.perfect7:
      case _SuggestionKind.perfect14:
      case _SuggestionKind.perfect30:
      case _SuggestionKind.perfect60:
        final n = switch (k) {
          _SuggestionKind.perfect14 => 14,
          _SuggestionKind.perfect30 => 30,
          _SuggestionKind.perfect60 => 60,
          _ => 7,
        };
        built = _make(PrereqKind.perfectDays, {
          'targetCount': n,
          'scoreThreshold': 90,
        });
        break;
      case _SuggestionKind.nutrition14:
      case _SuggestionKind.nutrition30:
        final n = k == _SuggestionKind.nutrition30 ? 30 : 14;
        built = _make(PrereqKind.nutritionDays, {
          'targetCount': n,
          'ratioThreshold': 0.80,
        });
        break;
    }
    _commit(ref, built);
  }

  Habit? _pickFirstAthletic(List<Habit> habits) =>
      habits.where((h) => h.section == HabitSection.athletic).firstOrNull;

  LevelPrereq _make(PrereqKind kind, Map<String, dynamic> config) {
    final id = const Uuid().v4();
    return LevelPrereq(
      id: id,
      userId: 'pending',
      level: level,
      kind: kind,
      // Stamp the start so any timeframe window has a clock to count from.
      config: {
        ...config,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  void _commit(WidgetRef ref, LevelPrereq prereq) async {
    if (ref.read(devModeProvider)) {
      addPrereqDevMode(ref, prereq);
      return;
    }
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final withUid = LevelPrereq(
      id: prereq.id,
      userId: session.user.id,
      level: prereq.level,
      kind: prereq.kind,
      config: prereq.config,
    );
    await ref.read(levelPrereqRepoProvider).insert(withUid);
    ref.invalidate(userPrereqsProvider);
  }

  void _remove(WidgetRef ref, LevelPrereq p) async {
    if (ref.read(devModeProvider)) {
      removePrereqDevMode(ref, p.id, p.level);
      return;
    }
    await ref.read(levelPrereqRepoProvider).delete(p.id);
    ref.invalidate(userPrereqsProvider);
  }

  void _openCustomSheet(
      BuildContext context, WidgetRef ref, List<Habit> habits) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.background,
      builder: (ctx) => _CustomPrereqSheet(
        habits: habits,
        onSave: (prereq) {
          final lifted = LevelPrereq(
            id: prereq.id,
            userId: 'pending',
            level: level,
            kind: prereq.kind,
            config: prereq.config,
          );
          _commit(ref, lifted);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

// ── Hero header ──────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final int level;
  const _HeroCard({required this.level});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LEVEL ${level - 1} → LEVEL $level',
                style: AppType.overline
                    .copyWith(color: c.textMuted, letterSpacing: 1.4),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _themeFor(level),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                    letterSpacing: 0.6,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pick the milestones for this chapter',
            style: AppType.display
                .copyWith(color: c.textPrimary, fontSize: 22, letterSpacing: -0.6),
          ),
          const SizedBox(height: 6),
          Text(
            '${level == 2 ? "Break bad habits + build new ones" : _themeFor(level)} — track your real progress alongside the 2,100-XP base.',
            style: AppType.meta.copyWith(color: c.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

String _themeFor(int level) {
  if (level <= 2) return 'FOUNDATIONS';
  if (level <= 5) return 'CONSISTENCY';
  if (level <= 9) return 'DEPTH';
  if (level <= 15) return 'IDENTITY';
  if (level <= 25) return 'MASTERY';
  return 'LEGACY';
}

// ── Suggestion chips ─────────────────────────────────────────────

enum _SuggestionKind {
  gymSessions,
  gym25,
  gym50,
  streak21,
  streak30,
  streak60,
  streak100,
  perfect7,
  perfect14,
  perfect30,
  perfect60,
  nutrition14,
  nutrition30,
}

/// Maps a [_SuggestionKind] to its chip label + icon.
({String label, IconData icon}) _chipFor(_SuggestionKind k) {
  switch (k) {
    case _SuggestionKind.gymSessions:
      return (label: '5 gym sessions', icon: LucideIcons.dumbbell);
    case _SuggestionKind.gym25:
      return (label: '25 gym sessions', icon: LucideIcons.dumbbell);
    case _SuggestionKind.gym50:
      return (label: '50 gym sessions', icon: LucideIcons.dumbbell);
    case _SuggestionKind.streak21:
      return (label: '21-day streak on…', icon: LucideIcons.flame);
    case _SuggestionKind.streak30:
      return (label: '30-day streak on…', icon: LucideIcons.flame);
    case _SuggestionKind.streak60:
      return (label: '60-day streak on…', icon: LucideIcons.flame);
    case _SuggestionKind.streak100:
      return (label: '100-day streak on…', icon: LucideIcons.flame);
    case _SuggestionKind.perfect7:
      return (label: '7 perfect days', icon: LucideIcons.target);
    case _SuggestionKind.perfect14:
      return (label: '14 perfect days', icon: LucideIcons.target);
    case _SuggestionKind.perfect30:
      return (label: '30 perfect days', icon: LucideIcons.target);
    case _SuggestionKind.perfect60:
      return (label: '60 perfect days', icon: LucideIcons.target);
    case _SuggestionKind.nutrition14:
      return (label: '14d nutrition target', icon: LucideIcons.apple);
    case _SuggestionKind.nutrition30:
      return (label: '30d nutrition target', icon: LucideIcons.apple);
  }
}

/// Theme-band-aware suggestions. Each band gets 3–4 themed milestones so the
/// user feels the journey instead of seeing the same chips at every level.
/// See docs/LEVELING.md §7 for the band themes.
List<_SuggestionKind> _suggestionsForLevel(int level) {
  // Foundations (L1–2): break + build basics.
  if (level <= 2) {
    return const [
      _SuggestionKind.gymSessions,
      _SuggestionKind.streak21,
      _SuggestionKind.perfect7,
    ];
  }
  // Consistency (L3–5): multi-week streaks, no-break.
  if (level <= 5) {
    return const [
      _SuggestionKind.perfect14,
      _SuggestionKind.streak30,
      _SuggestionKind.nutrition14,
    ];
  }
  // Depth (L6–9): per-skill mastery.
  if (level <= 9) {
    return const [
      _SuggestionKind.gym25,
      _SuggestionKind.streak30,
      _SuggestionKind.perfect30,
      _SuggestionKind.nutrition30,
    ];
  }
  // Identity (L10–15): 60d streaks, deep journaling habit.
  if (level <= 15) {
    return const [
      _SuggestionKind.streak60,
      _SuggestionKind.perfect60,
      _SuggestionKind.gym50,
    ];
  }
  // Mastery (L16–25) & Legacy (L26+): hardest milestones.
  return const [
    _SuggestionKind.streak100,
    _SuggestionKind.perfect60,
    _SuggestionKind.gym50,
  ];
}

class _SuggestionsRow extends StatelessWidget {
  final int level;
  final void Function(_SuggestionKind) onPick;
  const _SuggestionsRow({required this.level, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final kinds = _suggestionsForLevel(level);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in kinds)
          _SuggestionChip(
            label: _chipFor(k).label,
            icon: _chipFor(k).icon,
            onTap: () => onPick(k),
          ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: c.border, width: 0.5),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: c.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.plus, size: 13, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chosen rows ──────────────────────────────────────────────────

class _ChosenRow extends StatelessWidget {
  final LevelPrereq prereq;
  final String label;
  final VoidCallback onRemove;
  const _ChosenRow({
    required this.prereq,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = _kindColor(c, prereq.kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 6, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(_kindIcon(prereq.kind), size: 15, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.x, size: 16, color: c.textMuted),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(PrereqKind k) => switch (k) {
      PrereqKind.habitCompletions => LucideIcons.checkSquare,
      PrereqKind.streakDays => LucideIcons.flame,
      PrereqKind.perfectDays => LucideIcons.target,
      PrereqKind.nutritionDays => LucideIcons.utensils,
    };

Color _kindColor(AppPalette c, PrereqKind k) => switch (k) {
      PrereqKind.habitCompletions => c.accent,
      PrereqKind.streakDays => c.amber,
      PrereqKind.perfectDays => c.athletic,
      PrereqKind.nutritionDays => c.body,
    };

class _EmptyChosen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
            color: c.border, width: 0.5, strokeAlign: BorderSide.strokeAlignInside),
      ),
      alignment: Alignment.center,
      child: Text(
        'No milestones chosen — XP-only level-up.',
        style: AppType.meta.copyWith(color: c.textMuted),
      ),
    );
  }
}

class _AddCustomButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCustomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AtlasButton(
      label: 'Custom milestone',
      icon: LucideIcons.plus,
      variant: AtlasButtonVariant.tonal,
      height: 46,
      onPressed: onTap,
    );
  }
}

// ── Bottom CTA bar ───────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int level;
  final int chosen;
  const _BottomBar({required this.level, required this.chosen});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => popOrGo(context, '/stats/progression'),
                child: Text(
                  'Skip',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      color: c.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => popOrGo(context, '/stats/progression'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text(
                  chosen == 0 ? 'Lock in (XP only)' : 'Lock in $chosen',
                  style: const TextStyle(
                      fontFamily: 'Inter', fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Themed task picker ───────────────────────────────────────────
//
// Reusable bottom sheet that lists the user's tasks (habits) so a milestone
// can be linked to a real one. Replaces the bare dropdown that showed the
// literal word "Habit".

Future<Habit?> showHabitPickerSheet(
  BuildContext context,
  List<Habit> habits, {
  required String title,
}) {
  return showModalBottomSheet<Habit>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.c;
      return Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpace.screenH,
          14,
          AppSpace.screenH,
          MediaQuery.of(ctx).viewPadding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: ctx.t.h2),
            const SizedBox(height: 12),
            if (habits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('No tasks yet — create one first.',
                    style: AppType.meta.copyWith(color: c.textMuted)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: habits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final h = habits[i];
                    final color = h.section.color(c);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(ctx).pop(h);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.surfaceElevated,
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                            border: Border.all(color: c.border, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(habitIcon(h.icon),
                                    size: 15, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h.name, style: ctx.t.bodyStrong),
                                    Text(_sectionLabel(h.section),
                                        style: AppType.meta
                                            .copyWith(color: c.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

// ── Custom prereq sheet ──────────────────────────────────────────

class _CustomPrereqSheet extends StatefulWidget {
  final List<Habit> habits;
  final void Function(LevelPrereq prereq) onSave;
  const _CustomPrereqSheet({required this.habits, required this.onSave});

  @override
  State<_CustomPrereqSheet> createState() => _CustomPrereqSheetState();
}

class _CustomPrereqSheetState extends State<_CustomPrereqSheet> {
  PrereqKind _kind = PrereqKind.habitCompletions;
  Habit? _habit;
  int _count = 7;
  int _threshold = 90; // score % or nutrition %
  int? _windowDays; // null = no timeframe

  bool get _needsHabit =>
      _kind == PrereqKind.habitCompletions || _kind == PrereqKind.streakDays;
  bool get _hasThreshold =>
      _kind == PrereqKind.perfectDays || _kind == PrereqKind.nutritionDays;

  String get _countLabel => switch (_kind) {
        PrereqKind.habitCompletions => 'Repetitions',
        PrereqKind.streakDays => 'Streak length (days)',
        PrereqKind.perfectDays => 'Number of days',
        PrereqKind.nutritionDays => 'Number of days',
      };

  void _onKindChanged(PrereqKind k) {
    setState(() {
      _kind = k;
      if (k == PrereqKind.streakDays && _count < 7) _count = 21;
      _threshold = k == PrereqKind.nutritionDays ? 80 : 90;
    });
  }

  Future<void> _pickHabit() async {
    final h = await showHabitPickerSheet(context, widget.habits,
        title: 'Link a task');
    if (h != null) setState(() => _habit = h);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        14,
        AppSpace.screenH,
        MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Custom milestone', style: context.t.h2),
            const SizedBox(height: 18),

            _FieldLabel('TYPE'),
            const SizedBox(height: 8),
            _KindChips(selected: _kind, onChanged: _onKindChanged),
            const SizedBox(height: 18),

            if (_needsHabit) ...[
              _FieldLabel('TASK'),
              const SizedBox(height: 8),
              _PickerTile(
                icon: _habit == null
                    ? LucideIcons.listPlus
                    : habitIcon(_habit!.icon),
                color: _habit == null
                    ? c.textMuted
                    : _habit!.section.color(c),
                label: _habit?.name ?? 'Choose a task',
                muted: _habit == null,
                onTap: _pickHabit,
              ),
              const SizedBox(height: 18),
            ],

            _FieldLabel(_countLabel.toUpperCase()),
            const SizedBox(height: 8),
            _Stepper(
              value: _count,
              min: 1,
              max: 365,
              step: _kind == PrereqKind.habitCompletions ? 1 : 1,
              onChanged: (v) => setState(() => _count = v),
            ),

            if (_hasThreshold) ...[
              const SizedBox(height: 18),
              _FieldLabel(_kind == PrereqKind.perfectDays
                  ? 'MIN SCORE (%)'
                  : 'MIN NUTRITION (%)'),
              const SizedBox(height: 8),
              _Stepper(
                value: _threshold,
                min: 50,
                max: 100,
                step: 5,
                onChanged: (v) => setState(() => _threshold = v),
              ),
            ],

            const SizedBox(height: 18),
            Row(
              children: [
                _FieldLabel('TIMEFRAME'),
                const SizedBox(width: 8),
                Text('optional',
                    style: AppType.meta.copyWith(color: c.textDim)),
              ],
            ),
            const SizedBox(height: 8),
            _TimeframeChips(
              selected: _windowDays,
              onChanged: (v) => setState(() => _windowDays = v),
            ),
            const SizedBox(height: 6),
            Text(
              _windowDays == null
                  ? 'No deadline — finish it whenever.'
                  : 'You’ll have $_windowDays days to finish this once set.',
              style: AppType.meta.copyWith(color: c.textMuted),
            ),

            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: AtlasButton(
                    label: 'Cancel',
                    variant: AtlasButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AtlasButton(
                    label: 'Save milestone',
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_needsHabit && _habit == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a task to link this milestone to.')),
      );
      return;
    }
    final cfg = <String, dynamic>{
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      if (_windowDays != null) 'windowDays': _windowDays,
    };
    switch (_kind) {
      case PrereqKind.habitCompletions:
        cfg.addAll({'habitId': _habit!.id, 'targetCount': _count});
        break;
      case PrereqKind.streakDays:
        cfg.addAll({'habitId': _habit!.id, 'targetDays': _count});
        break;
      case PrereqKind.perfectDays:
        cfg.addAll({'targetCount': _count, 'scoreThreshold': _threshold});
        break;
      case PrereqKind.nutritionDays:
        cfg.addAll({'targetCount': _count, 'ratioThreshold': _threshold / 100.0});
        break;
    }
    final p = LevelPrereq(
      id: const Uuid().v4(),
      userId: 'pending',
      level: 0, // overwritten by caller
      kind: _kind,
      config: cfg,
    );
    widget.onSave(p);
  }
}

// ── Custom-sheet building blocks ─────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppType.overline
            .copyWith(color: context.c.textMuted, letterSpacing: 1.2),
      );
}

({String label, IconData icon}) _kindChip(PrereqKind k) => switch (k) {
      PrereqKind.habitCompletions =>
        (label: 'Task reps', icon: LucideIcons.checkSquare),
      PrereqKind.streakDays => (label: 'Streak', icon: LucideIcons.flame),
      PrereqKind.perfectDays =>
        (label: 'Perfect days', icon: LucideIcons.target),
      PrereqKind.nutritionDays =>
        (label: 'Nutrition', icon: LucideIcons.utensils),
    };

class _KindChips extends StatelessWidget {
  final PrereqKind selected;
  final ValueChanged<PrereqKind> onChanged;
  const _KindChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in PrereqKind.values)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(k);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: selected == k ? c.accentSoft : c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: selected == k ? c.accent : c.border,
                  width: selected == k ? 1 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_kindChip(k).icon,
                      size: 13,
                      color: selected == k ? c.accent : c.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    _kindChip(k).label,
                    style: AppType.label.copyWith(
                      color: selected == k ? c.accent : c.textSecondary,
                      fontWeight:
                          selected == k ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool muted;
  final VoidCallback onTap;
  const _PickerTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: context.t.bodyStrong.copyWith(
                    color: muted ? c.textMuted : c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(icon,
                  size: 20,
                  color: onTap == null ? c.textDim : c.textPrimary),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          btn(LucideIcons.minus,
              value > min ? () => onChanged((value - step).clamp(min, max)) : null),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppType.numMd.copyWith(color: c.textPrimary, fontSize: 20),
            ),
          ),
          btn(LucideIcons.plus,
              value < max ? () => onChanged((value + step).clamp(min, max)) : null),
        ],
      ),
    );
  }
}

class _TimeframeChips extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;
  const _TimeframeChips({required this.selected, required this.onChanged});

  static const _options = <({String label, int? days})>[
    (label: 'No deadline', days: null),
    (label: '21 days', days: 21),
    (label: '30 days', days: 30),
    (label: '60 days', days: 60),
    (label: '90 days', days: 90),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in _options)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(o.days);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: selected == o.days ? c.accentSoft : c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: selected == o.days ? c.accent : c.border,
                  width: selected == o.days ? 1 : 0.5,
                ),
              ),
              child: Text(
                o.label,
                style: AppType.label.copyWith(
                  color: selected == o.days ? c.accent : c.textSecondary,
                  fontWeight:
                      selected == o.days ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _sectionLabel(HabitSection s) => switch (s) {
      HabitSection.athletic => 'Athletic',
      HabitSection.mind => 'Mind',
      HabitSection.body => 'Body',
    };
