import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../domain/food.dart';
import '../domain/targets.dart';
import '../providers/food_providers.dart';
import '../providers/health_score_providers.dart';
import '../scoring/nutrition_score.dart';
import 'calorie_ring.dart';
import 'health_score_chip.dart';
import 'hero_nutrition_card.dart';

/// The diary's single fuel card. One section, top-to-bottom:
///   1. a settings bar (phase · score · gear → goals/meals, collapse chevron)
///   2. the calorie ring + budget + compact macro bars + micros (collapsible)
///   3. the log actions (Log food · water · quick-add) pinned at the end.
///
/// Replaces the old two-card split (command bar + separate hero card).
class DiaryNutritionSummary extends ConsumerStatefulWidget {
  final VoidCallback? onMicrosTap;
  final VoidCallback? onGoalTap;
  final VoidCallback? onAddMeal;
  final VoidCallback? onQuickAdd;
  const DiaryNutritionSummary({
    super.key,
    this.onMicrosTap,
    this.onGoalTap,
    this.onAddMeal,
    this.onQuickAdd,
  });

  @override
  ConsumerState<DiaryNutritionSummary> createState() =>
      _DiaryNutritionSummaryState();
}

class _DiaryNutritionSummaryState extends ConsumerState<DiaryNutritionSummary> {
  bool _expanded = true;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    HapticFeedback.selectionClick();
  }

  Future<void> _addWater() async {
    HapticFeedback.lightImpact();
    final repo = ref.read(foodRepositoryProvider);
    final date = ref.read(diaryDateProvider);
    await repo.addWater(250, date);
    ref.invalidate(waterIntakeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final totals = ref.watch(diaryTotalsProvider);
    final targets = ref.watch(dailyTargetsProvider);
    final phase = ref.watch(bodyPhaseProvider);
    final score = ref.watch(dayHealthScoreProvider);
    final water = ref.watch(waterIntakeProvider).valueOrNull ?? 0;

    final remaining = (targets.kcal - totals.kcal).round();
    final over = remaining < 0;
    final deltaColor =
        over ? (phase == BodyPhase.cut ? c.negative : c.amber) : c.accent;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Settings bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
            child: Row(
              children: [
                if (_expanded) ...[
                  Text('TODAY · FUELING',
                      style: AppType.overline
                          .copyWith(color: c.textMuted, letterSpacing: 1.2)),
                  const SizedBox(width: 8),
                  PhasePill(phase: phase),
                ] else ...[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(LucideIcons.flame, size: 14, color: c.accent),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _fmtKcal(over ? -remaining : remaining),
                    style: AppType.numMd.copyWith(
                        color: deltaColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  Text(over ? 'over' : 'left',
                      style: AppType.meta.copyWith(color: c.textMuted)),
                  const SizedBox(width: 8),
                  PhasePill(phase: phase),
                ],
                const Spacer(),
                HealthScoreChip(score: score, large: false),
                const SizedBox(width: 2),
                _IconBtn(
                  icon: LucideIcons.settings2,
                  tooltip: 'Goals & meals',
                  onTap: widget.onGoalTap,
                ),
                _IconBtn(
                  icon:
                      _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  onTap: _toggle,
                ),
              ],
            ),
          ),

          // ── 2. Ring + budget + macros (collapsible) ──────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _Body(
              totals: totals,
              targets: targets,
              phase: phase,
              onMicrosTap: widget.onMicrosTap,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOutCubic,
          ),

          // ── 3. Log actions, pinned at the end ────────────────────
          Divider(
              height: 1, thickness: 0.5, color: c.border, indent: 12, endIndent: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: LucideIcons.plus,
                    label: 'Log food',
                    primary: true,
                    onTap: widget.onAddMeal,
                  ),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: LucideIcons.glassWater,
                  label: '${(water / 1000).toStringAsFixed(1)}L',
                  tint: c.athletic,
                  onTap: _addWater,
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: LucideIcons.zap,
                  tooltip: 'Quick add calories',
                  onTap: widget.onQuickAdd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtKcal(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Collapsible body: ring + budget + compact macro grid ───────────────

class _Body extends StatelessWidget {
  final Nutrients totals;
  final DailyTargets targets;
  final BodyPhase phase;
  final VoidCallback? onMicrosTap;
  const _Body({
    required this.totals,
    required this.targets,
    required this.phase,
    required this.onMicrosTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = phaseDelta(phase, consumed: totals.kcal, target: targets.kcal);
    final tint = resolveDeltaColor(c, delta.tone);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CalorieRing(
                consumed: totals.kcal,
                target: targets.kcal,
                size: 124,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delta.label.toUpperCase(),
                      style: AppType.overline
                          .copyWith(color: c.textMuted, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      delta.value,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: tint,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phaseHint(phase,
                          consumed: totals.kcal, target: targets.kcal),
                      style: AppType.meta.copyWith(color: c.textMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Compact macro grid — two per row, thin bars.
          Row(
            children: [
              Expanded(
                child: _MacroBar(
                    label: 'Protein',
                    value: totals.proteinG,
                    target: targets.proteinG,
                    tint: c.athletic),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MacroBar(
                    label: 'Carbs',
                    value: totals.carbsG,
                    target: targets.carbsG,
                    tint: c.amber),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MacroBar(
                    label: 'Fat',
                    value: totals.fatG,
                    target: targets.fatG,
                    tint: c.mind),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MacroBar(
                    label: 'Fiber',
                    value: totals.fiberG,
                    target: targets.micros.fiberG,
                    tint: c.positive),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onMicrosTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View micros',
                      style: context.t.meta.copyWith(
                          color: c.accent, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight, size: 13, color: c.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact macro bar: label + value on one line, a thin progress bar below.
/// Smaller than the old full-width rows so the card stays tight.
class _MacroBar extends StatelessWidget {
  final String label;
  final double value, target;
  final Color tint;
  const _MacroBar({
    required this.label,
    required this.value,
    required this.target,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final over = target > 0 && value > target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: AppType.meta.copyWith(
                    color: c.textSecondary, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '${value.round()}/${target.round()}',
              style: AppType.meta.copyWith(
                color: over ? c.negative : c.textPrimary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(height: 4, color: c.surfaceElevated),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(height: 4, color: over ? c.negative : tint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A square icon button used in the settings bar.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final btn = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: c.textMuted),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// A compact quick-access action button. `primary` fills with the accent;
/// otherwise it's a tinted outline chip. Icon-only when [label] is null.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool primary;
  final Color? tint;
  final String? tooltip;
  final VoidCallback? onTap;
  const _QuickAction({
    required this.icon,
    this.label,
    this.primary = false,
    this.tint,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = tint ?? c.accent;
    final fg = primary ? c.onAccent : accent;
    final box = Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: label == null ? 12 : 14),
      decoration: BoxDecoration(
        color: primary ? c.accent : accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: primary
            ? null
            : Border.all(color: accent.withValues(alpha: 0.35), width: 0.5),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.26),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
    final child = onTap == null
        ? box
        : PressScale(scale: 0.95, onTap: onTap!, child: box);
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
