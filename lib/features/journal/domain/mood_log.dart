/// One intraday mood check-in — a row in `public.mood_logs`.
///
/// Unlike [JournalEntry] (one per day), there can be many of these per day;
/// they form the mood-through-the-day timeseries. `daily_journal` keeps the
/// day's latest mood/energy as the summary used by the 30-day wellness trend.
class MoodLog {
  final String? id;
  final String userId;
  final DateTime loggedAt;
  final int? mood; // 1..5 — null for energy-only check-ins (notification picker)
  final int? energy; // 1..5
  final String? note;

  const MoodLog({
    this.id,
    required this.userId,
    required this.loggedAt,
    this.mood,
    this.energy,
    this.note,
  });

  factory MoodLog.fromJson(Map<String, dynamic> j) => MoodLog(
        id: j['id'] as String?,
        userId: j['user_id'] as String,
        loggedAt: DateTime.parse(j['logged_at'] as String).toLocal(),
        mood: (j['mood'] as num?)?.toInt(),
        energy: (j['energy'] as num?)?.toInt(),
        note: j['note'] as String?,
      );
}
