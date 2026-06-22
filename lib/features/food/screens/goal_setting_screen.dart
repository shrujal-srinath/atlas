import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_targets.dart';

/// HealthifyMe-style goal editor.
///
/// Auto-calculates TDEE from Mifflin-St Jeor, then lets the user
/// apply a surplus/deficit and manually tweak any macro target.
class GoalSettingScreen extends ConsumerStatefulWidget {
  const GoalSettingScreen({super.key});
  @override
  ConsumerState<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends ConsumerState<GoalSettingScreen> {
  late TextEditingController _height, _weight, _age;
  late TextEditingController _kcal, _protein, _carbs, _fat, _fiber, _water;
  // Per-meal calorie goals, one controller per slot (kDiarySlotOrder).
  final Map<MealTimeSlot, TextEditingController> _meal = {
    for (final s in kDiarySlotOrder) s: TextEditingController(),
  };
  String _gender = 'male';
  String _activity = 'active';
  String _goal = 'gain';
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _height = TextEditingController();
    _weight = TextEditingController();
    _age = TextEditingController();
    _kcal = TextEditingController();
    _protein = TextEditingController();
    _carbs = TextEditingController();
    _fat = TextEditingController();
    _fiber = TextEditingController();
    _water = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [_height, _weight, _age, _kcal, _protein, _carbs, _fat, _fiber, _water]) {
      c.dispose();
    }
    for (final c in _meal.values) {
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
    _kcal.text = user.dailyCalorieTarget.toString();
    _protein.text = user.dailyProteinTarget.toString();
    _carbs.text = user.dailyCarbsTarget?.toString() ?? '';
    _fat.text = user.dailyFatTarget?.toString() ?? '';
    _fiber.text = user.dailyFiberTarget?.toString() ?? '';
    _water.text = (user.waterTargetMl / 1000).toStringAsFixed(1);

    // Per-meal goals: stored override wins, else the auto-split of the daily
    // target. Optional workout slots stay blank until the user sets one.
    final resolved = resolveMealTargets(
      dailyKcal: user.dailyCalorieTarget,
      overrides: user.mealCalorieTargetsJson,
    );
    for (final slot in kDiarySlotOrder) {
      final v = resolved[slot];
      _meal[slot]!.text = (v != null && v > 0) ? v.toString() : '';
    }
  }

  /// Re-fill the main-meal fields from the auto-split of the current calorie
  /// field. Optional workout slots are left as the user set them.
  void _applyMealAutoSplit() {
    final kcal = int.tryParse(_kcal.text) ?? 0;
    if (kcal <= 0) return;
    for (final slot in kDiarySlotOrder) {
      final split = autoSplitFor(slot, kcal);
      if (split > 0) _meal[slot]!.text = split.toString();
    }
    setState(() {});
  }

  static bool _isOptionalSlot(MealTimeSlot s) =>
      s == MealTimeSlot.preWorkout || s == MealTimeSlot.postWorkout;

  Widget _mealField(MealTimeSlot slot) => _Field(
        controller: _meal[slot]!,
        label: _isOptionalSlot(slot) ? '${slot.label} (opt)' : slot.label,
        suffix: 'kcal',
        hint: _isOptionalSlot(slot) ? 'optional' : '0',
      );

