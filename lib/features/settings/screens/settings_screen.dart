import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../phase/phase_provider.dart';
import '../widgets/edit_sheets.dart';

const _phaseOptions = {
  'Rehab + Bulk': 'Rehab + Bulk',
  'Bulk + Train': 'Bulk + Train',
  'Performance': 'Performance',
  'Off-season': 'Off-season',
};

const _genderOptions = {
  'male': 'Male',
  'female': 'Female',
  'other': 'Other',
};

const _activityOptions = {
  'sedentary': 'Sedentary',
  'light': 'Lightly active',
  'active': 'Active',
  'very_active': 'Very active',
  'athlete': 'Athlete',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(appUserProvider);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 18, AppSpace.screenH, 0),
          child: user.when(
            data: (u) => _Body(user: u, mode: mode),
            loading: () => Center(
              child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Text(
                e.toString(),
                style: TextStyle(color: c.negative, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final AppUser? user;
  final ThemeMode mode;
  const _Body({required this.user, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final u = user;

    Future<void> patch(Map<String, dynamic> data) =>
        ref.read(userActionsProvider.notifier).update(data);

    return ListView(
      padding: const EdgeInsets.only(bottom: 118),
      children: [
        Text('Settings', style: t.h1),
        const SizedBox(height: 4),
        Text('Account and targets',
            style: t.body.copyWith(color: c.textMuted)),
        const SizedBox(height: 22),

        // ─── Profile ──────────────────────────────────────────
        _SectionLabel('Profile'),
        const SizedBox(height: 8),
        _Card(children: [
          _Row(
            label: 'Name',
            value: u?.name ?? '—',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Your name', initial: u?.name ?? '');
              if (v != null && v.isNotEmpty) await patch({'name': v});
            },
          ),
          _Divider(),
          _Row(
            label: 'Phase',
            value: u?.currentPhase ?? '—',
            onTap: () async {
              final v = await showSelectSheet(context,
                  title: 'Training phase',
                  options: _phaseOptions,
                  initial: u?.currentPhase);
              if (v != null && v != u?.currentPhase) {
                await patch({'current_phase': v});
                await recordPhaseChange(ref, v);
              }
            },
          ),
        ]),
        const SizedBox(height: 22),

        // ─── Body ─────────────────────────────────────────────
        _SectionLabel('Body'),
        const SizedBox(height: 8),
        _Card(children: [
          _Row(
            label: 'Height',
            value: u?.heightCm == null
                ? 'Set'
                : '${u!.heightCm!.toStringAsFixed(0)} cm',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Height',
                  initial: u?.heightCm?.toStringAsFixed(0) ?? '',
                  hint: '180',
                  suffix: 'cm',
                  keyboardType: TextInputType.number);
              if (v != null && v.isNotEmpty) {
                await patch({'height_cm': double.tryParse(v)});
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Weight',
            value: u?.weightKg == null
                ? 'Set'
                : '${u!.weightKg!.toStringAsFixed(1)} kg',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Weight',
                  initial: u?.weightKg?.toStringAsFixed(1) ?? '',
                  hint: '78',
                  suffix: 'kg',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true));
              if (v != null && v.isNotEmpty) {
                await patch({'weight_kg': double.tryParse(v)});
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Age',
            value: u?.age?.toString() ?? 'Set',
            onTap: () async {
              final v = await showTextEditSheet(context,
                  title: 'Age',
                  initial: u?.age?.toString() ?? '',
                  hint: '23',
                  keyboardType: TextInputType.number);
              if (v != null && v.isNotEmpty) {
                await patch({'age': int.tryParse(v)});
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Gender',
            value: _genderOptions[u?.gender] ?? '—',
            onTap: () async {
              final v = await showSelectSheet(context,
                  title: 'Gender',
                  options: _genderOptions,
                  initial: u?.gender);
              if (v != null) await patch({'gender': v});
            },
          ),
          _Divider(),
          _Row(
            label: 'Activity level',
            value: _activityOptions[u?.activityLevel] ?? '—',
            onTap: () async {
              final v = await showSelectSheet(context,
                  title: 'Activity level',
                  options: _activityOptions,
                  initial: u?.activityLevel);
              if (v != null) await patch({'activity_level': v});
            },
          ),
        ]),
        const SizedBox(height: 22),

        // ─── Daily targets ────────────────────────────────────
        _SectionLabel('Daily targets'),
        const SizedBox(height: 8),
        _Card(children: [
          _NumRow(
            label: 'Calories',
            unit: 'kcal',
            value: u?.dailyCalorieTarget,
            onSaved: (v) => patch({'daily_calorie_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Protein',
            unit: 'g',
            value: u?.dailyProteinTarget,
            onSaved: (v) => patch({'daily_protein_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Carbs',
            unit: 'g',
            value: u?.dailyCarbsTarget,
            onSaved: (v) => patch({'daily_carbs_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Fat',
            unit: 'g',
            value: u?.dailyFatTarget,
            onSaved: (v) => patch({'daily_fat_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Fiber',
            unit: 'g',
            value: u?.dailyFiberTarget,
            onSaved: (v) => patch({'daily_fiber_target': v}),
          ),
          _Divider(),
          _NumRow(
            label: 'Water',
            unit: 'ml',
            value: u?.waterTargetMl,
            onSaved: (v) => patch({'water_target_ml': v}),
          ),
        ]),
        const SizedBox(height: 22),

        // ─── Notifications ────────────────────────────────────
        _SectionLabel('Notifications'),
        const SizedBox(height: 8),
        _Card(children: [
          _SwitchRow(
            label: 'Enabled',
            sub: 'Master switch for all reminders',
            value: u?.notificationsEnabled ?? true,
            onChanged: (v) async {
              await patch({'notifications_enabled': v});
              if (!v) await NotificationService.instance.cancelAll();
            },
          ),
          _Divider(),
          _Row(
            label: 'Default reminder time',
            value: u?.defaultReminderTime ?? '08:00',
            onTap: () async {
              final parts =
                  (u?.defaultReminderTime ?? '08:00').split(':');
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.tryParse(parts[0]) ?? 8,
                  minute: int.tryParse(parts.last) ?? 0,
                ),
              );
              if (picked != null) {
                final hhmm =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                await patch({'default_reminder_time': hhmm});
              }
            },
          ),
          _Divider(),
          _Row(
            label: 'Quiet hours',
            value: (u?.quietHoursStart == null || u?.quietHoursEnd == null)
                ? 'Off'
                : '${u!.quietHoursStart} → ${u.quietHoursEnd}',
            onTap: () => _editQuietHours(context, ref, u),
          ),
        ]),
        const SizedBox(height: 22),

        // ─── Library ──────────────────────────────────────────
        _SectionLabel('Library'),
        const SizedBox(height: 8),
        _Card(children: [
          _NavRow(
            icon: LucideIcons.layoutList,
            label: 'Manage habits',
            sub: 'Reorder, archive, edit',
            onTap: () => context.push('/habits'),
          ),
        ]),
        const SizedBox(height: 22),

        // ─── Appearance ───────────────────────────────────────
        _SectionLabel('Appearance'),
        const SizedBox(height: 8),
        _ThemeToggle(
          mode: mode,
          onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
        ),
        const SizedBox(height: 22),

        // ─── Data ─────────────────────────────────────────────
        _SectionLabel('Data'),
        const SizedBox(height: 8),
        _Card(children: [
          _NavRow(
            icon: LucideIcons.download,
            label: 'Export data',
            sub: 'Copy habits + logs as CSV',
            onTap: () => _exportData(context, ref),
          ),
          _Divider(),
          _NavRow(
            icon: LucideIcons.trash2,
            label: 'Delete account',
            sub: 'Permanently erase everything',
            destructive: true,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
        ]),
        const SizedBox(height: 22),

        // ─── About ────────────────────────────────────────────
        _SectionLabel('About'),
        const SizedBox(height: 8),
        _Card(children: [
          _Row(label: 'Version', value: '1.0.0+1', onTap: null),
        ]),
        const SizedBox(height: 22),

        // Sign out
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(LucideIcons.logOut, size: 16, color: c.negative),
            label: Text(
              'Sign out',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: c.negative,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.negative.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _editQuietHours(
      BuildContext context, WidgetRef ref, AppUser? u) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Quiet hours START',
    );
    if (start == null) return;
    if (!context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Quiet hours END',
    );
    if (end == null) return;
    String hhmm(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await ref.read(userActionsProvider.notifier).update({
      'quiet_hours_start': hhmm(start),
      'quiet_hours_end': hhmm(end),
    });
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final uid = session.user.id;

    final habits = await SupabaseService.client
        .from('habits')
        .select('id, name, section, type, days_of_week, is_archived')
        .eq('user_id', uid);
    final logs = await SupabaseService.client
        .from('habit_logs')
        .select('habit_id, date, completed, effort_rating')
        .eq('user_id', uid);

    final buf = StringBuffer();
    buf.writeln('# Habits');
    buf.writeln('id,name,section,type,days,archived');
    for (final h in habits as List) {
      buf.writeln(
        '${h['id']},"${h['name']}",${h['section']},${h['type']},'
        '"${(h['days_of_week'] as List).join('|')}",${h['is_archived']}',
      );
    }
    buf.writeln();
    buf.writeln('# Logs');
    buf.writeln('habit_id,date,completed,effort');
    for (final l in logs as List) {
      buf.writeln(
        '${l['habit_id']},${l['date']},${l['completed']},${l['effort_rating'] ?? ''}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied to clipboard')),
      );
    }
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
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
          title: Text('Delete account?', style: tt.h2),
          content: Text(
            'Every habit, log, food entry, and measurement will be erased. '
            'This cannot be undone.',
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
                'Delete',
                style: TextStyle(
                    color: cc.negative, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await NotificationService.instance.cancelAll();
      await ref.read(userActionsProvider.notifier).deleteAccount();
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
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
          title: Text('Sign out?', style: tt.h2),
          content: Text(
            'You can sign back in any time.',
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
                'Sign out',
                style: TextStyle(
                    color: cc.negative, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

// ─────────────────────────── primitives ────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: context.t.label);
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: context.c.border);
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _Row({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Text(label, style: t.body.copyWith(color: c.textSecondary)),
            const Spacer(),
            Text(value, style: t.bodyStrong),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 14, color: c.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumRow extends StatelessWidget {
  final String label;
  final String unit;
  final int? value;
  final Future<void> Function(int) onSaved;
  const _NumRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      value: value == null ? 'Set' : '$value $unit',
      onTap: () async {
        final v = await showTextEditSheet(
          context,
          title: label,
          initial: value?.toString() ?? '',
          suffix: unit,
          keyboardType: TextInputType.number,
        );
        if (v != null && v.isNotEmpty) {
          final n = int.tryParse(v);
          if (n != null) await onSaved(n);
        }
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodyStrong),
                const SizedBox(height: 2),
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

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool destructive;
  const _NavRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final iconColor = destructive ? c.negative : c.accent;
    final labelColor = destructive ? c.negative : c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.bodyStrong.copyWith(color: labelColor)),
                  const SizedBox(height: 2),
                  Text(sub, style: t.meta),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 14, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _ToggleHalf(
            icon: LucideIcons.moon,
            label: 'Dark',
            active: mode == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
          _ToggleHalf(
            icon: LucideIcons.sun,
            label: 'Light',
            active: mode == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
        ],
      ),
    );
  }
}

class _ToggleHalf extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleHalf({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: active ? c.accent : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? c.accent : c.textMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? c.accent : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
