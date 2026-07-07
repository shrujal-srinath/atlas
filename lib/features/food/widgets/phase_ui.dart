import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../scoring/nutrition_score.dart';

// Phase-aware fuel UI helpers — the bulk/cut/maintain pill plus the
// deficit/surplus delta label, hint copy, and tone colour. Shared by the diary
// fuel card (and previously the now-deleted hero card).

/// Tone for a phase delta — maps to a colour via [resolveDeltaColor].
enum DeltaTone { positive, warn, negative, neutral }

/// A phase-aware deficit/surplus readout: a short label, a value, and a tone.
class PhaseDelta {
  final String label;
  final String value;
  final DeltaTone tone;
  const PhaseDelta(this.label, this.value, this.tone);
}

/// Deficit/surplus framed by the user's body-composition phase: bulking wants a
/// surplus, cutting wants a deficit, maintaining wants to sit on target.
PhaseDelta phaseDelta(BodyPhase phase,
    {required double consumed, required double target}) {
  final remaining = (target - consumed).round();
  switch (phase) {
    case BodyPhase.bulk:
      if (consumed < target) {
        return PhaseDelta('Need', '$remaining more', DeltaTone.warn);
      }
      final over = (consumed - target).round();
      return PhaseDelta('Surplus', '+$over', DeltaTone.positive);
    case BodyPhase.cut:
      if (consumed <= target) {
        return PhaseDelta('Remaining', '$remaining', DeltaTone.positive);
      }
      final over = (consumed - target).round();
      return PhaseDelta('Over', '$over', DeltaTone.negative);
    case BodyPhase.maintain:
      if (consumed <= target) {
        return PhaseDelta('Remaining', '$remaining', DeltaTone.neutral);
      }
      final over = (consumed - target).round();
      return PhaseDelta('Over', '$over', DeltaTone.warn);
  }
}

/// One-line coaching hint for the current phase + intake.
String phaseHint(BodyPhase phase,
    {required double consumed, required double target}) {
  final pct = target <= 0 ? 0.0 : consumed / target;
  switch (phase) {
    case BodyPhase.bulk:
      if (pct < 0.8) return 'Bulking — calorie surplus rewards score.';
      if (pct >= 1.0) return 'Surplus locked in — keep protein on target.';
      return 'Close to target — a snack lifts the body score.';
    case BodyPhase.cut:
      if (pct <= 1.0) return 'Cutting — staying under target rewards score.';
      if (pct <= 1.1) return 'Slightly over — score penalty kicks in.';
      return 'Hard cap exceeded — body score reset to 0 for calories.';
    case BodyPhase.maintain:
      if ((pct - 1.0).abs() <= 0.05) return 'On target — keep it steady.';
      if (consumed < target) return 'Slightly under — a balanced snack is fine.';
      return 'A touch over — light dinner balances the day.';
  }
}

Color resolveDeltaColor(AppPalette c, DeltaTone tone) {
  return switch (tone) {
    DeltaTone.positive => c.accent,
    DeltaTone.warn => c.amber,
    DeltaTone.negative => c.negative,
    DeltaTone.neutral => c.textPrimary,
  };
}

/// Small pill naming the user's current body-composition phase.
class PhasePill extends StatelessWidget {
  final BodyPhase phase;
  const PhasePill({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color, icon) = switch (phase) {
      BodyPhase.bulk => ('BULK', c.athletic, LucideIcons.trendingUp),
      BodyPhase.cut => ('CUT', c.mind, LucideIcons.trendingDown),
      BodyPhase.maintain => ('MAINTAIN', c.textMuted, LucideIcons.minus),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
