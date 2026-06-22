import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// The "Me" tab — a hub that routes to the personal sections. Replaces the old
/// behaviour where this tab dropped you straight into Settings.
class MeHubScreen extends ConsumerWidget {
  const MeHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final user = ref.watch(appUserProvider).valueOrNull;
    final name = (user?.name ?? '').trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 18, AppSpace.screenH, 118),
          children: [
            // ── Identity header ──────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    initial,
                    style: AppType.h1.copyWith(color: c.accent, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'You' : name, style: t.h1),
                      const SizedBox(height: 2),
                      Text('Your space',
                          style: t.body.copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),

            _HubTile(
              icon: LucideIcons.userCircle,
              title: 'About me',
              sub: 'Profile · body · daily targets',
              onTap: () => context.push('/me/about'),
            ),
            const SizedBox(height: 10),
            _HubTile(
              icon: LucideIcons.bookOpen,
              title: 'Journal',
              sub: 'Goals, wellness & reflection',
              onTap: () => context.push('/journal'),
            ),
            const SizedBox(height: 10),
            _HubTile(
              icon: LucideIcons.stickyNote,
              title: 'Notes',
              sub: 'Notes, lists & reminders',
              onTap: () => context.push('/me/notes'),
            ),
            const SizedBox(height: 10),
            _HubTile(
              icon: LucideIcons.settings,
              title: 'Settings',
              sub: 'Notifications · theme · data',
              onTap: () => context.push('/me/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Icon(icon, size: 18, color: c.accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.bodyStrong.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(sub, style: t.meta.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
