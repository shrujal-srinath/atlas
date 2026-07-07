import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

/// Compact date selector for the diary: ‹ Tue · May 27 ›. Month/date jumping
/// lives in the Fueling strip's calendar right above this (which also shows
/// adherence), so this strip intentionally has no separate calendar button.
class DateStrip extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const DateStrip({super.key, required this.date, required this.onChanged});

  bool get _isToday {
    final n = DateTime.now();
    return n.year == date.year && n.month == date.month && n.day == date.day;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final label = _isToday ? 'Today' : DateFormat('EEE · MMM d').format(date);

    return Row(
      children: [
        _IconBtn(
          icon: LucideIcons.chevronLeft,
          onTap: () => onChanged(date.subtract(const Duration(days: 1))),
        ),
        Expanded(
          child: Center(
            child: Column(
              children: [
                Text(label, style: t.h2),
                if (!_isToday)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      DateFormat('y').format(date),
                      style: t.meta.copyWith(color: c.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _IconBtn(
          icon: LucideIcons.chevronRight,
          onTap: _isToday
              ? null
              : () => onChanged(date.add(const Duration(days: 1))),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: disabled ? null : AppShadows.card,
        ),
        child: Icon(icon, size: 18, color: disabled ? c.textDim : c.textSecondary),
      ),
    );
  }
}
