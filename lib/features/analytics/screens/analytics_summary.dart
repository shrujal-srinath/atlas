part of 'analytics_screen.dart';

// ── Summary cards ──────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final AnalyticsData data;
  const _SummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = data.weekAvg - data.prevWeekAvg;
    final deltaSign = delta >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'WEEK AVG',
              value: '${data.weekAvg.round()}%',
              sub: '$deltaSign${delta.round()}% vs last week',
              subColor: delta >= 0 ? c.positive : c.negative,
              icon: LucideIcons.trendingUp,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'COMPLETED',
              value: '${data.totalCompletions}',
              sub: 'last 28 days',
              subColor: c.textMuted,
              icon: LucideIcons.checkCheck,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'PERFECT',
              value: '${data.perfectDays}',
              sub: 'days this month',
              subColor: data.perfectDays > 0 ? c.amber : c.textMuted,
              icon: LucideIcons.crown,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color subColor;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppType.numLg.copyWith(fontSize: 22, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: subColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
