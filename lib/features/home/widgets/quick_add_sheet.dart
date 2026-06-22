import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../food/providers/food_providers.dart';

/// 4-tile bottom sheet invoked by the center FAB on Home.
/// Order: Habit · Food · Water · Journal.
/// Habit opens the existing type-picker; Food navigates to the diary;
/// Water logs +250 ml inline (long-press for a custom-volume dialog);
/// Journal opens the daily wellness check-in.
///
/// Two kinds of tile share the grid, and the corner glyph tells them apart:
///   · ↗  opens a flow on another screen
///   · +  commits an action inline and closes the sheet
Future<void> showQuickAdd4Tile(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _QuickAdd4Tile(),
  );
}

class _QuickAdd4Tile extends ConsumerStatefulWidget {
  const _QuickAdd4Tile();

  @override
  ConsumerState<_QuickAdd4Tile> createState() => _QuickAdd4TileState();
}

class _QuickAdd4TileState extends ConsumerState<_QuickAdd4Tile>
    with SingleTickerProviderStateMixin {
  // Drives the staggered reveal: header first, then the tiles in reading order
  // so the eye is led across the grid rather than hit with everything at once.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              spreadRadius: -4,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _StaggerItem(
              listenable: _intro,
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 14, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUICK ADD',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Start a moment', style: t.h2.copyWith(fontSize: 20)),
                          const SizedBox(height: 2),
                          Text(
                            'Capture it before it passes.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: c.textMuted,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StaggerItem(
                          listenable: _intro,
                          index: 1,
                          child: _QuickTile(
                            icon: LucideIcons.repeat,
                            label: 'Habit',
                            sublabel: 'Build a routine',
                            accent: c.accent,
                            onTap: () {
                              // Capture the router before popping the sheet so
                              // the push runs on a live context.
                              final router = GoRouter.of(context);
                              Navigator.of(context).pop();
                              router.push('/habit-type');
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _StaggerItem(
                          listenable: _intro,
                          index: 2,
                          child: _QuickTile(
                            icon: LucideIcons.utensilsCrossed,
                            label: 'Food',
                            sublabel: 'Log a meal',
                            accent: c.athletic,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.go('/food');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: _StaggerItem(
                          listenable: _intro,
                          index: 3,
                          child: _QuickTile(
                            icon: LucideIcons.droplet,
                            label: 'Water',
                            sublabel: '+250 ml · hold for more',
                            accent: c.mind,
                            instant: true,
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final repo = ref.read(foodRepositoryProvider);
                              final date = ref.read(diaryDateProvider);
                              await repo.addWater(250, date);
                              ref.invalidate(waterIntakeProvider);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            onLongPress: () async {
                              final ml = await _promptCustomWater(context);
                              if (ml == null || ml <= 0) return;
                              final repo = ref.read(foodRepositoryProvider);
                              final date = ref.read(diaryDateProvider);
                              await repo.addWater(ml, date);
                              ref.invalidate(waterIntakeProvider);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _StaggerItem(
                          listenable: _intro,
                          index: 4,
                          child: _QuickTile(
                            icon: LucideIcons.bookOpen,
                            label: 'Journal',
                            sublabel: 'Reflect & check in',
                            accent: c.body,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/journal');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<int?> _promptCustomWater(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Custom volume', style: ctx.t.h2),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: ctx.t.body,
            decoration: InputDecoration(
              hintText: 'ml',
              suffixText: 'ml',
              suffixStyle: AppType.meta.copyWith(color: c.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

/// Fades + lifts a child into place on an [Interval] keyed off [index], so the
/// header and four tiles arrive in sequence rather than all at once.
class _StaggerItem extends StatelessWidget {
  final Listenable listenable;
  final int index;
  final Widget child;
  const _StaggerItem({
    required this.listenable,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.09).clamp(0.0, 0.7);
    final anim = CurvedAnimation(
      parent: listenable as Animation<double>,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - anim.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Icon(LucideIcons.x, size: 17, color: c.textSecondary),
      ),
    );
  }
}

/// One bento action tile. [instant] tiles commit an action inline (corner '+');
/// the rest open a flow on another screen (corner '↗'). The accent never washes
/// behind the text — it lives in the icon chip and the corner glyph only.
class _QuickTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color accent;
  final bool instant;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accent,
    required this.onTap,
    this.instant = false,
    this.onLongPress,
  });

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: widget.accent.withValues(alpha: 0.25),
                          width: 0.5),
                    ),
                    child: Icon(widget.icon, size: 19, color: widget.accent),
                  ),
                  const Spacer(),
                  // Behaviour glyph: '+' = commits inline, '↗' = opens a flow.
                  Icon(
                    widget.instant
                        ? LucideIcons.plus
                        : LucideIcons.arrowUpRight,
                    size: 15,
                    color: widget.instant ? widget.accent : c.textDim,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: c.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.sublabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: c.textMuted,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
