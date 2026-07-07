import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/nutrition_engine.dart';
import '../screens/how_we_calculate_screen.dart';
import '../widgets/goal_setup_widgets.dart';

/// The fully-resolved choice handed back to the caller (onboarding) when the
/// flow finishes without saving itself.
class GoalSetupResult {
  final double targetKg;
  final double weeklyRateKg;
  final int timelineDays;
  final int? kcalOverride;
  final NutritionPlan plan;

  /// Resolved direction (`gain | lose | maintain`). When the flow infers goal
  /// from the target weight, this is what the caller should persist.
  final String goal;
  const GoalSetupResult({
    required this.targetKg,
    required this.weeklyRateKg,
    required this.timelineDays,
    required this.kcalOverride,
    required this.plan,
    required this.goal,
  });
}

/// A self-contained, three-step goal-setup flow — target weight → pace →
/// animated calorie reveal — used by both onboarding (via [onComplete]) and the
/// in-app "change my goal" path (via [saveOnFinish]). Engine-driven throughout
/// so it always agrees with the live targets shown elsewhere.
class GoalSetupFlow extends ConsumerStatefulWidget {
  final BioSex sex;
  final int age;
  final double heightCm;
  final double currentKg;
  final String
  goal; // gain | lose | maintain (ignored when inferGoalFromTarget)
  final ActivityLevel activity;

  /// When true, the direction is derived from the target-weight wheel vs
  /// [currentKg] (HealthifyMe-style) instead of the fixed [goal]. The wheel
  /// seeds at the current weight so the user sets the direction themselves.
  final bool inferGoalFromTarget;

  /// Optional first name — shows a personalized summary on the reveal page.
  final String? name;

  // Macro prefs so the previewed plan matches the user's saved choices.
  final ProteinPlan proteinPlan;
  final double? proteinPerKg;
  final FatPlan fatPlan;
  final double? fatPct;

  // Seed values (null → engine defaults).
  final double? initialTargetKg;
  final double? initialWeeklyRateKg;
  final int? initialTimelineDays;
  final int? initialKcalOverride;
  final String initialUnit;

  /// true → write the result to Supabase and pop. false → call [onComplete].
  final bool saveOnFinish;
  final void Function(GoalSetupResult result)? onComplete;
  final String finishLabel;

  const GoalSetupFlow({
    super.key,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.currentKg,
    required this.goal,
    required this.activity,
    this.inferGoalFromTarget = false,
    this.name,
    this.proteinPlan = ProteinPlan.balanced,
    this.proteinPerKg,
    this.fatPlan = FatPlan.balanced,
    this.fatPct,
    this.initialTargetKg,
    this.initialWeeklyRateKg,
    this.initialTimelineDays,
    this.initialKcalOverride,
    this.initialUnit = 'kg',
    this.saveOnFinish = true,
    this.onComplete,
    this.finishLabel = 'Save goal',
  });

  @override
  ConsumerState<GoalSetupFlow> createState() => _GoalSetupFlowState();
}

class _GoalSetupFlowState extends ConsumerState<GoalSetupFlow> {
  final _pageCtrl = PageController();
  int _page = 0;

  late String _unit;
  double? _targetRaw;
  double? _rateRaw;
  int? _kcalOverride;
  bool _saving = false;

  /// Resolved direction — inferred from the target wheel, or the fixed goal.
  /// Even in fixed-goal mode, a target that lands back on the current weight has
  /// nothing to pace, so it resolves to `maintain` (no empty pace slider).
  String get _effectiveGoal {
    if (widget.inferGoalFromTarget) {
      return goalFromDelta(widget.currentKg, _effectiveTarget);
    }
    if (goalFromDelta(widget.currentKg, _effectiveTarget) == 'maintain') {
      return 'maintain';
    }
    return widget.goal;
  }

  bool get _isMaintain => _effectiveGoal == 'maintain';

  /// Protein preset follows the resolved direction when inferring; otherwise
  /// honour the caller's explicit preset.
  ProteinPlan get _proteinPlan => widget.inferGoalFromTarget
      ? proteinPlanForGoalKey(_effectiveGoal)
      : widget.proteinPlan;

