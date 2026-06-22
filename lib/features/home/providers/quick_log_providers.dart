import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/offline_writer.dart';
import '../../../shared/services/supabase_service.dart';
import '../../habits/providers/habit_provider.dart' show selectedDateProvider;

// ── Focus sessions ─────────────────────────────────────────────
// The mood / intention quick-logs that used to live here were removed with the
// home quick-log row; the focus timer is the only remaining consumer.

class FocusSession {
  final String id;
  final DateTime date;
  final int durationMin;
  final String? label;
  final DateTime startedAt;
  final DateTime completedAt;
  const FocusSession({
    required this.id,
    required this.date,
    required this.durationMin,
    this.label,
    required this.startedAt,
    required this.completedAt,
  });

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        durationMin: (j['duration_min'] as num).toInt(),
        label: j['label'] as String?,
        startedAt: DateTime.parse(j['started_at'] as String),
        completedAt: DateTime.parse(j['completed_at'] as String),
      );
}

/// Logs a completed focus session to `focus_sessions`.
Future<FocusSession> logFocus(
  WidgetRef ref, {
  required int durationMin,
  String? label,
  required DateTime startedAt,
}) async {
  final userId = SupabaseService.auth.currentUser!.id;
  final date = ref.read(selectedDateProvider);
  final now = DateTime.now();
  final inserted = await OfflineWriter.insert(
    table: 'focus_sessions',
    payload: {
      'user_id': userId,
      'date': _dateStr(date),
      'duration_min': durationMin,
      if (label != null && label.isNotEmpty) 'label': label,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': now.toUtc().toIso8601String(),
    },
  );
  return FocusSession.fromJson(inserted);
}

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
