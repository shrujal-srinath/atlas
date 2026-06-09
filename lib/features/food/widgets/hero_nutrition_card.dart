import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/food_providers.dart';
import '../providers/health_score_providers.dart';
import '../providers/macro_trend_provider.dart';
import '../scoring/nutrition_score.dart';
import 'calorie_ring.dart';
import 'health_score_chip.dart';
import 'macro_sparkline.dart';

enum HeroVariant { home, diary }

/// The big nutrition card. Same widget on Home (compact) and Diary (full).
///
/// Diary variant: 160-px ring, full macro rows with 7-day sparklines, micros link.
/// Home variant: 88-px ring, 3 hairline macro rows, no sparklines, tap → /food.
class HeroNutritionCard extends ConsumerWidget {
  final HeroVariant variant;
  final VoidCallback? onMicrosTap;
  final VoidCallback? onGoalTap;
  final VoidCallback? onTap;

  const HeroNutritionCard({
    super.key,
    required this.variant,
    this.onMicrosTap,
    this.onGoalTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final totals = ref.watch(diaryTotalsProvider);
    final targets = ref.watch(dailyTargetsProvider);
    final score = ref.watch(dayHealthScoreProvider);
    final phase = ref.watch(bodyPhaseProvider);

    final ringSize = variant == HeroVariant.diary ? 160.0 : 88.0;
    final isHome = variant == HeroVariant.home;

    final card = Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, isHome ? 12 : 12),
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
              Text('TODAY · FUELING',
                  style: AppType.overline.copyWith(
                      color: c.textMuted, letterSpacing: 1.2)),
              const SizedBox(width: 8),
              _PhasePill(phase: phase),
              const Spacer(),
              HealthScoreChip(score: score, large: !isHome),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CalorieRing(
                consumed: totals.kcal,
                target: targets.kcal,
                size: ringSize,
                compact: isHome,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: isHome
                    ? _CompactBudget(
                        consumed: totals.kcal,
                        target: targets.kcal,
                        protein: totals.proteinG,
                        carbs: totals.carbsG,
                        fat: totals.fatG,
                        proteinTarget: targets.proteinG,
                        carbsTarget: targets.carbsG,
                        fatTarget: targets.fatG,
                        phase: phase,
                      )
                    : _FullBudget(
                        consumed: totals.kcal,
                        target: targets.kcal,
                        phase: phase,
                        onGoalTap: onGoalTap,
                      ),
              ),
            ],
          ),
          if (!isHome) ...[
            const SizedBox(height: 14),
            _MacroRow(
                kind: MacroKind.protein,
                label: 'Protein',
                value: totals.proteinG,
                target: targets.proteinG,
                tint: c.athletic),
            _MacroRow(
                kind: MacroKind.carbs,
                label: 'Carbs',
                value: totals.carbsG,
                target: targets.carbsG,
                tint: c.amber),
            _MacroRow(
                kind: MacroKind.fat,
                label: 'Fat',
                value: totals.fatG,
                target: targets.fatG,
                tint: c.mind),
            _MacroRow(
                kind: MacroKind.fiber,
                label: 'Fiber',
                value: totals.fiberG,
                target: targets.micros.fiberG,
                tint: c.positive),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMicrosTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View micros',
                        style: context.t.bodyStrong.copyWith(color: c.accent)),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 14, color: c.accent),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: card,
    );
  }
}

// ── Diary variant: budget breakdown column ─────────────────────────

class _FullBudget extends StatelessWidget {
  final double consumed, target;
  final BodyPhase phase;
  final VoidCallback? onGoalTap;
  const _FullBudget({
    required this.consumed,
    required this.target,
    required this.phase,
    this.onGoalTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = _phaseDelta(phase, consumed: consumed, target: target);
    final tint = _resolveDeltaColor(c, delta.tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          delta.label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: c.textMuted,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          delta.value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: tint,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _phaseHint(phase, consumed: consumed, target: target),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: c.textMuted,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onGoalTap,
          child: Row(
            children: [
              Icon(LucideIcons.settings, size: 12, color: c.accent),
              const SizedBox(width: 4),
              Text('Edit goals', style: AppType.meta.copyWith(color: c.accent)),
            ],
          ),
        ),
      ],
    );
  }
}

