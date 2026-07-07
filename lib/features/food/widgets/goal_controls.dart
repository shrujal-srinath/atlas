import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../domain/nutrition_engine.dart';

// ── Shared nutrition goal / pace controls ─────────────────────────────
// One source of truth for the goal-weight stepper, pace slider, macro-plan
// pickers and the live plan card — used by both onboarding and the in-app
// goal-settings screen so the two always tell exactly the same story.

/// Colour for a pace difficulty band (green → orange → ruby).
Color paceColor(AppPalette c, PaceTier t) => switch (t) {
  PaceTier.maintain => c.textSecondary,
  PaceTier.sustainable => c.positive,
  PaceTier.hard => c.athletic,
  PaceTier.extreme => c.accent,
  PaceTier.unsafe => c.accent,
};

const _kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "by Oct 2026" for a date `days` from now.
String paceTargetDateLabel(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return 'by ${_kMonths[d.month - 1]} ${d.year}';
}

/// Strong, readable section label (textSecondary w700) — not the faint muted
/// label. Shared so every goal control reads consistently.
TextStyle goalLabelStyle(BuildContext context) => context.t.label.copyWith(
  color: context.c.textSecondary,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.1,
);

/// −/+ stepper for the goal weight, with the current weight as the anchor.
class GoalWeightStepper extends StatelessWidget {
  final double currentKg;
  final double targetKg;
  final ValueChanged<double> onChanged;
  const GoalWeightStepper({
    super.key,
    required this.currentKg,
    required this.targetKg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final loKg = (currentKg - 35).clamp(35.0, 400.0);
    final hiKg = currentKg + 35;
    final delta = targetKg - currentKg;
    final deltaLabel = delta.abs() < 0.05
        ? 'same as now'
        : '${delta > 0 ? '+' : '−'}${delta.abs().toStringAsFixed(1)} kg from ${currentKg.toStringAsFixed(0)} kg';

    void step(double by) {
      HapticFeedback.selectionClick();
      onChanged((targetKg + by).clamp(loKg, hiKg));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GOAL WEIGHT', style: goalLabelStyle(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StepBtn(icon: LucideIcons.minus, onTap: () => step(-0.5)),
              Expanded(
                child: Column(
                  children: [
                    Text('${targetKg.toStringAsFixed(1)} kg', style: t.numLg),
                    const SizedBox(height: 2),
                    Text(
                      deltaLabel,
                      style: t.meta.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              _StepBtn(icon: LucideIcons.plus, onTap: () => step(0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.92,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: c.borderStrong),
        ),
        child: Icon(icon, size: 19, color: c.textPrimary),
      ),
    );
  }
}

/// Pace slider — drag to set the weekly rate; the difficulty tier colours it.
class PaceSlider extends StatelessWidget {
  final double weeklyRateKg;
  final double min;
  final double max;
  final bool losing;
  final PaceTier tier;
  final ValueChanged<double> onChanged;
  const PaceSlider({
    super.key,
    required this.weeklyRateKg,
    required this.min,
    required this.max,
    required this.losing,
    required this.tier,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final col = paceColor(c, tier);
    final value = weeklyRateKg.clamp(min, max);
    final divisions = ((max - min) / 0.05).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('HOW FAST?', style: goalLabelStyle(context)),
            Text(
              '${losing ? '−' : '+'}${weeklyRateKg.toStringAsFixed(2)} kg / week',
              style: t.bodyStrong.copyWith(color: c.textPrimary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: col,
            inactiveTrackColor: c.border,
            thumbColor: col,
            overlayColor: col.withValues(alpha: 0.16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: divisions < 1 ? null : divisions,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gentle', style: t.meta.copyWith(color: c.textMuted)),
            Text('Aggressive', style: t.meta.copyWith(color: c.textMuted)),
          ],
        ),
      ],
    );
  }
}

/// Tap row to pin an exact duration; shows the current timeline in weeks.
class CustomDurationRow extends StatelessWidget {
  final int timelineDays;
  final bool custom;
  final VoidCallback onTap;
  const CustomDurationRow({
    super.key,
    required this.timelineDays,
    required this.custom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final weeks = (timelineDays / 7).round();
    return PressScale(
      scale: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: custom ? c.accent : c.borderStrong,
            width: custom ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendarClock, size: 16, color: c.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                timelineDays > 0
                    ? '$weeks weeks${custom ? ' (custom)' : ''}'
                    : 'Set exact duration',
                style: t.bodyStrong.copyWith(color: c.textPrimary),
              ),
            ),
            Text('Edit', style: t.bodyStrong.copyWith(color: c.accent)),
          ],
        ),
      ),
    );
  }
}

