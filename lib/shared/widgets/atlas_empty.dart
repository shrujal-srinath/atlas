import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';

/// Shared empty-state widget used across tabs.
///
/// Three variants:
///   - [AtlasEmpty.noData]    — backend returned [], no input from user yet
///   - [AtlasEmpty.noResults] — user query returned nothing (search, filters)
///   - [AtlasEmpty.firstRun]  — brand new account with no rows ever
class AtlasEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AtlasEmpty._({
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  factory AtlasEmpty.noData({
    IconData icon = LucideIcons.inbox,
    required String title,
    String? body,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      AtlasEmpty._(
        icon: icon,
        title: title,
        body: body,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  factory AtlasEmpty.noResults({
    IconData icon = LucideIcons.search,
    String title = 'No matches',
    String? body,
  }) =>
      AtlasEmpty._(icon: icon, title: title, body: body);

  factory AtlasEmpty.firstRun({
    IconData icon = LucideIcons.sparkles,
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) =>
      AtlasEmpty._(
        icon: icon,
        title: title,
        body: body,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Icon(icon, size: 24, color: c.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.h2.copyWith(color: c.textPrimary),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: c.textMuted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
