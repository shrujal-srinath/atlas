import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/food/domain/food.dart' show Nutrients;
import '../../features/food/domain/meal_entry.dart';
import '../../shared/models/models.dart';

/// Global dev-mode flag — bypasses Supabase auth and injects mock data.
final devModeProvider = StateProvider<bool>((_) => false);

// ── Mock user ──────────────────────────────────────────────────

const mockUser = AppUser(
  id: 'dev-user-000',
  name: 'Shrujal',
  currentPhase: 'Rehab + Bulk',
  dailyCalorieTarget: 3000,
  dailyProteinTarget: 180,
  dailyCarbsTarget: 350,
  dailyFatTarget: 80,
  dailyFiberTarget: 30,
  bodyWeightGoal: 'gain',
  targetBodyWeight: 78,
  heightCm: 180,
  weightKg: 74,
  age: 22,
  gender: 'male',
  activityLevel: 'very_active',
  waterTargetMl: 3500,
);

// ── Mock habits ────────────────────────────────────────────────

const _uid = 'dev-user-000';
const _allDays = [1, 2, 3, 4, 5, 6, 7];

List<Habit> get mockHabits => const [
      // Morning — Athletic
      Habit(
        id: 'h1', userId: _uid, name: 'Morning Run',
        icon: 'run', sectionId: 'athletic', type: HabitType.positive,
        daysOfWeek: _allDays, goalValue: 30, goalType: GoalType.durationMin,
        effortRatingEnabled: true, noteEnabled: false, isArchived: false,
        timePeriod: TimePeriod.morning, scheduledTime: '06:30',
      ),
      Habit(
        id: 'h2', userId: _uid, name: 'Strength Training',
        icon: 'dumbbell', sectionId: 'athletic', type: HabitType.positive,
        daysOfWeek: [1, 3, 5], goalValue: 45, goalType: GoalType.durationMin,
        effortRatingEnabled: true, noteEnabled: true, isArchived: false,
        timePeriod: TimePeriod.morning, scheduledTime: '07:15',
      ),
      Habit(
        id: 'h3', userId: _uid, name: 'Stretching',
        icon: 'stretch', sectionId: 'athletic', type: HabitType.positive,
        daysOfWeek: _allDays, goalValue: 15, goalType: GoalType.durationMin,
        effortRatingEnabled: false, noteEnabled: false, isArchived: false,
        timePeriod: TimePeriod.morning, scheduledTime: '08:00',
      ),

      // Afternoon — Building
      Habit(
        id: 'h4', userId: _uid, name: 'Deep Work — Code',
        icon: 'code', sectionId: 'mind', type: HabitType.positive,
        daysOfWeek: [1, 2, 3, 4, 5], goalValue: 90, goalType: GoalType.durationMin,
        effortRatingEnabled: true, noteEnabled: true, isArchived: false,
        timePeriod: TimePeriod.afternoon, scheduledTime: '13:00',
        skillCategory: 'Engineering',
      ),
      Habit(
        id: 'h5', userId: _uid, name: 'Read',
        icon: 'book', sectionId: 'mind', type: HabitType.positive,
        daysOfWeek: _allDays, goalValue: 20, goalType: GoalType.durationMin,
        effortRatingEnabled: false, noteEnabled: true, isArchived: false,
        timePeriod: TimePeriod.afternoon, scheduledTime: '15:00',
        skillCategory: 'Learning',
      ),

      // Evening — Breaking + Athletic
      Habit(
        id: 'h6', userId: _uid, name: 'No Phone After 10',
        icon: 'phone', sectionId: 'body', type: HabitType.negative,
        daysOfWeek: _allDays,
        effortRatingEnabled: false, noteEnabled: false, isArchived: false,
        timePeriod: TimePeriod.evening, scheduledTime: '22:00',
      ),
      Habit(
        id: 'h7', userId: _uid, name: 'Ice Bath',
        icon: 'snowflake', sectionId: 'athletic', type: HabitType.positive,
        daysOfWeek: [1, 3, 5, 7], goalValue: 3, goalType: GoalType.durationMin,
        effortRatingEnabled: true, noteEnabled: false, isArchived: false,
        timePeriod: TimePeriod.evening, scheduledTime: '20:00',
      ),
      Habit(
        id: 'h8', userId: _uid, name: 'No Junk Food',
        icon: 'pizza', sectionId: 'body', type: HabitType.negative,
        daysOfWeek: _allDays,
        effortRatingEnabled: false, noteEnabled: false, isArchived: false,
        timePeriod: TimePeriod.evening,
      ),
    ];

// ── Mock logs ──────────────────────────────────────────────────