// Phase-aware deficit/surplus label + tone.
enum _DeltaTone { positive, warn, negative, neutral }

class _PhaseDelta {
  final String label;
  final String value;
  final _DeltaTone tone;
  const _PhaseDelta(this.label, this.value, this.tone);
}

_PhaseDelta _phaseDelta(BodyPhase phase,
    {required double consumed, required double target}) {
  final remaining = (target - consumed).round();
  switch (phase) {
    case BodyPhase.bulk:
      // Bulking — under is bad, over is the goal.
      if (consumed < target) {
        return _PhaseDelta('Need', '$remaining more', _DeltaTone.warn);
      }
      final over = (consumed - target).round();
      return _PhaseDelta('Surplus', '+$over', _DeltaTone.positive);
    case BodyPhase.cut:
      // Cutting — under is good, over is bad.
      if (consumed <= target) {
        return _PhaseDelta('Remaining', '$remaining', _DeltaTone.positive);
      }
      final over = (consumed - target).round();
      return _PhaseDelta('Over', '$over', _DeltaTone.negative);
    case BodyPhase.maintain:
      if (consumed <= target) {
        return _PhaseDelta('Remaining', '$remaining', _DeltaTone.neutral);
      }
      final over = (consumed - target).round();
      return _PhaseDelta('Over', '$over', _DeltaTone.warn);
  }
}

String _phaseHint(BodyPhase phase,
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

Color _resolveDeltaColor(AppPalette c, _DeltaTone tone) {
  return switch (tone) {
    _DeltaTone.positive => c.accent,
    _DeltaTone.warn => c.amber,
    _DeltaTone.negative => c.negative,
    _DeltaTone.neutral => c.textPrimary,
  };
}

class _PhasePill extends StatelessWidget {
  final BodyPhase phase;
  const _PhasePill({required this.phase});

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

// ── Home variant: dense 3-line macro summary ───────────────────────

class _CompactBudget extends StatelessWidget {
  final double consumed, target;
  final double protein, carbs, fat;
  final double proteinTarget, carbsTarget, fatTarget;
  final BodyPhase phase;
  const _CompactBudget({
    required this.consumed,
    required this.target,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = _phaseDelta(phase, consumed: consumed, target: target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${delta.label} ${delta.value}'.toLowerCase() == 'remaining 0'
              ? 'on target'
              : '${delta.label}: ${delta.value} kcal',
          style: AppType.numLg.copyWith(
            color: _resolveDeltaColor(c, delta.tone),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        _macroLine('P', protein, proteinTarget, c.athletic, context),
        const SizedBox(height: 3),
        _macroLine('C', carbs, carbsTarget, c.amber, context),
        const SizedBox(height: 3),
        _macroLine('F', fat, fatTarget, c.mind, context),
      ],
    );
  }

  Widget _macroLine(String label, double v, double tgt, Color tint, BuildContext ctx) {
    final c = ctx.c;
    final pct = tgt <= 0 ? 0.0 : (v / tgt).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          width: 14, height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: tint)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 3, color: c.surfaceElevated),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(height: 3, color: tint),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${v.round()}/${tgt.round()}',
            style: AppType.numMd.copyWith(color: c.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ── Macro row with sparkline (diary variant) ───────────────────────

class _MacroRow extends ConsumerWidget {
  final MacroKind kind;
  final String label;
  final double value, target;
  final Color tint;
  const _MacroRow({
    required this.kind,
    required this.label,
    required this.value,
    required this.target,
    required this.tint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final over = target > 0 && value > target;
    final trendAsync = ref.watch(macroTrend(kind, 7));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(child: Text(label, style: t.bodyStrong)),
              Text(
                '${value.round()} / ${target.round()} g',
                style: AppType.numMd.copyWith(
                    color: over ? c.negative : c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(
                    children: [
                      Container(height: 4, color: c.surfaceElevated),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(height: 4, color: tint),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: trendAsync.maybeWhen(
                  data: (tr) => MacroSparkline(
                    values: tr.values,
                    target: tr.target,
                    tint: tint,
                    height: 18,
                  ),
                  orElse: () => const SizedBox(height: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
