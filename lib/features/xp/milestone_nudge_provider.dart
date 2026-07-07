/// Evaluates the next level's milestones and drops nudges into the in-app
/// notifications feed:
///  - a one-time **halfway** nudge when a timed milestone crosses 50%, and
///  - a daily **"can't skip" late warning** when the reps you still owe equal
///    (or exceed) the scheduled days remaining in the window — e.g. 7 jogging
///    sessions in 7 days where jogging is once/day.
///
/// De-duped by querying existing `milestone_*` notifications (halfway once ever,
/// late once per day). Real accounts only — the demo has no notifications write.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../shared/models/models.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../habits/providers/habit_provider.dart';
import '../notifications/notification_provider.dart';
import 'leveling_providers.dart';
import 'models/level_prereq.dart';
import 'prereq_providers.dart';

/// Keep-alive runner: watch this once (e.g. on the home screen) so milestone
/// nudges are evaluated whenever progress changes.
final milestoneNudgeRunnerProvider = Provider<void>((ref) {
  final level = ref.watch(confirmedLevelProvider).valueOrNull;
  if (level == null) return;
  ref.listen(prereqProgressProvider(level + 1), (_, next) {
    final progress = next.valueOrNull;
    if (progress == null || progress.isEmpty) return;
    if (ref.read(devModeProvider)) return; // demo has no notifications write
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final habits = ref.read(habitsProvider).valueOrNull ?? const <Habit>[];
    _evaluate(ref, session.user.id, progress, habits);
  }, fireImmediately: true);
});

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// How many of the next [daysLeft] days (from today) the habit is scheduled on.
/// Drives the "can't skip" test precisely for habits that aren't daily.
int _scheduledDaysInWindow(Habit? h, int daysLeft) {
  if (h == null || daysLeft <= 0) return daysLeft;
  final now = DateTime.now();
  int count = 0;
  for (int i = 0; i < daysLeft; i++) {
    final d = DateTime(now.year, now.month, now.day + i);
    final applies = switch (h.frequencyMode) {
      FrequencyMode.everyDay => true,
      FrequencyMode.specificDays => h.daysOfWeek.contains(d.weekday),
      FrequencyMode.timesPerWeek => true,
    };
    if (applies) count++;
  }
  return count == 0 ? daysLeft : count;
}

Future<void> _evaluate(
  Ref ref,
  String userId,
  List<PrereqProgress> progress,
  List<Habit> habits,
) async {
  // De-dup against what's already in the feed.
  final Set<String> halfwaySent = {};
  final Set<String> lateSentToday = {};
  final today = _dateKey(DateTime.now());
  try {
    final rows = await SupabaseService.client
        .from('notifications')
        .select('type, payload')
        .eq('user_id', userId)
        .inFilter('type', ['milestone_halfway', 'milestone_late']);
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final p = (r['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
      final mid = p['milestoneId'] as String?;
      if (mid == null) continue;
      if (r['type'] == 'milestone_halfway') {
        halfwaySent.add(mid);
      } else if (r['type'] == 'milestone_late' && p['day'] == today) {
        lateSentToday.add(mid);
      }
    }
  } catch (_) {
    return; // can't read feed → don't risk duplicate inserts
  }

  final toInsert = <Map<String, dynamic>>[];
  for (final pp in progress) {
    final d = pp.def;
    if (pp.isMet || pp.isExpired) continue;
    if (!d.hasWindow) continue; // nudges only make sense with a deadline
    final name = describePrereq(d, habits);

    // Halfway — once, when crossing 50%.
    if (pp.target > 0 &&
        pp.currentProgress * 2 >= pp.target &&
        !halfwaySent.contains(d.id)) {
      toInsert.add({
        'user_id': userId,
        'type': 'milestone_halfway',
        'title': 'Halfway there',
        'body': '$name — ${pp.currentProgress}/${pp.target}. Keep the pace.',
        'payload': {'milestoneId': d.id},
      });
    }

    // "Can't skip" — daily, when remaining reps ≥ scheduled days left.
    final daysLeft = pp.daysLeft;
    if (d.kind == PrereqKind.habitCompletions &&
        daysLeft != null &&
        daysLeft > 0 &&
        !lateSentToday.contains(d.id)) {
      final remaining = pp.target - pp.currentProgress;
      final habit = habits.where((h) => h.id == d.habitId).firstOrNull;
      final scheduledLeft = _scheduledDaysInWindow(habit, daysLeft);
      if (remaining > 0 && remaining >= scheduledLeft) {
        final hname = habit?.name ?? 'this task';
        toInsert.add({
          'user_id': userId,
          'type': 'milestone_late',
          'title': "Don't skip $hname",
          'body': "You can't skip $hname anymore — $remaining left in "
              "$daysLeft day${daysLeft == 1 ? '' : 's'} to hit “$name”.",
          'payload': {'milestoneId': d.id, 'day': today},
        });
      }
    }
  }

  if (toInsert.isEmpty) return;
  try {
    await SupabaseService.client.from('notifications').insert(toInsert);
    ref.invalidate(notificationsProvider);
  } catch (_) {}
}