/// Generates realistic recent logs — some habits completed, some not,
/// with a believable streak pattern over the last 14 days.
List<HabitLog> generateMockLogs() {
  final now = DateTime.now();
  final logs = <HabitLog>[];
  final habits = mockHabits;

  for (int daysAgo = 0; daysAgo < 14; daysAgo++) {
    final day = DateTime(now.year, now.month, now.day - daysAgo);
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final dow = day.weekday;

    for (final h in habits) {
      if (!h.daysOfWeek.contains(dow)) continue;

      // Today: first 3 habits done, rest pending
      // Yesterday+: ~75% completion rate for streaks
      bool completed;
      if (daysAgo == 0) {
        completed = ['h1', 'h2', 'h3', 'h6'].contains(h.id);
      } else {
        // Deterministic pseudo-random based on habit+day
        final seed = h.id.hashCode + daysAgo;
        completed = seed % 4 != 0; // ~75% done
      }

      if (completed) {
        logs.add(HabitLog(
          id: 'log-${h.id}-$dateStr',
          habitId: h.id,
          userId: _uid,
          date: dateStr,
          completed: true,
          effortRating: h.effortRatingEnabled ? (3 + (daysAgo % 3)) : null,
          urgeOnly: false,
          actualValue: h.goalValue, // full credit on a completed numeric task
        ));
      } else if (daysAgo == 0 &&
          h.goalType != null &&
          (h.goalValue ?? 0) > 0) {
        // Show off the new partial-progress UI: a couple of today's
        // numeric tasks land at ~50% of their goal.
        final partial = switch (h.id) {
          'h4' => h.goalValue! * 0.5,   // Deep Work — 45 of 90 min
          'h5' => h.goalValue! * 0.6,   // Read — 12 of 20 min
          _ => null,
        };
        if (partial != null) {
          logs.add(HabitLog(
            id: 'log-${h.id}-$dateStr',
            habitId: h.id,
            userId: _uid,
            date: dateStr,
            completed: false,
            urgeOnly: false,
            actualValue: partial,
          ));
        }
      }
    }
  }
  return logs;
}

// ── Mock food entries (today's diary) ──────────────────────────
//
// Realistic bulking day at ~75% of the 3000 kcal / 180g protein target so
// the home FuelCard + diary hero card + body section show meaningful
// partial progress instead of zeros.

MealEntry _entry({
  required String id,
  required String name,
  required MealTimeSlot slot,
  required DateTime date,
  required double qty,
  required String unit,
  required double kcal,
  required double protein,
  required double carbs,
  required double fat,
  double fiber = 0,
}) =>
    MealEntry(
      id: id,
      userId: _uid,
      foodId: null,
      name: name,
      date: date,
      slot: slot,
      qty: qty,
      unit: unit,
      totals: Nutrients(
        kcal: kcal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        fiberG: fiber,
      ),
    );

List<MealEntry> generateMockFoodEntries(DateTime date) {
  final today = DateTime.now();
  final isToday = date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
  if (!isToday) return const [];
  final d = DateTime(date.year, date.month, date.day);
  return [
    // Breakfast — ~640 kcal, ~40g protein
    _entry(id: 'mf-1', name: 'Oats porridge',     slot: MealTimeSlot.breakfast, date: d, qty: 250, unit: 'g',   kcal: 188, protein: 6,  carbs: 33, fat: 4,  fiber: 4),
    _entry(id: 'mf-2', name: 'Boiled eggs (2)',   slot: MealTimeSlot.breakfast, date: d, qty: 100, unit: 'g',   kcal: 155, protein: 13, carbs: 1,  fat: 11),
    _entry(id: 'mf-3', name: 'Whey shake (milk)', slot: MealTimeSlot.breakfast, date: d, qty: 1,   unit: 'scoop', kcal: 220, protein: 28, carbs: 7,  fat: 4),
    _entry(id: 'mf-4', name: 'Toned milk',        slot: MealTimeSlot.breakfast, date: d, qty: 250, unit: 'ml',  kcal: 125, protein: 8,  carbs: 12, fat: 4),

    // Pre-workout — ~110 kcal, ~1g protein
    _entry(id: 'mf-5', name: 'Banana',            slot: MealTimeSlot.preWorkout, date: d, qty: 120, unit: 'g',  kcal: 107, protein: 1,  carbs: 28, fat: 0),
    _entry(id: 'mf-6', name: 'Black coffee',      slot: MealTimeSlot.preWorkout, date: d, qty: 150, unit: 'ml', kcal: 2,   protein: 0,  carbs: 0,  fat: 0),

    // Lunch — ~745 kcal, ~42g protein
    _entry(id: 'mf-7',  name: 'Basmati rice',      slot: MealTimeSlot.lunch, date: d, qty: 200, unit: 'g',     kcal: 242, protein: 5,  carbs: 50, fat: 1),
    _entry(id: 'mf-8',  name: 'Chicken curry',     slot: MealTimeSlot.lunch, date: d, qty: 200, unit: 'g',     kcal: 340, protein: 32, carbs: 8,  fat: 20),
    _entry(id: 'mf-9',  name: 'Mixed veg curry',   slot: MealTimeSlot.lunch, date: d, qty: 150, unit: 'g',     kcal: 165, protein: 5,  carbs: 16, fat: 10, fiber: 5),

    // Snack — ~250 kcal, ~18g protein
    _entry(id: 'mf-10', name: 'Greek yogurt',     slot: MealTimeSlot.snack, date: d, qty: 170, unit: 'g',     kcal: 165, protein: 15, carbs: 7, fat: 9),
    _entry(id: 'mf-11', name: 'Almonds',          slot: MealTimeSlot.snack, date: d, qty: 15,  unit: 'g',     kcal: 87,  protein: 3,  carbs: 3, fat: 8,  fiber: 2),

    // Dinner — ~640 kcal, ~28g protein
    _entry(id: 'mf-12', name: 'Roti (wheat)',     slot: MealTimeSlot.dinner, date: d, qty: 120, unit: 'g',    kcal: 360, protein: 11, carbs: 56, fat: 11, fiber: 9),
    _entry(id: 'mf-13', name: 'Paneer butter masala', slot: MealTimeSlot.dinner, date: d, qty: 130, unit: 'g', kcal: 286, protein: 12, carbs: 13, fat: 21),
  ];
  // Daily total ≈ 2440 kcal · ~144g protein · ~234g carbs · ~103g fat · ~20g fiber
}
