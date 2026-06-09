import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/habit_provider.dart';

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
  HabitSection _section = HabitSection.athletic;
  HabitType _type = HabitType.positive;
  HabitPriority _priority = HabitPriority.normal;
  List<int> _days = [1, 2, 3, 4, 5, 6, 7];
  FrequencyMode _freq = FrequencyMode.everyDay;
  TimePeriod? _timePeriod;
  TimeOfDay? _scheduledTime;
  GoalType? _goalType;
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
      _colorKey = h.colorKey ?? _colorForSection(h.section);
      _section = h.section;
      _type = h.type;
      _priority = h.priority;
      _days = List.of(h.daysOfWeek);
      _freq = h.frequencyMode;
      if (h.timesPerWeek != null) _twpCtrl.text = h.timesPerWeek.toString();
      _timePeriod = h.timePeriod;
      if (h.scheduledTime != null) _scheduledTime = _parseHHmm(h.scheduledTime!);
      _goalType = h.goalType;
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
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
      _section = switch (_type) {
        HabitType.positive => HabitSection.athletic,
        HabitType.negative => HabitSection.body,
        HabitType.todo => HabitSection.mind,
      };
      _colorKey = _colorForSection(_section);
      if (_isTodo) _freq = FrequencyMode.specificDays;
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

  Color get _accent => Color(kHabitColorSwatch[_colorKey] ?? 0xFF2DD4BF);

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
      'section': _section.name,
      'type': _type.name,
      'days_of_week': daysToSave,
      'frequency_mode': Habit.freqToDb(_freq),
      if (_freq == FrequencyMode.timesPerWeek)
        'times_per_week': int.tryParse(_twpCtrl.text) ?? 3,
      if (_goalType != null && _goalCtrl.text.isNotEmpty)
        'goal_value': double.tryParse(_goalCtrl.text),
      if (_goalType != null) 'goal_type': _goalType!.name,
      'priority': _priority.name,
      'effort_rating_enabled': _effortRating,
      'note_enabled': _note,
      'photo_proof_enabled': _photoProof,
      if (_section == HabitSection.mind && _skillCtrl.text.isNotEmpty)
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

      // Schedule / cancel local notification.
      await NotificationService.instance.cancelHabit(habitId);
      if (_reminderEnabled && _reminderTime != null) {
        await NotificationService.instance.scheduleHabitReminder(
          habitId: habitId,
          name: _nameCtrl.text.trim(),
          time: (hour: _reminderTime!.hour, minute: _reminderTime!.minute),
          daysOfWeek: daysToSave,
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      _toast(e.toString(), isError: true);
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
                tint: _accent,
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
                  selected: _section,
                  onChanged: (s) => setState(() {
                    _section = s;
                    // If user hasn't picked a custom color yet, follow the section.
                    if (_colorKey == 'athletic' ||
                        _colorKey == 'building' ||
                        _colorKey == 'breaking') {
                      _colorKey = _colorForSection(s);
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
          else
            _BentoSection(
              title: 'Schedule',
              subtitle: 'When and how often',
              children: [
                _Label('Repeat'),
                const SizedBox(height: 8),
                _FreqRow(
                  selected: _freq,
                  accent: _accent,
                  onChanged: (f) => setState(() => _freq = f),
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
                ] else if (_freq == FrequencyMode.timesPerWeek) ...[
                  const SizedBox(height: 10),
                  _BentoField(
                    controller: _twpCtrl,
                    hint: '3',
                    suffix: 'times / week',
                    keyboard: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 16),
                _Label('Do it at'),
                const SizedBox(height: 8),
                _WhenRow(
                  selected: _timePeriod,
                  accent: _accent,
                  onChanged: (p) => setState(() {
                    _timePeriod = (_timePeriod == p) ? null : p;
                    if (_timePeriod == null) _scheduledTime = null;
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
              _Label('Daily goal'),
              const SizedBox(height: 8),
              _PickerRow(
                icon: LucideIcons.target,
                label: _goalType == null
                    ? 'Off'
                    : '${_goalCtrl.text.isEmpty ? "—" : _goalCtrl.text} '
                        '${_goalUnitLabel(_goalType!)}',
                accent: _accent,
                onTap: _openGoalSheet,
              ),
              if (_section == HabitSection.mind && !_isTodo) ...[
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
                onChanged: (v) => setState(() => _effortRating = v),
              ),
              _ToggleRow(
                label: 'Note',
                sub: 'Add a quick note when logging',
                value: _note,
                onChanged: (v) => setState(() => _note = v),
              ),
              _ToggleRow(
                label: 'Photo proof',
                sub: 'Attach a photo to complete',
                value: _photoProof,
                onChanged: (v) => setState(() => _photoProof = v),
              ),
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
              OutlinedButton.icon(
                onPressed: _confirmDelete,
                icon: Icon(LucideIcons.trash2, size: 16, color: c.negative),
                label: Text(
                  'Archive habit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: c.negative,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.negative.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _goalUnitLabel(GoalType g) => switch (g) {
        GoalType.reps => 'reps',
        GoalType.durationMin => 'min',
        GoalType.distanceKm => 'km',
        GoalType.litres => 'L',
        GoalType.custom => 'units',
      };

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
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _openGoalSheet() async {
    final result = await showModalBottomSheet<({GoalType? type, String value})>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(
        initialType: _goalType,
        initialValue: _goalCtrl.text,
        accent: _accent,
      ),
    );
    if (result != null) {
      setState(() {
        _goalType = result.type;
        _goalCtrl.text = result.value;
      });
    }
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

// ─────────────────────────────── pieces ───────────────────────────────

/// Titled BENTO container. Wraps a logical group of inputs in the same
/// surface + 0.5px border + soft-shadow card style used on the home screen.
class _BentoSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _BentoSection({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c.textMuted,
              height: 1.0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Single-line TextField wrapped in the BENTO input style: 56dp height,
/// `surfaceElevated` fill, 0.5px border, accent on focus. Matches home cards.
class _BentoField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType? keyboard;
  final bool autofocus;
  const _BentoField({
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboard,
    this.autofocus = false,
  });

  @override
  State<_BentoField> createState() => _BentoFieldState();
}

class _BentoFieldState extends State<_BentoField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final focused = _focus.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(
          color: focused ? c.accent.withValues(alpha: 0.55) : c.border,
          width: focused ? 1 : 0.5,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboard,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
        ),
        decoration: InputDecoration(
          isCollapsed: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.textMuted,
          ),
          suffixText: widget.suffix,
          suffixStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: context.t.label);
}

class _SectionRow extends StatelessWidget {
  final HabitSection selected;
  final ValueChanged<HabitSection> onChanged;
  const _SectionRow({required this.selected, required this.onChanged});

  Color _color(AppPalette c, HabitSection s) => switch (s) {
        HabitSection.athletic => c.athletic,
        HabitSection.body => c.body,
        HabitSection.mind => c.mind,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: HabitSection.values.map((s) {
        final active = s == selected;
        final sc = _color(c, s);
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(s);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: active ? sc.withValues(alpha: 0.10) : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: active ? sc : c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                s.name[0].toUpperCase() + s.name.substring(1),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? sc : c.textMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final HabitPriority selected;
  final ValueChanged<HabitPriority> onChanged;
  const _PriorityRow({required this.selected, required this.onChanged});

  Color _color(AppPalette c, HabitPriority p) => switch (p) {
        HabitPriority.low => c.textMuted,
        HabitPriority.normal => c.accent,
        HabitPriority.high => c.amber,
        HabitPriority.critical => c.negative,
      };

  String _label(HabitPriority p) => switch (p) {
        HabitPriority.low => 'Low',
        HabitPriority.normal => 'Normal',
        HabitPriority.high => 'High',
        HabitPriority.critical => 'Critical',
      };

  String _multiplier(HabitPriority p) => switch (p) {
        HabitPriority.low => '0.5×',
        HabitPriority.normal => '1×',
        HabitPriority.high => '1.5×',
        HabitPriority.critical => '2.5×',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: HabitPriority.values.map((p) {
        final active = p == selected;
        final pc = _color(c, p);
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(p);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? pc.withValues(alpha: 0.12) : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: active ? pc : c.border),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label(p),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? pc : c.textMuted,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _multiplier(p),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: active ? pc.withValues(alpha: 0.85) : c.textMuted,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FreqRow extends StatelessWidget {
  final FrequencyMode selected;
  final Color accent;
  final ValueChanged<FrequencyMode> onChanged;
  const _FreqRow({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const opts = [
      (FrequencyMode.everyDay, 'Every day'),
      (FrequencyMode.specificDays, 'Specific days'),
      (FrequencyMode.timesPerWeek, 'X / week'),
    ];
    return Row(
      children: opts.map((o) {
        final active = o.$1 == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(o.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.10) : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: active ? accent : c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                o.$2,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? accent : c.textMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DaysRow extends StatelessWidget {
  final List<int> selected;
  final Color accent;
  final ValueChanged<int> onToggle;
  const _DaysRow({
    required this.selected,
    required this.accent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: List.generate(7, (i) {
        final d = i + 1;
        final active = selected.contains(d);
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle(d);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 4),
              height: 36,
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.12) : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(color: active ? accent : c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                _dayLabels[i],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? accent : c.textMuted,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WhenRow extends StatelessWidget {
  final TimePeriod? selected;
  final Color accent;
  final ValueChanged<TimePeriod> onChanged;
  const _WhenRow({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final opts = [
      (TimePeriod.morning, LucideIcons.sunrise, 'Morning'),
      (TimePeriod.afternoon, LucideIcons.sun, 'Afternoon'),
      (TimePeriod.evening, LucideIcons.moon, 'Evening'),
    ];
    return Row(
      children: [
        // Anytime tile
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (selected != null) onChanged(selected!);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: selected == null
                    ? accent.withValues(alpha: 0.10)
                    : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(
                    color: selected == null ? accent : c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                'Anytime',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: selected == null
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selected == null ? accent : c.textMuted,
                ),
              ),
            ),
          ),
        ),
        ...opts.map((o) {
          final active = o.$1 == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(o.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: active ? accent.withValues(alpha: 0.10) : c.surface,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  border: Border.all(color: active ? accent : c.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(o.$2,
                        size: 14, color: active ? accent : c.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      o.$3,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? accent : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _EndRow extends StatelessWidget {
  final EndMode selected;
  final Color accent;
  final ValueChanged<EndMode> onChanged;
  const _EndRow({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const opts = [
      (EndMode.off, 'Off'),
      (EndMode.date, 'On date'),
      (EndMode.afterDays, 'After N days'),
    ];
    return Row(
      children: opts.map((o) {
        final active = o.$1 == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(o.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.10) : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: active ? accent : c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                o.$2,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? accent : c.textMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color accent;
  final VoidCallback onTap;
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: context.t.body),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
              Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _IconPicker extends StatefulWidget {
  final String selected;
  final Color tint;
  final ValueChanged<String> onSelect;
  const _IconPicker({
    required this.selected,
    required this.tint,
    required this.onSelect,
  });

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  String _category = 'Athletic';

  @override
  void initState() {
    super.initState();
    // Open on the category containing the current icon.
    for (final entry in kHabitIconCategories.entries) {
      if (entry.value.contains(widget.selected)) {
        _category = entry.key;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final icons = kHabitIconCategories[_category] ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kHabitIconCategories.keys.map((cat) {
                final active = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? widget.tint.withValues(alpha: 0.12)
                          : c.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: Border.all(
                        color: active ? widget.tint : c.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? widget.tint : c.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: icons.map((k) {
              final active = k == widget.selected;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onSelect(k);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: active
                        ? widget.tint.withValues(alpha: 0.12)
                        : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(
                      color: active ? widget.tint : c.border,
                    ),
                  ),
                  child: Icon(
                    habitIcon(k),
                    size: 18,
                    color: active ? widget.tint : c.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _ColorSwatchRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kHabitColorOrder.map((k) {
        final color = Color(kHabitColorSwatch[k]!);
        final active = k == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(k);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? c.textPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: active
                ? Icon(LucideIcons.check, size: 14, color: c.onAccent)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodyStrong),
                Text(sub, style: t.meta),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.accent,
            activeTrackColor: c.accent.withValues(alpha: 0.35),
            inactiveTrackColor: c.borderStrong,
            inactiveThumbColor: c.textDim,
          ),
        ],
      ),
    );
  }
}

class _AdvancedHeader extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  const _AdvancedHeader({required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              'Advanced',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(LucideIcons.chevronDown, size: 18, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplacementPicker extends ConsumerWidget {
  final String? selectedId;
  final Color accent;
  final ValueChanged<String?> onChanged;
  const _ReplacementPicker({
    required this.selectedId,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
    final builders = habits
        .where((h) => h.section == HabitSection.mind && !h.isArchived)
        .toList();

    if (builders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Text(
          'No Building habits yet — create one to use as a replacement.',
          style: context.t.body.copyWith(color: c.textMuted),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final h in builders)
          GestureDetector(
            onTap: () => onChanged(selectedId == h.id ? null : h.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selectedId == h.id
                    ? accent.withValues(alpha: 0.12)
                    : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(
                  color: selectedId == h.id ? accent : c.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(habitIcon(h.icon),
                      size: 14,
                      color: selectedId == h.id ? accent : c.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    h.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selectedId == h.id ? accent : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────── Goal sheet ─────────────────────

class _GoalSheet extends StatefulWidget {
  final GoalType? initialType;
  final String initialValue;
  final Color accent;
  const _GoalSheet({
    required this.initialType,
    required this.initialValue,
    required this.accent,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late GoalType? _type;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _label(GoalType g) => switch (g) {
        GoalType.reps => 'Count',
        GoalType.durationMin => 'Duration (min)',
        GoalType.distanceKm => 'Distance (km)',
        GoalType.litres => 'Volume (L)',
        GoalType.custom => 'Custom',
      };

  IconData _icon(GoalType g) => switch (g) {
        GoalType.reps => LucideIcons.hash,
        GoalType.durationMin => LucideIcons.clock,
        GoalType.distanceKm => LucideIcons.mapPin,
        GoalType.litres => LucideIcons.droplet,
        GoalType.custom => LucideIcons.target,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpace.screenH,
          14,
          AppSpace.screenH,
          MediaQuery.of(context).viewPadding.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Daily goal', style: t.h2),
            const SizedBox(height: 10),
            // Off + type tiles
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TypeChip(
                  label: 'Off',
                  icon: LucideIcons.ban,
                  active: _type == null,
                  accent: widget.accent,
                  onTap: () => setState(() => _type = null),
                ),
                for (final g in GoalType.values)
                  _TypeChip(
                    label: _label(g),
                    icon: _icon(g),
                    active: _type == g,
                    accent: widget.accent,
                    onTap: () => setState(() => _type = g),
                  ),
              ],
            ),
            if (_type != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: t.body,
                decoration: InputDecoration(
                  hintText: 'Target ${_label(_type!).toLowerCase()}',
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: c.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              onPressed: () => Navigator.pop(
                context,
                (type: _type, value: _ctrl.text.trim()),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.12) : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: active ? accent : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? accent : c.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? accent : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
