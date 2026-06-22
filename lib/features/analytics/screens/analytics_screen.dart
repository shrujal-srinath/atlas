import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../../food/providers/food_providers.dart';
import '../../food/providers/food_sub_tab_provider.dart';
import '../../food/providers/weekly_totals_provider.dart';
import '../../journal/widgets/wellness_trend_section.dart';
import '../../stats/providers/consistency_provider.dart';
import '../../stats/widgets/consistency_heatmap.dart';
import '../providers/analytics_provider.dart';

part 'analytics_summary.dart';
part 'analytics_charts.dart';
part 'analytics_sections.dart';
part 'analytics_cards.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final dataAsync = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(fallback: '/stats'),
        title: Text('Trends', style: t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: dataAsync.when(
          data: (data) => CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Summary cards row
              SliverToBoxAdapter(child: _SummaryRow(data: data)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Score trend chart
              SliverToBoxAdapter(child: _ScoreTrendChart(data: data)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Per-section trend lines (Athletic / Building / Breaking)
              const SliverToBoxAdapter(child: _SectionTrendChart()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // This week vs last (overall + per section)
              SliverToBoxAdapter(child: _WeekCompareCard(data: data)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Section breakdown
              SliverToBoxAdapter(child: _SectionBreakdown(sections: data.sections)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Performance patterns — best weekdays + time of day
              SliverToBoxAdapter(child: _PatternsCard(data: data)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Heatmap
              const SliverToBoxAdapter(child: _CompletionHeatmap()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Nutrition performance (drives half the Body score + its own XP)
              const SliverToBoxAdapter(child: _NutritionCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Streak leaderboard
              if (data.streaks.isNotEmpty)
                SliverToBoxAdapter(
                    child: _StreakLeaderboard(streaks: data.streaks)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Wellness trends (mood/energy/sleep — last 30 days).
              const SliverToBoxAdapter(child: WellnessTrendSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Wellness × performance correlation
              const SliverToBoxAdapter(child: _WellnessVsScoreCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 118)),
            ],
          ),
          loading: () => Center(
            child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Text(friendlyError(e),
                style: TextStyle(color: c.negative, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}