  /// Plain-language activity label for the pace + reveal microcopy.
  String get _activityLabel => switch (widget.activity) {
    ActivityLevel.sedentary => 'Sedentary',
    ActivityLevel.light => 'Lightly active',
    ActivityLevel.active => 'Active',
    ActivityLevel.veryActive => 'Very active',
    ActivityLevel.athlete => 'Athlete',
  };

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _targetRaw = widget.initialTargetKg;
    // Seed the pace from the saved rate, or derive it from a legacy timeline so
    // re-opening an existing goal lands the slider where the user left it.
    _rateRaw = widget.initialWeeklyRateKg ?? _rateFromLegacyTimeline();
    _kcalOverride = widget.initialKcalOverride;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Derive an implied weekly rate from a legacy saved timeline (days), for
  /// profiles saved before the rate itself was captured. Null when there's no
  /// usable timeline.
  double? _rateFromLegacyTimeline() {
    final days = widget.initialTimelineDays;
    final target = widget.initialTargetKg;
    if (days == null || days <= 0 || target == null) return null;
    final delta = (target - widget.currentKg).abs();
    if (delta < 0.1) return null;
    final b = paceSliderBounds(goalFromDelta(widget.currentKg, target));
    return (delta / (days / 7)).clamp(b.min, b.max);
  }

  // ── Derived (mirrors the engine inputs used everywhere) ─────────────
  // When inferring, the wheel seeds at the current weight (neutral) so moving
  // it is what sets the direction; otherwise it seeds toward the fixed goal.
  double get _effectiveTarget =>
      _targetRaw ??
      (widget.inferGoalFromTarget
          ? widget.currentKg
          : defaultTargetKg(widget.currentKg, widget.goal));

  ({double min, double max}) get _rateBounds =>
      paceSliderBounds(_effectiveGoal);

  /// The fastest sustainable pace for the resolved direction — the slider's seed
  /// and the position its "recommended" marker points at.
  double get _recommendedRate =>
      recommendedWeeklyRate(widget.currentKg, gaining: _effectiveGoal == 'gain');

  double get _weeklyRateKg => _rateRaw ?? _recommendedRate;

  /// The chosen pace as a *signed* weekly rate (+ gain / − loss) — the value
  /// that drives the engine, so the calories/badge/ETA always match the
  /// headline rate the user is dragging.
  double? get _signedRate =>
      _isMaintain ? null : (_effectiveGoal == 'gain' ? _weeklyRateKg : -_weeklyRateKg);

  /// Realistic days to reach the target at the chosen rate — read straight off
  /// the engine so the ETA, reveal and saved timeline never disagree with the
  /// calories.
  int get _timelineDays => _isMaintain ? 0 : (_plan.etaDays ?? 0);

  NutritionPlan get _plan => NutritionEngine.compute(
    sex: widget.sex,
    age: widget.age,
    heightCm: widget.heightCm,
    currentKg: widget.currentKg,
    targetKg: _isMaintain ? widget.currentKg : _effectiveTarget,
    activity: widget.activity,
    durationDays: 0, // rate-driven below
    weeklyRateKgOverride: _signedRate,
    proteinPlan: _proteinPlan,
    proteinPerKgOverride: _proteinPlan == ProteinPlan.custom
        ? widget.proteinPerKg
        : null,
    fatPlan: widget.fatPlan,
    fatPctOverride: widget.fatPlan == FatPlan.custom ? widget.fatPct : null,
    kcalOverride: _kcalOverride,
  );

  List<Widget> get _pages {
    final plan = _plan;
    // At (or holding) the goal weight there's no pace to choose, so the pace
    // step is dropped. When inferring we keep the target wheel so the user can
    // still pick a direction; a fixed-goal "maintain" collapses to the reveal.
    if (_isMaintain) {
      return widget.inferGoalFromTarget
          ? [_targetPage(), _revealPage(plan)]
          : [_revealPage(plan)];
    }
    return [_targetPage(), _pacePage(plan), _revealPage(plan)];
  }

