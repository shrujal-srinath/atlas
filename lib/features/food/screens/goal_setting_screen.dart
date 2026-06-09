import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

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
  }

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
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

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
                  _SectionLabel(text: 'BODY STATS'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _Field(controller: _height, label: 'Height', suffix: 'cm')),
                      const SizedBox(width: 10),
                      Expanded(child: _Field(controller: _weight, label: 'Weight', suffix: 'kg')),
                      const SizedBox(width: 10),
                      Expanded(child: _Field(controller: _age, label: 'Age', suffix: 'yr')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SegmentPicker(
                          label: 'Gender',
                          value: _gender,
                          options: const ['male', 'female'],
                          labels: const ['Male', 'Female'],
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SegmentPicker(
                    label: 'Activity level',
                    value: _activity,
                    options: const ['sedentary', 'light', 'moderate', 'active', 'very_active'],
                    labels: const ['Sedentary', 'Light', 'Moderate', 'Active', 'V. Active'],
                    onChanged: (v) => setState(() => _activity = v),
                  ),
                  const SizedBox(height: 12),
                  _SegmentPicker(
                    label: 'Goal',
                    value: _goal,
                    options: const ['lose', 'maintain', 'gain'],
                    labels: const ['Lose', 'Maintain', 'Gain'],
                    onChanged: (v) => setState(() => _goal = v),
                  ),
                  const SizedBox(height: 14),

                  // Auto-calc button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _autoCalc,
                      icon: const Icon(LucideIcons.calculator, size: 16),
                      label: const Text('Auto-calculate targets'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.accent,
                        side: BorderSide(color: c.accent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Targets ────────────
                  _SectionLabel(text: 'DAILY TARGETS'),
                  const SizedBox(height: 4),
                  Text('Edit any field to override the auto-calculated value.',
                      style: t.meta.copyWith(color: c.textMuted)),
                  const SizedBox(height: 10),
                  _Field(controller: _kcal, label: 'Calories', suffix: 'kcal', big: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _Field(controller: _protein, label: 'Protein', suffix: 'g')),
                      const SizedBox(width: 10),
                      Expanded(child: _Field(controller: _carbs, label: 'Carbs', suffix: 'g')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _Field(controller: _fat, label: 'Fat', suffix: 'g')),
                      const SizedBox(width: 10),
                      Expanded(child: _Field(controller: _fiber, label: 'Fiber', suffix: 'g')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Field(controller: _water, label: 'Water', suffix: 'L'),
                  const SizedBox(height: 24),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.overline.copyWith(color: context.c.textMuted));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, suffix;
  final bool big;
  const _Field({
    required this.controller,
    required this.label,
    required this.suffix,
    this.big = false,
  });
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.c;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: big
          ? AppType.numLg.copyWith(color: c.textPrimary, fontSize: 24)
          : t.body,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: t.label,
        suffixText: suffix,
        suffixStyle: t.meta.copyWith(color: c.textMuted),
      ),
    );
  }
}

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
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < options.length; i++)
              GestureDetector(
                onTap: () => onChanged(options[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: value == options[i] ? c.accentSoft : c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: value == options[i] ? c.accent : c.border,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
