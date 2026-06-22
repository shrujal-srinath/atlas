import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../habits/providers/habit_provider.dart';
import '../../habits/widgets/urge_surf_modal.dart';

part 'habit_log_widgets.dart';

enum HabitSheetMode { compact, expanded }

enum _BreakingOutcome { brokeIt, surfedIt, urgeOnly }

const _triggers = ['Stress', 'Bored', 'Social', 'Craving', 'Tired', 'Other'];

/// Compact "tap habit → quick action" sheet. Opens at ~360dp; user can flip
/// to the full editor via "More options". Replaces the page-sized modal for
/// the home-screen tap path.
Future<void> showHabitQuickSheet(
  BuildContext context,
  Habit habit,
  HabitLog? log,
  String dateStr,
) =>
    showHabitLogModal(context, habit, log, dateStr,
        mode: HabitSheetMode.compact);

/// Legacy entry — full editor. Kept for the stats / score screens where the
/// user has already drilled in and expects the full surface.
Future<void> showHabitLogModal(
  BuildContext context,
  Habit habit,
  HabitLog? log,
  String dateStr, {
  HabitSheetMode mode = HabitSheetMode.expanded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HabitLogSheet(
      habit: habit,
      log: log,
      dateStr: dateStr,
      initialMode: mode,
    ),
  );
}

class _HabitLogSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final HabitLog? log;
  final String dateStr;
  final HabitSheetMode initialMode;

  const _HabitLogSheet({
    required this.habit,
    required this.log,
    required this.dateStr,
    required this.initialMode,
  });

  @override
  ConsumerState<_HabitLogSheet> createState() => _HabitLogSheetState();
}

class _HabitLogSheetState extends ConsumerState<_HabitLogSheet> {
  late HabitSheetMode _mode;
  late bool _isDone;
  late int _effortRating;
  late _BreakingOutcome? _breakingOutcome;
  late String? _selectedTrigger;
  late TextEditingController _noteCtrl;
  late TextEditingController _valueCtrl;
  bool _saving = false;
  // Compact meta: inline reveals.
  bool _effortExpanded = false;
  bool _noteExpanded = false;
  /// Local filesystem path of the proof photo for this completion. Set by
  /// `_captureProof` and persisted under app docs at a deterministic path so
  /// it can be re-located later from habit detail.
  String? _proofPath;

  bool get _isBreaking => widget.habit.type == HabitType.negative;
  bool get _isTodo => widget.habit.type == HabitType.todo;

