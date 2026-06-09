import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';

class InboxNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;
  const InboxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory InboxNotification.fromJson(Map<String, dynamic> j) =>
      InboxNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? {},
        readAt: j['read_at'] != null
            ? DateTime.parse(j['read_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

final notificationsProvider =
    FutureProvider<List<InboxNotification>>((ref) async {
  if (ref.watch(devModeProvider)) return const [];
  final session = ref.watch(sessionProvider);
  if (session == null) return const [];
  try {
    final rows = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', session.user.id)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => InboxNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return list.where((n) => n.isUnread).length;
});

Future<void> markNotificationRead(WidgetRef ref, String id) async {
  final session = ref.read(sessionProvider);
  if (session == null) return;
  try {
    await SupabaseService.client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id);
    ref.invalidate(notificationsProvider);
  } catch (_) {}
}

Future<void> markAllNotificationsRead(WidgetRef ref) async {
  final session = ref.read(sessionProvider);
  if (session == null) return;
  try {
    await SupabaseService.client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', session.user.id)
        .isFilter('read_at', null);
    ref.invalidate(notificationsProvider);
  } catch (_) {}
}
