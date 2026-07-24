enum HabitSection { athletic, mind, body }

/// The three permanent built-in section ids (equal to the enum names). Custom
/// section ids are arbitrary slugs. Defined here (pure) so the scoring engine
/// can reference them without a Flutter dependency.
const String kAthleticId = 'athletic';
const String kMindId = 'mind';
const String kBodyId = 'body';
const List<String> kBuiltInSectionIds = [kAthleticId, kMindId, kBodyId];

bool isBuiltInSection(String id) => kBuiltInSectionIds.contains(id);

/// Custom section id → its built-in parent id (for scoring roll-up) and the
/// score-weight key. Kept in sync by `focusConfigProvider` from the registry so
/// the pure engine and [SectionIdToEnum] can resolve a custom section's parent.
Map<String, String> kSectionParentById = <String, String>{};

/// Section id → display name, kept in sync by `focusConfigProvider` from the
/// stored section registry (built-in renames AND custom sections). Read by
/// [HabitSectionParse.label] and [sectionNameOf] so a name shows everywhere
/// without threading the provider through every widget. Empty = canonical.
Map<String, String> kSectionNameById = <String, String>{};

/// Display name for any section id (built-in or custom). Falls back to a
/// title-cased id when the registry hasn't named it.
String sectionNameOf(String id) {
  final n = kSectionNameById[id];
  if (n != null && n.isNotEmpty) return n;
  if (id.isEmpty) return id;
  return id[0].toUpperCase() + id.substring(1);
}

extension HabitSectionParse on HabitSection {
  /// Map legacy `building` and `breaking` values from existing data to
  /// `mind` and `body`. New rows store the new names directly.
  static HabitSection fromDb(String? raw) {
    final v = (raw ?? 'athletic').toLowerCase();
    return switch (v) {
      'mind' || 'building' => HabitSection.mind,
      'body' || 'breaking' => HabitSection.body,
      _ => HabitSection.athletic,
    };
  }

  /// Display name, used app-wide. Honours the user's rename ([kSectionNameById])
  /// and falls back to the canonical name. Single source of truth — don't
  /// re-spell these in screen `switch`es.
  String get label => kSectionNameById[name] ?? defaultLabel;

  /// The built-in name, ignoring any rename.
  String get defaultLabel => switch (this) {
        HabitSection.athletic => 'Athletic',
        HabitSection.mind => 'Mind',
        HabitSection.body => 'Body',
      };

  /// Stable id for the section (equal to the enum name) — the value stored on a
  /// habit's `section` and used as the key throughout the dynamic-sections
  /// system.
  String get id => name;
}

/// Bridge a section id to a built-in [HabitSection] for the (still enum-keyed)
/// scoring: built-in ids map directly; a custom section rolls up to its parent
/// built-in (via [kSectionParentById]) so its habits count toward that core
/// section's weight.
extension SectionIdToEnum on String {
  HabitSection toSectionEnum() =>
      HabitSectionParse.fromDb(kSectionParentById[this] ?? this);
}

/// Normalise a raw stored `section` value to a section id, mapping the legacy
/// `building`/`breaking` names. Custom section ids pass through untouched.
String normalizeSectionId(String? raw) {
  final v = (raw ?? 'athletic').toLowerCase().trim();
  return switch (v) {
    'building' => 'mind',
    'breaking' => 'body',
    '' => 'athletic',
    _ => v,
  };
}

enum HabitType { positive, negative, todo }

enum GoalType { reps, durationMin, distanceKm, litres, custom }

// ── Goal units ────────────────────────────────────────────────────────
// A goal's numeric value is stored **as typed, in the unit the user picked**
// (`Habit.goalUnit`) — an "8 hr" sleep goal stores `goalValue: 8, goalUnit:
// 'hr'`, not 480 canonical minutes. Ratio scoring is unit-agnostic
// (actualValue is captured in the same unit), so this is safe as long as
// every consumer reads/writes in the habit's own unit rather than assuming
// a fixed base. `goalToCanonical`/`goalFromCanonical` below exist for
// callers that need a common unit for a moment (the goal-sheet's live
// unit-switch preview, the focus timer's real-clock seconds) — they are
// NOT how the value is persisted.

