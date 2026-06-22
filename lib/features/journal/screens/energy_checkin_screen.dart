import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/mood_log_providers.dart';

/// Minimal full-screen energy picker opened by tapping the every-2h energy
/// check-in notification. Logs an energy-only [mood_logs] point (1..5) and
/// returns home — so the user "answers on the notification" with one tap into
/// the app, no mood prompt.
class EnergyCheckinScreen extends ConsumerStatefulWidget {
  const EnergyCheckinScreen({super.key});

  @override
  ConsumerState<EnergyCheckinScreen> createState() =>
      _EnergyCheckinScreenState();
}

class _EnergyCheckinScreenState extends ConsumerState<EnergyCheckinScreen> {
  int? _picked;
  bool _saving = false;

  static const _labels = ['Drained', 'Low', 'Okay', 'Good', 'Energized'];

  Future<void> _log(int v) async {
    if (_saving) return;
    setState(() {
      _picked = v;
      _saving = true;
    });
    HapticFeedback.mediumImpact();
    try {
      await ref.read(moodLogRepositoryProvider).add(energy: v);
      ref.invalidate(moodTodayLogsProvider);
    } catch (_) {
      // Offline / not signed in (dev) — best-effort; still leave the screen.
    }
    if (!mounted) return;
    // Brief beat so the selection reads before we leave.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    _exit();
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _saving ? null : _exit,
                  child: Text('Skip',
                      style: t.body.copyWith(color: c.textMuted)),
                ),
              ),
              const Spacer(),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(LucideIcons.zap, size: 26, color: c.accent),
              ),
              const SizedBox(height: 20),
              Text('Energy check-in', style: t.h1),
              const SizedBox(height: 6),
              Text("How's your energy right now?",
                  style: t.body.copyWith(color: c.textMuted)),
              const SizedBox(height: 28),

              // 1..5 selector
              Row(
                children: [
                  for (int i = 1; i <= 5; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 5 ? 0 : 8),
                        child: _EnergyButton(
                          value: i,
                          label: _labels[i - 1],
                          selected: _picked == i,
                          onTap: () => _log(i),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '1 = drained · 5 = fully energized',
                  style: t.meta.copyWith(color: c.textDim),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergyButton extends StatelessWidget {
  final int value;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _EnergyButton({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.accent : c.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: selected ? c.accent : c.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Text(
              '$value',
              style: AppType.numLg.copyWith(
                color: selected ? c.onAccent : c.textPrimary,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: selected ? c.accent : c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
