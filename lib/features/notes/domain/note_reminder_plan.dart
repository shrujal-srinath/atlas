import 'note.dart';

/// Resolved schedule for a note's reminder — what the OS should actually queue.
/// Either a one-time [exactWhen] or a repeating [hour]:[minute] on [daysOfWeek]
/// (empty days = every day).
class NoteReminderPlan {
  final DateTime? exactWhen; // non-null => one-time
  final int hour;
  final int minute;
  final List<int> daysOfWeek; // 1=Mon … 7=Sun; empty => daily

  const NoteReminderPlan({
    this.exactWhen,
    this.hour = 0,
    this.minute = 0,
    this.daysOfWeek = const [],
  });

  bool get isOnce => exactWhen != null;
}

/// Pure decision: what (if anything) the OS should schedule for a note's
/// reminder. Returns null when nothing should fire — no reminder set, or a
/// one-time reminder whose moment has already passed. Extracted so the
/// day-resolution + past-skip logic is testable without the plugin.
NoteReminderPlan? planNoteReminder({
  required DateTime? at,
  required ReminderRule? rule,
  DateTime? now,
}) {
  if (at == null || rule == null) return null;
  switch (rule) {
    case ReminderRule.once:
      final n = now ?? DateTime.now();
      if (!at.isAfter(n)) return null; // already passed
      return NoteReminderPlan(exactWhen: at);
    case ReminderRule.daily:
      return NoteReminderPlan(hour: at.hour, minute: at.minute);
    case ReminderRule.weekdays:
      return NoteReminderPlan(
          hour: at.hour, minute: at.minute, daysOfWeek: const [1, 2, 3, 4, 5]);
    case ReminderRule.weekends:
      return NoteReminderPlan(
          hour: at.hour, minute: at.minute, daysOfWeek: const [6, 7]);
    case ReminderRule.weekly:
      return NoteReminderPlan(
          hour: at.hour, minute: at.minute, daysOfWeek: [at.weekday]);
  }
}
