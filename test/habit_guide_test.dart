import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/theme/app_theme.dart';
import 'package:atlas/features/onboarding/habit_guide.dart';

void main() {
  test('habit guide steps through fab → habitTile → off', () {
    final c = HabitGuideController();
    expect(c.state, HabitGuideStep.off);

    c.start();
    expect(c.state, HabitGuideStep.fab);

    c.advanceToTile();
    expect(c.state, HabitGuideStep.habitTile);

    c.dismiss();
    expect(c.state, HabitGuideStep.off);
  });

  testWidgets(
    'CoachmarkLayer shows copy and passes taps through to the target',
    (tester) async {
      final targetKey = GlobalKey();
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 300,
                  child: GestureDetector(
                    key: targetKey,
                    onTap: () => tapped = true,
                    child: Container(width: 60, height: 60, color: Colors.blue),
                  ),
                ),
                Positioned.fill(
                  child: CoachmarkLayer(
                    targetKey: targetKey,
                    title: 'Tap here',
                    body: 'Do the thing.',
                    stepIndex: 0,
                    stepCount: 2,
                    onSkip: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // Let the post-frame measure + entrance run (no pumpAndSettle — the ring
      // pulse loops forever).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Tap here'), findsOneWidget);
      expect(find.text('Do the thing.'), findsOneWidget);

      // The hole over the target stays tappable through the scrim.
      await tester.tapAt(const Offset(130, 330));
      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'CoachmarkLayer keeps the tooltip on-screen for a bottom target',
    (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                // A target hugging the very bottom, like the center FAB.
                Positioned(
                  left: 150,
                  bottom: 18,
                  child: Container(
                    key: targetKey,
                    width: 60,
                    height: 60,
                    color: Colors.blue,
                  ),
                ),
                Positioned.fill(
                  child: CoachmarkLayer(
                    targetKey: targetKey,
                    circular: true,
                    title: 'Tap here',
                    body: 'A reasonably long body line for the tooltip card.',
                    stepIndex: 0,
                    stepCount: 2,
                    onSkip: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // Lock the (stable) rect, then run the entrance.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 350));

      final screen = tester.getSize(find.byType(MaterialApp));
      final card = tester.getRect(find.text('Tap here'));
      // The card sits fully on-screen (the old bug pushed it off the bottom).
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(screen.height));
      // And it's placed above the bottom-anchored target, never over it.
      expect(card.bottom, lessThan(screen.height - 60));
    },
  );
}
