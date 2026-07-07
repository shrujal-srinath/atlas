import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/theme/app_theme.dart';
import 'package:atlas/features/food/widgets/food_score_info_sheet.dart';

void main() {
  testWidgets('explainer distinguishes food quality from goal adherence',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: FoodScoreInfoSheet()),
    ));
    expect(find.text('Two ways we read your day'), findsOneWidget);
    expect(find.text('Food quality'), findsOneWidget);
    expect(find.text('Goal adherence'), findsOneWidget);
    // Quality bands are listed; adherence points at the ATLAS score.
    expect(find.textContaining('Excellent', findRichText: true), findsOneWidget);
    expect(find.textContaining('ATLAS score'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });
}
