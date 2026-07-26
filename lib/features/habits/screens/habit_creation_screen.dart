import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../food/domain/food.dart'; // Nutrients
import '../../food/domain/meal_entry.dart'; // MealTimeSlotX, kDiarySlotOrder
import '../../food/providers/food_providers.dart'; // foodRepositoryProvider
import '../../food/screens/food_detail_screen.dart'; // FoodSelection
import '../../food/screens/food_search_sheet.dart'; // FoodSearchSheet
import '../models/habit_food_link.dart';
import '../providers/habit_provider.dart';
import '../../home/providers/home_providers.dart'; // sectionsProvider
import '../../home/scoring/section_def.dart'; // SectionDef, sectionColorForKey

part 'habit_creation_fields.dart';
part 'habit_creation_rows.dart';
part 'habit_creation_goal_sheet.dart';

const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class HabitCreationScreen extends ConsumerStatefulWidget {
  final Habit? existing;
  final HabitType? initialType;

  const HabitCreationScreen({
    super.key,
    this.existing,
    this.initialType,
  });

  @override
  ConsumerState<HabitCreationScreen> createState() => _HabitCreationScreenState();
}

class _HabitCreationScreenState extends ConsumerState<HabitCreationScreen> {
  final _nameCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final _endDaysCtrl = TextEditingController();
  final _twpCtrl = TextEditingController(text: '3');

  String _iconKey = 'run';
  String _colorKey = 'teal';
  String _sectionId = kAthleticId;
  HabitType _type = HabitType.positive;
  HabitPriority _priority = HabitPriority.normal;
  List<int> _days = [1, 2, 3, 4, 5, 6, 7];
  FrequencyMode _freq = FrequencyMode.everyDay;
  TimePeriod? _timePeriod;
  TimeOfDay? _scheduledTime;
  GoalType? _goalType;
  String? _goalUnit;
  bool _effortRating = false;
  bool _note = false;
  bool _photoProof = false;
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;
  EndMode _endMode = EndMode.off;
  DateTime? _endDate;
  String? _replacementHabitId;
  DateTime? _dueDate;
  bool _showAdvanced = false;
  bool _saving = false;

  HabitFoodLink? _foodLink;
  bool _addingFood = false;

