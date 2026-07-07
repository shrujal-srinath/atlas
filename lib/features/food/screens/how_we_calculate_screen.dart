import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

/// Plain-language, cited explanation of how the nutrition engine derives every
/// target. Reachable from the goal-settings screen and onboarding so every
/// recommendation is "backed by sources" per the house rules.
class HowWeCalculateScreen extends StatelessWidget {
  const HowWeCalculateScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HowWeCalculateScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('How we calculate'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(AppSpace.screenH, 8, AppSpace.screenH, 28),
          children: [
            _Intro(),
            const SizedBox(height: 14),
            for (final s in _sections) ...[
              _MethodCard(section: s),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 2),
            _Disclaimer(),
          ],
        ),
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String title;
  final String body;
  final List<String> sources;
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.sources,
  });
}

const _sections = <_Section>[
  _Section(
    icon: LucideIcons.flame,
    title: 'Calories',
    body: 'We estimate the energy you burn at rest with the Mifflin-St Jeor '
        'equation (from your sex, age, height and weight), then multiply by an '
        'activity factor (1.2 sedentary → 1.9 athlete) to get your daily burn '
        '(TDEE). Your goal then adds a surplus or deficit on top.',
    sources: ['Mifflin-St Jeor (1990)', 'IOM activity factors'],
  ),
  _Section(
    icon: LucideIcons.gauge,
    title: 'Pace & timeline',
    body: 'About 7,700 kcal equals one kilogram of body mass, so your weekly '
        'rate sets the daily surplus/deficit. We grade the pace — Sustainable, '
        'Hard, Extreme or Unsafe — by percent of bodyweight per week, and never '
        'let calories drop below your resting burn or a hard floor '
        '(1,500 kcal men · 1,200 women).',
    sources: ['CDC / NHS (0.5–1 kg/wk)', 'ACSM position stand'],
  ),
  _Section(
    icon: LucideIcons.beef,
    title: 'Protein',
    body: 'Protein is set per kilogram of bodyweight, not as a share of '
        'calories — so it stays steady whether you bulk or cut. Presets run '
        '1.2 g/kg (general health) up to 2.2 g/kg (preserving muscle in a '
        'deficit); the baseline RDA is 0.8 g/kg.',
    sources: ['ISSN Position Stand (Jäger 2017)', 'NASEM DRI'],
  ),
  _Section(
    icon: LucideIcons.droplets,
    title: 'Fat',
    body: 'Fat is a share of your calories (20–35%, the accepted healthy '
        'range), with a floor of about 0.8 g/kg to protect hormone function. '
        'Change the percentage and your carbs absorb the difference.',
    sources: ['IOM AMDR (20–35%)'],
  ),
  _Section(
    icon: LucideIcons.wheat,
    title: 'Carbohydrate',
    body: 'Carbs fill whatever calories remain after protein and fat — so they '
        'flex with your goal. Eat more to bulk, fewer to cut. This keeps every '
        'macro adding up to exactly your calorie target.',
    sources: ['IOM AMDR (45–65%)'],
  ),
  _Section(
    icon: LucideIcons.leaf,
    title: 'Fiber & water',
    body: 'Fiber scales with energy at 14 g per 1,000 kcal. Water starts near '
        '35 ml per kilogram of bodyweight and rises with your activity level.',
    sources: ['IOM (fiber)', 'NASEM (water)'],
  ),
  _Section(
    icon: LucideIcons.pill,
    title: 'Vitamins & minerals',
    body: 'Micronutrient goals use the official Dietary Reference Intakes for '
        'your sex and age band (for example, iron is 8 mg for men and 18 mg for '
        'most women). They set the floor you want to reach each day.',
    sources: ['NIH ODS', 'NASEM / IOM DRI'],
  ),
  _Section(
    icon: LucideIcons.shieldAlert,
    title: 'Healthy limits',
    body: 'Some nutrients have a ceiling, not a goal. We cap added sugar and '
        'saturated fat at 10% of calories each, trans fat at 1%, sodium at '
        '2,300 mg and cholesterol at 300 mg — and flag a day as over when you '
        'cross them.',
    sources: ['WHO', 'Dietary Guidelines for Americans'],
  ),
];

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.bookOpen, size: 18, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Every target is computed from your body, goal and activity — and '
              'grounded in published nutrition science. Here is the method, '
              'plainly.',
              style: t.body.copyWith(color: c.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final _Section section;
  const _MethodCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(section.icon, size: 16, color: c.accent),
              ),
              const SizedBox(width: 11),
              Text(section.title,
                  style: t.bodyStrong.copyWith(color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(section.body,
              style: t.body.copyWith(color: c.textSecondary, height: 1.45)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final src in section.sources) _SourceChip(label: src),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  const _SourceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bookMarked, size: 11, color: c.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'These targets are general guidance, not medical advice. If you have a '
        'health condition or specific clinical needs, check with a doctor or '
        'registered dietitian.',
        style: t.meta.copyWith(color: c.textMuted, height: 1.4),
      ),
    );
  }
}
