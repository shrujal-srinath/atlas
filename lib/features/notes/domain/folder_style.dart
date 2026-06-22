import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// Resolves a folder's stored `color`/`icon` keys to concrete theme values.
/// Keys are stored as short strings in the DB so they re-theme with the app.
class FolderStyle {
  /// Selectable colour keys → palette resolver. Order is the picker order.
  static const colorKeys = <String>[
    'accent',
    'athletic',
    'body',
    'mind',
    'amber',
    'indigo',
    'positive',
  ];

  static Color color(BuildContext context, String? key) {
    final c = context.c;
    return switch (key) {
      'athletic' => c.athletic,
      'body' => c.body,
      'mind' => c.mind,
      'amber' => c.amber,
      'indigo' => c.indigo,
      'positive' => c.positive,
      'accent' => c.accent,
      _ => c.textMuted,
    };
  }

  /// Selectable icon keys → lucide glyph. Order is the picker order.
  static const iconKeys = <String>[
    'folder',
    'dumbbell',
    'heartPulse',
    'listChecks',
    'lightbulb',
    'target',
    'bookOpen',
    'shoppingCart',
    'briefcase',
    'star',
  ];

  static IconData icon(String? key) {
    return switch (key) {
      'dumbbell' => LucideIcons.dumbbell,
      'heartPulse' => LucideIcons.heartPulse,
      'listChecks' => LucideIcons.listChecks,
      'lightbulb' => LucideIcons.lightbulb,
      'target' => LucideIcons.target,
      'bookOpen' => LucideIcons.bookOpen,
      'shoppingCart' => LucideIcons.shoppingCart,
      'briefcase' => LucideIcons.briefcase,
      'star' => LucideIcons.star,
      'folder' => LucideIcons.folder,
      _ => LucideIcons.folder,
    };
  }
}