  // ── Navigation ──────────────────────────────────────────────────────
  void _next() {
    final last = _pages.length - 1;
    if (_page >= last) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _page++);
    _pageCtrl.animateToPage(
      _page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _page--);
    _pageCtrl.animateToPage(
      _page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final plan = _plan;
    final result = GoalSetupResult(
      targetKg: _isMaintain ? widget.currentKg : _effectiveTarget,
      weeklyRateKg: plan.weeklyRateKg,
      timelineDays: _timelineDays,
      kcalOverride: _kcalOverride,
      plan: plan,
      goal: _effectiveGoal,
    );
    if (!widget.saveOnFinish) {
      widget.onComplete?.call(result);
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = SupabaseService.auth.currentUser!.id;
      final updates = <String, dynamic>{
        'body_weight_goal': _effectiveGoal,
        'activity_level': widget.activity.name == 'veryActive'
            ? 'very_active'
            : widget.activity.name,
        'daily_calorie_target': plan.kcal,
        'daily_protein_target': plan.proteinG,
        'daily_carbs_target': plan.carbsG,
        'daily_fat_target': plan.fatG,
        'daily_fiber_target': plan.fiberG,
        'water_target_ml': plan.waterMl,
      };
      if (!_isMaintain) updates['target_body_weight'] = _effectiveTarget;

      // Merge into the existing prefs so an unrelated setting (e.g. a manual
      // water goal) survives a goal change.
      final existing = ref.read(appUserProvider).valueOrNull?.nutritionPrefsRaw;
      final prefs = <String, dynamic>{...?existing};
      prefs['protein_plan'] = widget.proteinPlan.name;
      prefs['fat_plan'] = widget.fatPlan.name;
      // Persist the *rate* as the authoritative pace (drives the live engine),
      // plus the resulting timeline for display/back-compat.
      if (!_isMaintain) {
        prefs['weekly_rate_kg'] = plan.weeklyRateKg;
      } else {
        prefs.remove('weekly_rate_kg');
      }
      if (!_isMaintain && _timelineDays > 0) {
        prefs['timeline_days'] = _timelineDays;
      } else {
        prefs.remove('timeline_days');
      }
      if (_kcalOverride != null && _kcalOverride! > 0) {
        prefs['kcal_override'] = _kcalOverride;
      } else {
        prefs.remove('kcal_override');
      }
      updates['nutrition_prefs'] = prefs;

      await SupabaseService.client.from('users').update(updates).eq('id', uid);
      ref.invalidate(appUserProvider);

      if (!mounted) return;
      Navigator.of(context).pop(result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Goal updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnack(context, e);
    }
  }

  Future<void> _setManualCalories() async {
    final rec = _plan.kcal;
    final ctrl = TextEditingController(text: (_kcalOverride ?? rec).toString());
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        final t = ctx.t;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Set your own calories', style: t.h2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Override the recommendation with an exact daily target. '
                'Macros re-balance to match.',
                style: t.body.copyWith(color: c.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: t.body.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: '5000',
                  suffixText: 'kcal / day',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(LucideIcons.info, size: 13, color: c.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Eating 5000+ kcal is very demanding and tends to add fat — '
                      'use it only if you know what you\'re doing.',
                      style: t.meta.copyWith(color: c.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (_kcalOverride != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 0), // sentinel = clear
                child: Text(
                  'Use recommended',
                  style: t.bodyStrong.copyWith(color: c.textSecondary),
                ),
              ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
              child: Text('Set', style: t.bodyStrong.copyWith(color: c.accent)),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (result == null) return;
    setState(() {
      if (result == 0) {
        _kcalOverride = null;
      } else if (result > 0) {
        _kcalOverride = result.clamp(800, 8000);
      }
    });
  }

  // ── Pages ────────────────────────────────────────────────────────────
  Widget _targetPage() {
    final delta = _effectiveTarget - widget.currentKg;
    return _FlowShell(
      title: "What's your target weight?",
      subtitle: 'Set a realistic weight goal for yourself.',
      child: Column(
        children: [
          const SizedBox(height: 4),
          IdealRangeBanner(
            targetKg: _effectiveTarget,
            heightCm: widget.heightCm,
            unit: _unit,
          ),
          const SizedBox(height: 18),
          // Anchor the target to where the user is now, so the inferred
          // direction (gain / lose / maintain) is always legible.
          _NowWeightContext(
            currentKg: widget.currentKg,
            deltaKg: delta,
            unit: _unit,
          ),
          const SizedBox(height: 18),
          WeightWheelPicker(
            valueKg: _effectiveTarget,
            unit: _unit,
            onUnitChanged: (u) => setState(() => _unit = u),
            onChanged: (kg) => setState(() {
              _targetRaw = kg;
            }),
          ),
        ],
      ),
    );
  }

  Widget _pacePage(NutritionPlan plan) => _FlowShell(
    title: 'How fast do you want to reach your goal?',
    subtitle: 'Drag to choose your pace — calories follow.',
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GoalPaceControl(
        weeklyRateKg: _weeklyRateKg,
        min: _rateBounds.min,
        max: _rateBounds.max,
        recommendedRate: _recommendedRate,
        currentKg: widget.currentKg,
        gaining: _effectiveGoal == 'gain',
        tier: plan.paceTier,
        etaDays: _timelineDays,
        dailyKcal: plan.kcal,
        activityLabel: _activityLabel,
        manualActive: _kcalOverride != null,
        onChanged: (v) => setState(() {
          _rateRaw = v;
          _kcalOverride = null; // dragging returns to pace-driven calories
        }),
        onSetManual: _setManualCalories,
      ),
    ),
  );

  Widget _revealPage(NutritionPlan plan) => _FlowShell(
    title: '',
    subtitle: '',
    compactHeader: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CalorieReveal(
          plan: plan,
          goal: _effectiveGoal,
          currentKg: widget.currentKg,
          targetKg: _isMaintain ? widget.currentKg : _effectiveTarget,
          timelineDays: _timelineDays,
          // "At goal" only when we inferred maintain from a target that matches
          // the current weight — not when the user deliberately chose Maintain.
          atGoal: _isMaintain && widget.inferGoalFromTarget,
          name: widget.name,
          heightCm: widget.heightCm,
          activityLabel: _activityLabel,
        ),
        const SizedBox(height: 18),
        Center(
          child: PressScale(
            scale: 0.98,
            onTap: () => HowWeCalculateScreen.open(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.bookOpen,
                  size: 14,
                  color: context.c.textMuted,
                ),
                const SizedBox(width: 7),
                Text(
                  'How we calculate this',
                  style: context.t.meta.copyWith(
                    color: context.c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pages = _pages;
    final total = pages.length;
    final isLast = _page >= total - 1;
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _back,
          ),
          title: total > 1
              ? _Dots(count: total, index: _page)
              : const Text('Your goal'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: pages,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.screenH,
                  8,
                  AppSpace.screenH,
                  MediaQuery.of(context).viewPadding.bottom + 12,
                ),
                child: AtlasButton(
                  label: isLast ? widget.finishLabel : 'Next',
                  loading: _saving,
                  onPressed: _saving ? null : _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-page header + scrollable body shared by the flow's steps.
class _FlowShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool compactHeader;
  const _FlowShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.compactHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screenH,
        8,
        AppSpace.screenH,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compactHeader) ...[
            const SizedBox(height: 6),
            Text(title, style: t.h1),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: t.body.copyWith(color: c.textMuted, height: 1.4),
              ),
            ],
            const SizedBox(height: 22),
          ] else
            const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A calm anchor under the target wheel: where you are now + how far the chosen
/// target sits from it, so the inferred direction is always obvious.
class _NowWeightContext extends StatelessWidget {
  final double currentKg;
  final double deltaKg;
  final String unit;
  const _NowWeightContext({
    required this.currentKg,
    required this.deltaKg,
    required this.unit,
  });

  String _fmt(double kg) {
    final v = kgToDisplay(kg, unit);
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final u = unit == 'lb' ? 'lb' : 'kg';
    final gaining = deltaKg > 0.4;
    final losing = deltaKg < -0.4;
    final col = gaining
        ? c.athletic
        : losing
        ? c.mind
        : c.textMuted;
    final deltaLabel = (!gaining && !losing)
        ? 'maintain'
        : '${gaining ? '+' : '−'}${_fmt(deltaKg.abs())} $u';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Now ', style: t.meta.copyWith(color: c.textMuted)),
          Text(
            '${_fmt(currentKg)} $u',
            style: t.bodyStrong.copyWith(color: c.textSecondary),
          ),
          const SizedBox(width: 8),
          Icon(
            gaining
                ? LucideIcons.arrowUpRight
                : losing
                ? LucideIcons.arrowDownRight
                : LucideIcons.minus,
            size: 14,
            color: col,
          ),
          const SizedBox(width: 4),
          Text(
            deltaLabel,
            style: t.meta.copyWith(color: col, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Slim progress dots shown in the app bar while the flow has >1 step.
class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? c.accent : c.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
