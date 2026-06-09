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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/dev/dev_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
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
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
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
        final h = await _pickHabit(context, habits,
            title: 'Pick a habit to streak ($days days)');
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
      config: config,
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

  Future<Habit?> _pickHabit(BuildContext context, List<Habit> habits,
      {required String title}) {
    return showModalBottomSheet<Habit>(
      context: context,
      backgroundColor: context.c.background,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.c;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ctx.t.h2),
                const SizedBox(height: 12),
                if (habits.isEmpty)
                  Text('No habits yet — create one first.',
                      style: AppType.meta.copyWith(color: c.textMuted))
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: habits.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1, thickness: 0.5, color: c.border),
                      itemBuilder: (_, i) {
                        final h = habits[i];
                        return ListTile(
                          title: Text(h.name, style: ctx.t.bodyStrong),
                          subtitle: Text(_sectionLabel(h.section),
                              style: AppType.meta.copyWith(color: c.textMuted)),
                          onTap: () => Navigator.of(ctx).pop(h),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
    final c = context.c;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(LucideIcons.plus, size: 14, color: c.accent),
      label: Text(
        'Custom milestone',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.accent,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.border, width: 0.5),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card)),
      ),
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
                onPressed: () => context.pop(),
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
                onPressed: () => context.pop(),
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
  final _countCtl = TextEditingController(text: '7');
  final _thresholdCtl = TextEditingController(text: '90');

  @override
  void dispose() {
    _countCtl.dispose();
    _thresholdCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final needsHabit = _kind == PrereqKind.habitCompletions ||
        _kind == PrereqKind.streakDays;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 18, 20, 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Custom milestone', style: context.t.h2),
          const SizedBox(height: 12),
          DropdownButtonFormField<PrereqKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Kind'),
            items: const [
              DropdownMenuItem(
                  value: PrereqKind.habitCompletions,
                  child: Text('Habit completions')),
              DropdownMenuItem(
                  value: PrereqKind.streakDays, child: Text('Streak days')),
              DropdownMenuItem(
                  value: PrereqKind.perfectDays, child: Text('Perfect days')),
              DropdownMenuItem(
                  value: PrereqKind.nutritionDays,
                  child: Text('Nutrition days')),
            ],
            onChanged: (k) => setState(() => _kind = k ?? _kind),
          ),
          const SizedBox(height: 10),
          if (needsHabit) ...[
            DropdownButtonFormField<Habit>(
              initialValue: _habit,
              decoration: const InputDecoration(labelText: 'Habit'),
              items: [
                for (final h in widget.habits)
                  DropdownMenuItem(value: h, child: Text(h.name)),
              ],
              onChanged: (h) => setState(() => _habit = h),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _countCtl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _kind == PrereqKind.streakDays ? 'Days' : 'Count',
            ),
          ),
          if (_kind == PrereqKind.perfectDays ||
              _kind == PrereqKind.nutritionDays) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _thresholdCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _kind == PrereqKind.perfectDays
                    ? 'Min score (0-100)'
                    : 'Min nutrition % (0-100)',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: TextStyle(color: c.textMuted)),
                ),
              ),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final raw = int.tryParse(_countCtl.text.trim()) ?? 0;
    if (raw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a target count > 0')),
      );
      return;
    }
    if ((_kind == PrereqKind.habitCompletions ||
            _kind == PrereqKind.streakDays) &&
        _habit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a habit')),
      );
      return;
    }
    final cfg = <String, dynamic>{};
    switch (_kind) {
      case PrereqKind.habitCompletions:
        cfg.addAll({'habitId': _habit!.id, 'targetCount': raw});
        break;
      case PrereqKind.streakDays:
        cfg.addAll({'habitId': _habit!.id, 'targetDays': raw});
        break;
      case PrereqKind.perfectDays:
        final th = int.tryParse(_thresholdCtl.text.trim()) ?? 90;
        cfg.addAll({'targetCount': raw, 'scoreThreshold': th});
        break;
      case PrereqKind.nutritionDays:
        final th = (int.tryParse(_thresholdCtl.text.trim()) ?? 80) / 100.0;
        cfg.addAll({'targetCount': raw, 'ratioThreshold': th});
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

String _sectionLabel(HabitSection s) => switch (s) {
      HabitSection.athletic => 'Athletic',
      HabitSection.mind => 'Mind',
      HabitSection.body => 'Body',
    };