/// Selectable display units for a goal type. First entry is the canonical base.
/// Empty when the type carries a free-text unit (custom) or has no alternates.
List<String> goalUnitsFor(GoalType t) => switch (t) {
      GoalType.reps => const [],
      GoalType.durationMin => const ['min', 'hr'],
      GoalType.distanceKm => const ['km', 'mi'],
      GoalType.litres => const ['L', 'ml'],
      GoalType.custom => const [],
    };

const double _kMiPerKm = 1.609344;

/// Convert a value the user typed in [unit] into the canonical base.
double goalToCanonical(GoalType t, String? unit, double display) =>
    switch (t) {
      GoalType.durationMin when unit == 'hr' => display * 60,
      GoalType.distanceKm when unit == 'mi' => display * _kMiPerKm,
      GoalType.litres when unit == 'ml' => display / 1000,
      _ => display,
    };

/// Inverse of [goalToCanonical] — canonical base → the value shown in [unit].
double goalFromCanonical(GoalType t, String? unit, double canonical) =>
    switch (t) {
      GoalType.durationMin when unit == 'hr' => canonical / 60,
      GoalType.distanceKm when unit == 'mi' => canonical / _kMiPerKm,
      GoalType.litres when unit == 'ml' => canonical * 1000,
      _ => canonical,
    };

/// The unit label to display for a goal (custom uses its own free-text unit).
String goalUnitLabel(GoalType t, String? unit) {
  if (unit != null && unit.isNotEmpty) return unit;
  return switch (t) {
    GoalType.reps => 'reps',
    GoalType.durationMin => 'min',
    GoalType.distanceKm => 'km',
    GoalType.litres => 'L',
    GoalType.custom => 'units',
  };
}

enum FrequencyMode { everyDay, specificDays, timesPerWeek }

enum EndMode { off, date, afterDays }

enum TimePeriod { morning, afternoon, evening }

enum MealTimeSlot { breakfast, lunch, dinner, snack, preWorkout, postWorkout }

enum HabitPriority { low, normal, high, critical }

extension HabitPriorityParse on HabitPriority {
  static HabitPriority fromDb(String? raw) {
    final v = (raw ?? 'normal').toLowerCase();
    return switch (v) {
      'low' => HabitPriority.low,
      'high' => HabitPriority.high,
      'critical' => HabitPriority.critical,
      _ => HabitPriority.normal,
    };
  }
}

class AppUser {
  final String id;
  final String name;
  final String currentPhase;
  final int dailyCalorieTarget;
  final int dailyProteinTarget;
  final int? dailyCarbsTarget;
  final int? dailyFatTarget;
  final int? dailyFiberTarget;
  final String bodyWeightGoal;
  final double? targetBodyWeight;
  final double? heightCm;
  final double? weightKg;
  final int? age;
  final String gender;
  final String activityLevel;
  final int waterTargetMl;

  // Notification prefs
  final bool notificationsEnabled;
  final String? quietHoursStart; // HH:mm
  final String? quietHoursEnd;
  final String defaultReminderTime;
  /// Raw `notification_prefs` JSONB. Parsed into [NotificationPrefs] via the
  /// `notificationPrefsProvider` so the model itself stays import-free of
  /// notification-feature types (which would create an awkward cycle).
  final Map<String, dynamic>? notificationPrefsRaw;

  // Onboarding
  final bool isOnboarded;

  // Per-user section weights (Athletic/Mind/Body), stored as the raw jsonb from
  // Supabase (typically {athletic:40, mind:30, body:30}). Normalized to fractions
  // by [sectionWeightsProvider] before being used in scoring math.
  final Map<String, dynamic>? sectionWeightsJson;

