part of 'settings_screen.dart';

/// Personal info — profile, body, and daily targets. Lives under the Me hub
/// at `/me/about`. A `part of settings_screen.dart` so it reuses the same list
/// primitives (`_Card`, `_Row`, `_NumRow`, …) and edit sheets.
class AboutMeScreen extends ConsumerWidget {
  const AboutMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final userAsync = ref.watch(appUserProvider);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('About me', style: context.t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: userAsync.when(
          data: (u) => _AboutBody(user: u),
          loading: () => Center(
            child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Text(friendlyError(e),
                style: TextStyle(color: c.negative, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

class _AboutBody extends ConsumerWidget {
  final AppUser? user;
  const _AboutBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;

    Future<void> patch(Map<String, dynamic> data) =>
        ref.read(userActionsProvider.notifier).update(data);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screenH, 8, AppSpace.screenH, 118),
      children: [
        // ─── Profile ──────────────────────────────────────────
        _SectionLabel('Profile'),
        const SizedBox(height: 8),
        _Card(children: [
          _Row(
            label: 'Name',
            value: u?.name ?? '—',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Your name', initial: u?.name ?? '');
              if (v != null && v.isNotEmpty) await patch({'name': v});
            },
          ),
          _Divider(),
          _Row(
            label: 'Focus',
            value: ref.watch(focusConfigProvider).summary,
            onTap: () => FocusScreen.open(context),
          ),
        ]),
        const SizedBox(height: 22),

        // ─── Body ─────────────────────────────────────────────
        _SectionLabel('Body'),
        const SizedBox(height: 8),
        _Card(children: [
          _Row(
            label: 'Height',
            value: u?.heightCm == null
                ? 'Set'
                : '${u!.heightCm!.toStringAsFixed(0)} cm',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Height',
                  initial: u?.heightCm?.toStringAsFixed(0) ?? '',
                  hint: '180',
                  suffix: 'cm',
                  keyboardType: TextInputType.number);
              if (v != null && v.isNotEmpty) {
                await patch({'height_cm': double.tryParse(v)});
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Weight',
            value: u?.weightKg == null
                ? 'Set'
                : '${u!.weightKg!.toStringAsFixed(1)} kg',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Weight',
                  initial: u?.weightKg?.toStringAsFixed(1) ?? '',
                  hint: '78',
                  suffix: 'kg',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true));
              final kg = v == null ? null : double.tryParse(v);
              if (kg != null && kg > 0) {
                // One weight everywhere: update the engine-driving profile
                // weight AND today's history point on the Body-tab graph.
                await patch({'weight_kg': kg});
                await recordWeightHistoryPoint(ref, kg);
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Age',
            value: u?.age?.toString() ?? 'Set',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Age',
                  initial: u?.age?.toString() ?? '',
                  hint: '23',
                  keyboardType: TextInputType.number);
              if (v != null && v.isNotEmpty) {
                await patch({'age': int.tryParse(v)});
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Gender',
            value: _genderOptions[u?.gender] ?? '—',
            onTap: () async {
              final v = await showSelectSheet(context,
                  title: 'Gender',
                  options: _genderOptions,
                  initial: u?.gender);
              if (v != null) await patch({'gender': v});
            },
          ),
          _Divider(),
          _Row(
            label: 'Activity level',
            value: _activityOptions[u?.activityLevel] ?? '—',
            onTap: () async {
              final v = await showSelectSheet(context,
                  title: 'Activity level',
                  options: _activityOptions,
                  initial: u?.activityLevel);
              if (v != null) await patch({'activity_level': v});
            },
          ),
        ]),
        const SizedBox(height: 22),

        // ─── Nutrition goals ──────────────────────────────────
        // Single engine-driven editor. Targets are computed from your goal +
        // body + activity, not typed in raw — so they always tell one story.
        _SectionLabel('Nutrition goals'),
        const SizedBox(height: 8),
        _NutritionGoalsTile(
          user: u,
          targets: ref.watch(dailyTargetsProvider),
        ),
        const SizedBox(height: 10),
        _Card(children: [
          _Row(
            label: 'Meals',
            value: '${ref.watch(mealPlanProvider).enabledMeals.length} meals',
            onTap: () => MealsScreen.open(context),
          ),
        ]),
      ],
    );
  }
}

/// Live nutrition-goal summary (engine-computed) that opens the full goal
/// editor. Replaces the old raw per-macro number rows, which let you type
/// values that contradicted the recommendation engine.
class _NutritionGoalsTile extends StatelessWidget {
  final AppUser? user;
  final DailyTargets targets;
  const _NutritionGoalsTile({required this.user, required this.targets});

  String get _goalLine {
    final goal = user?.bodyWeightGoal ?? 'maintain';
    final tw = user?.targetBodyWeight;
    return switch (goal) {
      'gain' =>
        tw != null ? 'Gaining to ${tw.toStringAsFixed(0)} kg' : 'Gaining mass',
      'lose' =>
        tw != null ? 'Leaning to ${tw.toStringAsFixed(0)} kg' : 'Leaning down',
      _ => 'Maintaining weight',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final waterL = (user?.waterTargetMl ?? 0) / 1000;
    return PressScale(
      scale: 0.985,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalSettingsHub()),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_goalLine, style: t.bodyStrong),
                      const SizedBox(height: 2),
                      Text('Tap to adjust goal, pace, macros & calories',
                          style: t.meta.copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: c.border),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${targets.kcal.round()}', style: t.numLg),
                const SizedBox(width: 5),
                Text('kcal / day',
                    style: t.bodyStrong.copyWith(color: c.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _GoalMacro(label: 'Protein', value: '${targets.proteinG.round()}g'),
                _GoalMacro(label: 'Carbs', value: '${targets.carbsG.round()}g'),
                _GoalMacro(label: 'Fat', value: '${targets.fatG.round()}g'),
                _GoalMacro(
                    label: 'Water', value: '${waterL.toStringAsFixed(1)}L'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalMacro extends StatelessWidget {
  final String label;
  final String value;
  const _GoalMacro({required this.label, required this.value});

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
          Text(label.toUpperCase(),
              style: t.meta.copyWith(color: c.textMuted, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}
