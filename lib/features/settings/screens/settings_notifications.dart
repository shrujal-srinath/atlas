part of 'settings_screen.dart';

// ════════════════════════════════════════════════════════════════════
// NOTIFICATIONS SECTION
// ════════════════════════════════════════════════════════════════════

class _NotificationsSection extends ConsumerWidget {
  final AppUser? user;
  final Future<void> Function(Map<String, dynamic>) patch;
  const _NotificationsSection({required this.user, required this.patch});

  String _hhmm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _savePrefs(NotificationPrefs prefs) =>
      patch({'notification_prefs': prefs.toJson()});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final u = user;
    final prefs = ref.watch(notificationPrefsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master + global
        _Card(children: [
          _SwitchRow(
            label: 'Notifications',
            sub: 'Master switch for every reminder',
            value: u?.notificationsEnabled ?? true,
            onChanged: (v) async {
              await patch({'notifications_enabled': v});
              if (v) {
                // Prompt for OS permission at the moment of enabling; the prefs
                // change drives reminderRunnerProvider to (re)schedule.
                await NotificationService.instance.ensurePermissions();
              } else {
                await NotificationService.instance.cancelAll();
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Quiet hours',
            value: (u?.quietHoursStart == null || u?.quietHoursEnd == null)
                ? 'Off'
                : '${u!.quietHoursStart} → ${u.quietHoursEnd}',
            onTap: () => _editQuietHoursInline(context, ref, u),
          ),
        ]),
        const SizedBox(height: 10),

        // Categories
        _Card(children: [
          _SwitchRow(
            label: 'Habits',
            sub: 'Daily nudges for each scheduled habit',
            value: prefs.habits,
            onChanged: (v) => _savePrefs(prefs.copyWith(habits: v)),
          ),
          _Divider(),
          _SwitchRow(
            label: 'Meals',
            sub: 'Reminders for each meal slot',
            value: prefs.meals.enabled,
            onChanged: (v) =>
                _savePrefs(prefs.copyWith(meals: prefs.meals.copyWith(enabled: v))),
          ),
          if (prefs.meals.enabled) ...[
            _Divider(),
            ..._mealSlotRows(context, prefs),
          ],
          _Divider(),
          _SwitchRow(
            label: 'Water',
            sub: 'Periodic hydration nudges during waking hours',
            value: prefs.water.enabled,
            onChanged: (v) =>
                _savePrefs(prefs.copyWith(water: prefs.water.copyWith(enabled: v))),
          ),
          if (prefs.water.enabled) ...[
            _Divider(),
            _Row(
              label: 'Every',
              value: '${prefs.water.intervalHours}h',
              onTap: () => _pickInterval(context, prefs),
            ),
            _Divider(),
            _Row(
              label: 'Window',
              value:
                  '${_hhmm(prefs.water.startHour, 0)} → ${_hhmm(prefs.water.endHour, 0)}',
              onTap: () => _pickWindow(context, prefs),
            ),
          ],
          _Divider(),
          _SwitchRow(
            label: 'Mood check-ins',
            sub: 'Periodic prompts to log your mood through the day',
            value: prefs.moodCheckin.enabled,
            onChanged: (v) => _savePrefs(prefs.copyWith(
                moodCheckin: prefs.moodCheckin.copyWith(enabled: v))),
          ),
          if (prefs.moodCheckin.enabled) ...[
            _Divider(),
            _Row(
              label: 'Every',
              value: '${prefs.moodCheckin.intervalHours}h',
              onTap: () => _pickMoodInterval(context, prefs),
            ),
            _Divider(),
            _Row(
              label: 'Window',
              value:
                  '${_hhmm(prefs.moodCheckin.startHour, 0)} → ${_hhmm(prefs.moodCheckin.endHour, 0)}',
              onTap: () => _pickMoodWindow(context, prefs),
            ),
          ],
          _Divider(),
          _SwitchRow(
            label: 'Streak at risk',
            sub: 'Evening check for streaks needing a log',
            value: prefs.streakAtRisk.enabled,
            onChanged: (v) => _savePrefs(prefs.copyWith(
                streakAtRisk: prefs.streakAtRisk.copyWith(enabled: v))),
          ),
          if (prefs.streakAtRisk.enabled) ...[
            _Divider(),
            _Row(
              label: 'Check time',
              value: _hhmm(prefs.streakAtRisk.hour, prefs.streakAtRisk.minute),
              onTap: () => _pickStreakTime(context, prefs),
            ),
          ],
          _Divider(),
          _SwitchRow(
            label: 'Weekly weight',
            sub: 'One nudge per week if no weight is logged',
            value: prefs.weight.enabled,
            onChanged: (v) => _savePrefs(prefs.copyWith(
                weight: prefs.weight.copyWith(enabled: v))),
          ),
          if (prefs.weight.enabled) ...[
            _Divider(),
            _Row(
              label: 'When',
              value:
                  '${_weekdayLabel(prefs.weight.weekday)} · ${_hhmm(prefs.weight.hour, prefs.weight.minute)}',
              onTap: () => _pickWeightTime(context, prefs),
            ),
          ],
        ]),

        // Helpful note when the master is off — explains why the categories
        // look ignored.
        if (!(u?.notificationsEnabled ?? true)) ...[
          const SizedBox(height: 8),
          Text(
            'Master toggle is off — no reminders will fire regardless of the per-category settings above.',
            style: context.t.meta.copyWith(color: c.textMuted),
          ),
        ],
      ],
    );
  }

