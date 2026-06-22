/// One row in `public.daily_journal` — at most one per (user, date).
///
/// Captures the textual journal (`morningIntent`, top-3 `goals`, evening
/// reflection: `wins` / `improve` / `gratitude` / `nightReview`, plus a 1–5
/// `dayRating`) and the subjective wellness check-in (`mood`, `energy`,
/// `soreness`, `sleepHours`, `sleepQuality`). Every field is nullable/empty so
/// a partial entry is valid.
class JournalEntry {
  final String? id;
  final String userId;
  final DateTime date;
  final String? morningIntent;
  final List<String> goals; // top-3 morning goals
  final String? nightReview;
  final String? wins;
  final String? improve;
  final String? gratitude;
  final int? dayRating; // 1..5
  final int? mood; // 1..5
  final int? energy; // 1..5
  final int? soreness; // 1..5 — higher = more sore
  final double? sleepHours; // 0..23.9
  final int? sleepQuality; // 1..5

  const JournalEntry({
    this.id,
    required this.userId,
    required this.date,
    this.morningIntent,
    this.goals = const [],
    this.nightReview,
    this.wins,
    this.improve,
    this.gratitude,
    this.dayRating,
    this.mood,
    this.energy,
    this.soreness,
    this.sleepHours,
    this.sleepQuality,
  });

  /// True when nothing has been written yet for this date.
  bool get isEmpty =>
      (morningIntent ?? '').trim().isEmpty &&
      goals.every((g) => g.trim().isEmpty) &&
      (nightReview ?? '').trim().isEmpty &&
      (wins ?? '').trim().isEmpty &&
      (improve ?? '').trim().isEmpty &&
      (gratitude ?? '').trim().isEmpty &&
      dayRating == null &&
      mood == null &&
      energy == null &&
      soreness == null &&
      sleepHours == null &&
      sleepQuality == null;

  /// True when this counts toward the journaling streak (any real content).
  bool get hasContent => !isEmpty;

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
        goals: (j['goals'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList() ??
            const [],
        nightReview: j['night_review'] as String?,
        wins: j['wins'] as String?,
        improve: j['improve'] as String?,
        gratitude: j['gratitude'] as String?,
        dayRating: (j['day_rating'] as num?)?.toInt(),
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
        'goals': goals,
        'night_review': nightReview,
        'wins': wins,
        'improve': improve,
        'gratitude': gratitude,
        'day_rating': dayRating,
        'mood': mood,
        'energy': energy,
        'soreness': soreness,
        'sleep_hours': sleepHours,
        'sleep_quality': sleepQuality,
      };

  JournalEntry copyWith({
    String? morningIntent,
    List<String>? goals,
    String? nightReview,
    String? wins,
    String? improve,
    String? gratitude,
    int? dayRating,
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
        goals: goals ?? this.goals,
        nightReview: nightReview ?? this.nightReview,
        wins: wins ?? this.wins,
        improve: improve ?? this.improve,
        gratitude: gratitude ?? this.gratitude,
        dayRating: dayRating ?? this.dayRating,
        mood: mood ?? this.mood,
        energy: energy ?? this.energy,
        soreness: soreness ?? this.soreness,
        sleepHours: sleepHours ?? this.sleepHours,
        sleepQuality: sleepQuality ?? this.sleepQuality,
      );
}