  // Manual per-meal calorie goals, raw jsonb keyed by meal_time dbValue
  // (e.g. {breakfast: 1038, lunch: 1200}). Resolved against the auto-split of
  // [dailyCalorieTarget] by `resolveMealTargets` / `mealTargetsProvider`.
  final Map<String, dynamic>? mealCalorieTargetsJson;

  /// Raw `nutrition_prefs` JSONB — drives the goal-based nutrition engine.
  /// Shape: {timeline_days:int, protein_plan:text, protein_per_kg:num,
  /// fat_plan:text, fat_pct:num, kcal_override:int}. All keys optional; read via
  /// the typed accessors below and consumed by `nutritionPlanForUser`.
  final Map<String, dynamic>? nutritionPrefsRaw;

  /// User-chosen goal timeline (days) from the onboarding pace slider, if set.
  /// Kept for back-compat + display; [weeklyRateKg] is the authoritative pace.
  int? get timelineDays => (nutritionPrefsRaw?['timeline_days'] as num?)?.toInt();

  /// Authoritative pace from the slider — *signed* weekly weight change
  /// (+ gain / − loss), kg/week. The live engine drives calories from this so
  /// the saved plan matches exactly what the user dialled in. Null on legacy
  /// profiles (fall back to [timelineDays]).
  double? get weeklyRateKg =>
      (nutritionPrefsRaw?['weekly_rate_kg'] as num?)?.toDouble();

  /// Manual calorie override (goal-settings screen), if the user pinned one.
  int? get kcalOverride => (nutritionPrefsRaw?['kcal_override'] as num?)?.toInt();

  /// Manual water-goal override (ml) set in the Water goal editor, if any —
  /// otherwise the engine's weight/activity-derived target is used.
  int? get waterOverrideMl =>
      (nutritionPrefsRaw?['water_override_ml'] as num?)?.toInt();

  const AppUser({
    required this.id,
    required this.name,
    required this.currentPhase,
    required this.dailyCalorieTarget,
    required this.dailyProteinTarget,
    this.dailyCarbsTarget,
    this.dailyFatTarget,
    this.dailyFiberTarget,
    required this.bodyWeightGoal,
    this.targetBodyWeight,
    this.heightCm,
    this.weightKg,
    this.age,
    required this.gender,
    required this.activityLevel,
    required this.waterTargetMl,
    this.notificationsEnabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.defaultReminderTime = '08:00',
    this.notificationPrefsRaw,
    this.isOnboarded = true,
    this.sectionWeightsJson,
    this.mealCalorieTargetsJson,
    this.nutritionPrefsRaw,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        currentPhase: j['current_phase'] as String? ?? 'Rehab + Bulk',
        dailyCalorieTarget: (j['daily_calorie_target'] as num?)?.toInt() ?? 3000,
        dailyProteinTarget: (j['daily_protein_target'] as num?)?.toInt() ?? 180,
        dailyCarbsTarget: (j['daily_carbs_target'] as num?)?.toInt(),
        dailyFatTarget: (j['daily_fat_target'] as num?)?.toInt(),
        dailyFiberTarget: (j['daily_fiber_target'] as num?)?.toInt(),
        bodyWeightGoal: j['body_weight_goal'] as String? ?? 'gain',
        targetBodyWeight: (j['target_body_weight'] as num?)?.toDouble(),
        heightCm: (j['height_cm'] as num?)?.toDouble(),
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        age: (j['age'] as num?)?.toInt(),
        gender: j['gender'] as String? ?? 'male',
        activityLevel: j['activity_level'] as String? ?? 'active',
        waterTargetMl: (j['water_target_ml'] as num?)?.toInt() ?? 3500,
        notificationsEnabled: j['notifications_enabled'] as bool? ?? true,
        quietHoursStart: j['quiet_hours_start'] as String?,
        quietHoursEnd: j['quiet_hours_end'] as String?,
        defaultReminderTime: j['default_reminder_time'] as String? ?? '08:00',
        notificationPrefsRaw:
            (j['notification_prefs'] as Map?)?.cast<String, dynamic>(),
        isOnboarded: j['is_onboarded'] as bool? ?? true,
        sectionWeightsJson:
            (j['section_weights'] as Map?)?.cast<String, dynamic>(),
        mealCalorieTargetsJson:
            (j['meal_calorie_targets'] as Map?)?.cast<String, dynamic>(),
        nutritionPrefsRaw:
            (j['nutrition_prefs'] as Map?)?.cast<String, dynamic>(),
      );
}

class Habit {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final String sectionId;
  final HabitType type;
  final List<int> daysOfWeek;
  final double? goalValue;
  final GoalType? goalType;

