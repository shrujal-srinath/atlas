import '../../../shared/models/models.dart';

/// All notification preferences stored on the user row as a single JSONB.
///
/// Defaults mirror the Supabase migration `user_notification_prefs_jsonb`
/// so the typed view is consistent with brand-new accounts that haven't
/// touched their prefs yet.
class NotificationPrefs {
  final bool habits;
  final MealPrefs meals;
  final WaterNudgePrefs water;
  final StreakRiskPrefs streakAtRisk;
  final WeightNudgePrefs weight;
  final MoodCheckinPrefs moodCheckin;

  const NotificationPrefs({
    required this.habits,
    required this.meals,
    required this.water,
    required this.streakAtRisk,
    required this.weight,
    required this.moodCheckin,
  });

  static const defaults = NotificationPrefs(
    habits: true,
    meals: MealPrefs.defaults,
    water: WaterNudgePrefs.defaults,
    streakAtRisk: StreakRiskPrefs.defaults,
    weight: WeightNudgePrefs.defaults,
    moodCheckin: MoodCheckinPrefs.defaults,
  );

  factory NotificationPrefs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    return NotificationPrefs(
      habits: j['habits'] as bool? ?? true,
      meals: MealPrefs.fromJson(j['meals'] as Map<String, dynamic>?),
      water: WaterNudgePrefs.fromJson(j['water'] as Map<String, dynamic>?),
      streakAtRisk: StreakRiskPrefs.fromJson(
          j['streak_at_risk'] as Map<String, dynamic>?),
      weight: WeightNudgePrefs.fromJson(j['weight'] as Map<String, dynamic>?),
      moodCheckin: MoodCheckinPrefs.fromJson(
          j['mood_checkin'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'habits': habits,
        'meals': meals.toJson(),
        'water': water.toJson(),
        'streak_at_risk': streakAtRisk.toJson(),
        'weight': weight.toJson(),
        'mood_checkin': moodCheckin.toJson(),
      };

  NotificationPrefs copyWith({
    bool? habits,
    MealPrefs? meals,
    WaterNudgePrefs? water,
    StreakRiskPrefs? streakAtRisk,
    WeightNudgePrefs? weight,
    MoodCheckinPrefs? moodCheckin,
  }) =>
      NotificationPrefs(
        habits: habits ?? this.habits,
        meals: meals ?? this.meals,
        water: water ?? this.water,
        streakAtRisk: streakAtRisk ?? this.streakAtRisk,
        weight: weight ?? this.weight,
        moodCheckin: moodCheckin ?? this.moodCheckin,
      );
}

/// Recurring mood check-in nudge. Mirrors [WaterNudgePrefs] — an evenly-spaced
/// chain through the waking-hours window, every [intervalHours].
class MoodCheckinPrefs {
  final bool enabled;
  final int intervalHours; // typically 2
  final int startHour;     // 24h
  final int endHour;       // 24h

  const MoodCheckinPrefs({
    required this.enabled,
    required this.intervalHours,
    required this.startHour,
    required this.endHour,
  });

  static const defaults = MoodCheckinPrefs(
    enabled: true,
    intervalHours: 2,
    startHour: 8,
    endHour: 22,
  );

  factory MoodCheckinPrefs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    return MoodCheckinPrefs(
      enabled: j['enabled'] as bool? ?? true,
      intervalHours: (j['interval_hours'] as num?)?.toInt() ?? 2,
      startHour: (j['start_hour'] as num?)?.toInt() ?? 8,
      endHour: (j['end_hour'] as num?)?.toInt() ?? 22,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'interval_hours': intervalHours,
        'start_hour': startHour,
        'end_hour': endHour,
      };

  MoodCheckinPrefs copyWith({
    bool? enabled,
    int? intervalHours,
    int? startHour,
    int? endHour,
  }) =>
      MoodCheckinPrefs(
        enabled: enabled ?? this.enabled,
        intervalHours: intervalHours ?? this.intervalHours,
        startHour: startHour ?? this.startHour,
        endHour: endHour ?? this.endHour,
      );
}

class MealPrefs {
  final bool enabled;

  /// `MealTimeSlot → "HH:mm"` or null (slot has no scheduled reminder).
  final Map<MealTimeSlot, String?> slots;

  const MealPrefs({required this.enabled, required this.slots});

  static const defaults = MealPrefs(
    enabled: true,
    slots: {
      MealTimeSlot.breakfast: '08:00',
      MealTimeSlot.lunch: '13:00',
      MealTimeSlot.dinner: '20:00',
      MealTimeSlot.preWorkout: null,
      MealTimeSlot.postWorkout: null,
      MealTimeSlot.snack: null,
    },
  );

  factory MealPrefs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    final slotsRaw = (j['slots'] as Map?)?.cast<String, dynamic>() ?? {};
    return MealPrefs(
      enabled: j['enabled'] as bool? ?? true,
      slots: {
        for (final s in MealTimeSlot.values)
          s: slotsRaw[slotKey(s)] as String?,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'slots': {
          for (final entry in slots.entries) slotKey(entry.key): entry.value,
        },
      };

  MealPrefs copyWith({bool? enabled, Map<MealTimeSlot, String?>? slots}) =>
      MealPrefs(enabled: enabled ?? this.enabled, slots: slots ?? this.slots);

  MealPrefs withSlot(MealTimeSlot slot, String? time) {
    final m = {...slots, slot: time};
    return copyWith(slots: m);
  }

  /// Snake-case key used in the JSONB column and as the notification slot id.
  static String slotKey(MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast => 'breakfast',
        MealTimeSlot.lunch => 'lunch',
        MealTimeSlot.dinner => 'dinner',
        MealTimeSlot.preWorkout => 'pre_workout',
        MealTimeSlot.postWorkout => 'post_workout',
        MealTimeSlot.snack => 'snack',
      };
}

class WaterNudgePrefs {
  final bool enabled;
  final int intervalHours; // 1-6 typical
  final int startHour;     // 24h
  final int endHour;       // 24h

  const WaterNudgePrefs({
    required this.enabled,
    required this.intervalHours,
    required this.startHour,
    required this.endHour,
  });

  static const defaults = WaterNudgePrefs(
    enabled: false,
    intervalHours: 2,
    startHour: 9,
    endHour: 21,
  );

  factory WaterNudgePrefs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    return WaterNudgePrefs(
      enabled: j['enabled'] as bool? ?? false,
      intervalHours: (j['interval_hours'] as num?)?.toInt() ?? 2,
      startHour: (j['start_hour'] as num?)?.toInt() ?? 9,
      endHour: (j['end_hour'] as num?)?.toInt() ?? 21,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'interval_hours': intervalHours,
        'start_hour': startHour,
        'end_hour': endHour,
      };

  WaterNudgePrefs copyWith({
    bool? enabled,
    int? intervalHours,
    int? startHour,
    int? endHour,
  }) =>
      WaterNudgePrefs(
        enabled: enabled ?? this.enabled,
        intervalHours: intervalHours ?? this.intervalHours,
        startHour: startHour ?? this.startHour,
        endHour: endHour ?? this.endHour,
      );
}

class StreakRiskPrefs {
  final bool enabled;
  final int hour;
  final int minute;

  const StreakRiskPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static const defaults = StreakRiskPrefs(enabled: true, hour: 20, minute: 0);

  factory StreakRiskPrefs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    return StreakRiskPrefs(
      enabled: j['enabled'] as bool? ?? true,
      hour: (j['hour'] as num?)?.toInt() ?? 20,
      minute: (j['minute'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };

  StreakRiskPrefs copyWith({bool? enabled, int? hour, int? minute}) =>
      StreakRiskPrefs(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

class WeightNudgePrefs {
  final bool enabled;
  final int weekday; // 1=Mon … 7=Sun
  final int hour;
  final int minute;

  const WeightNudgePrefs({
    required this.enabled,
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  static const defaults =
      WeightNudgePrefs(enabled: true, weekday: 7, hour: 9, minute: 0);

  factory WeightNudgePrefs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    return WeightNudgePrefs(
      enabled: j['enabled'] as bool? ?? true,
      weekday: (j['weekday'] as num?)?.toInt() ?? 7,
      hour: (j['hour'] as num?)?.toInt() ?? 9,
      minute: (j['minute'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'weekday': weekday,
        'hour': hour,
        'minute': minute,
      };

  WeightNudgePrefs copyWith({
    bool? enabled,
    int? weekday,
    int? hour,
    int? minute,
  }) =>
      WeightNudgePrefs(
        enabled: enabled ?? this.enabled,
        weekday: weekday ?? this.weekday,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}
