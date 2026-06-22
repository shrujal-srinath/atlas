import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';

/// Shared error widget for failed loads.
///
/// Pass [isOffline] true when the failure is connectivity-related — this swaps
/// the icon and copy to be network-shaped instead of generic. Stage 3 will
/// wire a real `connectivityProvider` and screens will pass that bool through.
class AtlasError extends StatelessWidget {
  final Object? error;
  final String? title;
  final String? body;
  final bool isOffline;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  const AtlasError({
    super.key,
    this.error,
    this.title,
    this.body,
    this.isOffline = false,
    this.onRetry,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final headline = title ??
        (isOffline ? 'You\'re offline' : 'Couldn\'t load this');
    final detail = body ??
        (isOffline
            ? 'Reconnect to refresh today\'s data.'
            : 'Pull to retry, or tap the button below.');

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.negative.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                  color: c.negative.withValues(alpha: 0.30), width: 0.5),
            ),
            child: Icon(
              isOffline ? LucideIcons.wifiOff : LucideIcons.alertTriangle,
              size: 24,
              color: c.negative,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: t.h2.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: c.textMuted),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              friendlyError(error),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.meta.copyWith(color: c.textDim),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
