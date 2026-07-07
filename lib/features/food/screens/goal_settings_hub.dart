import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/nutrition_engine.dart';
import '../providers/food_providers.dart';
import 'goal_setting_screen.dart';
import 'goal_setup_flow.dart';

const _activityLabels = {
  'sedentary': 'Sedentary',
  'light': 'Light',
  'active': 'Active',
  'very_active': 'Very active',
  'athlete': 'Athlete',
};

/// Build a seeded [GoalSetupFlow] for the given user + chosen direction/activity.
GoalSetupFlow _flowForUser(
  AppUser u, {
  required String goal,
  required String activityKey,
}) {
  final prefs = u.nutritionPrefsRaw;
  final w = u.weightKg ?? 75;
  final tw = u.targetBodyWeight;
  final tl = u.timelineDays;
  double? initRate;
  if (tw != null && tl != null && tl > 0) {
    final delta = (tw - w).abs();
    if (delta >= 0.1) initRate = delta / (tl / 7);
  }
  return GoalSetupFlow(
    sex: bioSexFromKey(u.gender),
    age: u.age ?? 25,
    heightCm: u.heightCm ?? 175,
    currentKg: w,
    goal: goal,
    activity: activityFromKey(activityKey),
    proteinPlan: proteinPlanFromName(prefs?['protein_plan'] as String?) ??
        proteinPlanForGoalKey(goal),
    proteinPerKg: (prefs?['protein_per_kg'] as num?)?.toDouble(),
    fatPlan: fatPlanFromName(prefs?['fat_plan'] as String?) ?? FatPlan.balanced,
    fatPct: (prefs?['fat_pct'] as num?)?.toDouble(),
    initialTargetKg: tw,
    initialWeeklyRateKg: initRate,
    initialTimelineDays: tl,
    initialKcalOverride: u.kcalOverride,
    saveOnFinish: true,
    finishLabel: 'Save goal',
  );
}

