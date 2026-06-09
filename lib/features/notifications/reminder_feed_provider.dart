/// Aggregates everything that should appear in the bell tray as a "reminder":
///   • Timed habits/tasks scheduled today that aren't done yet
///   • Habits with `reminderTime` set + `reminderEnabled` (deduped against tasks)
///   • Built-in water reminder (when intake < daily target)
///
/// The [bellBadgeCountProvider] combines pending reminders with unread inbox
/// notifications so the dot on the bell reflects everything that needs the
/// user's attention.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_icons.dart';
import '../../shared/models/models.dart';
import '../food/providers/food_providers.dart';
import '../habits/providers/habit_provider.dart';
import '../home/providers/home_providers.dart';
import 'notification_provider.dart';

enum ReminderKind { task, reminder, water }

class UpcomingReminder {
  final String id;
  final ReminderKind kind;
  final String title;
  final String? subtitle;
  final String? timeLabel; // 'HH:mm' or 'Ongoing'
  final DateTime? scheduledAt;
  final IconData icon;
  final HabitSection? section; // for section tinting
  final String? route;
  final bool isDone;
  const UpcomingReminder({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.timeLabel,
    this.scheduledAt,
    required this.icon,
    this.section,
    this.route,
    this.isDone = false,
  });
}

bool _appliesToday(Habit h, DateTime today) {
  if (h.isArchived) return false;
  switch (h.frequencyMode) {
    case FrequencyMode.everyDay:
      return true;
    case FrequencyMode.specificDays:
      return h.daysOfWeek.contains(today.weekday);
    case FrequencyMode.timesPerWeek:
      return true;
  }
}

(int, int)? _parseHHmm(String? hhmm) {
  if (hhmm == null) return null;
  final p = hhmm.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return (h, m);
}

final upcomingRemindersProvider =
    FutureProvider<List<UpcomingReminder>>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final out = <UpcomingReminder>[];
  final seenHabitIds = <String>{};

  // 1) Today's timed tasks (not done yet, with a scheduledTime)
  final tasks = await ref.watch(homeTasksProvider(today).future);
  for (final t in tasks) {
    if (t.isCompleted) continue;
    if (t.time.isEmpty) continue;
    final hm = _parseHHmm(t.time);
    if (hm == null) continue;
    final at = DateTime(today.year, today.month, today.day, hm.$1, hm.$2);
    seenHabitIds.add(t.habit.id);
    out.add(UpcomingReminder(
      id: 'task-${t.habit.id}',
      kind: ReminderKind.task,
      title: t.habit.name,
      subtitle: _periodLabel(t.period),
      timeLabel: t.time,
      scheduledAt: at,
      icon: habitIcon(t.habit.icon),
      section: t.habit.section,
      route: '/habit/${t.habit.id}',
      isDone: false,
    ));
  }

  // 2) Habits with explicit reminderTime that aren't already shown.
  final habits = await ref.watch(habitsProvider.future);
  for (final h in habits) {
    if (seenHabitIds.contains(h.id)) continue;
    if (!h.reminderEnabled || h.reminderTime == null) continue;
    if (!_appliesToday(h, today)) continue;
    final hm = _parseHHmm(h.reminderTime);
    if (hm == null) continue;
    final at = DateTime(today.year, today.month, today.day, hm.$1, hm.$2);
    out.add(UpcomingReminder(
      id: 'reminder-${h.id}',
      kind: ReminderKind.reminder,
      title: h.name,
      subtitle: 'Reminder',
      timeLabel: h.reminderTime,
      scheduledAt: at,
      icon: habitIcon(h.icon),
      section: h.section,
      route: '/habit/${h.id}',
      isDone: false,
    ));
  }

  // 3) Water — built-in reminder while intake < target.
  final waterMl = ref.watch(waterIntakeProvider).valueOrNull ?? 0;
  final waterTargetMl = ref.watch(waterTargetProvider);
  if (waterMl < waterTargetMl) {
    final remaining = waterTargetMl - waterMl;
    final remainingL = (remaining / 1000).toStringAsFixed(1);
    final progressPct = ((waterMl / waterTargetMl) * 100).round().clamp(0, 100);
    out.add(UpcomingReminder(
      id: 'water',
      kind: ReminderKind.water,
      title: 'Drink water',
      subtitle: '${remainingL}L to go · $progressPct% of daily goal',
      timeLabel: 'Ongoing',
      icon: LucideIcons.droplet,
      route: '/food',
      isDone: false,
    ));
  }

  // Sort: future scheduled times first (ascending), then ongoing, then past-due.
  out.sort((a, b) {
    final aAt = a.scheduledAt;
    final bAt = b.scheduledAt;
    final aFuture = aAt != null && aAt.isAfter(now);
    final bFuture = bAt != null && bAt.isAfter(now);
    if (aFuture && bFuture) return aAt.compareTo(bAt);
    if (aFuture) return -1;
    if (bFuture) return 1;
    // Neither is future. Ongoing (no scheduledAt) before past-due.
    if (aAt == null && bAt != null) return -1;
    if (bAt == null && aAt != null) return 1;
    if (aAt == null && bAt == null) return 0;
    return aAt!.compareTo(bAt!);
  });

  return out;
});

String _periodLabel(String period) => switch (period) {
      'MORNING' => 'This morning',
      'AFTERNOON' => 'This afternoon',
      'EVENING' => 'This evening',
      'NIGHT' => 'Tonight',
      _ => 'Today',
    };

/// Number of dot-worthy items on the bell:
///   pending reminders today + unread inbox entries.
final bellBadgeCountProvider = Provider<int>((ref) {
  final upcoming =
      ref.watch(upcomingRemindersProvider).valueOrNull ?? const [];
  final inboxUnread = ref.watch(unreadNotificationsCountProvider);
  return upcoming.length + inboxUnread;
});