  /// Display unit for the goal, e.g. 'min' | 'hr' | 'km' | 'mi' | 'L' | 'ml',
  /// or a free-text label for a custom goal. [goalValue] is always stored in
  /// the canonical base (minutes, km, L) so scoring/log math is unit-agnostic;
  /// this only drives input conversion + display. Null → the type's default.
  final String? goalUnit;
  final bool effortRatingEnabled;
  final bool noteEnabled;
  final String? skillCategory;
  final String? replacementHabitId;
  final bool isArchived;
  final TimePeriod? timePeriod;
  final String? scheduledTime; // HH:mm format

  // v2 fields
  final String? colorKey;
  final FrequencyMode frequencyMode;
  final int? timesPerWeek;
  final bool reminderEnabled;
  final String? reminderTime; // HH:mm
  final List<int> reminderDays; // 1..7
  final EndMode endMode;
  final DateTime? endDate;
  final int? endAfterDays;
  final bool photoProofEnabled;
  final DateTime? dueDate; // for one-time todos
  final int sortOrder;
  final HabitPriority priority;

  /// Raw `food_link` JSONB — a saved food link that auto-logs to the diary when
  /// the task is completed. Parsed into `HabitFoodLink` in the habits feature
  /// (kept raw here so this model stays free of food-feature types, mirroring
  /// [notificationPrefsRaw]). Null when the task has no food link.
  final Map<String, dynamic>? foodLinkRaw;