/// The Goal Settings landing page — a clean hub of the user's weight, nutrition
/// and water goals, each summarised with a one-tap path into its own editor.
class GoalSettingsHub extends ConsumerWidget {
  const GoalSettingsHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final user = ref.watch(appUserProvider).valueOrNull;
    final targets = ref.watch(dailyTargetsProvider);
    final waterMl = ref.watch(waterTargetProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(title: const Text('Goal Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final goal = user.bodyWeightGoal;
    final plan = nutritionPlanForUser(user);
    final isMaintain = goal == 'maintain';
    final paceLine = isMaintain || plan == null
        ? 'Maintain weight'
        : '${plan.weeklyRateKg >= 0 ? 'Gain' : 'Lose'} '
            '${plan.weeklyRateKg.abs().toStringAsFixed(2)} kg / week';
    final goalWeight = user.targetBodyWeight;
    final glasses = (waterMl / 250).round();
    final planName = _planLabel(user.nutritionPrefsRaw?['protein_plan'] as String?);

    Future<void> openWeight() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WeightGoalEditor()),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Goal Settings')),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.screenH, 12, AppSpace.screenH, 32),
        children: [
          _HubCard(
            icon: LucideIcons.scale,
            iconColor: c.body,
            title: 'Weight Goal',
            onEdit: openWeight,
            rows: [
              _KV('Current weight',
                  user.weightKg != null ? '${user.weightKg!.toStringAsFixed(0)} kg' : '—'),
              _KV('Goal weight',
                  goalWeight != null && !isMaintain
                      ? '${goalWeight.toStringAsFixed(0)} kg'
                      : '—'),
              _KV('Pace', paceLine),
              _KV('Activity level', _activityLabels[user.activityLevel] ?? 'Active'),
            ],
          ),
          const SizedBox(height: 14),
          _HubCard(
            icon: LucideIcons.utensilsCrossed,
            iconColor: c.athletic,
            title: 'Nutrition Goal',
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GoalSettingScreen()),
            ),
            rows: [
              _KV('Daily calorie budget', '${targets.kcal.round()} kcal'),
              _KV(
                'Macros',
                'P ${targets.proteinG.round()} · C ${targets.carbsG.round()} · '
                    'F ${targets.fatG.round()} g',
              ),
              _KV('Protein plan', planName),
            ],
          ),
          const SizedBox(height: 14),
          _HubCard(
            icon: LucideIcons.droplet,
            iconColor: c.mind,
            title: 'Water Goal',
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WaterGoalEditor()),
            ),
            rows: [
              _KV('Daily water goal',
                  '$glasses glasses · ${(waterMl / 1000).toStringAsFixed(1)} L'),
              if (user.waterOverrideMl != null && user.waterOverrideMl! > 0)
                _KV('Source', 'Set by you')
              else
                _KV('Source', 'Recommended for you'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Your calories, macros, fibre and water are all calculated together '
            'from your body stats, goal and pace.',
            style: t.meta.copyWith(color: c.textMuted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _planLabel(String? key) => switch (key) {
        'general' => 'General',
        'balanced' => 'Balanced',
        'building' => 'Building',
        'cutting' => 'Cutting',
        'custom' => 'Custom',
        _ => 'Balanced',
      };
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onEdit;
  final List<_KV> rows;
  const _HubCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: t.h2)),
              PressScale(
                scale: 0.94,
                onTap: onEdit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text('Edit',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.onAccent,
                      )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final r in rows) r,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  const _KV(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: t.bodyStrong.copyWith(color: c.textSecondary)),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: t.bodyStrong.copyWith(color: c.textPrimary),
              textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

// ───────────────────────────── Weight editor ─────────────────────────

/// Lightweight pre-flow: choose goal direction + activity, then drop into the
/// premium target → pace → reveal flow (which saves everything in one go).
class WeightGoalEditor extends ConsumerStatefulWidget {
  const WeightGoalEditor({super.key});
  @override
  ConsumerState<WeightGoalEditor> createState() => _WeightGoalEditorState();
}

class _WeightGoalEditorState extends ConsumerState<WeightGoalEditor> {
  String _goal = 'gain';
  String _activity = 'active';
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    final u = ref.read(appUserProvider).valueOrNull;
    if (u == null) return;
    _loaded = true;
    _goal = u.bodyWeightGoal;
    _activity = u.activityLevel;
  }

  Future<void> _continue() async {
    final u = ref.read(appUserProvider).valueOrNull;
    if (u == null) return;
    HapticFeedback.selectionClick();
    // Build the flow with the *currently chosen* direction + activity so it
    // persists them on save.
    final base = _flowForUser(u, goal: _goal, activityKey: _activity);
    final result = await Navigator.of(context).push<GoalSetupResult>(
      MaterialPageRoute(builder: (_) => base),
    );
    if (result != null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    _load();
    final c = context.c;
    final t = context.t;
    final u = ref.watch(appUserProvider).valueOrNull;
    final isMaintain = _goal == 'maintain';
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Weight Goal')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 12, AppSpace.screenH, 24),
                children: [
                  _EditorCard(
                    title: 'What do you want to do?',
                    child: _Seg(
                      value: _goal,
                      options: const ['lose', 'maintain', 'gain'],
                      labels: const ['Lose weight', 'Maintain', 'Gain weight'],
                      onChanged: (v) => setState(() => _goal = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EditorCard(
                    title: 'How active are you?',
                    subtitle:
                        'Be honest — this sets the calories you burn at rest + daily life.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in _activityLabels.entries)
                          _Pill(
                            label: e.value,
                            active: _activity == e.key,
                            onTap: () => setState(() => _activity = e.key),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: c.border, width: 0.5),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.scale, size: 17, color: c.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Current weight ${u?.weightKg != null ? '${u!.weightKg!.toStringAsFixed(0)} kg' : 'not set'} — '
                            'update it from the Body tab.',
                            style: t.meta.copyWith(color: c.textMuted, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                  label: isMaintain ? 'See my targets' : 'Set target & pace',
                  icon: LucideIcons.arrowRight,
                  onPressed: u == null ? null : _continue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Water editor ──────────────────────────

class WaterGoalEditor extends ConsumerStatefulWidget {
  const WaterGoalEditor({super.key});
  @override
  ConsumerState<WaterGoalEditor> createState() => _WaterGoalEditorState();
}

class _WaterGoalEditorState extends ConsumerState<WaterGoalEditor> {
  static const _mlPerGlass = 250;
  int? _glasses;
  bool _saving = false;

  int _recommendedGlasses(AppUser u) {
    final rec = nutritionPlanForUser(u)?.waterMl ?? u.waterTargetMl;
    return (rec / _mlPerGlass).round().clamp(4, 25);
  }

  Future<void> _save() async {
    final u = ref.read(appUserProvider).valueOrNull;
    if (u == null || _glasses == null) return;
    setState(() => _saving = true);
    try {
      final uid = SupabaseService.auth.currentUser!.id;
      final ml = _glasses! * _mlPerGlass;
      final prefs = <String, dynamic>{...?u.nutritionPrefsRaw};
      final usingRecommended = _glasses == _recommendedGlasses(u);
      if (usingRecommended) {
        prefs.remove('water_override_ml');
      } else {
        prefs['water_override_ml'] = ml;
      }
      await SupabaseService.client.from('users').update({
        'nutrition_prefs': prefs,
        'water_target_ml': ml,
      }).eq('id', uid);
      ref.invalidate(appUserProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Water goal updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final u = ref.watch(appUserProvider).valueOrNull;
    if (u == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(title: const Text('Water Goal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final rec = _recommendedGlasses(u);
    final int currentMl = u.waterOverrideMl ?? ref.read(waterTargetProvider);
    _glasses ??= (currentMl / _mlPerGlass).round().clamp(4, 25);
    final glasses = _glasses!;
    final liters = glasses * _mlPerGlass / 1000;

    void step(int by) {
      HapticFeedback.selectionClick();
      setState(() => _glasses = (glasses + by).clamp(4, 25));
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Water Goal')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 24, AppSpace.screenH, 24),
                children: [
                  Center(
                    child: Icon(LucideIcons.droplet, size: 40, color: c.mind),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundBtn(icon: LucideIcons.minus, onTap: () => step(-1)),
                      const SizedBox(width: 28),
                      Column(
                        children: [
                          Text('$glasses',
                              style: AppType.display
                                  .copyWith(color: c.textPrimary, fontSize: 64)),
                          Text('glasses',
                              style: t.h2.copyWith(color: c.textMuted)),
                        ],
                      ),
                      const SizedBox(width: 28),
                      _RoundBtn(icon: LucideIcons.plus, onTap: () => step(1)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      '≈ ${liters.toStringAsFixed(2)} L · 1 glass = 250 ml',
                      style: t.body.copyWith(color: c.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (glasses != rec)
                    Center(
                      child: PressScale(
                        scale: 0.97,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _glasses = rec);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: c.borderStrong),
                          ),
                          child: Text('Use recommended ($rec glasses)',
                              style: t.bodyStrong.copyWith(color: c.accent)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
                  label: 'Save water goal',
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
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.9,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.borderStrong),
          boxShadow: AppShadows.card,
        ),
        child: Icon(icon, size: 22, color: c.textPrimary),
      ),
    );
  }
}

// ── Small shared editor primitives ────────────────────────────────────

class _EditorCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _EditorCard({required this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.bodyStrong.copyWith(color: c.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: t.meta.copyWith(color: c.textMuted, height: 1.35)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String value;
  final List<String> options;
  final List<String> labels;
  final ValueChanged<String> onChanged;
  const _Seg({
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          PressScale(
            scale: 0.98,
            onTap: () => onChanged(options[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: value == options[i] ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(
                  color: value == options[i] ? c.accent : c.border,
                  width: value == options[i] ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    value == options[i]
                        ? LucideIcons.checkCircle2
                        : LucideIcons.circle,
                    size: 18,
                    color: value == options[i]
                        ? c.onAccent
                        : c.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight:
                          value == options[i] ? FontWeight.w700 : FontWeight.w600,
                      color: value == options[i] ? c.onAccent : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: active ? c.accent : c.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? c.onAccent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