  bool get _hasNumericGoal =>
      widget.habit.type == HabitType.positive &&
      widget.habit.goalType != null &&
      (widget.habit.goalValue ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final log = widget.log;
    _isDone = log?.completed ?? false;
    _effortRating = log?.effortRating ?? 0;
    _noteCtrl = TextEditingController(text: log?.note ?? '');
    final av = log?.actualValue;
    _valueCtrl = TextEditingController(
      text: av == null ? '' : _trimZero(av),
    );
    _selectedTrigger = log?.triggerTag;

    if (_isBreaking && log != null) {
      if (log.urgeOnly) {
        _breakingOutcome = _BreakingOutcome.urgeOnly;
      } else if (log.completed) {
        _breakingOutcome = _BreakingOutcome.surfedIt;
      } else {
        _breakingOutcome = _BreakingOutcome.brokeIt;
      }
    } else {
      _breakingOutcome = null;
    }

    // Pre-expand effort/note in compact mode if there's prior content.
    _effortExpanded = _effortRating > 0;
    _noteExpanded = _noteCtrl.text.isNotEmpty;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  static String _trimZero(double v) {
    final r = v.toStringAsFixed(2);
    if (r.endsWith('.00')) return r.substring(0, r.length - 3);
    if (r.endsWith('0')) return r.substring(0, r.length - 1);
    return r;
  }

  double get _currentValue =>
      double.tryParse(_valueCtrl.text.trim()) ?? 0.0;

  void _setValue(double v) {
    if (v < 0) v = 0;
    _valueCtrl.text = _trimZero(v);
    final goal = widget.habit.goalValue ?? 0;
    if (goal > 0 && v >= goal && !_isDone) {
      setState(() => _isDone = true);
    } else {
      setState(() {});
    }
  }

  void _addToValue(double delta) => _setValue(_currentValue + delta);

  Future<void> _save({bool closeOnSuccess = true}) async {
    setState(() => _saving = true);
    try {
      if (_isBreaking) {
        if (_breakingOutcome == null) {
          setState(() => _saving = false);
          return;
        }
        await ref.read(habitActionsProvider.notifier).toggleHabit(
              widget.habit.id,
              widget.dateStr,
              completed: _breakingOutcome == _BreakingOutcome.surfedIt ||
                  _breakingOutcome == _BreakingOutcome.urgeOnly,
              note: _noteCtrl.text,
              triggerTag: _breakingOutcome == _BreakingOutcome.brokeIt
                  ? _selectedTrigger
                  : null,
              urgeOnly: _breakingOutcome == _BreakingOutcome.urgeOnly,
            );
      } else {
        await ref.read(habitActionsProvider.notifier).toggleHabit(
              widget.habit.id,
              widget.dateStr,
              completed: _isDone,
              effortRating: _effortRating,
              note: _noteCtrl.text,
              actualValue: _hasNumericGoal ? _currentValue : null,
            );
      }
      if (mounted && closeOnSuccess) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _expandToFull() {
    HapticFeedback.selectionClick();
    setState(() => _mode = HabitSheetMode.expanded);
  }

  void _viewDetails() {
    Navigator.of(context).pop();
    context.push('/habit/${widget.habit.id}');
  }

  /// Captures a photo via the camera, copies it into a deterministic spot
  /// under app docs (`habit_proofs/{habitId}-{date}.jpg`), and returns true
  /// on success. Used to gate completion when `photoProofEnabled` is on.
  Future<bool> _captureProof() async {
    HapticFeedback.selectionClick();
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (shot == null) return false;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'habit_proofs'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final dest = File(
        p.join(dir.path, '${widget.habit.id}-${widget.dateStr}.jpg'),
      );
      await File(shot.path).copy(dest.path);
      if (mounted) setState(() => _proofPath = dest.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final secColor = widget.habit.section.color(c);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: AppShadows.sheet,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _header(c, t, secColor),
              Divider(height: 1, color: c.border),
              const SizedBox(height: 14),
              if (_mode == HabitSheetMode.compact)
                _buildCompactBody(c, t, secColor)
              else
                _buildExpandedBody(c, t, secColor),
              _buildFooter(c, t),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────

  Widget _header(AppPalette c, AppTextStyles t, Color secColor) {
    final priority = widget.habit.priority;
    final showPriorityDot = priority != HabitPriority.normal && priority != HabitPriority.low;
    final priorityColor = switch (priority) {
      HabitPriority.high => c.amber,
      HabitPriority.critical => c.negative,
      _ => c.textMuted,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: secColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadii.chip),
              border: Border.all(color: secColor.withValues(alpha: 0.25), width: 0.5),
            ),
            child: Icon(habitIcon(widget.habit.icon), size: 20, color: secColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.habit.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: c.textPrimary,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showPriorityDot) ...[
                      const SizedBox(width: 6),
                      Icon(
                        priority == HabitPriority.critical
                            ? LucideIcons.alertTriangle
                            : LucideIcons.chevronsUp,
                        size: 12,
                        color: priorityColor,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _sectionLabel(widget.habit.section),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: secColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          if (_mode == HabitSheetMode.compact)
            _CircleIconBtn(
              icon: LucideIcons.arrowUpRight,
              tooltip: 'Open detail',
              onTap: _viewDetails,
            ),
        ],
      ),
    );
  }

  // ── Compact body ─────────────────────────────────────────────────────

  Widget _buildCompactBody(AppPalette c, AppTextStyles t, Color secColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isBreaking)
            _buildCompactBreaking(c, t, secColor)
          else
            _buildCompactPositive(c, t, secColor),
        ],
      ),
    );
  }

  Widget _buildCompactPositive(AppPalette c, AppTextStyles t, Color secColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasNumericGoal) ...[
          _CompactStepper(
            currentValue: _currentValue,
            goal: widget.habit.goalValue!,
            unit: _unitLabelFor(widget.habit.goalType!),
            sectionColor: secColor,
            onAdd: _addToValue,
            onSet: _setValue,
          ),
          const SizedBox(height: 12),
        ],
        _compactPrimaryCta(c, secColor),
        if (widget.habit.effortRatingEnabled || widget.habit.noteEnabled) ...[
          const SizedBox(height: 12),
          _compactMetaRow(c, t, secColor),
        ],
      ],
    );
  }

  Widget _buildCompactBreaking(AppPalette c, AppTextStyles t, Color secColor) {
    final hasOutcome = _breakingOutcome != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _CompactOutcomeBtn(
                label: 'Surfed it',
                color: c.positive,
                selected: _breakingOutcome == _BreakingOutcome.surfedIt,
                onTap: () => setState(() {
                  _breakingOutcome = _BreakingOutcome.surfedIt;
                  _selectedTrigger = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactOutcomeBtn(
                label: 'Urge only',
                color: c.textSecondary,
                selected: _breakingOutcome == _BreakingOutcome.urgeOnly,
                onTap: () => setState(() {
                  _breakingOutcome = _BreakingOutcome.urgeOnly;
                  _selectedTrigger = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactOutcomeBtn(
                label: 'Broke it',
                color: c.negative,
                selected: _breakingOutcome == _BreakingOutcome.brokeIt,
                onTap: () => setState(() => _breakingOutcome = _BreakingOutcome.brokeIt),
              ),
            ),
          ],
        ),
        if (_breakingOutcome == _BreakingOutcome.brokeIt) ...[
          const SizedBox(height: 12),
          Text('Trigger', style: t.label.copyWith(fontSize: 11, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _triggers.map((trig) {
              final selected = _selectedTrigger == trig;
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedTrigger = selected ? null : trig),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? c.negative.withValues(alpha: 0.12)
                        : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: selected ? c.negative : c.border,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    trig,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: selected ? c.negative : c.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: hasOutcome && !_saving
                ? () async {
                    HapticFeedback.mediumImpact();
                    await _save();
                  }
                : null,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.onAccent),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        if (widget.habit.type == HabitType.negative) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final outcome = await showUrgeSurfModal(
                context,
                habit: widget.habit,
                dateStr: widget.dateStr,
              );
              if (!mounted) return;
              if (outcome == UrgeOutcome.surfed) {
                Navigator.pop(context);
              } else if (outcome == UrgeOutcome.gaveIn) {
                setState(() => _breakingOutcome = _BreakingOutcome.brokeIt);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: c.accent.withValues(alpha: 0.35), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.waves, size: 14, color: c.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Surf the urge · 5 min',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactPrimaryCta(AppPalette c, Color secColor) {
    final isTimer = widget.habit.type == HabitType.positive &&
        widget.habit.goalType == GoalType.durationMin &&
        (widget.habit.goalValue ?? 0) > 0 &&
        !_isDone;
    // Photo-proof gate: the user must capture a photo before the habit can
    // flip to done. Once `_proofPath` is set, completion proceeds normally.
    final needsProof = widget.habit.photoProofEnabled &&
        widget.habit.type == HabitType.positive &&
        !_isDone &&
        _proofPath == null;

    String label;
    IconData? icon;
    if (_isTodo) {
      label = _isDone ? 'Undo · done' : 'Mark done';
    } else if (needsProof) {
      label = 'Take photo to complete';
      icon = LucideIcons.camera;
    } else if (isTimer) {
      label = 'Start ${_trimZero(widget.habit.goalValue!)} min';
      icon = LucideIcons.play;
    } else if (_hasNumericGoal) {
      final goal = widget.habit.goalValue!;
      final unit = _unitLabelFor(widget.habit.goalType!);
      if (_currentValue <= 0) {
        label = 'Log ${_trimZero(goal)} $unit';
      } else if (_currentValue >= goal) {
        label = 'Complete · ${_trimZero(_currentValue)} $unit';
      } else {
        label = 'Log ${_trimZero(_currentValue)} / ${_trimZero(goal)} $unit';
      }
    } else {
      label = _isDone ? 'Undo · done' : 'Complete';
    }

    final showUndo = _isDone && (_isTodo || (!_hasNumericGoal));

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: showUndo ? c.surfaceElevated : c.accent,
          foregroundColor: showUndo ? c.textPrimary : c.onAccent,
        ),
        onPressed: _saving
            ? null
            : () async {
                HapticFeedback.mediumImpact();
                if (needsProof) {
                  final ok = await _captureProof();
                  if (!ok) return;
                  // Proof captured — fall through to mark done.
                }
                if (isTimer && !needsProof) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  context.push('/habit/${widget.habit.id}/focus');
                  return;
                }
                if (_isTodo) {
                  setState(() => _isDone = !_isDone);
                } else if (_hasNumericGoal) {
                  if (_currentValue <= 0) {
                    _setValue(widget.habit.goalValue ?? 0);
                  }
                  final goal = widget.habit.goalValue ?? 0;
                  setState(() => _isDone = _currentValue >= goal);
                } else {
                  setState(() => _isDone = !_isDone);
                }
                await _save();
              },
        child: _saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: showUndo ? c.textPrimary : c.onAccent,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _compactMetaRow(AppPalette c, AppTextStyles t, Color secColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.habit.effortRatingEnabled)
              Expanded(
                child: _MetaPill(
                  icon: LucideIcons.star,
                  label: _effortRating > 0
                      ? '$_effortRating / 5'
                      : 'Add effort',
                  active: _effortExpanded || _effortRating > 0,
                  accent: c.amber,
                  onTap: () =>
                      setState(() => _effortExpanded = !_effortExpanded),
                ),
              ),
            if (widget.habit.effortRatingEnabled && widget.habit.noteEnabled)
              const SizedBox(width: 8),
            if (widget.habit.noteEnabled)
              Expanded(
                child: _MetaPill(
                  icon: LucideIcons.pencil,
                  label: _noteCtrl.text.isEmpty
                      ? 'Add note'
                      : 'Note ·  ✓',
                  active: _noteExpanded || _noteCtrl.text.isNotEmpty,
                  accent: secColor,
                  onTap: () => setState(() => _noteExpanded = !_noteExpanded),
                ),
              ),
          ],
        ),
        if (widget.habit.effortRatingEnabled && _effortExpanded) ...[
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = star <= _effortRating;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _effortRating =
                        _effortRating == star ? 0 : star);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: filled
                          ? c.amber.withValues(alpha: 0.14)
                          : c.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: Border.all(
                        color: filled ? c.amber : c.border,
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.star,
                      size: 17,
                      color: filled ? c.amber : c.textDim,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
        if (widget.habit.noteEnabled && _noteExpanded) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            style: t.body.copyWith(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'How did it go?',
              hintStyle: t.body.copyWith(color: c.textMuted, fontSize: 13),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: secColor, width: 1),
              ),
            ),
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  // ── Expanded body (legacy, untouched) ────────────────────────────────

  Widget _buildExpandedBody(AppPalette c, AppTextStyles t, Color secColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _isBreaking ? _buildBreakingBody(c, t) : _buildPositiveBody(c, t),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.onAccent),
                    )
                  : const Text('Save'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositiveBody(AppPalette c, AppTextStyles t) {
    final secColor = widget.habit.section.color(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasNumericGoal) ...[
          _NumericProgressBlock(
            valueCtrl: _valueCtrl,
            current: _currentValue,
            goal: widget.habit.goalValue!,
            unit: _unitLabelFor(widget.habit.goalType!),
            sectionColor: secColor,
            onChanged: (_) => setState(() {
              final goal = widget.habit.goalValue ?? 0;
              if (goal > 0 && _currentValue >= goal) _isDone = true;
            }),
            onAdd: _addToValue,
            onSet: _setValue,
          ),
          const SizedBox(height: 16),
        ],
        GestureDetector(
          onTap: () => setState(() => _isDone = !_isDone),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _isDone ? c.positive.withValues(alpha: 0.12) : c.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: Border.all(
                color: _isDone ? c.positive : c.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isDone ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color: _isDone ? c.positive : c.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  _isDone ? 'Done' : 'Mark as done',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isDone ? c.positive : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.habit.effortRatingEnabled) ...[
          const SizedBox(height: 22),
          Text('How hard?', style: t.label),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = star <= _effortRating;
              return GestureDetector(
                onTap: () => setState(
                    () => _effortRating = _effortRating == star ? 0 : star),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    LucideIcons.star,
                    color: filled ? c.amber : c.textDim,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ],
        if (widget.habit.noteEnabled) ...[
          const SizedBox(height: 22),
          Text('Quick note', style: t.label),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            style: t.body,
            decoration: const InputDecoration(hintText: 'How did it go?'),
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildBreakingBody(AppPalette c, AppTextStyles t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AtlasButton(
          label: 'Surf the urge · 5 min',
          icon: LucideIcons.waves,
          variant: AtlasButtonVariant.tonal,
          height: 48,
          onPressed: () async {
            final outcome = await showUrgeSurfModal(
              context,
              habit: widget.habit,
              dateStr: widget.dateStr,
            );
            if (!mounted) return;
            if (outcome == UrgeOutcome.surfed) {
              Navigator.pop(context);
            } else if (outcome == UrgeOutcome.gaveIn) {
              setState(() => _breakingOutcome = _BreakingOutcome.brokeIt);
            }
          },
        ),
        const SizedBox(height: 18),
        Text("How'd it go?", style: t.label),
        const SizedBox(height: 10),
        Row(
          children: [
            _OutcomeBtn(
              label: 'Broke it',
              color: c.negative,
              selected: _breakingOutcome == _BreakingOutcome.brokeIt,
              onTap: () =>
                  setState(() => _breakingOutcome = _BreakingOutcome.brokeIt),
            ),
            const SizedBox(width: 8),
            _OutcomeBtn(
              label: 'Surfed it',
              color: c.positive,
              selected: _breakingOutcome == _BreakingOutcome.surfedIt,
              onTap: () => setState(() {
                _breakingOutcome = _BreakingOutcome.surfedIt;
                _selectedTrigger = null;
              }),
            ),
            const SizedBox(width: 8),
            _OutcomeBtn(
              label: 'Urge only',
              color: c.textSecondary,
              selected: _breakingOutcome == _BreakingOutcome.urgeOnly,
              onTap: () => setState(() {
                _breakingOutcome = _BreakingOutcome.urgeOnly;
                _selectedTrigger = null;
              }),
            ),
          ],
        ),
        if (_breakingOutcome == _BreakingOutcome.brokeIt) ...[
          const SizedBox(height: 22),
          Text('What triggered it?', style: t.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _triggers.map((trig) {
              final selected = _selectedTrigger == trig;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedTrigger = selected ? null : trig),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? c.negative.withValues(alpha: 0.12)
                        : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: selected ? c.negative : c.border,
                    ),
                  ),
                  child: Text(
                    trig,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: selected ? c.negative : c.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (widget.habit.noteEnabled) ...[
          const SizedBox(height: 22),
          Text('Quick note', style: t.label),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            style: t.body,
            decoration: const InputDecoration(hintText: 'Anything to note?'),
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────

  Widget _buildFooter(AppPalette c, AppTextStyles t) {
    if (_mode == HabitSheetMode.compact) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
            14, 4, 14, 12 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                icon: Icon(LucideIcons.arrowUpRight,
                    size: 14, color: c.textMuted),
                label: Text(
                  'View details',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: _viewDetails,
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon:
                    Icon(LucideIcons.sliders, size: 14, color: c.textMuted),
                label: Text(
                  'More options',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: _expandToFull,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 4),
      child: const SizedBox.shrink(),
    );
  }

  static String _sectionLabel(HabitSection s) => switch (s) {
        HabitSection.athletic => 'Athletic',
        HabitSection.body => 'Breaking',
        HabitSection.mind => 'Building',
      };
}
