import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';

/// Explains the two distinct ways the diary reads a day, so the "food quality"
/// chip is never confused with the goal-adherence that drives the ATLAS score.
///
///  • **Food quality** — the chip. How nutritious the food is.
///  • **Goal adherence** — the calorie ring + macro bars. How well you hit your
///    targets; this is what powers your ATLAS score & XP.
class FoodScoreInfoSheet extends StatelessWidget {
  const FoodScoreInfoSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FoodScoreInfoSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 10, AppSpace.screenH, 16),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Two ways we read your day', style: t.h1),
              const SizedBox(height: 6),
              Text(
                'They measure different things — and you want both.',
                style: t.body.copyWith(color: c.textMuted, height: 1.4),
              ),
              const SizedBox(height: 18),

              _ScoreCard(
                icon: LucideIcons.sparkles,
                tint: c.positive,
                title: 'Food quality',
                where: 'the chip on your fuel card & each meal',
                body:
                    'Rates how nutritious your food is — protein density, fibre, '
                    'and staying under the sugar, saturated-fat and sodium limits.',
                bands: const [
                  ('Excellent', '85+'),
                  ('Well fuelled', '70–84'),
                  ('OK', '50–69'),
                  ('Off track', '<50'),
                ],
              ),
              const SizedBox(height: 12),
              _ScoreCard(
                icon: LucideIcons.target,
                tint: c.accent,
                title: 'Goal adherence',
                where: 'your calorie ring + macro bars',
                body:
                    'How closely you hit your calorie & protein targets for your '
                    'current goal (bulk, cut or maintain). This is what powers your '
                    'STRIDE score and XP.',
                bands: const [],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: c.accent.withValues(alpha: 0.20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.lightbulb, size: 17, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Separate on purpose: you can hit your numbers on junk, or '
                        'eat clean but miss your targets. Aim for both.',
                        style: t.bodyStrong
                            .copyWith(color: c.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AtlasButton(
                label: 'Got it',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String where;
  final String body;
  final List<(String, String)> bands;
  const _ScoreCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.where,
    required this.body,
    required this.bands,
  });

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
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: tint),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodyStrong.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 1),
                    Text(where,
                        style: t.meta.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: t.body.copyWith(color: c.textSecondary, height: 1.42)),
          if (bands.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in bands)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: b.$1,
                          style: t.meta.copyWith(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: '  ${b.$2}',
                          style: t.meta.copyWith(color: c.textMuted),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
