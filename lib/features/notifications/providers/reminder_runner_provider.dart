import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/quiet_hours.dart';
import '../../../shared/services/reminder_scheduler.dart';
import '../../auth/providers/auth_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../domain/notification_prefs.dart';
import 'notification_prefs_provider.dart';

/// Listens to user-prefs / habit / quiet-hours changes and reconciles the OS
/// notification schedule whenever any of them update.
///
/// Critically: when no user is signed in (or auth state is errored), the
/// runner *cancels all* scheduled notifications instead of reconciling to
/// defaults — otherwise signing out would leave the old user's reminders
/// running, or a fresh-boot signed-out app would schedule default reminders
/// for a user that doesn't exist yet.
final reminderRunnerProvider = Provider<void>((ref) {
  // Ask the OS for notification permission exactly once per session, the first
  // time we see an enabled signed-in user. Without this, nothing we schedule
  // ever surfaces on Android 13+/iOS.
  var permissionsAsked = false;

  Future<void> sync(AppUserState user, NotificationPrefs prefs) async {
    if (user == AppUserState.none) {
      await NotificationService.instance.cancelAll();
      return;
    }
    if (user.notificationsEnabled && !permissionsAsked) {
      permissionsAsked = true;
      await NotificationService.instance.ensurePermissions();
    }
    // If habits can't be read (offline / still loading), pass null so the
    // reconciler leaves existing habit reminders untouched rather than wiping
    // them — meal/water/streak/weight still reconcile from prefs.
    List<Habit>? habits;
    try {
      habits = await ref.read(habitsProvider.future);
    } catch (_) {
      habits = null;
    }
    await ReminderScheduler.instance.reconcile(
      master: user.notificationsEnabled,
      prefs: prefs,
      habits: habits,
      quiet: user.quietHours,
    );
  }

  ref.listen<AppUserState>(_appUserStateProvider, (prev, next) {
    sync(next, ref.read(notificationPrefsProvider));
  }, fireImmediately: true);

  ref.listen<NotificationPrefs>(notificationPrefsProvider, (prev, next) {
    sync(ref.read(_appUserStateProvider), next);
  });

  // Habit add/edit/delete/archive changes what should be scheduled.
  ref.listen<AsyncValue<List<Habit>>>(habitsProvider, (prev, next) {
    if (next is AsyncData<List<Habit>>) {
      sync(ref.read(_appUserStateProvider), ref.read(notificationPrefsProvider));
    }
  });
});

/// Compact, cycle-safe view of the auth state — collapses
/// `AsyncValue<AppUser?>` into either `AppUserState.none` (signed out / loading
/// / errored) or `AppUserState.signedIn(...)` with the fields the scheduler
/// cares about. Equality covers all of them so any change reschedules.
class AppUserState {
  final bool _present;
  final bool notificationsEnabled;
  final QuietHours? quietHours;
  const AppUserState._(this._present, this.notificationsEnabled, this.quietHours);

  static const none = AppUserState._(false, false, null);
  static AppUserState signedIn(bool enabled, QuietHours? quiet) =>
      AppUserState._(true, enabled, quiet);

  @override
  bool operator ==(Object other) =>
      other is AppUserState &&
      other._present == _present &&
      other.notificationsEnabled == notificationsEnabled &&
      other.quietHours == quietHours;

  @override
  int get hashCode => Object.hash(_present, notificationsEnabled, quietHours);
}

final _appUserStateProvider = Provider<AppUserState>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return AppUserState.none;
  return AppUserState.signedIn(
    user.notificationsEnabled,
    QuietHours.parse(user.quietHoursStart, user.quietHoursEnd),
  );
});
