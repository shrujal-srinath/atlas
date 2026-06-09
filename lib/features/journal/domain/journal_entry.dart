/// One row in `public.daily_journal` — at most one per (user, date).
///
/// Captures both the textual journal (`morningIntent`, `nightReview`) and the
/// subjective wellness check-in (`mood`, `energy`, `soreness`, `sleepHours`,
/// `sleepQuality`). Every field is nullable so a partial check-in is valid.
class JournalEntry {
  final String? id;
  final String userId;
  final DateTime date;
  final String? morningIntent;
  final String? nightReview;
  final int? mood;          // 1..5
  final int? energy;        // 1..5
  final int? soreness;      // 1..5 — higher = more sore
  final double? sleepHours; // 0..23.9
  final int? sleepQuality;  // 1..5

  const JournalEntry({
    this.id,
    required this.userId,
    required this.date,
    this.morningIntent,
    this.nightReview,
    this.mood,
    this.energy,
    this.soreness,
    this.sleepHours,
    this.sleepQuality,
  });

  /// True when nothing has been written yet for this date.
  bool get isEmpty =>
      (morningIntent ?? '').trim().isEmpty &&
      (nightReview ?? '').trim().isEmpty &&
      mood == null &&
      energy == null &&
      soreness == null &&
      sleepHours == null &&
      sleepQuality == null;

  bool get hasWellness =>
      mood != null ||
      energy != null ||
      soreness != null ||
      sleepHours != null ||
      sleepQuality != null;

  factory JournalEntry.empty(String userId, DateTime date) =>
      JournalEntry(userId: userId, date: date);

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String?,
        userId: j['user_id'] as String,
        date: DateTime.parse(j['date'] as String),
        morningIntent: j['morning_intent'] as String?,
        nightReview: j['night_review'] as String?,
        mood: (j['mood'] as num?)?.toInt(),
        energy: (j['energy'] as num?)?.toInt(),
        soreness: (j['soreness'] as num?)?.toInt(),
        sleepHours: (j['sleep_hours'] as num?)?.toDouble(),
        sleepQuality: (j['sleep_quality'] as num?)?.toInt(),
      );

  Map<String, dynamic> toUpsert() => {
        'user_id': userId,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'morning_intent': morningIntent,
        'night_review': nightReview,
        'mood': mood,
        'energy': energy,
        'soreness': soreness,
        'sleep_hours': sleepHours,
        'sleep_quality': sleepQuality,
      };

  JournalEntry copyWith({
    String? morningIntent,
    String? nightReview,
    int? mood,
    int? energy,
    int? soreness,
    double? sleepHours,
    int? sleepQuality,
  }) =>
      JournalEntry(
        id: id,
        userId: userId,
        date: date,
        morningIntent: morningIntent ?? this.morningIntent,
        nightReview: nightReview ?? this.nightReview,
        mood: mood ?? this.mood,
        energy: energy ?? this.energy,
        soreness: soreness ?? this.soreness,
        sleepHours: sleepHours ?? this.sleepHours,
        sleepQuality: sleepQuality ?? this.sleepQuality,
      );
}
