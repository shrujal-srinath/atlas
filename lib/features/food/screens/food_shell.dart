import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/food_sub_tab_provider.dart';
import 'body_tab.dart';
import 'diary_tab.dart';
import 'insights_tab.dart';

/// Root of the Food bottom-nav branch. Hosts the Diary / Body / Insights
/// sub-tabs and persists the selected sub-tab across nav switches via
/// [foodSubTabProvider].
class FoodShell extends ConsumerStatefulWidget {
  const FoodShell({super.key});

  @override
  ConsumerState<FoodShell> createState() => _FoodShellState();
}

class _FoodShellState extends ConsumerState<FoodShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(foodSubTabProvider).index;
    _tab = TabController(length: 3, vsync: this, initialIndex: initial);
    _tab.addListener(_syncProvider);
  }

  void _syncProvider() {
    if (_tab.indexIsChanging) return;
    ref.read(foodSubTabProvider.notifier).state =
        FoodSubTab.values[_tab.index];
  }

  @override
  void dispose() {
    _tab.removeListener(_syncProvider);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Allow external deep-links (e.g. the Stats nutrition card) to drive the
    // visible sub-tab even when the shell is already alive in the IndexedStack.
    ref.listen<FoodSubTab>(foodSubTabProvider, (_, next) {
      if (_tab.index != next.index) _tab.animateTo(next.index);
    });
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: c.background,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: false,
                indicatorColor: c.accent,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: c.accent,
                unselectedLabelColor: c.textMuted,
                labelStyle: AppType.overline.copyWith(letterSpacing: 1.4, fontSize: 11),
                unselectedLabelStyle:
                    AppType.overline.copyWith(letterSpacing: 1.4, fontSize: 11),
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'DIARY'),
                  Tab(text: 'BODY'),
                  Tab(text: 'INSIGHTS'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  DiaryTab(),
                  BodyTab(),
                  InsightsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