  /// When the habit row was created (local time). A habit never affects any day
  /// before this, so adding a new habit can't retroactively lower a past day's
  /// score, streak, or completion stats. Null when unknown (e.g. bundled demo
  /// data) → no lower bound. See [existedOn].
  final DateTime? createdAt;

  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.sectionId,
    required this.type,
    required this.daysOfWeek,
    this.goalValue,
    this.goalType,
    this.goalUnit,
    required this.effortRatingEnabled,
    required this.noteEnabled,
    this.skillCategory,
    this.replacementHabitId,
    required this.isArchived,
    this.timePeriod,
    this.scheduledTime,
    this.colorKey,
    this.frequencyMode = FrequencyMode.specificDays,
    this.timesPerWeek,
    this.reminderEnabled = false,
    this.reminderTime,
    this.reminderDays = const [],
    this.endMode = EndMode.off,
    this.endDate,
    this.endAfterDays,
    this.photoProofEnabled = false,
    this.dueDate,
    this.sortOrder = 0,
    this.priority = HabitPriority.normal,
    this.foodLinkRaw,
    this.createdAt,
  });

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String? ?? '⚡',
        sectionId: normalizeSectionId(j['section'] as String?),
        type: HabitType.values.byName(j['type'] as String? ?? 'positive'),
        daysOfWeek: (j['days_of_week'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
        goalValue: (j['goal_value'] as num?)?.toDouble(),
        goalType: j['goal_type'] != null ? GoalType.values.byName(j['goal_type'] as String) : null,
        goalUnit: j['goal_unit'] as String?,
        effortRatingEnabled: j['effort_rating_enabled'] as bool? ?? false,
        noteEnabled: j['note_enabled'] as bool? ?? false,
        skillCategory: j['skill_category'] as String?,
        replacementHabitId: j['replacement_habit_id'] as String?,
        isArchived: j['is_archived'] as bool? ?? false,
        timePeriod: j['time_period'] != null
            ? TimePeriod.values.byName(j['time_period'] as String)
            : null,
        scheduledTime: j['scheduled_time'] as String?,
        colorKey: j['color_key'] as String?,
        frequencyMode: _parseFreq(j['frequency_mode'] as String?),
        timesPerWeek: (j['times_per_week'] as num?)?.toInt(),
        reminderEnabled: j['reminder_enabled'] as bool? ?? false,
        reminderTime: j['reminder_time'] as String?,
        reminderDays: (j['reminder_days'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        endMode: _parseEnd(j['end_mode'] as String?),
        endDate: j['end_date'] != null
            ? DateTime.parse(j['end_date'] as String)
            : null,
        endAfterDays: (j['end_after_days'] as num?)?.toInt(),
        photoProofEnabled: j['photo_proof_enabled'] as bool? ?? false,
        dueDate: j['due_date'] != null
            ? DateTime.parse(j['due_date'] as String)
            : null,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        priority: HabitPriorityParse.fromDb(j['priority'] as String?),
        foodLinkRaw: (j['food_link'] as Map?)?.cast<String, dynamic>(),
        // Supabase returns `created_at` as a UTC timestamp — localize it so the
        // "existed on day D" check compares against the user's local calendar.
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String).toLocal()
            : null,
      );

  static FrequencyMode _parseFreq(String? s) => switch (s) {
        'every_day' => FrequencyMode.everyDay,
        'times_per_week' => FrequencyMode.timesPerWeek,
        _ => FrequencyMode.specificDays,
      };

  static EndMode _parseEnd(String? s) => switch (s) {
        'date' => EndMode.date,
        'after_days' => EndMode.afterDays,
        _ => EndMode.off,
      };

  static String freqToDb(FrequencyMode m) => switch (m) {
        FrequencyMode.everyDay => 'every_day',
        FrequencyMode.timesPerWeek => 'times_per_week',
        FrequencyMode.specificDays => 'specific_days',
      };

  static String endToDb(EndMode m) => switch (m) {
        EndMode.date => 'date',
        EndMode.afterDays => 'after_days',
        EndMode.off => 'off',
      };

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'icon': icon,
        'section': sectionId,
        'type': type.name,
        'days_of_week': daysOfWeek,
        if (goalValue != null) 'goal_value': goalValue,
        if (goalType != null) 'goal_type': goalType!.name,
        if (goalUnit != null) 'goal_unit': goalUnit,
        'effort_rating_enabled': effortRatingEnabled,
        'note_enabled': noteEnabled,
        if (skillCategory != null) 'skill_category': skillCategory,
        if (replacementHabitId != null) 'replacement_habit_id': replacementHabitId,
        'is_archived': isArchived,
        if (colorKey != null) 'color_key': colorKey,
        'frequency_mode': freqToDb(frequencyMode),
        if (timesPerWeek != null) 'times_per_week': timesPerWeek,
        'reminder_enabled': reminderEnabled,
        if (reminderTime != null) 'reminder_time': reminderTime,
        'reminder_days': reminderDays,
        'end_mode': endToDb(endMode),
        if (endDate != null) 'end_date': endDate!.toIso8601String().split('T').first,
        if (endAfterDays != null) 'end_after_days': endAfterDays,
        'photo_proof_enabled': photoProofEnabled,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String().split('T').first,
        'sort_order': sortOrder,
        'priority': priority.name,
        if (foodLinkRaw != null) 'food_link': foodLinkRaw,
      };

  /// Local date-only day the habit began counting — its creation day. Null when
  /// unknown (e.g. bundled demo data), which imposes no lower bound.
  DateTime? get startDate {
    final c = createdAt;
    return c == null ? null : DateTime(c.year, c.month, c.day);
  }

  /// Whether the habit already existed on [date] (date-only). A habit never
  /// affects a day before it was created, so a newly-added habit can't
  /// retroactively lower a past day's score, streak, or completion stats. The
  /// creation day itself counts.
  bool existedOn(DateTime date) {
    final s = startDate;
    if (s == null) return true;
    return !DateTime(date.year, date.month, date.day).isBefore(s);
  }
}

