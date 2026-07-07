import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_prefs_provider.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_plan.dart';
import '../providers/food_providers.dart';

/// The "Meals" editor — your daily meal schedule. Each meal can be turned on or
/// off, renamed, given a time, and set to Auto (a share of your daily calories)
/// or a Fixed amount. The per-meal calories always reconcile to your daily goal.
class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MealsScreen()),
      );

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  MealPlan? _plan;
  bool _saving = false;

  MealPlan get _p => _plan!;

  void _load() {
    _plan ??= ref.read(mealPlanProvider);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notif = ref.read(notificationPrefsProvider);
      final slots = <MealTimeSlot, String?>{
        for (final e in _p.ordered) e.slot: e.time,
      };
      await ref.read(userActionsProvider.notifier).update({
        // Names + on/off + fixed kcal live here.
        'meal_calorie_targets': _p.toMealTargetsJson(),
        // Meal times are the meal reminders — one source.
        'notification_prefs':
            notif.copyWith(meals: notif.meals.copyWith(slots: slots)).toJson(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meals updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnack(context, e);
    }
  }

  void _resetToDefaults() {
    final goal = ref.read(appUserProvider).valueOrNull?.bodyWeightGoal ?? 'maintain';
    final times = ref.read(notificationPrefsProvider).meals.slots;
    HapticFeedback.selectionClick();
    setState(() => _plan = MealPlan.forGoal(goal, times: times));
  }

  Future<void> _editMeal(MealPlanEntry entry) async {
    final result = await showModalBottomSheet<MealPlanEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.c.background,
      builder: (_) => _MealEditSheet(entry: entry),
    );
    if (result != null) setState(() => _plan = _p.withEntry(result));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    _load();
    final goalKcal = ref.watch(dailyTargetsProvider).kcal.round();
    final resolved = _p.resolveKcal(goalKcal);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Meals'),
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: Text('Reset',
                style: context.t.bodyStrong.copyWith(color: c.accent)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _ReconcileBar(plan: _p, goalKcal: goalKcal, resolved: resolved),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 12, AppSpace.screenH, 24),
                children: [
                  for (final e in _p.ordered) ...[
                    _MealCard(
                      entry: e,
                      kcal: resolved[e.slot],
                      onTap: () => _editMeal(e),
                      onToggle: (on) => setState(
                          () => _plan = _p.withEntry(e.copyWith(enabled: on))),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Auto meals share whatever calories aren’t pinned to a '
                    'Fixed meal, so your day always adds up to your goal.',
                    style: context.t.meta.copyWith(color: c.textMuted, height: 1.4),
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
                  label: 'Save meals',
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

/// Live reconciliation header — total assigned vs the daily goal, with a
/// segmented bar of each enabled meal's share.
class _ReconcileBar extends StatelessWidget {
  final MealPlan plan;
  final int goalKcal;
  final Map<MealTimeSlot, int> resolved;
  const _ReconcileBar(
      {required this.plan, required this.goalKcal, required this.resolved});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final assigned = plan.assignedTotal(goalKcal);
    final over = assigned > goalKcal;
    final n = plan.enabledMeals.length;
    final segColors = [c.accent, c.athletic, c.positive, c.mind, c.body, c.amber];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screenH, 12, AppSpace.screenH, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$assigned', style: t.numLg),
              const SizedBox(width: 5),
              Text('/ $goalKcal kcal',
                  style: t.bodyStrong.copyWith(color: c.textMuted)),
              const Spacer(),
              Text('$n ${n == 1 ? 'meal' : 'meals'}',
                  style: t.meta.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                for (final (i, e) in plan.enabledMeals.indexed)
                  Expanded(
                    flex: ((resolved[e.slot] ?? 0)).clamp(1, 100000),
                    child: Container(
                        height: 10,
                        color: segColors[i % segColors.length]),
                  ),
                if (plan.enabledMeals.isEmpty)
                  Expanded(child: Container(height: 10, color: c.border)),
              ],
            ),
          ),
          if (over) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.alertTriangle, size: 13, color: c.accent),
                const SizedBox(width: 6),
                Text(
                  'Fixed meals total ${assigned - goalKcal} kcal over your goal.',
                  style: t.meta.copyWith(color: c.accent),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealPlanEntry entry;
  final int? kcal;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  const _MealCard({
    required this.entry,
    required this.kcal,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final on = entry.enabled;
    final timeLabel = entry.time ?? 'No reminder';
    return PressScale(
      scale: 0.99,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.accent.withValues(alpha: 0.10) : c.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.utensils,
                  size: 17, color: on ? c.accent : c.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: t.bodyStrong.copyWith(
                        color: on ? c.textPrimary : c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 12, color: c.textMuted),
                      const SizedBox(width: 4),
                      Text(timeLabel,
                          style: t.meta.copyWith(color: c.textMuted)),
                      if (on) ...[
                        const SizedBox(width: 8),
                        _Pill(
                          label: entry.isAuto ? 'Auto' : 'Fixed',
                          color: entry.isAuto ? c.textSecondary : c.athletic,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (on)
              Text('${kcal ?? 0}',
                  style: AppType.numMd.copyWith(color: c.textPrimary)),
            if (on)
              Text(' kcal', style: t.meta.copyWith(color: c.textMuted)),
            const SizedBox(width: 4),
            Switch(
              value: on,
              activeThumbColor: c.onAccent,
              activeTrackColor: c.accent,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onToggle(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}

/// Bottom sheet to edit a single meal.
class _MealEditSheet extends StatefulWidget {
  final MealPlanEntry entry;
  const _MealEditSheet({required this.entry});
  @override
  State<_MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends State<_MealEditSheet> {
  late MealPlanEntry _e;
  late final TextEditingController _name;
  late final TextEditingController _kcal;

  @override
  void initState() {
    super.initState();
    _e = widget.entry;
    _name = TextEditingController(text: _e.customName ?? '');
    _kcal = TextEditingController(text: _e.fixedKcal?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = (_e.time ?? '08:00').split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() => _e = _e.copyWith(time: '$hh:$mm'));
    }
  }

  void _done() {
    final name = _name.text.trim();
    final fixed = _e.isAuto ? null : (int.tryParse(_kcal.text.trim()));
    Navigator.pop(
      context,
      _e.copyWith(
        customName: name.isEmpty ? null : name,
        clearName: name.isEmpty,
        fixedKcal: _e.isAuto ? null : (fixed != null && fixed > 0 ? fixed : null),
        clearFixed: _e.isAuto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpace.screenH, 14, AppSpace.screenH,
          18 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(_e.name, style: t.h2),
          const SizedBox(height: 16),

          _label('Name'),
          const SizedBox(height: 6),
          _field(_name, hint: widget.entry.slot.label),
          const SizedBox(height: 16),

          _label('Reminder time'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  scale: 0.98,
                  onTap: _pickTime,
                  child: Container(
                    height: 50,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock, size: 16, color: c.textSecondary),
                        const SizedBox(width: 10),
                        Text(_e.time ?? 'No reminder',
                            style: t.body.copyWith(
                                color: _e.time != null
                                    ? c.textPrimary
                                    : c.textDim,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              if (_e.time != null) ...[
                const SizedBox(width: 8),
                PressScale(
                  scale: 0.92,
                  onTap: () => setState(() => _e = _e.copyWith(clearTime: true)),
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Icon(LucideIcons.bellOff, size: 17, color: c.textSecondary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          _label('Calories'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _modeChip('Auto', _e.isAuto,
                    () => setState(() => _e = _e.copyWith(clearFixed: true))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeChip('Fixed', !_e.isAuto, () {
                  final v = int.tryParse(_kcal.text.trim()) ?? 500;
                  setState(() => _e = _e.copyWith(fixedKcal: v));
                }),
              ),
            ],
          ),
          if (!_e.isAuto) ...[
            const SizedBox(height: 10),
            _field(_kcal, hint: '500', suffix: 'kcal', number: true),
          ] else ...[
            const SizedBox(height: 8),
            Text('Auto: a share of your daily goal.',
                style: t.meta.copyWith(color: c.textMuted)),
          ],
          const SizedBox(height: 20),
          AtlasButton(label: 'Done', onPressed: _done),
        ],
      ),
    );
  }

  Widget _label(String s) => Text(s,
      style: context.t.label.copyWith(
          color: context.c.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1));

  Widget _field(TextEditingController ctrl,
      {String? hint, String? suffix, bool number = false}) {
    final c = context.c;
    final t = context.t;
    return TextField(
      controller: ctrl,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: t.body.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: t.body.copyWith(color: c.textDim, fontWeight: FontWeight.w400),
        suffixText: suffix,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          borderSide: BorderSide(color: c.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          borderSide: BorderSide(color: c.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) {
    final c = context.c;
    return PressScale(
      scale: 0.97,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
              color: active ? c.accent : c.border, width: active ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? c.onAccent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
