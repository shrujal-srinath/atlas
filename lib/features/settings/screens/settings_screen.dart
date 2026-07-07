import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../food/domain/targets.dart';
import '../../food/providers/food_providers.dart';
import '../../food/providers/weight_providers.dart';
import '../../food/screens/goal_settings_hub.dart';
import '../../food/screens/meals_screen.dart';
import '../../home/providers/home_providers.dart';
import '../../phase/focus_screen.dart';
import '../../notifications/domain/notification_prefs.dart';
import '../../notifications/providers/notification_prefs_provider.dart';
import '../widgets/edit_sheets.dart';

part 'settings_rows.dart';
part 'settings_notifications.dart';
part 'about_me_screen.dart';

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

// TODO: replace with the hosted legal documents before store submission.
const _privacyPolicyUrl = 'https://atlas.app/privacy';
const _termsUrl = 'https://atlas.app/terms';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(appUserProvider);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings', style: context.t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 8, AppSpace.screenH, 0),
          child: user.when(
            data: (u) => _Body(user: u, mode: mode),
            loading: () => Center(
              child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Text(
                friendlyError(e),
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
    final u = user;

    Future<void> patch(Map<String, dynamic> data) =>
        ref.read(userActionsProvider.notifier).update(data);

    return ListView(
      padding: const EdgeInsets.only(bottom: 118),
      children: [
        // ─── Notifications ────────────────────────────────────
        _SectionLabel('Notifications'),
        const SizedBox(height: 8),
        _NotificationsSection(user: u, patch: patch),
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

        // ─── Legal ────────────────────────────────────────────
        _SectionLabel('Legal'),
        const SizedBox(height: 8),
        _Card(children: [
          _NavRow(
            icon: LucideIcons.shield,
            label: 'Privacy Policy',
            sub: 'How your data is used',
            onTap: () => _openUrl(context, _privacyPolicyUrl),
          ),
          _Divider(),
          _NavRow(
            icon: LucideIcons.fileText,
            label: 'Terms of Service',
            sub: 'Terms & conditions',
            onTap: () => _openUrl(context, _termsUrl),
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
        AtlasButton(
          label: 'Sign out',
          icon: LucideIcons.logOut,
          variant: AtlasButtonVariant.tonal,
          color: c.negative,
          onPressed: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showSnack(context, 'Could not open the link', isError: true);
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
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
