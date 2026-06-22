import 'package:flutter/material.dart';

import '../domain/note.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _shortDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${d.day} ${_months[d.month - 1]}';
}

/// Human label for a note's reminder, e.g. "Daily · 9:00 am",
/// "Tomorrow · 3:00 pm", or "Missed" for a lapsed one-time reminder.
String formatReminder(BuildContext context, Note note) {
  final at = note.reminderAt;
  if (at == null) return '';
  final time = TimeOfDay.fromDateTime(at).format(context);
  switch (note.reminderRule) {
    case ReminderRule.once:
      if (note.reminderPassed) return 'Missed';
      return '${_shortDate(at)} · $time';
    case ReminderRule.daily:
      return 'Daily · $time';
    case ReminderRule.weekdays:
      return 'Weekdays · $time';
    case ReminderRule.weekends:
      return 'Weekends · $time';
    case ReminderRule.weekly:
      return '${_weekdays[at.weekday - 1]} · $time';
    case null:
      return time;
  }
}
