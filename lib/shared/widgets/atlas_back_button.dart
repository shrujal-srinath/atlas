import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// A back button that always does something sensible.
///
/// Screens reached via `context.go(...)` or a notification deep-link have an
/// empty back stack, so a bare `context.pop()` silently no-ops — that's the
/// "back doesn't work / isn't there" bug. This pops when there's something to
/// pop, and otherwise navigates to [fallback] so the chevron is never a dead
/// end.
class AtlasBackButton extends StatelessWidget {
  final String fallback;
  final IconData icon;
  const AtlasBackButton({
    super.key,
    this.fallback = '/home',
    this.icon = LucideIcons.chevronLeft,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: () => popOrGo(context, fallback),
    );
  }
}

/// Pop the current route, or navigate to [fallback] when the stack is empty.
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
