import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../phase/phase_config.dart';
import '../phase/phase_provider.dart';
import 'habit_templates.dart';

const _phaseDescriptions = {
  'Rehab + Bulk': 'Eating + rehab compliance.',
  'Bulk + Train': 'Training consistency.',
  'Performance': 'Conditioning + competition.',
  'Off-season': 'Behaviour + base habits.',
};

const _activityMultipliers = {
  'sedentary': 1.20,
  'light': 1.375,
  'active': 1.55,
  'very_active': 1.725,
  'athlete': 1.90,
};

const _genderLabels = {
  'male': 'Male',
  'female': 'Female',
  'other': 'Other',
};

const _activityLabels = {
  'sedentary': 'Sedentary',
  'light': 'Lightly active',
  'active': 'Active',
  'very_active': 'Very active',
  'athlete': 'Athlete',
};

const _goalLabels = {
  'gain': 'Gain mass',
  'maintain': 'Maintain',
  'lose': 'Lean down',
};

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Collected state
  final _nameCtrl = TextEditingController();
  String _phase = 'Rehab + Bulk';
  String _gender = 'male';
  String _activity = 'active';
  String _goal = 'gain';
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  bool _targetsTouched = false;

  final Set<String> _picked = {'run', 'read', 'no_phone'};
  bool _submitting = false;

  static const _totalSteps = 5;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null && user.name.isNotEmpty) _nameCtrl.text = user.name;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    super.dispose();
  }

  int? get _height => int.tryParse(_heightCtrl.text);
  double? get _weight => double.tryParse(_weightCtrl.text);
  int? get _age => int.tryParse(_ageCtrl.text);

  /// Mifflin–St Jeor BMR.
  double? get _bmr {
    final h = _height;
    final w = _weight;
    final a = _age;
    if (h == null || w == null || a == null) return null;
    final base = 10 * w + 6.25 * h - 5 * a;
    return base + (_gender == 'male' ? 5 : (_gender == 'female' ? -161 : 0));
  }

  double? get _tdee {
    final b = _bmr;
    if (b == null) return null;
    return b * (_activityMultipliers[_activity] ?? 1.55);
  }

  /// Recommended kcal + protein for the chosen goal.
  ({int kcal, int protein})? get _recommendation {
    final t = _tdee;
    final w = _weight;
    if (t == null || w == null) return null;
    final kcal = switch (_goal) {
      'gain' => (t + 500).round(),
      'lose' => (t - 500).round(),
      _ => t.round(),
    };
    final protein = switch (_goal) {
      'gain' => (w * 2.0).round(),
      'lose' => (w * 2.2).round(),
      _ => (w * 1.8).round(),
    };
    return (kcal: kcal, protein: protein);
  }

  void _recomputeTargetsIfUntouched() {
    if (_targetsTouched) return;
    final rec = _recommendation;
    if (rec == null) return;
    _kcalCtrl.text = rec.kcal.toString();
    _proteinCtrl.text = rec.protein.toString();
  }

  bool _canAdvance() {
    return switch (_step) {
      0 => _nameCtrl.text.trim().isNotEmpty,
      1 => true,
      2 => _height != null && _weight != null && _age != null,
      3 => int.tryParse(_kcalCtrl.text) != null &&
          int.tryParse(_proteinCtrl.text) != null,
      _ => true,
    };
  }

  Future<void> _next() async {
    if (_step == _totalSteps - 1) {
      await _submit();
      return;
    }
    if (!_canAdvance()) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    if (_step == 2) _recomputeTargetsIfUntouched();
    setState(() => _step++);
    await _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_step == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _step--);
    await _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final session = ref.read(sessionProvider);
    final uid = session?.user.id;
    if (uid == null) {
      setState(() => _submitting = false);
      return;
    }

    try {
      // 1. Persist user profile.
      await SupabaseService.client.from('users').update({
        'name': _nameCtrl.text.trim(),
        'current_phase': _phase,
        'gender': _gender,
        'activity_level': _activity,
        'body_weight_goal': _goal,
        if (_height != null) 'height_cm': _height,
        if (_weight != null) 'weight_kg': _weight,
        if (_age != null) 'age': _age,
        'daily_calorie_target': int.tryParse(_kcalCtrl.text),
        'daily_protein_target': int.tryParse(_proteinCtrl.text),
        'is_onboarded': true,
      }).eq('id', uid);

      // 2. Initial phase_history row.
      try {
        await SupabaseService.client.from('phase_history').insert({
          'user_id': uid,
          'phase_name': _phase,
          'weights': phaseWeightsFor(_phase).toJson(),
        });
      } catch (_) {
        // table may not exist yet
      }

      // 3. Insert chosen starter habits.
      if (_picked.isNotEmpty) {
        final rows = kStarterTemplates
            .where((t) => _picked.contains(t.id))
            .map((t) => t.toInsertPayload(uid))
            .toList();
        await SupabaseService.client.from('habits').insert(rows);
      }

      ref.invalidate(appUserProvider);
      ref.invalidate(activePhaseProvider);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: context.c.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressStrip(step: _step, total: _totalSteps),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _StepName(controller: _nameCtrl),
                  _StepPhase(
                    selected: _phase,
                    onChanged: (v) => setState(() => _phase = v),
                  ),
                  _StepBody(
                    heightCtrl: _heightCtrl,
                    weightCtrl: _weightCtrl,
                    ageCtrl: _ageCtrl,
                    gender: _gender,
                    activity: _activity,
                    goal: _goal,
                    onGender: (v) => setState(() => _gender = v),
                    onActivity: (v) => setState(() => _activity = v),
                    onGoal: (v) => setState(() => _goal = v),
                  ),
                  _StepTargets(
                    kcalCtrl: _kcalCtrl,
                    proteinCtrl: _proteinCtrl,
                    recommendation: _recommendation,
                    onTouched: () => _targetsTouched = true,
                  ),
                  _StepHabits(
                    picked: _picked,
                    onToggle: (id) => setState(() {
                      if (_picked.contains(id)) {
                        _picked.remove(id);
                      } else {
                        _picked.add(id);
                      }
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.screenH,
                10,
                AppSpace.screenH,
                MediaQuery.of(context).viewPadding.bottom + 12,
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _submitting ? null : _back,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      child: Icon(LucideIcons.arrowLeft,
                          size: 16, color: c.textSecondary),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting || !_canAdvance() ? null : _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: c.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      child: _submitting
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onAccent,
                              ),
                            )
                          : Text(
                              _step == _totalSteps - 1 ? 'Finish' : 'Continue',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── widgets ──────────────────────────────────

class _ProgressStrip extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressStrip({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 16, AppSpace.screenH, 0),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: active ? c.accent : c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  final String overline;
  final String title;
  final String? subtitle;
  final Widget child;
  const _StepShell({
    required this.overline,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 24, AppSpace.screenH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(overline,
              style: t.label.copyWith(letterSpacing: 0.8, color: c.accent)),
          const SizedBox(height: 6),
          Text(title, style: t.h1),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: t.body.copyWith(color: c.textMuted, height: 1.4)),
          ],
          const SizedBox(height: 22),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class _StepName extends StatelessWidget {
  final TextEditingController controller;
  const _StepName({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return _StepShell(
      overline: 'STEP 1 OF 5',
      title: 'Welcome.',
      subtitle:
          'ATLAS is your personal performance OS. We start with the basics.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your name', style: t.label),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            style: t.body,
            decoration: const InputDecoration(hintText: 'Shrujal'),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: c.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.activity, size: 18, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dense. Data-rich. Built for athletes — not generic wellness.',
                    style: t.body.copyWith(color: c.accent, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPhase extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StepPhase({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return _StepShell(
      overline: 'STEP 2 OF 5',
      title: "What's your phase?",
      subtitle:
          'Drives how your daily score weights each category. Change any time.',
      child: Column(
        children: [
          for (final entry in _phaseDescriptions.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.card),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(entry.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected == entry.key
                        ? c.accentSoft
                        : c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(
                      color: selected == entry.key ? c.accent : c.border,
                      width: selected == entry.key ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key,
                                style: t.bodyStrong.copyWith(
                                  color: selected == entry.key
                                      ? c.accent
                                      : c.textPrimary,
                                )),
                            const SizedBox(height: 4),
                            Text(entry.value, style: t.meta),
                          ],
                        ),
                      ),
                      if (selected == entry.key)
                        Icon(LucideIcons.check, size: 16, color: c.accent),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  final TextEditingController heightCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController ageCtrl;
  final String gender;
  final String activity;
  final String goal;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onActivity;
  final ValueChanged<String> onGoal;

  const _StepBody({
    required this.heightCtrl,
    required this.weightCtrl,
    required this.ageCtrl,
    required this.gender,
    required this.activity,
    required this.goal,
    required this.onGender,
    required this.onActivity,
    required this.onGoal,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _StepShell(
      overline: 'STEP 3 OF 5',
      title: 'Your body.',
      subtitle: 'Used to compute calorie and protein targets.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Height',
                  hint: '180',
                  suffix: 'cm',
                  controller: heightCtrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(
                  label: 'Weight',
                  hint: '78',
                  suffix: 'kg',
                  controller: weightCtrl,
                  decimal: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(
                  label: 'Age',
                  hint: '23',
                  controller: ageCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Gender', style: t.label),
          const SizedBox(height: 6),
          _SegRow(options: _genderLabels, selected: gender, onChanged: onGender),
          const SizedBox(height: 18),
          Text('Activity level', style: t.label),
          const SizedBox(height: 6),
          _StackOptions(
              options: _activityLabels, selected: activity, onChanged: onActivity),
          const SizedBox(height: 18),
          Text('Body goal', style: t.label),
          const SizedBox(height: 6),
          _SegRow(options: _goalLabels, selected: goal, onChanged: onGoal),
        ],
      ),
    );
  }
}

class _StepTargets extends StatefulWidget {
  final TextEditingController kcalCtrl;
  final TextEditingController proteinCtrl;
  final ({int kcal, int protein})? recommendation;
  final VoidCallback onTouched;

  const _StepTargets({
    required this.kcalCtrl,
    required this.proteinCtrl,
    required this.recommendation,
    required this.onTouched,
  });

  @override
  State<_StepTargets> createState() => _StepTargetsState();
}

class _StepTargetsState extends State<_StepTargets> {
  @override
  void initState() {
    super.initState();
    final rec = widget.recommendation;
    if (rec != null) {
      if (widget.kcalCtrl.text.isEmpty) {
        widget.kcalCtrl.text = rec.kcal.toString();
      }
      if (widget.proteinCtrl.text.isEmpty) {
        widget.proteinCtrl.text = rec.protein.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final rec = widget.recommendation;
    return _StepShell(
      overline: 'STEP 4 OF 5',
      title: 'Daily targets.',
      subtitle: rec != null
          ? 'Based on your inputs — edit if you have a tighter plan.'
          : 'Tap to set custom daily targets.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rec != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: c.accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.flame, size: 16, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recommended: ${rec.kcal} kcal · ${rec.protein} g protein',
                      style: t.body.copyWith(color: c.accent),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _LabeledField(
            label: 'Calories',
            hint: '3000',
            suffix: 'kcal',
            controller: widget.kcalCtrl,
            onChanged: widget.onTouched,
          ),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'Protein',
            hint: '180',
            suffix: 'g',
            controller: widget.proteinCtrl,
            onChanged: widget.onTouched,
          ),
        ],
      ),
    );
  }
}

class _StepHabits extends StatelessWidget {
  final Set<String> picked;
  final ValueChanged<String> onToggle;
  const _StepHabits({required this.picked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final groups = <HabitSection, List<HabitTemplate>>{
      for (final s in HabitSection.values)
        s: kStarterTemplates.where((tpl) => tpl.section == s).toList(),
    };
    String label(HabitSection s) =>
        s.name[0].toUpperCase() + s.name.substring(1);

    return _StepShell(
      overline: 'STEP 5 OF 5',
      title: 'Pick a few starters.',
      subtitle:
          'Tap any to add them to your day. You can always add or remove later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in HabitSection.values) ...[
            Text(label(s).toUpperCase(),
                style: t.label.copyWith(letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tpl in groups[s] ?? const <HabitTemplate>[])
                  _HabitChip(
                    template: tpl,
                    selected: picked.contains(tpl.id),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onToggle(tpl.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Text('${picked.length} selected',
              style: t.meta.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

class _HabitChip extends StatelessWidget {
  final HabitTemplate template;
  final bool selected;
  final VoidCallback onTap;
  const _HabitChip({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(
            color: selected ? c.accent : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? LucideIcons.check : LucideIcons.plus,
              size: 13,
              color: selected ? c.accent : c.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              template.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? c.accent : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? suffix;
  final TextEditingController controller;
  final bool decimal;
  final VoidCallback? onChanged;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.decimal = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged == null ? null : (_) => onChanged!(),
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          style: t.body,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
          ),
        ),
      ],
    );
  }
}

class _SegRow extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _SegRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: options.entries.map((entry) {
        final active = entry.key == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(entry.key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: active ? c.accentSoft : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: active ? c.accent : c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? c.accent : c.textMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StackOptions extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _StackOptions({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) {
        final active = entry.key == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(entry.key);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? c.accentSoft : c.surface,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              border: Border.all(color: active ? c.accent : c.border),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? c.accent : c.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