  void _autoCalc() {
    final h = double.tryParse(_height.text);
    final w = double.tryParse(_weight.text);
    final a = int.tryParse(_age.text);
    if (h == null || w == null || a == null) return;

    // Mifflin-St Jeor
    final bmr = _gender == 'male'
        ? 10 * w + 6.25 * h - 5 * a + 5
        : 10 * w + 6.25 * h - 5 * a - 161;

    final factor = switch (_activity) {
      'sedentary' => 1.2,
      'light'     => 1.375,
      'moderate'  => 1.55,
      'active'    => 1.725,
      'very_active' => 1.9,
      _ => 1.55,
    };
    final tdee = bmr * factor;

    // Goal adjustment
    final adj = switch (_goal) {
      'lose'     => -500.0,
      'maintain' =>    0.0,
      'gain'     =>  350.0,
      _          =>    0.0,
    };
    final target = (tdee + adj).round();

    // Protein: 2.0 g/kg for gain, 2.4 for lose, 1.8 for maintain
    final proteinPerKg = switch (_goal) {
      'gain' => 2.0,
      'lose' => 2.4,
      _ => 1.8,
    };
    final protein = (w * proteinPerKg).round();
    final proteinKcal = protein * 4;
    final remaining = math.max(0, target - proteinKcal);
    final carbs = (remaining * 0.55 / 4).round();
    final fat = (remaining * 0.45 / 9).round();
    final fiber = (14 * target / 1000).round();

    setState(() {
      _kcal.text = target.toString();
      _protein.text = protein.toString();
      _carbs.text = carbs.toString();
      _fat.text = fat.toString();
      _fiber.text = fiber.toString();
    });
    _applyMealAutoSplit();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    // Load from profile on first build
    _loadFromProfile();

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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 8, AppSpace.screenH, 24),
                children: [
                  // ── Body stats ─────────
                  _SectionCard(
                    title: 'Body stats',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Field(controller: _height, label: 'Height', suffix: 'cm', hint: '175')),
                          const SizedBox(width: 10),
                          Expanded(child: _Field(controller: _weight, label: 'Weight', suffix: 'kg', hint: '70')),
                          const SizedBox(width: 10),
                          Expanded(child: _Field(controller: _age, label: 'Age', suffix: 'yr', hint: '25')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SegmentPicker(
                        label: 'Gender',
                        value: _gender,
                        options: const ['male', 'female'],
                        labels: const ['Male', 'Female'],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 16),
                      _SegmentPicker(
                        label: 'Activity level',
                        value: _activity,
                        options: const ['sedentary', 'light', 'moderate', 'active', 'very_active'],
                        labels: const ['Sedentary', 'Light', 'Moderate', 'Active', 'V. Active'],
                        onChanged: (v) => setState(() => _activity = v),
                      ),
                      const SizedBox(height: 16),
                      _SegmentPicker(
                        label: 'Goal',
                        value: _goal,
                        options: const ['lose', 'maintain', 'gain'],
                        labels: const ['Lose', 'Maintain', 'Gain'],
                        onChanged: (v) => setState(() => _goal = v),
                      ),
                      const SizedBox(height: 18),
                      AtlasButton(
                        label: 'Auto-calculate targets',
                        icon: LucideIcons.calculator,
                        variant: AtlasButtonVariant.tonal,
                        height: 50,
                        onPressed: _autoCalc,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Daily targets ────────────
                  _SectionCard(
                    title: 'Daily targets',
                    subtitle: 'Edit any field to override the auto-calculated value.',
                    children: [
                      _Field(controller: _kcal, label: 'Calories', suffix: 'kcal', hint: '3000', big: true),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Field(controller: _protein, label: 'Protein', suffix: 'g', hint: '180')),
                          const SizedBox(width: 10),
                          Expanded(child: _Field(controller: _carbs, label: 'Carbs', suffix: 'g', hint: '350')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Field(controller: _fat, label: 'Fat', suffix: 'g', hint: '80')),
                          const SizedBox(width: 10),
                          Expanded(child: _Field(controller: _fiber, label: 'Fiber', suffix: 'g', hint: '30')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Field(controller: _water, label: 'Water', suffix: 'L', hint: '3.5'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Per-meal calorie goals ────────────
                  _SectionCard(
                    title: 'Per-meal calorie goals',
                    subtitle: 'Splits your daily calories across meals. Workout '
                        'slots are optional — leave blank to show only what you log.',
                    action: _AutoSplitAction(onTap: _applyMealAutoSplit),
                    children: [
                      for (var i = 0; i < kDiarySlotOrder.length; i += 2)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom: i + 2 < kDiarySlotOrder.length ? 12 : 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _mealField(kDiarySlotOrder[i])),
                              const SizedBox(width: 10),
                              if (i + 1 < kDiarySlotOrder.length)
                                Expanded(child: _mealField(kDiarySlotOrder[i + 1]))
                              else
                                const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Sticky save button
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 10, AppSpace.screenH, 16),
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save goals',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = SupabaseService.auth.currentUser!.id;
      final updates = <String, dynamic>{
        'daily_calorie_target': int.tryParse(_kcal.text) ?? 3000,
        'daily_protein_target': int.tryParse(_protein.text) ?? 180,
        'body_weight_goal': _goal,
        'gender': _gender,
        'activity_level': _activity,
      };
      final h = double.tryParse(_height.text);
      final w = double.tryParse(_weight.text);
      final a = int.tryParse(_age.text);
      if (h != null) updates['height_cm'] = h;
      if (w != null) updates['weight_kg'] = w;
      if (a != null) updates['age'] = a;

      final carbs = int.tryParse(_carbs.text);
      final fat = int.tryParse(_fat.text);
      final fiber = int.tryParse(_fiber.text);
      if (carbs != null) updates['daily_carbs_target'] = carbs;
      if (fat != null) updates['daily_fat_target'] = fat;
      if (fiber != null) updates['daily_fiber_target'] = fiber;

      final waterL = double.tryParse(_water.text);
      if (waterL != null) updates['water_target_ml'] = (waterL * 1000).round();

      // Per-meal goals → jsonb keyed by slot dbValue. Only non-empty positive
      // values are stored; everything else falls back to the auto-split.
      final mealTargets = <String, int>{};
      for (final slot in kDiarySlotOrder) {
        final v = int.tryParse(_meal[slot]!.text.trim());
        if (v != null && v > 0) mealTargets[slot.dbValue] = v;
      }
      updates['meal_calorie_targets'] =
          mealTargets.isEmpty ? null : mealTargets;

      await SupabaseService.client
          .from('users')
          .update(updates)
          .eq('id', uid);

      // Refresh the profile provider.
      ref.invalidate(appUserProvider);

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

/// Grouped section: an overline title (+ optional subtitle / trailing action)
/// over a surface card — replaces the bare fields-on-linen layout.
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    this.subtitle,
    this.action,
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
              ?action,
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

class _AutoSplitAction extends StatelessWidget {
  final VoidCallback onTap;
  const _AutoSplitAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.95,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wand2, size: 13, color: c.accent),
            const SizedBox(width: 5),
            Text(
              'Auto-split',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c.accent,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numeric field with the label sitting ABOVE a clean filled box (the previous
/// Material floating label cut across the box edge and read as broken). The
/// unit suffix sits inline on the right; focus lights the border accent.
class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label, suffix;
  final String? hint;
  final bool big;
  const _Field({
    required this.controller,
    required this.label,
    required this.suffix,
    this.hint,
    this.big = false,
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
        : t.body.copyWith(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: t.label),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: focused ? c.accent.withValues(alpha: 0.6) : c.border,
              width: focused ? 1 : 0.5,
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
                        color: c.textDim, fontWeight: FontWeight.w500),
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

/// Single-choice pill picker (handles any option count, incl. the 5 activity
/// levels). Polished: press-scale, accent-tinted selection, hairline borders.
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
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < options.length; i++)
              PressScale(
                scale: 0.95,
                onTap: () => onChanged(options[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: value == options[i]
                        ? c.accent.withValues(alpha: 0.12)
                        : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: value == options[i] ? c.accent : c.border,
                      width: value == options[i] ? 1.2 : 0.5,
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
                      color: value == options[i] ? c.accent : c.textSecondary,
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
