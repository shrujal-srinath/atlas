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
            label: 'Phase',
            value: u?.currentPhase ?? '—',
            onTap: () async {
              final v = await showSelectSheet(context,
                  title: 'Training phase',
                  options: _phaseOptions,
                  initial: u?.currentPhase);
              if (v != null && v != u?.currentPhase) {
                await patch({'current_phase': v});
                await recordPhaseChange(ref, v);
              }
            },
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
              if (v != null && v.isNotEmpty) {
                await patch({'weight_kg': double.tryParse(v)});
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

        // ─── Daily targets ────────────────────────────────────
        _SectionLabel('Daily targets'),
        const SizedBox(height: 8),
        _Card(children: [
          _NumRow(
            label: 'Calories',
            unit: 'kcal',
            value: u?.dailyCalorieTarget,
            onSaved: (v) => patch({'daily_calorie_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Protein',
            unit: 'g',
            value: u?.dailyProteinTarget,
            onSaved: (v) => patch({'daily_protein_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Carbs',
            unit: 'g',
            value: u?.dailyCarbsTarget,
            onSaved: (v) => patch({'daily_carbs_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Fat',
            unit: 'g',
            value: u?.dailyFatTarget,
            onSaved: (v) => patch({'daily_fat_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Fiber',
            unit: 'g',
            value: u?.dailyFiberTarget,
            onSaved: (v) => patch({'daily_fiber_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Water',
            unit: 'ml',
            value: u?.waterTargetMl,
            onSaved: (v) => patch({'water_target_ml': v}),
          ),
        ]),
      ],
    );
  }
}
