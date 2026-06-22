import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/note.dart';
import '../domain/note_reminder_plan.dart';
import 'notes_providers.dart';

/// Keeps the OS notification schedule for note reminders in sync with the
/// notes table. Mirrors [reminderRunnerProvider]'s shape: reconciles whenever
/// the notes list or the signed-in user changes.
///
/// Gating: note reminders are user-set task reminders, so they fire at the
/// exact time chosen (no quiet-hours shifting) — but they still respect the
/// master notifications switch. When it's off, or the user signs out, every
/// known note reminder is cancelled.
final noteRemindersRunnerProvider = Provider<void>((ref) {
  Future<void> cancelAllKnown(List<Note>? notes) async {
    if (notes == null) return;
    final svc = NotificationService.instance;
    for (final n in notes) {
      await svc.cancelNoteReminder(n.id);
    }
  }

  Future<void> sync() async {
    final user = ref.read(appUserProvider).valueOrNull;
    final master = user?.notificationsEnabled ?? false;
    final notes = ref.read(notesListProvider).valueOrNull;

    if (user == null || !master) {
      await cancelAllKnown(notes);
      return;
    }
    if (notes == null) return; // still loading — leave existing schedule as-is

    final svc = NotificationService.instance;
    for (final n in notes) {
      await svc.cancelNoteReminder(n.id);
      final plan = planNoteReminder(at: n.reminderAt, rule: n.reminderRule);
      if (plan == null) continue;
      final body = n.isChecklist ? 'Open your list' : 'Open your note';
      if (plan.isOnce) {
        await svc.scheduleNoteOnce(
          noteId: n.id,
          title: n.displayTitle,
          body: body,
          whenLocal: plan.exactWhen!,
        );
      } else {
        await svc.scheduleNoteRepeating(
          noteId: n.id,
          title: n.displayTitle,
          body: body,
          time: (hour: plan.hour, minute: plan.minute),
          daysOfWeek: plan.daysOfWeek,
        );
      }
    }
  }

  ref.listen(appUserProvider, (_, _) => sync());
  ref.listen<AsyncValue<List<Note>>>(notesListProvider, (_, next) {
    if (next is AsyncData<List<Note>>) sync();
  }, fireImmediately: true);
});
