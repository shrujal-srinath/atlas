import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/atlas_controls.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../food/domain/nutrition_engine.dart';
import '../food/providers/weight_providers.dart';
import '../food/screens/goal_setup_flow.dart';
import '../home/scoring/focus.dart';
import '../phase/phase_provider.dart';
import 'habit_guide.dart';

const _genderLabels = {'male': 'Male', 'female': 'Female', 'other': 'Other'};

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
  FocusConfig _focus = FocusConfig.defaults.copyWith(
    personaKey: 'athlete',
    phaseKey: 'rehab_bulk',
  );
  String _gender = 'male';
  String _activity = 'active';
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  // Outcome of the target → pace → calorie reveal flow (opened after the body
  // step). Remembered so re-entering the flow restores the user's choices, and
  // so `_submit` persists exactly what the reveal showed.
  GoalSetupResult? _goalResult;
  bool _submitting = false;

  // Lightweight, auto-dismissing guidance for new users — one calm tip per step
  // (shown once), plus a contextual nudge when calories can't be computed yet.
  String? _hint;
  Timer? _hintTimer;
  final Set<int> _tippedSteps = {};

  static const _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null && user.name.isNotEmpty) _nameCtrl.text = user.name;
    // Surface the first step's tip once the screen settles.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTipForStep(0));
  }

  // ── Guided hints ──────────────────────────────────────────────────────
  /// Show a calm hint that fades itself out after a few seconds.
  void _showHint(String msg) {
    _hintTimer?.cancel();
    setState(() => _hint = msg);
    _hintTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  void _clearHint() {
    _hintTimer?.cancel();
    if (mounted) setState(() => _hint = null);
  }

  /// The one-line tip for a step — nothing prescriptive, just orientation.
  String _tipForStep(int step) => switch (step) {
        0 => 'Tell us what to call you — a first name is plenty.',
        1 => 'Pick what matters most right now. You can change it anytime.',
        2 =>
          'Add your height, weight & age to unlock your calorie & protein targets.',
        _ => '',
      };

  /// Show a step's tip only the first time the user lands on it this session.
  void _maybeTipForStep(int step) {
    if (!mounted || _tippedSteps.contains(step)) return;
    _tippedSteps.add(step);
    final tip = _tipForStep(step);
    if (tip.isNotEmpty) _showHint(tip);
  }

  bool _bodyComplete() =>
      _height != null && _weight != null && _age != null;

  @override
  void dispose() {
    _hintTimer?.cancel();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  // Bounded so an out-of-range value (a mistyped extra digit, a paste, a
  // stress-test) reads as "not entered yet" rather than silently flowing into
  // the BMR formula, which goes negative for extreme ages.
  int? get _height {
    final v = int.tryParse(_heightCtrl.text);
    return (v == null || v < 50 || v > 300) ? null : v;
  }

  double? get _weight {
    final v = double.tryParse(_weightCtrl.text);
    return (v == null || v < 20 || v > 400) ? null : v;
  }

  int? get _age {
    final v = int.tryParse(_ageCtrl.text);
    return (v == null || v < 10 || v > 120) ? null : v;
  }

  bool _canAdvance() {
    return switch (_step) {
      0 => _nameCtrl.text.trim().isNotEmpty,
      2 => _height != null && _weight != null && _age != null,
      _ => true,
    };
  }

  /// Names the specific reason `_canAdvance()` is blocked, for the step-2
  /// body form where "just buzz" leaves the user guessing which field (or
  /// which value) is the problem.
  String? _blockedReason() {
    if (_step != 2) return null;
    if (_heightCtrl.text.trim().isEmpty ||
        _weightCtrl.text.trim().isEmpty ||
        _ageCtrl.text.trim().isEmpty) {
      return 'Enter your height, weight, and age to continue.';
    }
    if (_height == null) return 'Enter a height between 50–300 cm.';
    if (_weight == null) return 'Enter a weight between 20–400 kg.';
    if (_age == null) return 'Enter an age between 10–120.';
    return null;
  }

  Future<void> _next() async {
    if (!_canAdvance()) {
      HapticFeedback.heavyImpact();
      final reason = _blockedReason();
      if (reason != null) showSnack(context, reason, isError: true);
      return;
    }
    // The body step is the last one we manage here: its Continue opens the
    // dedicated target → pace → calorie reveal flow, which finishes onboarding.
    if (_step == 2) {
      await _runGoalFlow();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _step++);
    _maybeTipForStep(_step);
    await _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Push the full-screen goal-setup flow (direction inferred from the target
  /// weight). On finish it returns the resolved plan; we persist the whole
  /// profile in one go and land on home — there is no further step.
  Future<void> _runGoalFlow() async {
    HapticFeedback.selectionClick();
    final seed = _goalResult;
    final name = _nameCtrl.text.trim();
    final result = await Navigator.of(context).push<GoalSetupResult>(
      MaterialPageRoute(
        builder: (_) => GoalSetupFlow(
          sex: bioSexFromKey(_gender),
          age: _age ?? 25,
          heightCm: _height?.toDouble() ?? 175,
          currentKg: _weight ?? 75,
          goal: 'maintain', // ignored — direction is inferred from the target
          inferGoalFromTarget: true,
          name: name.isEmpty ? null : name,
          activity: activityFromKey(_activity),
          initialTargetKg: seed?.targetKg,
          initialWeeklyRateKg: seed?.weeklyRateKg.abs(),
          initialTimelineDays: (seed?.timelineDays ?? 0) > 0
              ? seed!.timelineDays
              : null,
          initialKcalOverride: seed?.kcalOverride,
          saveOnFinish: false,
          finishLabel: 'Get started',
          onComplete: (r) => Navigator.of(context).pop(r),
        ),
      ),
    );
    if (result == null || !mounted) return; // backed out — stay on body step
    _goalResult = result;
    await _submit(result);
  }

  Future<void> _back() async {
    if (_step == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _step--);
    _maybeTipForStep(_step);
    await _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Persist the full profile from the resolved goal flow [result] and land on
  /// home. The flow already computed the engine plan, so stored targets and the
  /// reveal the user just saw are guaranteed to agree.
  Future<void> _submit(GoalSetupResult result) async {
    setState(() => _submitting = true);
    final session = ref.read(sessionProvider);
    final uid = session?.user.id;
    if (uid == null) {
      setState(() => _submitting = false);
      return;
    }

    try {
      final plan = result.plan;
      final isMaintain = result.goal == 'maintain';
      final phaseLabel =
          phaseByKey(_focus.personaKey, _focus.phaseKey)?.label ??
          _focus.summary;
      final update = SupabaseService.client
          .from('users')
          .update({
            'name': _nameCtrl.text.trim(),
            'current_phase': phaseLabel,
            // The Focus config is the single source the daily score weights from.
            'section_weights': _focus.toJson(),
            'gender': _gender,
            'activity_level': _activity,
            'body_weight_goal': result.goal,
            if (_height != null) 'height_cm': _height,
            if (_weight != null) 'weight_kg': _weight,
            if (_age != null) 'age': _age,
            if (!isMaintain) 'target_body_weight': result.targetKg,
            'daily_calorie_target': plan.kcal,
            'daily_protein_target': plan.proteinG,
            'daily_carbs_target': plan.carbsG,
            'daily_fat_target': plan.fatG,
            'daily_fiber_target': plan.fiberG,
            'water_target_ml': plan.waterMl,
            'nutrition_prefs': {
              // Authoritative pace (drives the live engine) + timeline/display.
              if (!isMaintain) 'weekly_rate_kg': result.weeklyRateKg,
              if (!isMaintain && result.timelineDays > 0)
                'timeline_days': result.timelineDays,
              if (result.kcalOverride != null && result.kcalOverride! > 0)
                'kcal_override': result.kcalOverride,
            },
            'is_onboarded': true,
          })
          .eq('id', uid);

      // Seed the weight-history graph with the onboarding weight so the Body
      // tab and profile share one timeline from day one. Independent of the
      // profile write, so run them together.
      await Future.wait([
        update,
        if (_weight != null && _weight! > 0)
          recordWeightHistoryPoint(ref, _weight!),
      ]);

      ref.invalidate(appUserProvider);
      ref.invalidate(activePhaseProvider);

      // Arm the first-run "where do I make a habit?" coach-mark, shown once on
      // Home now that we no longer seed starter habits during onboarding.
      ref.read(habitGuideProvider.notifier).start();

      // Wait for the refreshed user row (is_onboarded = true) to land BEFORE we
      // navigate. Otherwise the router's onboarding gate reads the stale cached
      // value (Riverpod keeps the previous value during the reload) and bounces
      // straight back to /onboarding — the "first screens flash" on first entry.
      try {
        await ref.read(appUserProvider.future);
      } catch (_) {
        // A transient read failure shouldn't strand the user on onboarding —
        // the profile write already succeeded; the router listener will settle
        // the route once the row resolves.
      }

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
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
            _OnbHint(message: _hint, onDismiss: _clearHint),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _StepName(controller: _nameCtrl),
                  _StepFocus(
                    focus: _focus,
                    onChanged: (f) => setState(() => _focus = f),
                  ),
                  _StepBody(
                    heightCtrl: _heightCtrl,
                    weightCtrl: _weightCtrl,
                    ageCtrl: _ageCtrl,
                    gender: _gender,
                    activity: _activity,
                    onGender: (v) => setState(() => _gender = v),
                    onActivity: (v) {
                      setState(() => _activity = v);
                      // Calories can't be shown until the stats exist — nudge,
                      // gently, exactly when the user reaches for them.
                      if (!_bodyComplete()) {
                        _showHint(
                          'Add your height, weight & age above to see exact '
                          'calories for each level.',
                        );
                      }
                    },
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
                  if (_step > 0) ...[
                    PressScale(
                      scale: 0.96,
                      onTap: () {
                        if (!_submitting) _back();
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(AppRadii.button),
                          border: Border.all(color: c.borderStrong, width: 1),
                          boxShadow: AppShadows.card,
                        ),
                        child: Icon(
                          LucideIcons.arrowLeft,
                          size: 18,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: AtlasButton(
                      label: 'Continue',
                      loading: _submitting,
                      onPressed: _canAdvance() ? _next : null,
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

/// A calm, auto-dismissing guidance strip under the progress bar. Animates its
/// own height so it takes zero space when there's no hint. Deliberately quiet —
/// muted surface, small text, an info glyph — never a modal.
class _OnbHint extends StatelessWidget {
  final String? message;
  final VoidCallback onDismiss;
  const _OnbHint({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim,
            axisAlignment: -1,
            child: child,
          ),
        ),
        child: message == null
            ? const SizedBox(width: double.infinity, key: ValueKey('no-hint'))
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 8, AppSpace.screenH, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: c.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.info, size: 14, color: c.textMuted),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            message!,
                            style: t.meta.copyWith(
                              color: c.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(LucideIcons.x, size: 13, color: c.textDim),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressStrip({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screenH,
        16,
        AppSpace.screenH,
        0,
      ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screenH,
        24,
        AppSpace.screenH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline,
            style: t.label.copyWith(letterSpacing: 0.8, color: c.accent),
          ),
          const SizedBox(height: 6),
          Text(title, style: t.h1),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: t.body.copyWith(color: c.textMuted, height: 1.4),
            ),
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
      overline: 'STEP 1 OF 3',
      title: 'Welcome.',
      subtitle:
          'STRIDE is your personal performance OS. We start with the basics.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your name', style: _onbLabel(context)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: t.body.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(hintText: 'e.g. Shrujal'),
          ),
          const SizedBox(height: 22),
          // A single brand "pull" card. Icon carries the accent; the message
          // stays high-contrast (textSecondary) so it reads cleanly — never
          // accent text on an accent tint (house rule 1).
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: c.accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Icon(
                    LucideIcons.activity,
                    size: 18,
                    color: c.onAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dense. Data-rich. Built for athletes — not generic wellness.',
                    style: t.bodyStrong.copyWith(
                      color: c.textSecondary,
                      height: 1.35,
                    ),
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

/// Pick your Focus — persona then phase. Drives how the daily score is
/// weighted; fully adjustable later (incl. Custom / Off) in Me → Focus.
class _StepFocus extends StatelessWidget {
  final FocusConfig focus;
  final ValueChanged<FocusConfig> onChanged;
  const _StepFocus({required this.focus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final persona = personaByKey(focus.personaKey) ?? kPersonas.first;
    return _StepShell(
      overline: 'STEP 2 OF 3',
      title: "What's your focus?",
      subtitle:
          'Sets how your daily score weights each area. Fine-tune any time.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('I am a…', style: _onbLabel(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in kPersonas)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(
                      focus.copyWith(
                        personaKey: p.key,
                        phaseKey: p.phases.first.key,
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: p.key == focus.personaKey ? c.accent : c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: p.key == focus.personaKey ? c.accent : c.border,
                        width: p.key == focus.personaKey ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: p.key == focus.personaKey
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: p.key == focus.personaKey
                            ? c.onAccent
                            : c.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Phase', style: _onbLabel(context)),
          const SizedBox(height: 8),
          for (final ph in persona.phases)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(focus.copyWith(phaseKey: ph.key));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(
                      color: ph.key == focus.phaseKey ? c.accent : c.border,
                      width: ph.key == focus.phaseKey ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ph.label, style: t.bodyStrong),
                            const SizedBox(height: 4),
                            Text(ph.blurb, style: t.meta),
                          ],
                        ),
                      ),
                      Icon(
                        ph.key == focus.phaseKey
                            ? LucideIcons.checkCircle2
                            : LucideIcons.circle,
                        size: 18,
                        color: ph.key == focus.phaseKey
                            ? c.accent
                            : c.textMuted,
                      ),
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

/// Plain-language activity options: (key, label, descriptor). Keys match
/// `activityFromKey` so the engine and form stay in lockstep.
const _activityCards = <(String, String, String)>[
  ('sedentary', 'Sedentary', 'Desk job · little exercise'),
  ('light', 'Lightly active', 'Light exercise 1–3×/week'),
  ('active', 'Active', 'Moderate exercise 4–5×/week'),
  ('very_active', 'Very active', 'Hard exercise 6–7×/week'),
  ('athlete', 'Athlete', 'Training 2× a day · physical job'),
];

class _StepBody extends StatefulWidget {
  final TextEditingController heightCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController ageCtrl;
  final String gender;
  final String activity;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onActivity;

  const _StepBody({
    required this.heightCtrl,
    required this.weightCtrl,
    required this.ageCtrl,
    required this.gender,
    required this.activity,
    required this.onGender,
    required this.onActivity,
  });

  @override
  State<_StepBody> createState() => _StepBodyState();
}

class _StepBodyState extends State<_StepBody> {
  @override
  void initState() {
    super.initState();
    // Live BMI + maintenance-calorie feedback as the user types.
    widget.heightCtrl.addListener(_onChanged);
    widget.weightCtrl.addListener(_onChanged);
    widget.ageCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.heightCtrl.removeListener(_onChanged);
    widget.weightCtrl.removeListener(_onChanged);
    widget.ageCtrl.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int? get _height => int.tryParse(widget.heightCtrl.text);
  double? get _weight => double.tryParse(widget.weightCtrl.text);
  int? get _age => int.tryParse(widget.ageCtrl.text);

  @override
  Widget build(BuildContext context) {
    final h = _height, a = _age;
    final w = _weight;
    final hasBody =
        h != null && h > 0 && w != null && w > 0 && a != null && a > 0;
    // Maintenance kcal per activity level (null until stats exist).
    int? maintFor(String key) => hasBody
        ? NutritionEngine.maintenanceKcal(
            sex: bioSexFromKey(widget.gender),
            age: a,
            heightCm: h.toDouble(),
            weightKg: w,
            activity: activityFromKey(key),
          )
        : null;

    return _StepShell(
      overline: 'STEP 3 OF 3',
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
                  controller: widget.heightCtrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(
                  label: 'Weight',
                  hint: '78',
                  suffix: 'kg',
                  controller: widget.weightCtrl,
                  decimal: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(
                  label: 'Age',
                  hint: '23',
                  controller: widget.ageCtrl,
                ),
              ),
            ],
          ),
          // Live BMI read-out — slides in once height + weight are entered.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: child,
              ),
            ),
            child: (h != null && h > 0 && w != null && w > 0)
                ? Padding(
                    key: ValueKey(
                      'bmi${bmiFor(w, h.toDouble()).toStringAsFixed(1)}',
                    ),
                    padding: const EdgeInsets.only(top: 16),
                    child: _BmiCard(weightKg: w, heightCm: h.toDouble()),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          Text('Gender', style: _onbLabel(context)),
          const SizedBox(height: 6),
          _SegRow(
            options: _genderLabels,
            selected: widget.gender,
            onChanged: widget.onGender,
          ),
          const SizedBox(height: 18),
          Text('Activity level', style: _onbLabel(context)),
          const SizedBox(height: 8),
          for (final (key, label, desc) in _activityCards) ...[
            _ActivityCard(
              label: label,
              descriptor: desc,
              maintKcal: maintFor(key),
              selected: widget.activity == key,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onActivity(key);
              },
            ),
            const SizedBox(height: 8),
          ],
          // The "what does my activity cost?" explainer — resting vs maintenance.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: child,
              ),
            ),
            child: hasBody
                ? Padding(
                    key: ValueKey(
                      'exp${widget.activity}'
                      '${maintFor(widget.activity)}',
                    ),
                    padding: const EdgeInsets.only(top: 4),
                    child: _ActivityExplainer(
                      sex: bioSexFromKey(widget.gender),
                      age: a,
                      heightCm: h.toDouble(),
                      weightKg: w,
                      activityKey: widget.activity,
                      activityLabel: _activityCards
                          .firstWhere((e) => e.$1 == widget.activity)
                          .$2,
                    ),
                  )
                // Until height/weight/age exist we can't compute calories — say
                // so calmly instead of leaving the cards blank.
                : Padding(
                    key: const ValueKey('activity-need-stats'),
                    padding: const EdgeInsets.only(top: 4),
                    child: _NeedStatsNote(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Band colour for a BMI band. Healthy = green; under/over = amber; obese =
/// ruby. Used only for chips / borders / dots — never as low-contrast text.
Color _bmiColor(AppPalette c, BmiBand b) => switch (b) {
  BmiBand.healthy => c.positive,
  BmiBand.underweight => c.amber,
  BmiBand.overweight => c.amber,
  BmiBand.obese => c.accent,
};

/// Live BMI card: value + band chip + an athletic-aware one-liner tying the
/// number to the healthy weight range for the user's height.
class _BmiCard extends StatelessWidget {
  final double weightKg;
  final double heightCm;
  const _BmiCard({required this.weightKg, required this.heightCm});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final bmi = bmiFor(weightKg, heightCm);
    final band = bmiBand(bmi);
    final col = _bmiColor(c, band);
    final chipInk = Color.lerp(col, Colors.black, 0.28)!;
    final range = idealWeightRange(heightCm);
    final lo = range.lo.round();
    final hi = range.hi.round();
    final line = switch (band) {
      BmiBand.underweight =>
        'Below your healthy range ($lo–$hi kg). A surplus will help you build.',
      BmiBand.healthy =>
        'Right in your healthy range ($lo–$hi kg) — a strong base to build from.',
      BmiBand.overweight =>
        'Above your healthy range ($lo–$hi kg). A lean recomp suits you well.',
      BmiBand.obese =>
        'Well above your healthy range ($lo–$hi kg). A steady cut is the move.',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: col.withValues(alpha: 0.45)),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BMI',
                style: t.meta.copyWith(color: c.textMuted, letterSpacing: 0.6),
              ),
              const SizedBox(height: 1),
              Text(
                bmi.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 30,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ).copyWith(color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(color: col.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    band.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: chipInk,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  line,
                  style: t.meta.copyWith(color: c.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable activity row: label + descriptor, with the live maintenance
/// kcal for that level on the right. Selected = solid accent (house rule 1).
/// Calm note shown under the activity cards before height/weight/age exist —
/// explains why no calorie numbers are showing yet.
class _NeedStatsNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.calculator, size: 14, color: c.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Enter your height, weight & age above and each level will show '
              'its calories.',
              style: t.meta.copyWith(color: c.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String label;
  final String descriptor;
  final int? maintKcal;
  final bool selected;
  final VoidCallback onTap;
  const _ActivityCard({
    required this.label,
    required this.descriptor,
    required this.maintKcal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? null : AppShadows.card,
        ),
        child: Row(
          children: [
            // Selection dot.
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.onAccent : Colors.transparent,
                border: Border.all(
                  color: selected ? c.onAccent : c.borderStrong,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? Icon(LucideIcons.check, size: 11, color: c.accent)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.onAccent : c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    descriptor,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? c.onAccent.withValues(alpha: 0.85)
                          : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Calories once stats exist; a quiet "—" placeholder before that, so
            // the slot reads as "a number will appear here", not broken.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  maintKcal != null ? '≈${_grouped(maintKcal!)}' : '—',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: maintKcal == null
                        ? (selected
                            ? c.onAccent.withValues(alpha: 0.6)
                            : c.textDim)
                        : (selected ? c.onAccent : c.textSecondary),
                  ),
                ),
                Text(
                  'kcal/day',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? c.onAccent.withValues(alpha: 0.8)
                        : c.textDim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Resting burn ≈X · with {level}, maintain on ≈Y kcal/day" — surfaces the
/// science (BMR vs TDEE) so the activity choice feels consequential.
class _ActivityExplainer extends StatelessWidget {
  final BioSex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final String activityKey;
  final String activityLabel;
  const _ActivityExplainer({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityKey,
    required this.activityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final bmr = NutritionEngine.bmr(
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
    ).round();
    final maintain = NutritionEngine.maintenanceKcal(
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activity: activityFromKey(activityKey),
    );
    final burn = maintain - bmr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.flame, size: 16, color: c.athletic),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: t.meta.copyWith(color: c.textSecondary, height: 1.4),
                children: [
                  const TextSpan(text: 'At rest you burn about '),
                  TextSpan(
                    text: '${_grouped(bmr)} kcal',
                    style: t.meta.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: '. As $activityLabel, you maintain on '),
                  TextSpan(
                    text: '≈${_grouped(maintain)} kcal/day',
                    style: t.meta.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: ' — about +${_grouped(burn)} from movement.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "2,900" — grouped thousands.
String _grouped(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Stronger section-label style for the onboarding form — clearly readable and
/// important, not the old too-light label.
TextStyle _onbLabel(BuildContext context) => context.t.label.copyWith(
  color: context.c.textSecondary,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.1,
);

class _LabeledField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? suffix;
  final TextEditingController controller;
  final bool decimal;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stronger label so the field reads as a clear, important section.
        Text(
          label,
          style: t.label.copyWith(
            color: c.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          // Entered value: high-emphasis (dark, semibold). Placeholder: dim.
          // So a real value is unmistakable from the default hint.
          style: t.body.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t.body.copyWith(
              color: c.textDim,
              fontWeight: FontWeight.w400,
            ),
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
                // Selected = solid accent fill + white text (high-contrast,
                // unambiguous) instead of muddy accent-text-on-accent-tint.
                color: active ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(
                  color: active ? c.accent : c.border,
                  width: active ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? c.onAccent : c.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