  List<Widget> _mealSlotRows(BuildContext context, NotificationPrefs prefs) {
    final out = <Widget>[];
    final order = const [
      MealTimeSlot.breakfast,
      MealTimeSlot.preWorkout,
      MealTimeSlot.lunch,
      MealTimeSlot.snack,
      MealTimeSlot.postWorkout,
      MealTimeSlot.dinner,
    ];
    for (int i = 0; i < order.length; i++) {
      final slot = order[i];
      final value = prefs.meals.slots[slot];
      out.add(_Row(
        label: _slotLabel(slot),
        value: value ?? 'Off',
        onTap: () => _pickMealSlotTime(context, prefs, slot),
      ));
      if (i != order.length - 1) out.add(_Divider());
    }
    return out;
  }

  Future<void> _pickMealSlotTime(
    BuildContext context,
    NotificationPrefs prefs,
    MealTimeSlot slot,
  ) async {
    final current = prefs.meals.slots[slot] ?? '08:00';
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.last) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: '${_slotLabel(slot).toUpperCase()} REMINDER',
    );
    if (picked == null) return;
    // Long-press on the picker would let user clear; tapping shorthand:
    // we provide a Cancel/Off path via a dialog after picking? Keep MVP simple:
    // any time picked turns the slot on; toggling Meals off cancels all.
    final next = prefs.meals.withSlot(
      slot,
      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
    await _savePrefs(prefs.copyWith(meals: next));
  }

  Future<void> _pickInterval(BuildContext context, NotificationPrefs prefs) async {
    final c = context.c;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: c.background,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Hydration check every',
                style: ctx.t.h2.copyWith(color: ctx.c.textPrimary)),
            const SizedBox(height: 8),
            for (final h in const [1, 2, 3, 4, 6])
              ListTile(
                title: Text('${h}h'),
                trailing: h == prefs.water.intervalHours
                    ? Icon(LucideIcons.check, color: c.accent, size: 18)
                    : null,
                onTap: () => Navigator.of(ctx).pop(h),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _savePrefs(
        prefs.copyWith(water: prefs.water.copyWith(intervalHours: picked)));
  }

  Future<void> _pickWindow(BuildContext context, NotificationPrefs prefs) async {
    final start = await showTimePicker(
      context: context,
      helpText: 'WATER WINDOW START',
      initialTime: TimeOfDay(hour: prefs.water.startHour, minute: 0),
    );
    if (start == null) return;
    if (!context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'WATER WINDOW END',
      initialTime: TimeOfDay(hour: prefs.water.endHour, minute: 0),
    );
    if (end == null) return;
    if (end.hour <= start.hour) return;
    await _savePrefs(prefs.copyWith(
      water: prefs.water.copyWith(
        startHour: start.hour,
        endHour: end.hour,
      ),
    ));
  }

  Future<void> _pickMoodInterval(
      BuildContext context, NotificationPrefs prefs) async {
    final c = context.c;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: c.background,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Mood check-in every',
                style: ctx.t.h2.copyWith(color: ctx.c.textPrimary)),
            const SizedBox(height: 8),
            for (final h in const [1, 2, 3, 4])
              ListTile(
                title: Text('${h}h'),
                trailing: h == prefs.moodCheckin.intervalHours
                    ? Icon(LucideIcons.check, color: c.accent, size: 18)
                    : null,
                onTap: () => Navigator.of(ctx).pop(h),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _savePrefs(prefs.copyWith(
        moodCheckin: prefs.moodCheckin.copyWith(intervalHours: picked)));
  }

  Future<void> _pickMoodWindow(
      BuildContext context, NotificationPrefs prefs) async {
    final start = await showTimePicker(
      context: context,
      helpText: 'MOOD WINDOW START',
      initialTime: TimeOfDay(hour: prefs.moodCheckin.startHour, minute: 0),
    );
    if (start == null) return;
    if (!context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'MOOD WINDOW END',
      initialTime: TimeOfDay(hour: prefs.moodCheckin.endHour, minute: 0),
    );
    if (end == null) return;
    if (end.hour <= start.hour) return;
    await _savePrefs(prefs.copyWith(
      moodCheckin: prefs.moodCheckin.copyWith(
        startHour: start.hour,
        endHour: end.hour,
      ),
    ));
  }

  Future<void> _pickStreakTime(
      BuildContext context, NotificationPrefs prefs) async {
    final picked = await showTimePicker(
      context: context,
      helpText: 'STREAK CHECK',
      initialTime: TimeOfDay(
          hour: prefs.streakAtRisk.hour, minute: prefs.streakAtRisk.minute),
    );
    if (picked == null) return;
    await _savePrefs(prefs.copyWith(
      streakAtRisk: prefs.streakAtRisk.copyWith(
        hour: picked.hour,
        minute: picked.minute,
      ),
    ));
  }

  Future<void> _pickWeightTime(
      BuildContext context, NotificationPrefs prefs) async {
    final c = context.c;
    final picked = await showModalBottomSheet<({int weekday, int hour, int minute})>(
      context: context,
      backgroundColor: c.background,
      isScrollControlled: true,
      builder: (ctx) {
        int weekday = prefs.weight.weekday;
        int hour = prefs.weight.hour;
        int minute = prefs.weight.minute;
        return StatefulBuilder(builder: (ctx, setSt) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.screenH,
              16,
              AppSpace.screenH,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Weekly weight reminder',
                    style: ctx.t.h2.copyWith(color: ctx.c.textPrimary)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  children: [
                    for (int d = 1; d <= 7; d++)
                      ChoiceChip(
                        label: Text(_weekdayLabel(d)),
                        selected: weekday == d,
                        onSelected: (_) => setSt(() => weekday = d),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(LucideIcons.clock, size: 16),
                  label: Text('Time · ${_hhmmRaw(hour, minute)}'),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(hour: hour, minute: minute),
                    );
                    if (t != null) {
                      setSt(() {
                        hour = t.hour;
                        minute = t.minute;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(
                      (weekday: weekday, hour: hour, minute: minute)),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        });
      },
    );
    if (picked == null) return;
    await _savePrefs(prefs.copyWith(
      weight: prefs.weight.copyWith(
        weekday: picked.weekday,
        hour: picked.hour,
        minute: picked.minute,
      ),
    ));
  }

  Future<void> _editQuietHoursInline(
      BuildContext context, WidgetRef ref, AppUser? u) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
      helpText: 'QUIET HOURS START',
    );
    if (start == null) return;
    if (!context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: 'QUIET HOURS END',
    );
    if (end == null) return;
    String h(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await ref.read(userActionsProvider.notifier).update({
      'quiet_hours_start': h(start),
      'quiet_hours_end': h(end),
    });
  }

  static String _slotLabel(MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast => 'Breakfast',
        MealTimeSlot.preWorkout => 'Pre-workout',
        MealTimeSlot.lunch => 'Lunch',
        MealTimeSlot.snack => 'Snack',
        MealTimeSlot.postWorkout => 'Post-workout',
        MealTimeSlot.dinner => 'Dinner',
      };

  static String _weekdayLabel(int d) => switch (d) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        _ => 'Sun',
      };

  static String _hhmmRaw(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
