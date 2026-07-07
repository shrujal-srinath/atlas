import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../home/scoring/section_def.dart';
import '../providers/habit_provider.dart';

/// Full-screen countdown timer for a single `durationMin` habit. Starts
/// at goalValue minutes; on complete, auto-logs the habit and pops. Stopping
/// early logs whatever fraction was completed as `actualValue` (also persisted
/// so partial credit shows up in the score engine).
class HabitFocusScreen extends ConsumerStatefulWidget {
  final String habitId;
  const HabitFocusScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitFocusScreen> createState() => _HabitFocusScreenState();
}

class _HabitFocusScreenState extends ConsumerState<HabitFocusScreen> {
  Timer? _tick;
  int _totalSec = 0;
  int _remainingSec = 0;
  bool _running = false;
  bool _finished = false;
  bool _saving = false;

  Habit? _habit;

  @override
  void initState() {
    super.initState();
    // Defer to next frame so the ref + habit data are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final habits = ref.read(habitsProvider).valueOrNull ?? const [];
    final habit = habits.where((h) => h.id == widget.habitId).firstOrNull;
    if (habit == null) {
      Navigator.of(context).pop();
      return;
    }
    final mins = (habit.goalValue ?? 0).toInt().clamp(1, 240);
    setState(() {
      _habit = habit;
      _totalSec = mins * 60;
      _remainingSec = _totalSec;
    });
    _start();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _start() {
    _tick?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => _running = true);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSec <= 1) {
        _onFinish();
      } else {
        setState(() => _remainingSec -= 1);
      }
    });
  }

  void _pause() {
    _tick?.cancel();
    HapticFeedback.selectionClick();
    setState(() => _running = false);
  }

  Future<void> _stopEarly() async {
    _tick?.cancel();
    final h = _habit;
    if (h == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final elapsedSec = _totalSec - _remainingSec;
    final elapsedMin = elapsedSec / 60.0;
    final shouldLog = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Stop session?', style: ctx.t.h2),
          content: Text(
            'You did ${elapsedMin.toStringAsFixed(1)} of ${(_totalSec / 60).round()} min. '
            'Log partial progress?',
            style: ctx.t.body.copyWith(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Log partial'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (shouldLog == true && elapsedSec > 0) {
      await _persist(actual: elapsedMin, completed: false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onFinish() async {
    _tick?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _running = false;
      _finished = true;
      _remainingSec = 0;
    });
    final h = _habit;
    if (h == null) return;
    await _persist(
      actual: (h.goalValue ?? 0).toDouble(),
      completed: true,
    );
  }

  Future<void> _persist({required double actual, required bool completed}) async {
    final h = _habit;
    if (h == null) return;
    setState(() => _saving = true);
    final date = ref.read(selectedDateProvider);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(habitActionsProvider.notifier).toggleHabit(
            h.id,
            key,
            completed: completed,
            actualValue: actual,
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtClock(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final h = _habit;
    final accent = h == null ? c.accent : h.sectionId.sectionColor(c);
    final pct = _totalSec == 0 ? 0.0 : (1.0 - _remainingSec / _totalSec);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.x, color: c.textSecondary),
                    // Always route through _stopEarly — it already no-ops the
                    // "log partial progress?" prompt when nothing has elapsed,
                    // but paused progress deserves the same chance to be saved
                    // that the dedicated Stop button already gives it.
                    onPressed: _stopEarly,
                  ),
                  const Spacer(),
                  Text(
                    'FOCUS · ${h == null ? "" : h.name.toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: c.textMuted,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const Spacer(),
              // Big countdown ring.
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(260, 260),
                      painter: _FocusRingPainter(
                        pct: pct,
                        accent: accent,
                        track: c.surfaceElevated,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (h != null) ...[
                          Icon(habitIcon(h.icon), size: 22, color: accent),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          _fmtClock(_remainingSec),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            color: c.textPrimary,
                            height: 1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _finished
                              ? 'COMPLETE'
                              : (_running ? 'IN PROGRESS' : 'PAUSED'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: _finished
                                ? c.positive
                                : (_running ? accent : c.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (h != null)
                Text(
                  h.name,
                  textAlign: TextAlign.center,
                  style: t.h2,
                ),
              const Spacer(),
              if (!_finished)
                Row(
                  children: [
                    Expanded(
                      child: AtlasButton(
                        label: 'Stop',
                        icon: LucideIcons.square,
                        variant: AtlasButtonVariant.secondary,
                        onPressed: _saving ? null : _stopEarly,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AtlasButton(
                        label: _running ? 'Pause' : 'Resume',
                        icon: _running ? LucideIcons.pause : LucideIcons.play,
                        color: accent,
                        onPressed:
                            _saving ? null : (_running ? _pause : _start),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.positive,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final double pct;
  final Color accent;
  final Color track;
  _FocusRingPainter({
    required this.pct,
    required this.accent,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final r = size.width / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, trackPaint);

    if (pct > 0) {
      final p = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        2 * math.pi * pct,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter old) =>
      old.pct != pct || old.accent != accent;
}
