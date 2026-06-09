/// Real-time ticker lines pulled from every signal that matters today.
/// The Home `_NotifBanner` rotates through whatever this returns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/models/models.dart';
import '../../food/providers/food_providers.dart';
import '../../habits/providers/habit_provider.dart';
import '../../journal/providers/journal_providers.dart';
import 'home_providers.dart';

enum TickerTone { normal, warn, accent }

class TickerLine {
  final IconData icon;
  final String text;
  final TickerTone tone;
  final String? routeTo;
  const TickerLine({
    required this.icon,
    required this.text,
    this.tone = TickerTone.normal,
    this.routeTo,
  });
}

final tickerLinesProvider = Provider<List<TickerLine>>((ref) {
  final lines = <TickerLine>[];
  final now = DateTime.now();
  final selDate = ref.watch(selectedDateProvider);
  final score = ref.watch(homeScoreProvider(selDate)).valueOrNull;
  final tasks = ref.watch(homeTasksProvider(selDate)).valueOrNull ?? const [];
  final waterMl = ref.watch(waterIntakeProvider).valueOrNull ?? 0;
  final waterTargetMl = ref.watch(waterTargetProvider);
  final totals = ref.watch(diaryTotalsProvider);
  final targets = ref.watch(dailyTargetsProvider);
  final needsIntent = ref.watch(needsMorningIntentProvider);
  final needsReview = ref.watch(needsNightReviewProvider);

  // 1. Greeting.
  final hour = now.hour;
  final greeting = hour < 12
      ? 'Good morning'
      : hour < 17
          ? 'Good afternoon'
          : 'Good evening';
  lines.add(TickerLine(
    icon: LucideIcons.sun,
    text: '$greeting · keep moving',
    tone: TickerTone.normal,
  ));

  // 2. Critical pending habits — highest urgency.
  final criticalPending = tasks
      .where((t) => !t.isCompleted && t.habit.priority == HabitPriority.critical)
      .toList();
  if (criticalPending.isNotEmpty) {
    lines.add(TickerLine(
      icon: LucideIcons.alertTriangle,
      text:
          'Critical pending · ${criticalPending.first.habit.name}${criticalPending.length > 1 ? ' +${criticalPending.length - 1}' : ''}',
      tone: TickerTone.warn,
      routeTo: '/habit/${criticalPending.first.habit.id}',
    ));
  }

  // 3. Calorie pace.
  if (targets.kcal > 0) {
    final remaining = (targets.kcal - totals.kcal).round();
    if (remaining > 100) {
      lines.add(TickerLine(
        icon: LucideIcons.zap,
        text:
            'On pace for ${targets.kcal.round()} kcal — ${_fmt(remaining)} to go',
        tone: TickerTone.normal,
        routeTo: '/food',
      ));
    } else if (remaining < -200) {
      lines.add(TickerLine(
        icon: LucideIcons.alertCircle,
        text: 'Over by ${_fmt(-remaining)} kcal',
        tone: TickerTone.warn,
        routeTo: '/food',
      ));
    }
  }

  // 4. Hydration low (after 11 AM).
  if (hour >= 11 && waterTargetMl > 0) {
    final pct = waterMl / waterTargetMl;
    if (pct < 0.5) {
      lines.add(TickerLine(
        icon: LucideIcons.droplet,
        text:
            'Hydration low · ${(waterMl / 1000).toStringAsFixed(1)} of ${(waterTargetMl / 1000).toStringAsFixed(1)} L',
        tone: TickerTone.warn,
        routeTo: '/food',
      ));
    }
  }

  // 5. Streak / day score pace.
  if (score != null && score.total > 0) {
    final pct = score.score / 100.0;
    if (pct >= 1.0) {
      lines.add(const TickerLine(
        icon: LucideIcons.award,
        text: 'Perfect day · keep it going',
        tone: TickerTone.accent,
      ));
    } else if (score.streakDays > 0) {
      lines.add(TickerLine(
        icon: LucideIcons.flame,
        text: '${score.streakDays}-day streak — finish strong tonight',
        tone: TickerTone.accent,
      ));
    }
  }

  // 6. Journal nudges.
  if (needsIntent) {
    lines.add(const TickerLine(
      icon: LucideIcons.edit3,
      text: "Set today's intent",
      tone: TickerTone.accent,
      routeTo: '/journal',
    ));
  }
  if (needsReview) {
    lines.add(const TickerLine(
      icon: LucideIcons.moon,
      text: 'Reflect on today',
      tone: TickerTone.accent,
      routeTo: '/journal',
    ));
  }

  // 7. Next-up incomplete task.
  final upcoming = tasks
      .where((t) => !t.isCompleted && t.time.isNotEmpty)
      .toList();
  if (upcoming.isNotEmpty) {
    final next = upcoming.first;
    lines.add(TickerLine(
      icon: LucideIcons.clock,
      text: 'Up next · ${next.habit.name} at ${next.time}',
      tone: TickerTone.normal,
      routeTo: '/habit/${next.habit.id}',
    ));
  }

  return lines;
});

String _fmt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
