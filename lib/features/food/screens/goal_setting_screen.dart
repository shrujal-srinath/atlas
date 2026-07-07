import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/nutrition_engine.dart';
import '../providers/weight_providers.dart';
import '../widgets/goal_controls.dart';
import 'how_we_calculate_screen.dart';
import 'meals_screen.dart';

/// Engine-driven goal editor — the in-app "adjust later" surface for the
/// nutrition system. Body stats + goal weight + pace + macro plans + an
/// optional manual calorie override all feed the SAME [NutritionEngine] as
/// onboarding, so the live preview here tells one consistent story.
class GoalSettingScreen extends ConsumerStatefulWidget {
  const GoalSettingScreen({super.key});
  @override
  ConsumerState<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends ConsumerState<GoalSettingScreen> {
  late TextEditingController _height, _weight, _age, _kcalOverrideCtrl;
  String _gender = 'male';
  String _activity = 'active';
  String _goal = 'gain';

  // Goal / pace.
  double? _targetWeightRaw;
  double? _weeklyRateKgRaw;

  // Macro plans.
  ProteinPlan _proteinPlan = ProteinPlan.balanced;
  double? _proteinCustom; // g/kg
  FatPlan _fatPlan = FatPlan.balanced;
  double? _fatCustom; // 0..1

  // Calorie override.
  bool _kcalOverrideOn = false;

  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _height = TextEditingController();
    _weight = TextEditingController();
    _age = TextEditingController();
    _kcalOverrideCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [_height, _weight, _age, _kcalOverrideCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadFromProfile() {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null || _loaded) return;
    _loaded = true;
    _height.text = user.heightCm?.toStringAsFixed(0) ?? '';
    _weight.text = user.weightKg?.toStringAsFixed(0) ?? '';
    _age.text = user.age?.toString() ?? '';
    _gender = user.gender;
    _activity = user.activityLevel;
    _goal = user.bodyWeightGoal;
    _targetWeightRaw = user.targetBodyWeight;

    final prefs = user.nutritionPrefsRaw;
    // Position the pace to the saved plan: prefer the authoritative weekly rate,
    // else derive it from a legacy timeline. Left null → the sustainable default
    // for fresh profiles.
    final b = _rateBounds;
    final savedRate = user.weeklyRateKg;
    final storedTimeline = user.timelineDays;
    final tw = user.targetBodyWeight;
    final w = user.weightKg;
    if (!_isMaintain && savedRate != null && savedRate.abs() >= 0.01) {
      _weeklyRateKgRaw = savedRate.abs().clamp(b.min, b.max);
    } else if (!_isMaintain &&
        storedTimeline != null &&
        storedTimeline > 0 &&
        tw != null &&
        w != null &&
        w > 0) {
      final delta = (tw - w).abs();
      if (delta >= 0.1) {
        _weeklyRateKgRaw = (delta / (storedTimeline / 7)).clamp(b.min, b.max);
      }
    }
    _proteinPlan = proteinPlanFromName(prefs?['protein_plan'] as String?) ??
        proteinPlanForGoalKey(_goal);
    _proteinCustom = (prefs?['protein_per_kg'] as num?)?.toDouble();
    _fatPlan = fatPlanFromName(prefs?['fat_plan'] as String?) ?? FatPlan.balanced;
    _fatCustom = (prefs?['fat_pct'] as num?)?.toDouble();
    final override = user.kcalOverride;
    if (override != null && override > 0) {
      _kcalOverrideOn = true;
      _kcalOverrideCtrl.text = override.toString();
    }
  }

  // ── Derived goal/pace values (mirror onboarding) ────────────────────
  bool get _isMaintain => _goal == 'maintain';

  // Bounded so an extreme/mistyped value reads as "incomplete" rather than
  // flowing into the BMR formula (which goes negative for extreme ages) or
  // being saved verbatim.
  double? get _h {
    final v = double.tryParse(_height.text);
    return (v == null || v < 50 || v > 300) ? null : v;
  }

  double? get _w {
    final v = double.tryParse(_weight.text);
    return (v == null || v < 20 || v > 400) ? null : v;
  }

  int? get _a {
    final v = int.tryParse(_age.text);
    return (v == null || v < 10 || v > 120) ? null : v;
  }

  double get _effectiveTarget =>
      _targetWeightRaw ?? defaultTargetKg(_w ?? 75, _goal);

  // One source of truth for the pace bounds — shared with the onboarding flow
  // so gain/loss ranges never tell two different stories.
  ({double min, double max}) get _rateBounds => paceSliderBounds(_goal);

  double get _weeklyRateKg =>
      _weeklyRateKgRaw ??
      recommendedWeeklyRate(_w ?? 75, gaining: _goal == 'gain');

  /// Signed weekly rate (+ gain / − loss) that drives the engine.
  double? get _signedRate =>
      _isMaintain ? null : (_goal == 'gain' ? _weeklyRateKg : -_weeklyRateKg);

  int get _timelineDays {
    if (_isMaintain) return 0;
    return _plan?.etaDays ?? 0;
  }

  /// The plan, optionally forcing the kcal override off (for the recommended
  /// baseline shown next to the override toggle). Rate-driven so the saved
  /// targets match the live engine exactly.
  NutritionPlan? _computePlan({required bool applyOverride}) {
    final h = _h;
    final w = _w;
    final a = _a;
    if (h == null || w == null || a == null) return null;
    final override = applyOverride && _kcalOverrideOn
        ? int.tryParse(_kcalOverrideCtrl.text)
        : null;
    return NutritionEngine.compute(
      sex: bioSexFromKey(_gender),
      age: a,
      heightCm: h,
      currentKg: w,
      targetKg: _isMaintain ? w : _effectiveTarget,
      activity: activityFromKey(_activity),
      durationDays: 0,
      weeklyRateKgOverride: _signedRate,
      proteinPlan: _proteinPlan,
      proteinPerKgOverride:
          _proteinPlan == ProteinPlan.custom ? _proteinCustom : null,
      fatPlan: _fatPlan,
      fatPctOverride: _fatPlan == FatPlan.custom ? _fatCustom : null,
      kcalOverride: override,
    );
  }

  NutritionPlan? get _plan => _computePlan(applyOverride: true);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    _loadFromProfile();
    final plan = _plan;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Nutrition goals'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Live target summary — always visible while you tweak below.
            if (plan != null) _SummaryBar(plan: plan, goal: _goal),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 12, AppSpace.screenH, 24),
                children: [
                  // ── Body stats ─────────
                  _SectionCard(
                    title: 'Body stats',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: _Field(
                                  controller: _height,
                                  label: 'Height',
                                  suffix: 'cm',
                                  hint: '175',
                                  onChanged: _refresh)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _Field(
                                  controller: _weight,
                                  label: 'Weight',
                                  suffix: 'kg',
                                  hint: '70',
                                  onChanged: _refresh)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _Field(
                                  controller: _age,
                                  label: 'Age',
                                  suffix: 'yr',
                                  hint: '25',
                                  onChanged: _refresh)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SegmentPicker(
                        label: 'Gender',
                        value: _gender,
                        options: const ['male', 'female', 'other'],
                        labels: const ['Male', 'Female', 'Other'],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 16),
                      _SegmentPicker(
                        label: 'Activity level',
                        value: _activity,
                        options: const [
                          'sedentary',
                          'light',
                          'active',
                          'very_active',
                          'athlete'
                        ],
                        labels: const [
                          'Sedentary',
                          'Light',
                          'Active',
                          'V. Active',
                          'Athlete'
                        ],
                        onChanged: (v) => setState(() => _activity = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Macros ─────────
                  _SectionCard(
                    title: 'Macros',
                    subtitle: 'Protein tracks your bodyweight; fat sets the '
                        'balance; carbs flex with your calories.',
                    children: [
                      ProteinPlanPicker(
                        selected: _proteinPlan,
                        customPerKg: _proteinCustom,
                        currentKg: _w ?? 70,
                        onPlan: (p) => setState(() {
                          _proteinPlan = p;
                          if (p == ProteinPlan.custom) {
                            _proteinCustom ??= proteinPerKgFor(_proteinPlan);
                          }
                        }),
                        onCustom: (v) => setState(() => _proteinCustom = v),
                      ),
                      const SizedBox(height: 18),
                      FatPlanPicker(
                        selected: _fatPlan,
                        customPct: _fatCustom,
                        onPlan: (p) => setState(() {
                          _fatPlan = p;
                          if (p == FatPlan.custom) _fatCustom ??= 0.27;
                        }),
                        onCustom: (v) => setState(() => _fatCustom = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Calories ─────────
                  _SectionCard(
                    title: 'Calories',
                    subtitle:
                        'Use the recommended target, or pin your own — macros '
                        're-derive to match.',
                    children: [
                      _OverrideToggle(
                        on: _kcalOverrideOn,
                        recommended:
                            _computePlan(applyOverride: false)?.kcal,
                        onChanged: (on) => setState(() {
                          _kcalOverrideOn = on;
                          if (on && _kcalOverrideCtrl.text.trim().isEmpty) {
                            final rec = _computePlan(applyOverride: false)?.kcal;
                            if (rec != null) {
                              _kcalOverrideCtrl.text = rec.toString();
                            }
                          }
                        }),
                      ),
                      if (_kcalOverrideOn) ...[
                        const SizedBox(height: 14),
                        _Field(
                          controller: _kcalOverrideCtrl,
                          label: 'Daily calories',
                          suffix: 'kcal',
                          hint: '3000',
                          big: true,
                          onChanged: _refresh,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Meals → dedicated schedule editor ────────────
                  _MealsLinkCard(onTap: () => MealsScreen.open(context)),
                  const SizedBox(height: 16),
                  _HowWeCalculateLink(
                    onTap: () => HowWeCalculateScreen.open(context),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Sticky save button
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 10, AppSpace.screenH, 16),
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: AtlasButton(
                  label: 'Save goals',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refresh() => setState(() {});

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = SupabaseService.auth.currentUser!.id;
      final plan = _plan;
      final updates = <String, dynamic>{
        'body_weight_goal': _goal,
        'gender': _gender,
        'activity_level': _activity,
      };

      final h = _h;
      final w = _w;
      final a = _a;
      if (h != null) updates['height_cm'] = h;
      if (w != null) updates['weight_kg'] = w;
      if (a != null) updates['age'] = a;
      if (!_isMaintain) updates['target_body_weight'] = _effectiveTarget;

      if (plan != null) {
        updates['daily_calorie_target'] = plan.kcal;
        updates['daily_protein_target'] = plan.proteinG;
        updates['daily_carbs_target'] = plan.carbsG;
        updates['daily_fat_target'] = plan.fatG;
        updates['daily_fiber_target'] = plan.fiberG;
        updates['water_target_ml'] = plan.waterMl;
      }

      // nutrition_prefs jsonb — drives the live recompute everywhere. Merge
      // into the existing map so unrelated settings (timeline, manual water
      // goal) are preserved; explicitly clear the keys this screen owns.
      final prefs = <String, dynamic>{
        ...?ref.read(appUserProvider).valueOrNull?.nutritionPrefsRaw,
      };
      prefs['protein_plan'] = _proteinPlan.name;
      prefs['fat_plan'] = _fatPlan.name;
      // Authoritative pace (drives the live engine) + timeline for display.
      if (!_isMaintain && plan != null) {
        prefs['weekly_rate_kg'] = plan.weeklyRateKg;
      } else {
        prefs.remove('weekly_rate_kg');
      }
      if (!_isMaintain && _timelineDays > 0) {
        prefs['timeline_days'] = _timelineDays;
      } else {
        prefs.remove('timeline_days');
      }
      if (_proteinPlan == ProteinPlan.custom && _proteinCustom != null) {
        prefs['protein_per_kg'] = _proteinCustom;
      } else {
        prefs.remove('protein_per_kg');
      }
      if (_fatPlan == FatPlan.custom && _fatCustom != null) {
        prefs['fat_pct'] = _fatCustom;
      } else {
        prefs.remove('fat_pct');
      }
      final override = int.tryParse(_kcalOverrideCtrl.text);
      if (_kcalOverrideOn && override != null && override > 0) {
        prefs['kcal_override'] = override;
      } else {
        prefs.remove('kcal_override');
      }
      updates['nutrition_prefs'] = prefs;
      // Per-meal goals are owned by the Meals screen (meal_calorie_targets);
      // this screen no longer writes them.

      await SupabaseService.client.from('users').update(updates).eq('id', uid);
      ref.invalidate(appUserProvider);

      // Keep one weight timeline: mirror the profile weight onto today's
      // Body-tab history point.
      if (w != null && w > 0) await recordWeightHistoryPoint(ref, w);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goals updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnack(context, e);
    }
  }
}

/// Compact live target bar pinned above the editor — kcal + pace + macros.
class _SummaryBar extends StatelessWidget {
  final NutritionPlan plan;
  final String goal;
  const _SummaryBar({required this.plan, required this.goal});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final isMaintain = goal == 'maintain';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 10, AppSpace.screenH, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${plan.kcal}', style: t.numLg),
                  const SizedBox(width: 5),
                  Text('kcal',
                      style: t.bodyStrong.copyWith(color: c.textMuted)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'P ${plan.proteinG}g · C ${plan.carbsG}g · F ${plan.fatG}g',
                style: t.meta.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (!isMaintain) PaceBadge(tier: plan.paceTier),
        ],
      ),
    );
  }
}

/// "Use recommended" ↔ "Set my own" toggle for the calorie target.
class _OverrideToggle extends StatelessWidget {
  final bool on;
  final int? recommended;
  final ValueChanged<bool> onChanged;
  const _OverrideToggle({
    required this.on,
    required this.recommended,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(on ? 'Manual calories' : 'Recommended calories',
                  style: t.bodyStrong.copyWith(color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(
                on
                    ? 'You set the number; macros adjust.'
                    : recommended != null
                        ? '$recommended kcal from your goal & pace.'
                        : 'Computed from your goal & pace.',
                style: t.meta.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
        Switch(
          value: on,
          activeThumbColor: c.onAccent,
          activeTrackColor: c.accent,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
        ),
      ],
    );
  }
}

/// Grouped section: an overline title (+ optional subtitle / trailing action)
/// over a surface card.
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppType.overline
                      .copyWith(color: c.textMuted, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!,
                style: AppType.meta.copyWith(color: c.textMuted, height: 1.35)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Footer link to the cited methodology screen.
class _HowWeCalculateLink extends StatelessWidget {
  final VoidCallback onTap;
  const _HowWeCalculateLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return PressScale(
      scale: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bookOpen, size: 15, color: c.textMuted),
          const SizedBox(width: 8),
          Text(
            'How we calculate your targets',
            style: t.bodyStrong.copyWith(color: c.textSecondary),
          ),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronRight, size: 15, color: c.textMuted),
        ],
      ),
    );
  }
}

/// Tappable card linking to the dedicated Meals schedule editor.
class _MealsLinkCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MealsLinkCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return PressScale(
      scale: 0.99,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.utensils, size: 17, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meals', style: t.bodyStrong),
                  const SizedBox(height: 2),
                  Text('Schedule, names, times & per-meal calories',
                      style: t.meta.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Numeric field — label above a clean filled box. Per house rules, inputs use
/// a `surface` fill + a defined `borderStrong` border so they read as inputs.
class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label, suffix;
  final String? hint;
  final bool big;
  final VoidCallback? onChanged;
  const _Field({
    required this.controller,
    required this.label,
    required this.suffix,
    this.hint,
    this.big = false,
    this.onChanged,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final focused = _focus.hasFocus;
    final valueStyle = widget.big
        ? AppType.numLg.copyWith(color: c.textPrimary, fontSize: 24)
        : t.body.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: goalLabelStyle(context)),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: focused ? c.accent : c.borderStrong,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  onChanged:
                      widget.onChanged == null ? null : (_) => widget.onChanged!(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: valueStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: widget.big ? 15 : 14),
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: valueStyle.copyWith(
                        color: c.textDim, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.suffix,
                style: t.meta
                    .copyWith(color: c.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Single-choice pill picker. Selected = solid accent fill + white text
/// (high-contrast, per house rule 1 — never accent-on-tint here).
class _SegmentPicker extends StatelessWidget {
  final String label, value;
  final List<String> options, labels;
  final ValueChanged<String> onChanged;
  const _SegmentPicker({
    required this.label,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: goalLabelStyle(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < options.length; i++)
              PressScale(
                scale: 0.95,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(options[i]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: value == options[i] ? c.accent : c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: value == options[i] ? c.accent : c.border,
                      width: value == options[i] ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: value == options[i]
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: value == options[i] ? c.onAccent : c.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