  bool get _isEditing => widget.existing != null;
  bool get _isTodo => _type == HabitType.todo;
  bool get _isBreaking => _type == HabitType.negative;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    if (h != null) {
      _nameCtrl.text = h.name;
      _iconKey = h.icon;
      _colorKey = h.colorKey ?? _colorForSection(h.sectionId.toSectionEnum());
      _sectionId = h.sectionId;
      _type = h.type;
      _priority = h.priority;
      _days = List.of(h.daysOfWeek);
      _freq = h.frequencyMode;
      if (h.timesPerWeek != null) _twpCtrl.text = h.timesPerWeek.toString();
      _timePeriod = h.timePeriod;
      if (h.scheduledTime != null) _scheduledTime = _parseHHmm(h.scheduledTime!);
      _goalType = h.goalType;
      _goalUnit = h.goalUnit;
      if (h.goalValue != null) _goalCtrl.text = _fmtNum(h.goalValue!);
      _effortRating = h.effortRatingEnabled;
      _note = h.noteEnabled;
      _photoProof = h.photoProofEnabled;
      _reminderEnabled = h.reminderEnabled;
      if (h.reminderTime != null) _reminderTime = _parseHHmm(h.reminderTime!);
      _endMode = h.endMode;
      _endDate = h.endDate;
      if (h.endAfterDays != null) _endDaysCtrl.text = h.endAfterDays.toString();
      _replacementHabitId = h.replacementHabitId;
      _dueDate = h.dueDate;
      if (h.skillCategory != null) _skillCtrl.text = h.skillCategory!;
      _foodLink = HabitFoodLink.fromRaw(h.foodLinkRaw);
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
      _sectionId = switch (_type) {
        HabitType.positive => kAthleticId,
        HabitType.negative => kBodyId,
        HabitType.todo => kMindId,
      };
      _colorKey = _colorForSection(_sectionId.toSectionEnum());
      if (_isTodo) {
        _freq = FrequencyMode.specificDays;
      } else if (_isBreaking) {
        // Negatives are always everyday — no scheduling.
        _freq = FrequencyMode.everyDay;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    _skillCtrl.dispose();
    _endDaysCtrl.dispose();
    _twpCtrl.dispose();
    super.dispose();
  }

  String _colorForSection(HabitSection s) => switch (s) {
        HabitSection.athletic => 'athletic',
        HabitSection.mind => 'building',
        HabitSection.body => 'breaking',
      };

  /// The habit's identity colour — used ONLY where the habit itself is being
  /// previewed (icon tint). Form controls stay on the app accent so the screen
  /// keeps the ATLAS look whatever colour is picked; a teal habit used to turn
  /// the whole form — segmented controls, chips, even the Save button — teal
  /// (NORTHSTAR T3).
  Color get _habitColor => Color(kHabitColorSwatch[_colorKey] ?? 0xFF2DD4BF);

  /// Control accent for every interactive element on this form.
  Color get _accent => context.c.accent;

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  TimeOfDay _parseHHmm(String s) {
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _typeTitle => switch (_type) {
        HabitType.positive => _isEditing ? 'Edit habit' : 'New habit',
        HabitType.negative => _isEditing ? 'Edit habit' : 'New break habit',
        HabitType.todo => _isEditing ? 'Edit todo' : 'New todo',
      };

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Give it a name', isError: true);
      return;
    }
    if (_isTodo && _dueDate == null) {
      _toast('Pick a due date for this todo', isError: true);
      return;
    }
    // A week only has 7 days — anything else can never be completed, which
    // silently breaks that habit's streak/completion math forever.
    if (_freq == FrequencyMode.timesPerWeek) {
      final twp = int.tryParse(_twpCtrl.text);
      if (twp == null || twp < 1 || twp > 7) {
        _toast('Times per week must be between 1 and 7', isError: true);
        return;
      }
    }
    if (_goalType != null && _goalCtrl.text.isNotEmpty) {
      final goal = double.tryParse(_goalCtrl.text);
      if (goal == null || goal <= 0 || goal > 100000) {
        _toast('Enter a valid goal amount', isError: true);
        return;
      }
    }
    if (_endMode == EndMode.afterDays && _endDaysCtrl.text.isNotEmpty) {
      final days = int.tryParse(_endDaysCtrl.text);
      if (days == null || days <= 0 || days > 3650) {
        _toast('Enter a number of days between 1 and 3650', isError: true);
        return;
      }
    }
    setState(() => _saving = true);

    final session = ref.read(sessionProvider);
    final userId = session?.user.id;
    if (!_isEditing && userId == null) {
      _toast('Not signed in', isError: true);
      setState(() => _saving = false);
      return;
    }

    // Resolve days_of_week based on frequency mode.
    final daysToSave = switch (_freq) {
      FrequencyMode.everyDay => const [1, 2, 3, 4, 5, 6, 7],
      FrequencyMode.specificDays => _days,
      FrequencyMode.timesPerWeek => const [1, 2, 3, 4, 5, 6, 7],
    };

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'icon': _iconKey,
      'color_key': _colorKey,
      'section': _sectionId,
      'type': _type.name,
      'days_of_week': daysToSave,
      'frequency_mode': Habit.freqToDb(_freq),
      if (_freq == FrequencyMode.timesPerWeek)
        'times_per_week': int.tryParse(_twpCtrl.text) ?? 3,
      if (_goalType != null && _goalCtrl.text.isNotEmpty)
        'goal_value': double.tryParse(_goalCtrl.text),
      if (_goalType != null) 'goal_type': _goalType!.name,
      // Value is stored in the chosen unit (ratio scoring is unit-agnostic);
      // goal_unit records it so it displays as "8 hr" not "480 min".
      if (_goalType != null && _goalUnit != null) 'goal_unit': _goalUnit,
      'priority': _priority.name,
      'effort_rating_enabled': _effortRating,
      'note_enabled': _note,
      'photo_proof_enabled': _photoProof,
      if (_sectionId == kMindId && _skillCtrl.text.isNotEmpty)
        'skill_category': _skillCtrl.text.trim(),
      if (_replacementHabitId != null)
        'replacement_habit_id': _replacementHabitId,
      'is_archived': false,
      if (_timePeriod != null) 'time_period': _timePeriod!.name,
      if (_scheduledTime != null) 'scheduled_time': _hhmm(_scheduledTime!),
      'reminder_enabled': _reminderEnabled,
      if (_reminderEnabled && _reminderTime != null)
        'reminder_time': _hhmm(_reminderTime!),
      'reminder_days': _reminderEnabled ? daysToSave : <int>[],
      'end_mode': Habit.endToDb(_endMode),
      if (_endMode == EndMode.date && _endDate != null)
        'end_date': _endDate!.toIso8601String().split('T').first,
      if (_endMode == EndMode.afterDays && _endDaysCtrl.text.isNotEmpty)
        'end_after_days': int.tryParse(_endDaysCtrl.text),
      if (_isTodo && _dueDate != null)
        'due_date': _dueDate!.toIso8601String().split('T').first,
    };