/// The full live recommendation: calories, pace badge, rate + ETA, and the
/// correlated macro split — so the user sees everything moves together.
class NutritionPlanCard extends StatelessWidget {
  final NutritionPlan plan;
  final String goal;

  /// When true, render flush (no card chrome) for embedding inside another card.
  final bool bare;
  const NutritionPlanCard({
    super.key,
    required this.plan,
    required this.goal,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final isMaintain = goal == 'maintain';
    final eta = plan.etaDays;
    String paceLine;
    if (isMaintain || plan.paceTier == PaceTier.maintain) {
      paceLine = 'Maintenance — holding your weight.';
    } else {
      final rate =
          '${plan.weeklyRateKg >= 0 ? '+' : '−'}${plan.weeklyRateKg.abs().toStringAsFixed(2)} kg/wk';
      paceLine = eta != null
          ? '$rate · ${(eta / 7).round()} weeks · ${paceTargetDateLabel(eta)}'
          : rate;
    }

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('DAILY TARGET', style: goalLabelStyle(context)),
            const Spacer(),
            if (!isMaintain) PaceBadge(tier: plan.paceTier),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${plan.kcal}', style: t.numLg),
            const SizedBox(width: 6),
            Text('kcal', style: t.bodyStrong.copyWith(color: c.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Text(paceLine, style: t.meta.copyWith(color: c.textSecondary)),
        if (plan.clampedToFloor) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.shieldAlert, size: 15, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Capped at the safe minimum. Ease the pace or extend the timeline.',
                  style: t.meta.copyWith(color: c.accent, height: 1.35),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Divider(height: 1, color: c.border),
        const SizedBox(height: 14),
        Row(
          children: [
            _MacroPill(label: 'Protein', value: '${plan.proteinG}g'),
            _MacroPill(label: 'Carbs', value: '${plan.carbsG}g'),
            _MacroPill(label: 'Fat', value: '${plan.fatG}g'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(LucideIcons.droplet, size: 14, color: c.athletic),
            const SizedBox(width: 6),
            Text(
              '${(plan.waterMl / 1000).toStringAsFixed(1)} L water · ${plan.fiberG} g fiber',
              style: t.meta.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ],
    );

    if (bare) return inner;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card,
      ),
      child: inner,
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  const _MacroPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.bodyStrong.copyWith(color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: t.meta.copyWith(color: c.textMuted, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

/// Small status pill that names the pace difficulty tier (a single hero badge —
/// the one place accent-on-tint is allowed per the house rules).
class PaceBadge extends StatelessWidget {
  final PaceTier tier;
  const PaceBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = paceColor(c, tier);
    // Darken the label/icon so small bold text clears AA on the soft tint
    // (the raw hue sits ~3.2:1, which fails for 11 px text).
    final inkCol = Color.lerp(col, Colors.black, 0.28)!;
    final danger = tier == PaceTier.unsafe || tier == PaceTier.extreme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: col.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (danger) ...[
            Icon(LucideIcons.alertTriangle, size: 12, color: inkCol),
            const SizedBox(width: 5),
          ],
          Text(
            tier.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: inkCol,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Macro-plan pickers ────────────────────────────────────────────────

/// One selectable chip in a macro-plan picker. Selected = solid accent fill +
/// white text (high-contrast, per house rule 1 — never accent-on-tint here).
class _PlanChip extends StatelessWidget {
  final String title;
  final String sub;
  final bool active;
  final VoidCallback onTap;
  const _PlanChip({
    required this.title,
    required this.sub,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.96,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(
            color: active ? c.accent : c.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? c.onAccent : c.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: active
                    ? c.onAccent.withValues(alpha: 0.85)
                    : c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Protein target picker: evidence-based presets (g/kg) + a custom slider.
class ProteinPlanPicker extends StatelessWidget {
  final ProteinPlan selected;
  final double? customPerKg; // active only when selected == custom
  final double currentKg; // to preview resulting grams
  final ValueChanged<ProteinPlan> onPlan;
  final ValueChanged<double> onCustom;
  const ProteinPlanPicker({
    super.key,
    required this.selected,
    required this.customPerKg,
    required this.currentKg,
    required this.onPlan,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    const presets = [
      (ProteinPlan.general, 'General', '1.2 g/kg'),
      (ProteinPlan.balanced, 'Balanced', '1.6 g/kg'),
      (ProteinPlan.building, 'Building', '2.0 g/kg'),
      (ProteinPlan.cutting, 'Cutting', '2.2 g/kg'),
      (ProteinPlan.custom, 'Custom', 'set g/kg'),
    ];
    final perKg = selected == ProteinPlan.custom
        ? (customPerKg ?? 1.6)
        : proteinPerKgFor(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PROTEIN', style: goalLabelStyle(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in presets)
              _PlanChip(
                title: p.$2,
                sub: p.$3,
                active: selected == p.$1,
                onTap: () => onPlan(p.$1),
              ),
          ],
        ),
        if (selected == ProteinPlan.custom) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: c.accent,
                    inactiveTrackColor: c.border,
                    thumbColor: c.accent,
                    overlayColor: c.accent.withValues(alpha: 0.16),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                    ),
                  ),
                  child: Slider(
                    value: perKg.clamp(0.8, 3.0),
                    min: 0.8,
                    max: 3.0,
                    divisions: 22,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      onCustom(double.parse(v.toStringAsFixed(1)));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${perKg.toStringAsFixed(1)} g/kg',
                style: t.bodyStrong.copyWith(color: c.textPrimary),
              ),
            ],
          ),
        ],
        const SizedBox(height: 2),
        Text(
          '≈ ${(currentKg * perKg).round()} g/day at ${currentKg.toStringAsFixed(0)} kg',
          style: t.meta.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

/// Fat target picker: AMDR-based presets (% of calories) + a custom slider.
class FatPlanPicker extends StatelessWidget {
  final FatPlan selected;
  final double? customPct; // 0..1, active only when selected == custom
  final ValueChanged<FatPlan> onPlan;
  final ValueChanged<double> onCustom;
  const FatPlanPicker({
    super.key,
    required this.selected,
    required this.customPct,
    required this.onPlan,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    const presets = [
      (FatPlan.lower, 'Lower', '20%'),
      (FatPlan.balanced, 'Balanced', '27%'),
      (FatPlan.higher, 'Higher', '35%'),
      (FatPlan.custom, 'Custom', 'set %'),
    ];
    final pct = selected == FatPlan.custom
        ? (customPct ?? 0.27)
        : fatPctFor(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FAT', style: goalLabelStyle(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in presets)
              _PlanChip(
                title: p.$2,
                sub: p.$3,
                active: selected == p.$1,
                onTap: () => onPlan(p.$1),
              ),
          ],
        ),
        if (selected == FatPlan.custom) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: c.accent,
                    inactiveTrackColor: c.border,
                    thumbColor: c.accent,
                    overlayColor: c.accent.withValues(alpha: 0.16),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                    ),
                  ),
                  child: Slider(
                    value: pct.clamp(0.15, 0.45),
                    min: 0.15,
                    max: 0.45,
                    divisions: 30,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      onCustom(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(pct * 100).round()}%',
                style: t.bodyStrong.copyWith(color: c.textPrimary),
              ),
            ],
          ),
        ],
        const SizedBox(height: 2),
        Text(
          'Carbs fill the rest of your calories.',
          style: t.meta.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}
