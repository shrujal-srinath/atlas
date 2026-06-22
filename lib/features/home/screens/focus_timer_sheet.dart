import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../providers/quick_log_providers.dart';

/// Focus timer with countdown. Pick duration (5/10/25/custom) → label →
/// timer counts down → completion logs to `focus_sessions`.
class FocusTimerSheet extends ConsumerStatefulWidget {
  const FocusTimerSheet({super.key});

  @override
  ConsumerState<FocusTimerSheet> createState() => _FocusTimerSheetState();
}

class _FocusTimerSheetState extends ConsumerState<FocusTimerSheet> {
  static const _presets = [5, 10, 25, 45];

  int _duration = 25;
  final _label = TextEditingController();

  Timer? _ticker;
  DateTime? _startedAt;
  int _remainingSec = 0;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _label.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    _startedAt = DateTime.now();
    _remainingSec = _duration * 60;
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSec -= 1);
      if (_remainingSec <= 0) {
        _ticker?.cancel();
        _complete();
      }
    });
  }

  bool _completing = false;

  Future<void> _complete() async {
    // Idempotency guards. The natural-completion path (timer hits 0) and the
    // "Finish now" button can race when the user taps near zero, and the
    // ticker may emit another tick before this async method finishes.
    if (_completing || _startedAt == null) return;
    _completing = true;
    _ticker?.cancel();
    if (mounted) setState(() => _running = false);
    HapticFeedback.heavyImpact();
    try {
      await logFocus(
        ref,
        durationMin: _duration,
        label: _label.text.trim().isEmpty ? null : _label.text.trim(),
        startedAt: _startedAt!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _completing = false; // allow retry
      showErrorSnack(context, e);
    }
  }

  void _cancel() {
    _ticker?.cancel();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_running) return _runningView(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        18,
        AppSpace.screenH,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.timer, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text('Focus timer', style: context.t.h2),
            ],
          ),
          const SizedBox(height: 14),
          Text('DURATION',
              style: AppType.overline.copyWith(color: c.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in _presets) ...[
                Expanded(child: _PresetChip(
                  minutes: p,
                  selected: _duration == p,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _duration = p);
                  },
                )),
                if (p != _presets.last) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AtlasField(
            controller: _label,
            label: 'Focus on (optional)',
            hint: 'e.g. reading, deep work',
          ),
          const SizedBox(height: 16),
          AtlasButton(
            label: 'Start · $_duration min',
            icon: LucideIcons.play,
            onPressed: _start,
          ),
        ],
      ),
    );
  }

  Widget _runningView(BuildContext context) {
    final c = context.c;
    final mm = (_remainingSec ~/ 60).toString().padLeft(2, '0');
    final ss = (_remainingSec % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 28, AppSpace.screenH, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_label.text.isEmpty ? 'FOCUS' : _label.text.toUpperCase(),
              style: AppType.overline.copyWith(color: c.textMuted, letterSpacing: 1.6)),
          const SizedBox(height: 8),
          Text(
            '$mm:$ss',
            style: AppType.display.copyWith(
              color: c.textPrimary,
              fontSize: 72,
              letterSpacing: -3.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text('of $_duration min',
              style: context.t.body.copyWith(color: c.textMuted)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: AtlasButton(
                  label: 'Stop',
                  icon: LucideIcons.x,
                  variant: AtlasButtonVariant.secondary,
                  onPressed: _cancel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AtlasButton(
                  label: 'Finish now',
                  icon: LucideIcons.check,
                  onPressed: _complete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          '$minutes m',
          style: AppType.numMd.copyWith(
            color: selected ? c.accent : c.textPrimary,
          ),
        ),
      ),
    );
  }
}
