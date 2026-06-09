import '../../shared/models/models.dart';

/// Preset habit a user can pick during onboarding. Maps cleanly to a Habit
/// insert payload — see [toInsertPayload].
class HabitTemplate {
  final String id; // local key
  final String name;
  final String icon;
  final String colorKey;
  final HabitSection section;
  final HabitType type;
  final TimePeriod? timePeriod;
  final String? scheduledTime;
  final FrequencyMode frequencyMode;
  final List<int> daysOfWeek;
  final GoalType? goalType;
  final double? goalValue;

  const HabitTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorKey,
    required this.section,
    required this.type,
    this.timePeriod,
    this.scheduledTime,
    this.frequencyMode = FrequencyMode.everyDay,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.goalType,
    this.goalValue,
  });

  Map<String, dynamic> toInsertPayload(String userId) => {
        'user_id': userId,
        'name': name,
        'icon': icon,
        'color_key': colorKey,
        'section': section.name,
        'type': type.name,
        'days_of_week': daysOfWeek,
        'frequency_mode': Habit.freqToDb(frequencyMode),
        'effort_rating_enabled': false,
        'note_enabled': false,
        'photo_proof_enabled': false,
        'is_archived': false,
        'reminder_enabled': false,
        'end_mode': 'off',
        if (timePeriod != null) 'time_period': timePeriod!.name,
        if (scheduledTime != null) 'scheduled_time': scheduledTime,
        if (goalType != null) 'goal_type': goalType!.name,
        if (goalValue != null) 'goal_value': goalValue,
      };
}

const kStarterTemplates = <HabitTemplate>[
  // Athletic
  HabitTemplate(
    id: 'run',
    name: 'Morning run',
    icon: 'run',
    colorKey: 'athletic',
    section: HabitSection.athletic,
    type: HabitType.positive,
    timePeriod: TimePeriod.morning,
    scheduledTime: '06:30',
    goalType: GoalType.durationMin,
    goalValue: 30,
  ),
  HabitTemplate(
    id: 'lift',
    name: 'Strength session',
    icon: 'dumbbell',
    colorKey: 'athletic',
    section: HabitSection.athletic,
    type: HabitType.positive,
    timePeriod: TimePeriod.evening,
    frequencyMode: FrequencyMode.specificDays,
    daysOfWeek: [1, 3, 5],
    goalType: GoalType.durationMin,
    goalValue: 60,
  ),
  HabitTemplate(
    id: 'stretch',
    name: 'Stretching',
    icon: 'stretch',
    colorKey: 'athletic',
    section: HabitSection.athletic,
    type: HabitType.positive,
    timePeriod: TimePeriod.morning,
    goalType: GoalType.durationMin,
    goalValue: 15,
  ),
  HabitTemplate(
    id: 'hydrate',
    name: 'Hit hydration goal',
    icon: 'droplet',
    colorKey: 'athletic',
    section: HabitSection.athletic,
    type: HabitType.positive,
    goalType: GoalType.litres,
    goalValue: 3,
  ),

  // Building
  HabitTemplate(
    id: 'read',
    name: 'Read 20 min',
    icon: 'book',
    colorKey: 'building',
    section: HabitSection.mind,
    type: HabitType.positive,
    timePeriod: TimePeriod.evening,
    goalType: GoalType.durationMin,
    goalValue: 20,
  ),
  HabitTemplate(
    id: 'deep_work',
    name: 'Deep work',
    icon: 'code',
    colorKey: 'building',
    section: HabitSection.mind,
    type: HabitType.positive,
    timePeriod: TimePeriod.afternoon,
    scheduledTime: '13:00',
    goalType: GoalType.durationMin,
    goalValue: 90,
  ),
  HabitTemplate(
    id: 'meditate',
    name: 'Meditate',
    icon: 'leaf',
    colorKey: 'building',
    section: HabitSection.mind,
    type: HabitType.positive,
    timePeriod: TimePeriod.morning,
    goalType: GoalType.durationMin,
    goalValue: 10,
  ),
  HabitTemplate(
    id: 'journal',
    name: 'Evening journal',
    icon: 'pen',
    colorKey: 'building',
    section: HabitSection.mind,
    type: HabitType.positive,
    timePeriod: TimePeriod.evening,
  ),

  // Breaking
  HabitTemplate(
    id: 'no_phone',
    name: 'No phone after 10pm',
    icon: 'phone',
    colorKey: 'breaking',
    section: HabitSection.body,
    type: HabitType.negative,
    timePeriod: TimePeriod.evening,
    scheduledTime: '22:00',
  ),
  HabitTemplate(
    id: 'no_junk',
    name: 'No junk food',
    icon: 'pizza',
    colorKey: 'breaking',
    section: HabitSection.body,
    type: HabitType.negative,
  ),
  HabitTemplate(
    id: 'no_doom',
    name: 'No doomscroll',
    icon: 'gamepad',
    colorKey: 'breaking',
    section: HabitSection.body,
    type: HabitType.negative,
  ),
  HabitTemplate(
    id: 'no_alcohol',
    name: 'No alcohol',
    icon: 'beer',
    colorKey: 'breaking',
    section: HabitSection.body,
    type: HabitType.negative,
  ),
];