    // Only touch the `food_link` column when the feature is actually in play,
    // so tasks that don't use it keep saving even before the DB migration is
    // applied. Send an explicit null only to *clear* a link the task used to
    // have (toggled off on edit). A Flexible link is "in play" with zero
    // items — it's the whole point of Flexible — so isNotEmpty alone would
    // silently drop it, same bug HabitFoodLink.fromRaw had.
    final hasLink = !_isBreaking &&
        _foodLink != null &&
        (_foodLink!.isNotEmpty || _foodLink!.isFlexible);
    final hadLink = widget.existing?.foodLinkRaw != null;
    if (hasLink) {
      payload['food_link'] = _foodLink!.toJson();
    } else if (hadLink) {
      payload['food_link'] = null;
    }

    try {
      String habitId;
      if (_isEditing) {
        habitId = widget.existing!.id;
        await ref
            .read(habitActionsProvider.notifier)
            .updateHabit(habitId, payload);
      } else {
        payload['user_id'] = userId;
        habitId = await ref
            .read(habitActionsProvider.notifier)
            .addHabit(payload);
      }

      // The OS reminder schedule is reconciled centrally: saving invalidates
      // habitsProvider, which reminderRunnerProvider listens to and reconciles
      // (honoring the master switch, the Habits category toggle, and quiet
      // hours). See ReminderScheduler.reconcile.

      if (mounted) context.pop();
    } catch (e) {
      _toast(friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? context.c.negative : context.c.surfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text('Cancel', style: t.body.copyWith(color: c.textMuted)),
        ),
        title: Text(_typeTitle, style: t.h2),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accent),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.screenH, 8, AppSpace.screenH, 64),
        children: [
          // ─── Identity ─────────────────────────────────────────
          _BentoSection(
            title: 'Identity',
            children: [
              _Label('Name'),
              const SizedBox(height: 8),
              _BentoField(
                controller: _nameCtrl,
                autofocus: !_isEditing,
                hint: switch (_type) {
                  HabitType.positive => 'What habit?',
                  HabitType.negative => 'What to avoid?',
                  HabitType.todo => 'What to do?',
                },
              ),
              const SizedBox(height: 16),
              _Label('Icon'),
              const SizedBox(height: 8),
              _IconPicker(
                selected: _iconKey,
                tint: _habitColor,
                onSelect: (k) => setState(() => _iconKey = k),
              ),
              const SizedBox(height: 16),
              _Label('Color'),
              const SizedBox(height: 8),
              _ColorSwatchRow(
                selected: _colorKey,
                onSelect: (k) => setState(() => _colorKey = k),
              ),
            ],
          ),

          // ─── Type & priority ──────────────────────────────────
          _BentoSection(
            title: _isTodo ? 'Priority' : 'Type & priority',
            subtitle: 'How much does this one matter?',
            children: [
              if (!_isTodo) ...[
                _Label('Section'),
                const SizedBox(height: 8),
                _SectionRow(
                  selectedId: _sectionId,
                  onChanged: (id) => setState(() {
                    _sectionId = id;
                    // If user hasn't picked a custom color yet, follow the section.
                    if (_colorKey == 'athletic' ||
                        _colorKey == 'building' ||
                        _colorKey == 'breaking') {
                      _colorKey = _colorForSection(id.toSectionEnum());
                    }
                  }),
                ),
                const SizedBox(height: 16),
              ],
              _Label('Priority'),
              const SizedBox(height: 8),
              _PriorityRow(
                selected: _priority,
                onChanged: (p) => setState(() => _priority = p),
              ),
            ],
          ),

          // ─── Schedule (or due date for todos) ─────────────────
          if (_isTodo)
            _BentoSection(
              title: 'Due date',
              children: [
                _PickerRow(
                  icon: LucideIcons.calendarDays,
                  label: _dueDate == null
                      ? 'Pick a date'
                      : '${_dueDate!.day.toString().padLeft(2, '0')}/'
                          '${_dueDate!.month.toString().padLeft(2, '0')}/'
                          '${_dueDate!.year}',
                  accent: _accent,
                  onTap: _pickDueDate,
                ),
              ],
            )
          else if (_isBreaking)
            _BentoSection(
              title: 'Schedule',
              subtitle: 'Tracked every day',
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.calendarCheck, size: 15, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This runs every day. Each day starts clean — you only '
                        'log a slip if you break it.',
                        style: AppType.meta
                            .copyWith(color: context.c.textMuted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            _BentoSection(
              title: 'Schedule',
              subtitle: 'When and how often',
              children: [
                _Label('Repeat'),
                const SizedBox(height: 8),
                _FreqRow(
                  isEveryDay: _freq == FrequencyMode.everyDay,
                  accent: _accent,
                  onEveryDay: () =>
                      setState(() => _freq = FrequencyMode.everyDay),
                  // Entering "X / week" defaults to flexible count; if the user
                  // already had a weekly cadence, keep their sub-choice.
                  onXWeek: () => setState(() {
                    if (_freq == FrequencyMode.everyDay) {
                      _freq = FrequencyMode.timesPerWeek;
                    }
                  }),
                ),
                if (_freq != FrequencyMode.everyDay) ...[
                  const SizedBox(height: 10),
                  _XWeekModeRow(
                    exactDays: _freq == FrequencyMode.specificDays,
                    accent: _accent,
                    onChanged: (exact) => setState(() => _freq = exact
                        ? FrequencyMode.specificDays
                        : FrequencyMode.timesPerWeek),
                  ),
                  if (_freq == FrequencyMode.specificDays) ...[
                    const SizedBox(height: 10),
                    _DaysRow(
                      selected: _days,
                      accent: _accent,
                      onToggle: (d) => setState(() {
                        if (_days.contains(d)) {
                          _days = _days.where((x) => x != d).toList();
                        } else {
                          _days = [..._days, d]..sort();
                        }
                      }),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    _BentoField(
                      controller: _twpCtrl,
                      hint: '3',
                      suffix: 'times / week',
                      keyboard: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _RestDayHint(controller: _twpCtrl, accent: _accent),
                  ],
                ],
                const SizedBox(height: 16),
                _Label('Do it at'),
                const SizedBox(height: 8),
                _WhenRow(
                  selected: _timePeriod,
                  accent: _accent,
                  onChanged: (p) => setState(() {
                    _timePeriod = p;
                    if (p == null) _scheduledTime = null;
                  }),
                ),
                if (_timePeriod != null) ...[
                  const SizedBox(height: 10),
                  _PickerRow(
                    icon: LucideIcons.clock,
                    label: _scheduledTime == null
                        ? 'Scheduled time (optional)'
                        : _scheduledTime!.format(context),
                    trailing: _scheduledTime != null
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () =>
                                setState(() => _scheduledTime = null),
                          )
                        : null,
                    accent: _accent,
                    onTap: _pickScheduledTime,
                  ),
                ],
              ],
            ),

          // ─── Goal ─────────────────────────────────────────────
          _BentoSection(
            title: 'Goal',
            subtitle: _isBreaking
                ? 'Replacement & how to track'
                : 'How much counts as done',
            children: [
              if (!_isBreaking && _foodLink?.isFlexible == true) ...[
                _Label('Daily goal'),
                const SizedBox(height: 8),
                _MutedHintRow(
                  icon: LucideIcons.target,
                  text: "Off — a flexible meal is simple done/not-done",
                ),
              ] else if (!_isBreaking) ...[
                _Label('Daily goal'),
                const SizedBox(height: 8),
                _PickerRow(
                  icon: LucideIcons.target,
                  label: _goalType == null
                      ? 'Off'
                      : '${_goalCtrl.text.isEmpty ? "—" : _goalCtrl.text} '
                          '${goalUnitLabel(_goalType!, _goalUnit)}',
                  accent: _accent,
                  onTap: _openGoalSheet,
                ),
              ],
              if (_sectionId == kMindId && !_isTodo) ...[
                const SizedBox(height: 14),
                _Label('Skill category'),
                const SizedBox(height: 8),
                _BentoField(
                  controller: _skillCtrl,
                  hint: 'e.g. Programming, Guitar, Cricket',
                ),
              ],
              if (_isBreaking) ...[
                const SizedBox(height: 14),
                _Label('Replace with (optional)'),
                const SizedBox(height: 8),
                _ReplacementPicker(
                  selectedId: _replacementHabitId,
                  accent: _accent,
                  onChanged: (id) =>
                      setState(() => _replacementHabitId = id),
                ),
              ],
            ],
          ),

          // ─── Tracking opts ────────────────────────────────────
          _BentoSection(
            title: 'Tracking',
            subtitle: 'Optional inputs when you log',
            children: [
              _ToggleRow(
                label: 'Effort rating',
                sub: 'Rate how hard it felt (1–5)',
                value: _effortRating,
                accent: _accent,
                onChanged: (v) => setState(() => _effortRating = v),
              ),
              _ToggleRow(
                label: 'Note',
                sub: 'Add a quick note when logging',
                value: _note,
                accent: _accent,
                onChanged: (v) => setState(() => _note = v),
              ),
              _ToggleRow(
                label: 'Photo proof',
                sub: 'Attach a photo to complete',
                value: _photoProof,
                accent: _accent,
                onChanged: (v) => setState(() => _photoProof = v),
              ),
            ],
          ),

          // ─── Auto-log food ────────────────────────────────────
          if (!_isBreaking)
            _BentoSection(
              title: 'Auto-log food',
              subtitle: 'Log food to your diary when you complete this',
              children: [
                _ToggleRow(
                  label: 'Log food when done',
                  sub: _foodLink == null
                      ? 'Off'
                      : _foodLink!.isFlexible
                          ? 'Flexible · ${_foodLink!.slot.label}'
                          : '${_foodLink!.items.length} '
                              'food${_foodLink!.items.length == 1 ? '' : 's'} · '
                              '${_foodLink!.slot.label}',
                  value: _foodLink != null,
                  accent: _accent,
                  onChanged: _toggleFoodLink,
                ),
                if (_foodLink != null) ...[
                  const SizedBox(height: 12),
                  _FoodLinkEditor(
                    link: _foodLink!,
                    accent: _accent,
                    busy: _addingFood,
                    onFlexibleChanged: _setFoodLinkFlexible,
                    onSlotChanged: (s) => setState(
                        () => _foodLink = _foodLink!.copyWith(slot: s)),
                    onAddItem: _addFoodItem,
                    onAddManualItem: _addManualFoodItem,
                    onRemoveItem: _removeFoodItem,
                  ),
                ],
              ],
            ),

          // ─── Advanced ─────────────────────────────────────────
          _AdvancedHeader(
            open: _showAdvanced,
            onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 14),
            _BentoSection(
              title: 'Reminders',
              children: [
                _ToggleRow(
                  label: 'Notify me',
                  sub: _reminderEnabled && _reminderTime != null
                      ? 'Daily at ${_reminderTime!.format(context)}'
                      : 'Off',
                  value: _reminderEnabled,
                  accent: _accent,
                  onChanged: (v) async {
                    setState(() => _reminderEnabled = v);
                    if (v && _reminderTime == null) {
                      await _pickReminderTime();
                    }
                  },
                ),
                if (_reminderEnabled) ...[
                  const SizedBox(height: 10),
                  _PickerRow(
                    icon: LucideIcons.bell,
                    label: _reminderTime == null
                        ? 'Pick a time'
                        : _reminderTime!.format(context),
                    accent: _accent,
                    onTap: _pickReminderTime,
                  ),
                ],
              ],
            ),
            if (!_isTodo)
              _BentoSection(
                title: 'End on',
                children: [
                  _EndRow(
                    selected: _endMode,
                    accent: _accent,
                    onChanged: (m) => setState(() => _endMode = m),
                  ),
                  if (_endMode == EndMode.date) ...[
                    const SizedBox(height: 10),
                    _PickerRow(
                      icon: LucideIcons.calendarDays,
                      label: _endDate == null
                          ? 'Pick a date'
                          : '${_endDate!.day.toString().padLeft(2, '0')}/'
                              '${_endDate!.month.toString().padLeft(2, '0')}/'
                              '${_endDate!.year}',
                      accent: _accent,
                      onTap: _pickEndDate,
                    ),
                  ] else if (_endMode == EndMode.afterDays) ...[
                    const SizedBox(height: 10),
                    _BentoField(
                      controller: _endDaysCtrl,
                      hint: '30',
                      suffix: 'days',
                      keyboard: TextInputType.number,
                    ),
                  ],
                ],
              ),
            if (_isEditing) ...[
              const SizedBox(height: 6),
              AtlasButton(
                label: 'Archive habit',
                icon: LucideIcons.trash2,
                variant: AtlasButtonVariant.tonal,
                color: c.negative,
                height: 50,
                onPressed: _confirmDelete,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickScheduledTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? _scheduledTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    // Date-only floor. `firstDate: now` (with a time component) would reject an
    // initialDate at midnight — including a saved end date of *today* — so both
    // the bounds and the seed are normalized, and a past saved date is clamped
    // up to today (editing an already-ended habit must never crash the picker).
    final first = DateTime(now.year, now.month, now.day);
    final seed = _endDate ?? first.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: seed.isBefore(first) ? first : seed,
      firstDate: first,
      lastDate: first.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    // See _pickEndDate — an overdue todo (due date in the past) must not crash
    // the picker; its seed is clamped up to today.
    final first = DateTime(now.year, now.month, now.day);
    final seed = _dueDate ?? first;
    final picked = await showDatePicker(
      context: context,
      initialDate: seed.isBefore(first) ? first : seed,
      firstDate: first,
      lastDate: first.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _openGoalSheet() async {
    final result = await showModalBottomSheet<GoalChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(
        initialType: _goalType,
        initialValue: _goalCtrl.text,
        initialUnit: _goalUnit,
        accent: _accent,
      ),
    );
    if (result != null) {
      setState(() {
        _goalType = result.type;
        _goalCtrl.text = result.value;
        _goalUnit = result.unit;
      });
    }
  }

  // ── Food link ────────────────────────────────────────────────────────

  void _toggleFoodLink(bool on) {
    setState(() => _foodLink = on ? (_foodLink ?? HabitFoodLink.empty) : null);
  }

  /// Switches between a Fixed (preset foods, auto-logged) and Flexible (no
  /// preset — completing the habit opens a decision gate instead) meal link.
  /// A Flexible meal is binary done/not-done, so switching to it clears any
  /// numeric goal — there is no "12/20 reps" equivalent for "did you eat".
  void _setFoodLinkFlexible(bool flexible) {
    setState(() {
      final link = _foodLink ?? HabitFoodLink.empty;
      _foodLink = link.copyWith(
        isFlexible: flexible,
        items: flexible ? const [] : link.items,
      );
      if (flexible) {
        _goalType = null;
        _goalUnit = null;
        _goalCtrl.clear();
      }
    });
  }

  Future<void> _addFoodItem() async {
    final selection = await showModalBottomSheet<FoodSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => FoodSearchSheet(
        slot: _foodLink?.slot ?? MealTimeSlot.snack,
        date: DateTime.now(),
        selectMode: true,
      ),
    );
    if (selection == null || !mounted) return;

    // Resolve a real food_id (best-effort) so the auto-logged entry still feeds
    // Recents / frequent-food ranking.
    setState(() => _addingFood = true);
    String? foodId;
    try {
      foodId = await ref.read(foodRepositoryProvider).ensureFoodId(selection.food);
    } catch (_) {
      foodId = null;
    }
    if (!mounted) return;

    final item = HabitFoodLinkItem(
      foodId: foodId,
      name: selection.food.displayLine,
      qty: selection.qty,
      unit: selection.unit,
      totals: selection.totals,
    );
    setState(() {
      final link = _foodLink ?? HabitFoodLink.empty;
      _foodLink = link.copyWith(items: [...link.items, item]);
      _addingFood = false;
    });
  }

  /// Adds a `HabitFoodLinkItem` without a food-database lookup — just a
  /// name + calories, for a food you know the numbers for by heart.
  Future<void> _addManualFoodItem() async {
    final item = await showModalBottomSheet<HabitFoodLinkItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _ManualFoodEntrySheet(),
    );
    if (item == null || !mounted) return;
    setState(() {
      final link = _foodLink ?? HabitFoodLink.empty;
      _foodLink = link.copyWith(items: [...link.items, item]);
    });
  }

  void _removeFoodItem(int index) {
    final link = _foodLink;
    if (link == null) return;
    setState(() {
      final items = [...link.items]..removeAt(index);
      _foodLink = link.copyWith(items: items);
    });
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cc = ctx.c;
        final tt = ctx.t;
        return AlertDialog(
          backgroundColor: cc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: cc.border),
          ),
          title: Text('Archive habit?', style: tt.h2),
          content: Text(
            'It will be hidden from your daily list. History is kept.',
            style: tt.body.copyWith(color: cc.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Archive',
                style: TextStyle(color: cc.negative, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await ref
          .read(habitActionsProvider.notifier)
          .deleteHabit(widget.existing!.id);
      await NotificationService.instance.cancelHabit(widget.existing!.id);
      if (mounted) context.pop();
    }
  }
}
