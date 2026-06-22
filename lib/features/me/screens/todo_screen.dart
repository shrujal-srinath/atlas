import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_back_button.dart';

/// Placeholder for the upcoming "Today's tasks / To-do" section that will live
/// in the Notes tab. The home reminder tile's To-do face links here; the real
/// experience is still to be built.
class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(),
        title: Text("Today's Tasks", style: t.h2),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Icon(LucideIcons.checkSquare, size: 28, color: c.accent),
              ),
              const SizedBox(height: 20),
              Text('Coming soon', style: t.h1, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'A dedicated To-do section is being built into your Notes tab. '
                'For now, your tasks live on the Home timeline.',
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: c.textMuted, height: 1.45),
              ),
              const SizedBox(height: 22),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.wrench, size: 13, color: c.amber),
                    const SizedBox(width: 6),
                    Text(
                      'Under construction',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
