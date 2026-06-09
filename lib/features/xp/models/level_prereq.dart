/// User-defined milestone that gates a level transition.
///
/// See `docs/LEVELING.md` for the rationale + the supported kinds.
library;

/// What sort of milestone the user picked. Each kind has its own `config`
/// shape (see comments on the enum values).
enum PrereqKind {
  /// Counts how many times a specific habit has been completed.
  /// `config`: `{habitId: String, targetCount: int}`
  habitCompletions,

  /// Longest current consecutive-day streak on a specific habit.
  /// `config`: `{habitId: String, targetDays: int}`
  streakDays,

  /// Count of days at or above a score threshold.
  /// `config`: `{targetCount: int, scoreThreshold: int}` (default 90)
  perfectDays,

  /// Count of days at or above a nutrition adherence ratio.
  /// `config`: `{targetCount: int, ratioThreshold: double}` (default 0.80)
  nutritionDays,
}

PrereqKind? prereqKindFromDb(String s) {
  switch (s) {
    case 'habit_completions':
      return PrereqKind.habitCompletions;
    case 'streak_days':
      return PrereqKind.streakDays;
    case 'perfect_days':
      return PrereqKind.perfectDays;
    case 'nutrition_days':
      return PrereqKind.nutritionDays;
    default:
      return null;
  }
}

String prereqKindToDb(PrereqKind k) => switch (k) {
      PrereqKind.habitCompletions => 'habit_completions',
      PrereqKind.streakDays => 'streak_days',
      PrereqKind.perfectDays => 'perfect_days',
      PrereqKind.nutritionDays => 'nutrition_days',
    };

/// One row in the `level_prerequisites` table.
class LevelPrereq {
  final String id;
  final String userId;
  /// Target level — e.g., `2` means "pre-requisites to reach Level 2".
  final int level;
  final PrereqKind kind;
  final Map<String, dynamic> config;
  final DateTime? completedAt;

  const LevelPrereq({
    required this.id,
    required this.userId,
    required this.level,
    required this.kind,
    required this.config,
    this.completedAt,
  });

  factory LevelPrereq.fromJson(Map<String, dynamic> j) {
    final k = prereqKindFromDb(j['kind'] as String);
    if (k == null) throw FormatException('unknown prereq kind: ${j['kind']}');
    return LevelPrereq(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      level: (j['level'] as num).toInt(),
      kind: k,
      config: (j['config'] as Map?)?.cast<String, dynamic>() ?? const {},
      completedAt: j['completed_at'] != null
          ? DateTime.parse(j['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'level': level,
        'kind': prereqKindToDb(kind),
        'config': config,
      };

  // Convenience accessors for typed config values.
  int get targetCount => (config['targetCount'] as num?)?.toInt() ?? 0;
  int get targetDays => (config['targetDays'] as num?)?.toInt() ?? 0;
  String? get habitId => config['habitId'] as String?;
  int get scoreThreshold => (config['scoreThreshold'] as num?)?.toInt() ?? 90;
  double get ratioThreshold =>
      (config['ratioThreshold'] as num?)?.toDouble() ?? 0.80;

  /// Numeric target this pre-req is graded against (used by the UI's progress
  /// bar). Each kind exposes a single integer target.
  int get target => switch (kind) {
        PrereqKind.habitCompletions => targetCount,
        PrereqKind.streakDays => targetDays,
        PrereqKind.perfectDays => targetCount,
        PrereqKind.nutritionDays => targetCount,
      };
}

/// Combines a definition with its derived current progress + target.
/// Returned by `prereqProgressProvider` — UI consumes this directly.
class PrereqProgress {
  final LevelPrereq def;
  final int currentProgress;
  final int target;
  final bool isMet;
  const PrereqProgress({
    required this.def,
    required this.currentProgress,
    required this.target,
    required this.isMet,
  });
}
