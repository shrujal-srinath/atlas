import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../domain/note.dart';

/// Result of the reminder sheet. [cleared] = the user removed the reminder;
/// otherwise [at] + [rule] describe the new reminder. A null return from the
/// sheet means "no change".
class ReminderChoice {
  final DateTime? at;
  final ReminderRule? rule;
  final bool cleared;
  const ReminderChoice({this.at, this.rule, this.cleared = false});
}

Future<ReminderChoice?> showNoteReminderSheet(
  BuildContext context, {
  DateTime? initialAt,
  ReminderRule? initialRule,
}) {
  return showModalBottomSheet<ReminderChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ReminderSheet(initialAt: initialAt, initialRule: initialRule),
  );
}

class _ReminderSheet extends StatefulWidget {
  final DateTime? initialAt;
  final ReminderRule? initialRule;
  const _ReminderSheet({this.initialAt, this.initialRule});

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late ReminderRule _rule;
  late DateTime _date; // date part (used by once + weekly)
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final base = widget.initialAt ??
        DateTime.now().add(const Duration(hours: 1));
    _rule = widget.initialRule ?? ReminderRule.once;
    _date = DateTime(base.year, base.month, base.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
  }

  bool get _needsDate =>
      _rule == ReminderRule.once || _rule == ReminderRule.weekly;

  DateTime get _composed => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  bool get _isPastOnce =>
      _rule == ReminderRule.once && !_composed.isAfter(DateTime.now());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  String get _dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = _date.difference(today).inDays;
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${wd[_date.weekday - 1]}, ${_date.day} ${mo[_date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final hadReminder = widget.initialRule != null;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        14,
        AppSpace.screenH,
        MediaQuery.of(context).viewPadding.bottom + 16,
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
          Row(
            children: [
              Icon(LucideIcons.bell, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text('Reminder', style: t.h2),
            ],
          ),
          const SizedBox(height: 18),

          // Repeat selector
          Text('REPEAT', style: t.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in ReminderRule.values)
                _Chip(
                  label: r.label,
                  selected: _rule == r,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rule = r);
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Date (only when relevant)
          if (_needsDate) ...[
            _Row(
              icon: LucideIcons.calendar,
              label: _rule == ReminderRule.weekly ? 'Starts / weekday' : 'Date',
              value: _dateLabel,
              onTap: _pickDate,
            ),
            const SizedBox(height: 10),
          ],
          _Row(
            icon: LucideIcons.clock,
            label: 'Time',
            value: _time.format(context),
            onTap: _pickTime,
          ),

          if (_isPastOnce) ...[
            const SizedBox(height: 12),
            Text(
              'That time has already passed — pick a future moment.',
              style: t.meta.copyWith(color: c.negative),
            ),
          ],
          const SizedBox(height: 20),

          Row(
            children: [
              if (hadReminder) ...[
                Expanded(
                  child: AtlasButton(
                    label: 'Remove',
                    variant: AtlasButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).pop(
                        const ReminderChoice(cleared: true),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: AtlasButton(
                  label: hadReminder ? 'Update' : 'Set reminder',
                  onPressed: _isPastOnce
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            ReminderChoice(at: _composed, rule: _rule),
                          );
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: t.label.copyWith(
              color: selected ? c.textPrimary : c.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.textMuted),
              const SizedBox(width: 12),
              Text(label, style: t.body.copyWith(color: c.textSecondary)),
              const Spacer(),
              Text(value, style: t.bodyStrong.copyWith(color: c.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
