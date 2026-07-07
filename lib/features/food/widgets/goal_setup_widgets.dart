import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../domain/nutrition_engine.dart';
import '../food_colors.dart';
import 'goal_controls.dart' show PaceBadge, paceColor;

// ── Reusable goal-setup building blocks ───────────────────────────────
// The premium, HealthifyMe-grade controls shared by the onboarding goal
// flow and the in-app "change my goal" flow: a weight scroll-wheel, an
// ideal-range hint, a pace control with live feedback + danger zones, and
// the animated calorie reveal. All engine-driven so they tell one story.

const double _kLbPerKg = 2.2046226218;

double kgToDisplay(double kg, String unit) =>
    unit == 'lb' ? kg * _kLbPerKg : kg;
double displayToKg(double v, String unit) => unit == 'lb' ? v / _kLbPerKg : v;

/// "3,549" — grouped thousands for a calorie readout.
String _kcalStr(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// ───────────────────────────── Weight wheel ──────────────────────────

/// A tactile two-column scroll wheel for picking a body weight, with a Kg/Lb
/// toggle. The centre value is large + accent; neighbours recede (size +
/// colour). Source of truth is always kg; the wheel displays the chosen unit.
class WeightWheelPicker extends StatefulWidget {
  final double valueKg;
  final ValueChanged<double> onChanged;
  final String unit; // 'kg' | 'lb'
  final ValueChanged<String> onUnitChanged;
  const WeightWheelPicker({
    super.key,
    required this.valueKg,
    required this.onChanged,
    required this.unit,
    required this.onUnitChanged,
  });

  @override
  State<WeightWheelPicker> createState() => _WeightWheelPickerState();
}

class _WeightWheelPickerState extends State<WeightWheelPicker> {
  late FixedExtentScrollController _wholeCtrl;
  late FixedExtentScrollController _decCtrl;
  late int _whole;
  late int _dec;

  int get _wholeMin => widget.unit == 'lb' ? 66 : 30;
  int get _wholeMax => widget.unit == 'lb' ? 550 : 250;

  @override
  void initState() {
    super.initState();
    _syncFromValue();
    _wholeCtrl = FixedExtentScrollController(initialItem: _whole - _wholeMin);
    _decCtrl = FixedExtentScrollController(initialItem: _dec);
  }

  void _syncFromValue() {
    final d = kgToDisplay(widget.valueKg, widget.unit);
    var whole = d.floor();
    var dec = ((d - whole) * 10).round();
    if (dec >= 10) {
      whole += 1;
      dec = 0;
    }
    _whole = whole.clamp(_wholeMin, _wholeMax);
    _dec = dec.clamp(0, 9);
  }

  @override
  void didUpdateWidget(WeightWheelPicker old) {
    super.didUpdateWidget(old);
    // On a unit switch, re-place both wheels at the converted value.
    if (old.unit != widget.unit) {
      _syncFromValue();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _wholeCtrl.jumpToItem(_whole - _wholeMin);
        _decCtrl.jumpToItem(_dec);
      });
    }
  }

  @override
  void dispose() {
    _wholeCtrl.dispose();
    _decCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final display = _whole + _dec / 10;
    final kg = displayToKg(display, widget.unit).clamp(25.0, 350.0);
    widget.onChanged(double.parse(kg.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A faint centre band marking the selected row.
              IgnorePointer(
                child: Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    child: _Wheel(
                      controller: _wholeCtrl,
                      count: _wholeMax - _wholeMin + 1,
                      selectedIndex: _whole - _wholeMin,
                      align: Alignment.centerRight,
                      builder: (i) => _wholeMin + i,
                      onChanged: (i) {
                        setState(() => _whole = _wholeMin + i);
                        _emit();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '.',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 40,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: _Wheel(
                      controller: _decCtrl,
                      count: 10,
                      selectedIndex: _dec,
                      align: Alignment.centerLeft,
                      builder: (i) => i,
                      onChanged: (i) {
                        setState(() => _dec = i);
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
              // Top / bottom fade so the wheel dissolves into the page.
              IgnorePointer(child: _EdgeFade(color: c.background)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _UnitToggle(unit: widget.unit, onChanged: widget.onUnitChanged),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int count;
  final int selectedIndex;
  final Alignment align;
  final int Function(int index) builder;
  final ValueChanged<int> onChanged;
  const _Wheel({
    required this.controller,
    required this.count,
    required this.selectedIndex,
    required this.align,
    required this.builder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 60,
      perspective: 0.0032,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        onChanged(i);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) {
          final selected = i == selectedIndex;
          final near = (i - selectedIndex).abs() == 1;
          return Container(
            alignment: align,
            child: Text(
              '${builder(i)}',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: selected ? 42 : 30,
                height: 1.0,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? c.accent
                    : near
                    ? c.textMuted
                    : c.textDim,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  final Color color;
  const _EdgeFade({required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 66),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String unit;
  final ValueChanged<String> onChanged;
  const _UnitToggle({required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget seg(String u, String label) {
      final active = unit == u;
      return PressScale(
        scale: 0.94,
        onTap: () {
          if (!active) {
            HapticFeedback.selectionClick();
            onChanged(u);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
          decoration: BoxDecoration(
            color: active ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? c.onAccent : c.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('kg', 'Kg'), seg('lb', 'Lb')],
      ),
    );
  }
}

// ──────────────────────────── Ideal range hint ───────────────────────

/// A calm banner that tells the user whether their target sits in, above, or
/// below the healthy weight range for their height — reassurance, not a block.
class IdealRangeBanner extends StatelessWidget {
  final double targetKg;
  final double heightCm;
  final String unit;
  const IdealRangeBanner({
    super.key,
    required this.targetKg,
    required this.heightCm,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    if (heightCm <= 0) return const SizedBox.shrink();
    final range = idealWeightRange(heightCm);
    final fit = weightBandFit(targetKg, heightCm);
    final lo = kgToDisplay(range.lo, unit).round();
    final hi = kgToDisplay(range.hi, unit).round();
    final u = unit == 'lb' ? 'lb' : 'Kg';

    final (Color tint, IconData icon, String msg) = switch (fit) {
      WeightBandFit.within => (
        c.positive,
        LucideIcons.checkCircle2,
        'Your target sits right in your healthy range of $lo–$hi $u.',
      ),
      WeightBandFit.above => (
        c.amber,
        LucideIcons.trendingUp,
        'Above the typical healthy range ($lo–$hi $u) — reachable, just be deliberate about it.',
      ),
      WeightBandFit.below => (
        c.amber,
        LucideIcons.trendingDown,
        'Below the typical healthy range ($lo–$hi $u) — make sure this is right for you.',
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(msg),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: tint.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: tint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: t.bodyStrong.copyWith(
                  color: c.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── Pace control ───────────────────────────

/// Plain-language feedback for the chosen pace, by tier + direction.
String paceFeedback(PaceTier tier, {required bool gaining}) => switch (tier) {
  PaceTier.maintain => 'Holding steady at your current weight.',
  PaceTier.sustainable =>
    'A comfortable, sustainable pace — the easiest to stick to.',
  PaceTier.hard =>
    'A strong pace. Doable, but it asks for consistency every day.',
  PaceTier.extreme =>
    gaining
        ? 'Aggressive. Expect more fat alongside the muscle — train hard.'
        : 'Aggressive. Real muscle-loss risk — keep protein high.',
  PaceTier.unsafe =>
    gaining
        ? 'Very hard to do cleanly — most of this would be fat. Not recommended.'
        : 'Below safe limits — not recommended. Ease off a little.',
};

/// "about 6 weeks" / "about 4 months" style ETA from a day count.
String etaPhrase(int days) {
  if (days <= 0) return '';
  final weeks = (days / 7).round();
  if (weeks <= 0) return 'under a week';
  if (weeks == 1) return 'about a week';
  if (weeks <= 8) return 'about $weeks weeks';
  final months = days / 30.44;
  final rounded = (months * 2).round() / 2; // nearest half-month
  final label = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return 'about $label months';
}

/// The big "how fast?" control: headline rate, dynamic feedback, a tier-coloured
/// slider that runs past the safe band into the warning zones, an ETA banner,
/// and an escape hatch to enter calories by hand for truly aggressive goals.
class GoalPaceControl extends StatelessWidget {
  final double weeklyRateKg;
  final double min;
  final double max;

  /// The recommended (fastest-sustainable) pace. Marked on the track and offered
  /// as a one-tap "use recommended" reset. Null hides both affordances.
  final double? recommendedRate;

  /// Current bodyweight — used to paint the difficulty *zones* (sustainable →
  /// hard → extreme → unsafe) along the track, since the tiers are defined as a
  /// percentage of bodyweight per week.
  final double currentKg;
  final bool gaining;
  final PaceTier tier;
  final int etaDays;

  /// The live daily calorie target for the current pace — the "what do I eat?"
  /// answer the user wants while dragging. Already activity-aware (TDEE).
  final int dailyKcal;
  final String activityLabel;
  final ValueChanged<double> onChanged;
  final VoidCallback onSetManual;
  final bool manualActive;
  const GoalPaceControl({
    super.key,
    required this.weeklyRateKg,
    required this.min,
    required this.max,
    this.recommendedRate,
    required this.currentKg,
    required this.gaining,
    required this.tier,
    required this.etaDays,
    required this.dailyKcal,
    required this.activityLabel,
    required this.onChanged,
    required this.onSetManual,
    this.manualActive = false,
  });

  /// Difficulty-zone boundaries (kg/week) for the current direction, derived
  /// from the same %-bodyweight thresholds the engine classifies by.
  List<({double from, double to, Color color})> _zones(AppPalette c) {
    final w = currentKg > 0 ? currentKg : 75.0;
    // %bw/wk thresholds: looser for gain (muscle is slow) than for loss.
    final s = (gaining ? 0.0025 : 0.005) * w; // sustainable ceiling
    final h = (gaining ? 0.005 : 0.010) * w; // hard ceiling
    final e = (gaining ? 0.0075 : 0.015) * w; // extreme ceiling
    return [
      (from: min, to: s, color: c.positive.withValues(alpha: 0.26)),
      (from: s, to: h, color: c.athletic.withValues(alpha: 0.24)),
      (from: h, to: e, color: c.accent.withValues(alpha: 0.20)),
      (from: e, to: max, color: c.accent.withValues(alpha: 0.34)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final col = paceColor(c, tier);
    final value = weeklyRateKg.clamp(min, max);
    final divisions = ((max - min) / 0.05).round();
    final danger = tier == PaceTier.extreme || tier == PaceTier.unsafe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Big rate readout.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              weeklyRateKg.toStringAsFixed(2),
              style: AppType.display.copyWith(
                color: c.textPrimary,
                fontSize: 64,
              ),
            ),
            const SizedBox(width: 8),
            Text('kg', style: t.h1.copyWith(color: c.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text('per week', style: t.h2.copyWith(color: c.textMuted)),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: PaceBadge(key: ValueKey(tier), tier: tier),
        ),
        const SizedBox(height: 22),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            activeTrackColor: col,
            inactiveTrackColor: c.border,
            thumbColor: Colors.white,
            overlayColor: col.withValues(alpha: 0.16),
            thumbShape: _PaceThumbShape(ringColor: col),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            // Tier-zone bands + quarter-kg detent ticks, so the track teaches
            // *where* the safe band ends and gives the slider tangible "points".
            trackShape: _PaceTrackShape(
              minRate: min,
              maxRate: max,
              zones: _zones(c),
              inactiveColor: c.border,
              tickColor: c.textMuted.withValues(alpha: 0.45),
              tickActiveColor: Colors.white.withValues(alpha: 0.9),
              recommendedRate: recommendedRate,
              recommendedColor: c.textPrimary,
            ),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: divisions < 1 ? null : divisions,
            onChanged: (v) {
              // A firmer tap when the thumb settles onto a quarter-kg detent;
              // a light tick otherwise — so the "points" feel tactile.
              final crossedDetent =
                  (v / 0.25).round() != (weeklyRateKg / 0.25).round();
              if (crossedDetent) {
                HapticFeedback.lightImpact();
              } else {
                HapticFeedback.selectionClick();
              }
              onChanged(v);
            },
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gentle', style: t.meta.copyWith(color: c.textMuted)),
              Text('Aggressive', style: t.meta.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Center(child: _ZoneLegend()),
        if (recommendedRate != null) ...[
          const SizedBox(height: 14),
          Center(
            child: _RecommendedPaceCue(
              atRecommended: (weeklyRateKg - recommendedRate!).abs() < 0.026,
              recommendedRate: recommendedRate!,
              gaining: gaining,
              onUse: () => onChanged(recommendedRate!),
            ),
          ),
        ],
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: ch),
          child: Text(
            paceFeedback(tier, gaining: gaining),
            key: ValueKey(tier),
            textAlign: TextAlign.center,
            style: t.body.copyWith(
              color: danger ? col : c.textSecondary,
              height: 1.4,
              fontWeight: danger ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // The live "what do I actually eat?" answer — updates as you drag, and
        // is already tailored to the user's activity level (TDEE-based).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.athletic.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Icon(LucideIcons.flame, size: 20, color: c.athletic),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Eat ',
                          style: t.bodyStrong.copyWith(color: c.textSecondary),
                        ),
                        Text(
                          _kcalStr(dailyKcal),
                          style: AppType.numLg.copyWith(
                            color: c.textPrimary,
                            fontSize: 23,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'kcal/day',
                          style: t.meta.copyWith(color: c.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tailored to your $activityLabel activity level',
                      style: t.meta.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (etaDays > 0) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: c.border),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.flag, size: 16, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: t.bodyStrong.copyWith(color: c.textSecondary),
                      children: [
                        const TextSpan(text: "You'll reach your goal in "),
                        TextSpan(
                          text: etaPhrase(etaDays),
                          style: t.bodyStrong.copyWith(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        PressScale(
          scale: 0.98,
          onTap: onSetManual,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                manualActive ? LucideIcons.checkCircle2 : LucideIcons.sliders,
                size: 14,
                color: manualActive ? c.accent : c.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                manualActive
                    ? 'Calories set manually — tap to change'
                    : 'Prefer to set calories yourself?',
                style: t.meta.copyWith(
                  color: manualActive ? c.accent : c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirms the chosen pace against the recommendation: a calm green tick when
/// the user is sitting on the recommended (fastest-sustainable) rate, or a
/// one-tap chip to snap back to it once they've dragged away.
class _RecommendedPaceCue extends StatelessWidget {
  final bool atRecommended;
  final double recommendedRate;
  final bool gaining;
  final VoidCallback onUse;
  const _RecommendedPaceCue({
    required this.atRecommended,
    required this.recommendedRate,
    required this.gaining,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    if (atRecommended) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCircle2, size: 14, color: c.positive),
          const SizedBox(width: 6),
          Text(
            'Recommended pace for you',
            style: t.meta.copyWith(
              color: c.positive,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return PressScale(
      scale: 0.97,
      onTap: () {
        HapticFeedback.selectionClick();
        onUse();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: c.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, size: 14, color: c.accent),
            const SizedBox(width: 7),
            Text(
              'Use recommended · ${gaining ? '+' : '−'}${recommendedRate.toStringAsFixed(2)} kg/wk',
              style: t.bodyStrong.copyWith(color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact key for the slider's difficulty zones — a green→ruby cue so the
/// coloured bands on the track read as "safe … unsafe", not decoration.
class _ZoneLegend extends StatelessWidget {
  const _ZoneLegend();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    Widget item(Color col, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: col, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: t.meta.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(c.positive, 'Sustainable'),
        const SizedBox(width: 14),
        item(c.athletic, 'Hard'),
        const SizedBox(width: 14),
        item(c.accent, 'Risky'),
      ],
    );
  }
}

/// Slider track that paints difficulty *zones* + quarter-kg detent ticks, so
/// the pace control teaches where the safe band ends and gains tangible
/// "points" rather than reading as a featureless ramp.
class _PaceTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  final double minRate;
  final double maxRate;
  final List<({double from, double to, Color color})> zones;
  final Color inactiveColor;
  final Color tickColor;
  final Color tickActiveColor;

  /// Optional "recommended pace" marker — a tall pin drawn at this rate.
  final double? recommendedRate;
  final Color recommendedColor;
  const _PaceTrackShape({
    required this.minRate,
    required this.maxRate,
    required this.zones,
    required this.inactiveColor,
    required this.tickColor,
    required this.tickActiveColor,
    this.recommendedRate,
    this.recommendedColor = const Color(0xFF000000),
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final h = sliderTheme.trackHeight ?? 0;
    if (h <= 0) return;
    final Rect rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final radius = Radius.circular(rect.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final span = (maxRate - minRate).abs() < 1e-9 ? 1.0 : (maxRate - minRate);
    double xFor(double v) =>
        rect.left + (((v - minRate) / span).clamp(0.0, 1.0)) * rect.width;
    final thumbX = thumbCenter.dx.clamp(rect.left, rect.right);

    // Base (inactive) rounded track.
    canvas.drawRRect(rrect, Paint()..color = inactiveColor);

    // Difficulty zones + active fill, clipped to the rounded base.
    canvas.save();
    canvas.clipRRect(rrect);
    for (final z in zones) {
      final l = xFor(z.from);
      final r = xFor(z.to);
      if (r <= l) continue;
      canvas.drawRect(
        Rect.fromLTRB(l, rect.top, r, rect.bottom),
        Paint()..color = z.color,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top, thumbX, rect.bottom),
      Paint()..color = sliderTheme.activeTrackColor ?? inactiveColor,
    );
    canvas.restore();

    // Quarter-kg detent ticks.
    const step = 0.25;
    final first = (minRate / step).ceilToDouble() * step;
    final tickH = rect.height * 0.46;
    for (double v = first; v <= maxRate + 1e-9; v += step) {
      final x = xFor(v);
      if ((x - thumbX).abs() < rect.height * 0.7) continue; // hidden by thumb
      final p = Paint()
        ..color = x <= thumbX ? tickActiveColor : tickColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, rect.center.dy - tickH / 2),
        Offset(x, rect.center.dy + tickH / 2),
        p,
      );
    }

    // Recommended-pace pin: a tall rounded bar that stands above and below the
    // track, with a soft white halo so it reads on any zone colour. Hidden when
    // the thumb sits on it (then the "recommended" cue below carries the story).
    final rec = recommendedRate;
    if (rec != null && rec >= minRate && rec <= maxRate) {
      final rx = xFor(rec);
      if ((rx - thumbX).abs() >= rect.height * 0.85) {
        final pinH = rect.height * 1.7;
        final pin = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(rx, rect.center.dy), width: 4, height: pinH),
          const Radius.circular(2),
        );
        canvas.drawRRect(
          pin.inflate(1.6),
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawRRect(pin, Paint()..color = recommendedColor);
      }
    }
  }
}

/// White pill thumb with a tier-coloured ring — reads clearly on the coloured
/// track and signals the current difficulty without relying on colour alone.
class _PaceThumbShape extends SliderComponentShape {
  final Color ringColor;
  const _PaceThumbShape({required this.ringColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(30, 30);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    const r = 13.0;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      r - 2,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }
}

// ──────────────────────────── Calorie reveal ─────────────────────────

/// The payoff screen: an animated odometer that counts your daily calorie
/// target up into rolling digit cards, with the goal framed in plain language
/// and the correlated macro split underneath.
class CalorieReveal extends StatefulWidget {
  final NutritionPlan plan;
  final String goal; // gain | lose | maintain
  final double currentKg;
  final double targetKg;
  final int timelineDays;

  /// True when the user is already sitting on their goal weight (target ≈
  /// current). Frames the maintain headline as "you're already there" rather
  /// than a chosen maintenance goal.
  final bool atGoal;

  // Optional identity for the personalized summary pill at the foot of the
  // reveal (onboarding passes these; the in-app change-goal path leaves them).
  final String? name;
  final double heightCm;
  final String activityLabel;
  const CalorieReveal({
    super.key,
    required this.plan,
    required this.goal,
    required this.currentKg,
    required this.targetKg,
    required this.timelineDays,
    this.atGoal = false,
    this.name,
    this.heightCm = 0,
    this.activityLabel = '',
  });

  @override
  State<CalorieReveal> createState() => _CalorieRevealState();
}

class _CalorieRevealState extends State<CalorieReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void didUpdateWidget(CalorieReveal old) {
    super.didUpdateWidget(old);
    // Replay when the headline numbers change (e.g. re-opened on a new goal).
    if (old.plan.kcal != widget.plan.kcal) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Interval _stage(double begin, double end) => Interval(begin, end);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final isMaintain =
        widget.goal == 'maintain' || widget.plan.paceTier == PaceTier.maintain;
    final delta = (widget.targetKg - widget.currentKg).abs();
    final weeks = (widget.timelineDays / 7).round();
    final verb = widget.goal == 'lose' ? 'lose' : 'gain';

    final headline = _ctrl.drive(CurveTween(curve: _stage(0.0, 0.35)));
    final number = _ctrl.drive(CurveTween(curve: _stage(0.18, 0.85)));
    final macros = _ctrl.drive(CurveTween(curve: _stage(0.65, 1.0)));

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline.
            _Fade(
              t: headline.value,
              dy: 14,
              child: isMaintain
                  ? Text(
                      widget.atGoal
                          ? "You're already at your goal weight"
                          : 'To hold your weight, aim for…',
                      style: t.h1,
                    )
                  : RichText(
                      text: TextSpan(
                        style: t.h1,
                        children: [
                          const TextSpan(text: 'To '),
                          TextSpan(text: verb),
                          TextSpan(
                            text:
                                ' ${delta.toStringAsFixed(delta % 1 == 0 ? 0 : 1)} kg',
                            style: t.h1.copyWith(color: c.accent),
                          ),
                          const TextSpan(text: ' in '),
                          TextSpan(
                            text: '$weeks weeks',
                            style: t.h1.copyWith(color: c.accent),
                          ),
                          const TextSpan(text: ', aim to…'),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 28),
            // EAT row.
            _Fade(
              t: headline.value,
              dy: 10,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.utensilsCrossed,
                    size: 18,
                    color: c.athletic,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMaintain ? 'EAT TO MAINTAIN' : 'EAT EVERY DAY',
                    style: AppType.overline.copyWith(
                      color: c.textSecondary,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Odometer.
            Center(
              child: _Odometer(
                value: widget.plan.kcal,
                progress: number.value,
                suffix: 'kcal',
              ),
            ),
            const SizedBox(height: 28),
            // Safety note when clamped / unsafe.
            if (widget.plan.clampedToFloor ||
                widget.plan.paceTier == PaceTier.unsafe) ...[
              _Fade(
                t: macros.value,
                dy: 8,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: c.accent.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.shieldAlert, size: 16, color: c.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.plan.clampedToFloor
                              ? 'We held your calories at the safe minimum. Ease the pace or extend the timeline.'
                              : 'This is an aggressive target. Push hard, but listen to your body.',
                          style: t.bodyStrong.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Macro breakdown.
            _Fade(
              t: macros.value,
              dy: 12,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: c.border),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Macro(
                          label: 'Protein',
                          value: '${widget.plan.proteinG}g',
                          color: c.proteinColor,
                        ),
                        _Macro(
                          label: 'Carbs',
                          value: '${widget.plan.carbsG}g',
                          color: c.carbsColor,
                        ),
                        _Macro(
                          label: 'Fat',
                          value: '${widget.plan.fatG}g',
                          color: c.fatColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: c.border),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.droplet,
                          size: 14,
                          color: c.waterColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(widget.plan.waterMl / 1000).toStringAsFixed(1)} L water',
                          style: t.meta.copyWith(color: c.textSecondary),
                        ),
                        const SizedBox(width: 14),
                        Icon(LucideIcons.wheat, size: 14, color: c.fiberColor),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.plan.fiberG} g fiber',
                          style: t.meta.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Personalized identity strip — quietly confirms the plan was built
            // for *this* athlete, from their own numbers.
            if (widget.name != null && widget.name!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _Fade(
                t: macros.value,
                dy: 10,
                child: _IdentitySummary(
                  name: widget.name!.trim(),
                  heightCm: widget.heightCm,
                  weightKg: widget.currentKg,
                  activityLabel: widget.activityLabel,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A compact "{Name} · {h} cm · {w} kg · {activity}" pill row shown under the
/// reveal so the numbers feel personal, not generic.
class _IdentitySummary extends StatelessWidget {
  final String name;
  final double heightCm;
  final double weightKg;
  final String activityLabel;
  const _IdentitySummary({
    required this.name,
    required this.heightCm,
    required this.weightKg,
    required this.activityLabel,
  });

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final parts = <String>[
      if (heightCm > 0) '${_fmt(heightCm)} cm',
      if (weightKg > 0) '${_fmt(weightKg)} kg',
      if (activityLabel.isNotEmpty) activityLabel,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.userCircle2, size: 16, color: c.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: t.meta.copyWith(color: c.textMuted),
                children: [
                  TextSpan(
                    text: name,
                    style: t.bodyStrong.copyWith(
                      color: c.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  if (parts.isNotEmpty)
                    TextSpan(text: '   ·   ${parts.join('   ·   ')}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + slide-up helper driven by a 0→1 stage value.
class _Fade extends StatelessWidget {
  final double t;
  final double dy;
  final Widget child;
  const _Fade({required this.t, required this.dy, required this.child});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - t.clamp(0.0, 1.0)) * dy),
        child: child,
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Macro({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: AppType.numMd.copyWith(
                  color: c.textPrimary,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: t.meta.copyWith(color: c.textMuted, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

/// Rolling-digit odometer. Counts the value up [progress] 0→1 and renders each
/// digit in its own flip-card so the number climbs like a mechanical counter.
class _Odometer extends StatelessWidget {
  final int value;
  final double progress;
  final String suffix;
  const _Odometer({
    required this.value,
    required this.progress,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final current =
        (value * Curves.easeOutCubic.transform(progress.clamp(0, 1))).round();
    final width = value.toString().length;
    final str = current.toString().padLeft(width, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < str.length; i++) ...[
          _DigitCard(digit: str[i]),
          if (i < str.length - 1) const SizedBox(width: 7),
        ],
        const SizedBox(width: 12),
        Text(suffix, style: t.h2.copyWith(color: c.textMuted)),
      ],
    );
  }
}

class _DigitCard extends StatelessWidget {
  final String digit;
  const _DigitCard({required this.digit});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 130),
      transitionBuilder: (child, anim) => ClipRect(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.45),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
      child: Container(
        key: ValueKey(digit),
        width: 50,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: c.borderStrong),
          boxShadow: AppShadows.card,
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 1.0,
            fontFeatures: [FontFeature.tabularFigures()],
          ).copyWith(color: c.textPrimary),
        ),
      ),
    );
  }
}
