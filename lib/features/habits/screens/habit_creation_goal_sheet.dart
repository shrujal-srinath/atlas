part of 'habit_creation_screen.dart';

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
