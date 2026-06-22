import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import 'notification_provider.dart';
import 'reminder_feed_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final inbox = ref.watch(notificationsProvider).valueOrNull ?? const [];
    final reminders =
        ref.watch(upcomingRemindersProvider).valueOrNull ?? const [];
    final unread = inbox.where((n) => n.isUnread).length;

    final isEmpty = inbox.isEmpty && reminders.isEmpty;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('Notifications', style: t.h2),
        centerTitle: true,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => markAllNotificationsRead(ref),
              child: Text(
                'Mark all',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: c.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: isEmpty
            ? _EmptyState()
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(upcomingRemindersProvider);
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                },
                color: c.accent,
                backgroundColor: c.surface,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.screenH, 8, AppSpace.screenH, 32),
                  children: [
                    if (reminders.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Today',
                        count: reminders.length,
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < reminders.length; i++) ...[
                        _ReminderTile(reminder: reminders[i]),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 14),
                    ],
                    if (inbox.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Recent activity',
                        count: inbox.length,
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < inbox.length; i++) ...[
                        _NotifTile(
                          notif: inbox[i],
                          onTap: () =>
                              markNotificationRead(ref, inbox[i].id),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bellOff, size: 32, color: c.textMuted),
          const SizedBox(height: 12),
          Text(
            'All clear',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No reminders or notifications for today.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: c.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final UpcomingReminder reminder;
  const _ReminderTile({required this.reminder});

  Color _sectionTint(BuildContext context, HabitSection? s) {
    final c = context.c;
    return s?.color(c) ?? c.accent;
  }

  Color _tint(BuildContext context) {
    final c = context.c;
    return switch (reminder.kind) {
      ReminderKind.water => c.mind,
      ReminderKind.task ||
      ReminderKind.reminder =>
        _sectionTint(context, reminder.section),
    };
  }

  String _whenLabel(BuildContext context) {
    final at = reminder.scheduledAt;
    if (at == null) return reminder.timeLabel ?? '';
    final now = DateTime.now();
    final diff = at.difference(now);
    if (diff.inMinutes.abs() < 1) return 'now';
    if (diff.isNegative) {
      final past = -diff.inMinutes;
      if (past < 60) return '${past}m ago';
      if (past < 24 * 60) return '${(past / 60).floor()}h ago';
      return reminder.timeLabel ?? '';
    }
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return reminder.timeLabel ?? '';
  }

  bool _isOverdue() {
    final at = reminder.scheduledAt;
    if (at == null) return false;
    return at.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = _tint(context);
    final overdue = _isOverdue();
    final when = _whenLabel(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: reminder.route == null
            ? null
            : () => context.push(reminder.route!),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: overdue
                  ? c.amber.withValues(alpha: 0.5)
                  : c.border,
              width: overdue ? 1 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 9,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(reminder.icon, size: 18, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reminder.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reminder.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        reminder.subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: c.textMuted,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (reminder.timeLabel != null &&
                      reminder.scheduledAt != null)
                    Text(
                      reminder.timeLabel!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: overdue ? c.amber : c.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.0,
                      ),
                    ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      when,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: overdue ? c.amber : c.textMuted,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final InboxNotification notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  IconData get _icon => switch (notif.type) {
        'achievement' => LucideIcons.trophy,
        'level_up' => LucideIcons.zap,
        'rank_up' => LucideIcons.award,
        'streak_milestone' => LucideIcons.flame,
        'reminder' => LucideIcons.bell,
        _ => LucideIcons.info,
      };

  Color _tint(BuildContext context) {
    final c = context.c;
    return switch (notif.type) {
      'achievement' => c.accent,
      'level_up' => c.amber,
      'rank_up' => c.athletic,
      'streak_milestone' => c.amber,
      'reminder' => c.mind,
      _ => c.textSecondary,
    };
  }

  String _ago() {
    final dur = DateTime.now().difference(notif.createdAt);
    if (dur.inMinutes < 1) return 'now';
    if (dur.inMinutes < 60) return '${dur.inMinutes}m';
    if (dur.inHours < 24) return '${dur.inHours}h';
    if (dur.inDays < 7) return '${dur.inDays}d';
    return '${(dur.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = _tint(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          decoration: BoxDecoration(
            color: notif.isUnread
                ? c.accent.withValues(alpha: 0.06)
                : c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: notif.isUnread ? c.accent.withValues(alpha: 0.3) : c.border,
              width: notif.isUnread ? 1 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 9,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 17, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _ago(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (notif.body != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        notif.body!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (notif.isUnread)
                Container(
                  margin: const EdgeInsets.only(left: 6, top: 6),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
