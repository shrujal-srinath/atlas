part of 'journal_screen.dart';

// ── Journaling streak chip ──────────────────────────────────────────

class _StreakChip extends StatelessWidget {
  final int days;
  const _StreakChip({required this.days});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.flame, size: 13, color: c.accent),
          const SizedBox(width: 4),
          Text(
            '$days',
            style: AppType.numMd.copyWith(color: c.accent, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Today's mood timeline (intraday check-ins) ──────────────────────

class _MoodTimeline extends ConsumerWidget {
  const _MoodTimeline();

  String _fmt(DateTime d) {
    final ampm = d.hour < 12 ? 'a' : 'p';
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h12$ampm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final logs = ref.watch(moodTodayLogsProvider).valueOrNull ?? const <MoodLog>[];
    if (logs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MOOD TODAY',
                style: AppType.overline.copyWith(color: c.textMuted)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final log in logs)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        children: [
                          if (log.mood != null)
                            Text(_moodEmoji[(log.mood! - 1).clamp(0, 4)],
                                style: const TextStyle(fontSize: 20))
                          else
                            // Energy-only check-in (from the notification picker).
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.zap, size: 14, color: c.accent),
                                const SizedBox(width: 2),
                                Text('${log.energy ?? '–'}',
                                    style: AppType.numMd.copyWith(
                                        color: c.textPrimary, fontSize: 15)),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Text(_fmt(log.loggedAt),
                              style: AppType.meta.copyWith(color: c.textMuted)),
                        ],
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

// ── Recent entries (history) ────────────────────────────────────────

class _HistoryList extends ConsumerWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final selected = ref.watch(selectedDateProvider);
    final entries = ref.watch(journalLast30Provider).valueOrNull ?? const [];
    final past = entries
        .where((e) => e.hasContent && !DateUtils.isSameDay(e.date, selected))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (past.isEmpty) return const SizedBox.shrink();
    final recent = past.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Recent entries'),
        const SizedBox(height: 8),
        for (final e in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.card),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedDateProvider.notifier).state =
                      DateTime(e.date.year, e.date.month, e.date.day);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      if (e.mood != null) ...[
                        Text(_moodEmoji[(e.mood! - 1).clamp(0, 4)],
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                      ],
                      Text(DateFormat('EEE d MMM').format(e.date),
                          style: t.bodyStrong.copyWith(color: c.textPrimary)),
                      const Spacer(),
                      if (e.dayRating != null)
                        Row(
                          children: [
                            Icon(LucideIcons.star, size: 12, color: c.accent),
                            const SizedBox(width: 3),
                            Text('${e.dayRating}',
                                style: t.meta.copyWith(color: c.textSecondary)),
                          ],
                        ),
                      const SizedBox(width: 8),
                      Icon(LucideIcons.chevronRight,
                          size: 16, color: c.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(),
          style: AppType.overline.copyWith(color: context.c.textMuted));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboard;

  const _Field({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.icon,
    this.maxLines = 1,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(icon, size: 14, color: c.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: maxLines,
              keyboardType: keyboard,
              onChanged: onChanged,
              style: context.t.body,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.body.copyWith(color: c.textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final ValueChanged<int> onSelect;
  final String? lowLabel;
  final String? highLabel;

  const _RatingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSelect,
    this.lowLabel,
    this.highLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(width: 10),
          Text(label,
              style: AppType.bodyStrong.copyWith(
                  color: c.textPrimary, fontSize: 13)),
          const Spacer(),
          for (int i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: value == i ? c.accent : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(
                      color: value == i ? c.accent : c.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$i',
                    style: AppType.numMd.copyWith(
                      color: value == i ? c.onAccent : c.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
