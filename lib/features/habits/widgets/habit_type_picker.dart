import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';

/// Bottom sheet that picks the kind of habit to create, then routes to
/// /habit-creation with the chosen type pre-selected.
Future<void> showHabitTypePicker(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _HabitTypePickerSheet(),
  );
}

class _HabitTypePickerSheet extends StatefulWidget {
  const _HabitTypePickerSheet();

  @override
  State<_HabitTypePickerSheet> createState() => _HabitTypePickerSheetState();
}

class _HabitTypePickerSheetState extends State<_HabitTypePickerSheet> {
  HabitType _selected = HabitType.positive;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        14,
        AppSpace.screenH,
        MediaQuery.of(context).viewPadding.bottom + 20,
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
          const SizedBox(height: 18),
          Text('Create a habit', style: t.h2),
          const SizedBox(height: 4),
          Text(
            'Pick what kind of behaviour you want to track.',
            style: t.body.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _TypeTile(
                icon: LucideIcons.repeat,
                label: 'Regular',
                accent: c.accent,
                selected: _selected == HabitType.positive,
                onTap: () => _select(HabitType.positive),
              ),
              const SizedBox(width: 10),
              _TypeTile(
                icon: LucideIcons.ban,
                label: 'Break',
                accent: c.negative,
                selected: _selected == HabitType.negative,
                onTap: () => _select(HabitType.negative),
              ),
              const SizedBox(width: 10),
              _TypeTile(
                icon: LucideIcons.checkSquare,
                label: 'Todo',
                accent: c.indigo,
                selected: _selected == HabitType.todo,
                onTap: () => _select(HabitType.todo),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DescriptionCard(type: _selected),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              context.push('/habit-creation', extra: {'type': _selected});
            },
            child: const Text(
              'Continue',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/habits');
            },
            icon: Icon(LucideIcons.layoutList, size: 14, color: c.textMuted),
            label: Text(
              'View all habits',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _select(HabitType t) {
    HapticFeedback.selectionClick();
    setState(() => _selected = t);
  }
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: selected ? accent : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? accent : c.textMuted),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : c.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final HabitType type;
  const _DescriptionCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final (title, body) = switch (type) {
      HabitType.positive => (
          'REGULAR',
          'A habit you want to do consistently — daily, weekly, or on specific days. '
              'E.g., morning run, read 20 min, stretch after training.',
        ),
      HabitType.negative => (
          'BREAK',
          'A behaviour you want to stop. Streaks track consecutive scheduled days '
              'with no slip-ups. E.g., no phone after 10pm, no junk food.',
        ),
      HabitType.todo => (
          'ONE-TIME TODO',
          'Something to do once by a date. Counts toward your day but doesn’t '
              'build a streak. E.g., book physio, order whey, send invoice.',
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(type),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.label),
            const SizedBox(height: 6),
            Text(body, style: t.body.copyWith(color: c.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
