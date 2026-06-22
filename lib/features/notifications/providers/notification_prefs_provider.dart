import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/notification_prefs.dart';

/// Typed view of the current user's `notification_prefs` JSONB.
/// Returns [NotificationPrefs.defaults] while the user row is loading
/// (or null) so callers never get a transient null.
final notificationPrefsProvider = Provider<NotificationPrefs>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return NotificationPrefs.fromJson(user?.notificationPrefsRaw);
});