class HabitLog {
  final String id;
  final String habitId;
  final String userId;
  final String date;
  final bool completed;
  final int? effortRating;
  final String? note;
  final String? triggerTag;
  final bool urgeOnly;
  /// Numeric progress for goal-bearing habits (reps/min/km/L).
  /// Null for binary habits and legacy logs — those resolve to ratio 1.0 when
  /// [completed] is true.
  final double? actualValue;

  /// Deliberate **rest day** for a flexible-count ("X / week") habit — a neutral
  /// skip: it's excluded from the day score, never breaks a streak, and earns no
  /// XP (mirrors a non-scheduled day). Distinct from a plain incomplete day,
  /// which still counts against the habit.
  final bool restDay;

  const HabitLog({
    required this.id,
    required this.habitId,
    required this.userId,
    required this.date,
    required this.completed,
    this.effortRating,
    this.note,
    this.triggerTag,
    required this.urgeOnly,
    this.actualValue,
    this.restDay = false,
  });

  factory HabitLog.fromJson(Map<String, dynamic> j) => HabitLog(
        id: j['id'] as String,
        habitId: j['habit_id'] as String,
        userId: j['user_id'] as String,
        date: j['date'] as String,
        completed: j['completed'] as bool? ?? false,
        effortRating: (j['effort_rating'] as num?)?.toInt(),
        note: j['note'] as String?,
        triggerTag: j['trigger_tag'] as String?,
        urgeOnly: j['urge_only'] as bool? ?? false,
        actualValue: (j['actual_value'] as num?)?.toDouble(),
        restDay: j['rest_day'] as bool? ?? false,
      );

  HabitLog copyWith({
    bool? completed,
    int? effortRating,
    String? note,
    String? triggerTag,
    bool? urgeOnly,
    double? actualValue,
    bool? restDay,
  }) =>
      HabitLog(
        id: id,
        habitId: habitId,
        userId: userId,
        date: date,
        completed: completed ?? this.completed,
        effortRating: effortRating ?? this.effortRating,
        note: note ?? this.note,
        triggerTag: triggerTag ?? this.triggerTag,
        urgeOnly: urgeOnly ?? this.urgeOnly,
        actualValue: actualValue ?? this.actualValue,
        restDay: restDay ?? this.restDay,
      );
}

class FoodLog {
  final String id;
  final String userId;
  final String? mealId;
  final String mealName;
  final String date;
  final MealTimeSlot mealTime;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double quantity;

  const FoodLog({
    required this.id,
    required this.userId,
    this.mealId,
    required this.mealName,
    required this.date,
    required this.mealTime,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
  });

  factory FoodLog.fromJson(Map<String, dynamic> j) => FoodLog(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        mealId: j['meal_id'] as String?,
        mealName: j['meal_name'] as String,
        date: j['date'] as String,
        mealTime: MealTimeSlot.values.byName(
          (j['meal_time'] as String? ?? 'snack').replaceAll('_', '').toLowerCase() == 'preworkout'
              ? 'preWorkout'
              : (j['meal_time'] as String? ?? 'snack').replaceAll('_', '').toLowerCase() == 'postworkout'
                  ? 'postWorkout'
                  : (j['meal_time'] as String? ?? 'snack'),
        ),
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        protein: (j['protein'] as num?)?.toDouble() ?? 0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0,
        quantity: (j['quantity'] as num?)?.toDouble() ?? 100,
      );
}
