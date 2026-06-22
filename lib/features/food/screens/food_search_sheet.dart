import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_bundle.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';
import '../providers/recipe_providers.dart';
import '../widgets/log_confirmation_toast.dart';
import 'barcode_scanner_screen.dart';
import 'food_detail_screen.dart';
import 'recipe_builder_screen.dart';
import 'saved_meals_sheet.dart';

/// Full-screen modal that powers "Add food".
///
/// Three tabs — Recents · Search results · Favorites. Search is debounced
/// in the provider (200 ms of stability) and merges local custom foods +
/// Open Food Facts hits.
class FoodSearchSheet extends ConsumerStatefulWidget {
  final MealTimeSlot slot;
  final DateTime date;

  /// When true, picking a food returns a [FoodSelection] to the caller instead
  /// of logging it. Used by the task food-link editor. Log-only affordances
  /// (scan, saved meals, create dish, quick-add) are hidden in this mode.
  final bool selectMode;

  const FoodSearchSheet({
    super.key,
    required this.slot,
    required this.date,
    this.selectMode = false,
  });

  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet> {
  final _controller = TextEditingController();
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      ref.read(foodSearchQueryProvider.notifier).state = _controller.text;
      final next = _controller.text.trim().isNotEmpty;
      if (next != _hasQuery) setState(() => _hasQuery = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 4, AppSpace.screenH, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selectMode
                          ? 'Add food to task'
                          : 'Add to ${widget.slot.label}',
                      style: t.h2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20, color: c.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            // Search bar + scan — the scan button is height-matched to the
            // field via IntrinsicHeight so the two read as one control.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: c.border),
                        ),
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          style: t.body,
                          decoration: InputDecoration(
                            hintText: 'Search food or scan barcode...',
                            hintStyle: t.body.copyWith(color: c.textDim),
                            prefixIcon: Icon(LucideIcons.search, size: 18, color: c.textMuted),
                            suffixIcon: _hasQuery
                                ? IconButton(
                                    icon: Icon(LucideIcons.x, size: 16, color: c.textMuted),
                                    onPressed: _controller.clear,
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ),
                    if (!widget.selectMode) ...[
                      const SizedBox(width: 10),
                      _ScanButton(
                        onTap: () async {
                          final entry = await Navigator.of(context).push<MealEntry>(
                            MaterialPageRoute(
                              builder: (_) => BarcodeScannerScreen(
                                slot: widget.slot,
                                date: widget.date,
                              ),
                            ),
                          );
                          if (entry != null && context.mounted) {
                            Navigator.of(context).pop(entry);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _hasQuery
                  ? _SearchResults(
                      slot: widget.slot,
                      date: widget.date,
                      scroll: scroll,
                      selectMode: widget.selectMode,
                    )
                  : _BrowseView(
                      slot: widget.slot,
                      date: widget.date,
                      scroll: scroll,
                      selectMode: widget.selectMode,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search results ──────────────────────────────────────────────────

/// Merge the fast core results with the slower branded (Open Food Facts) pass,
/// de-duplicating by brand + name so a branded hit never repeats a catalog one.
/// Keys match [FoodRepository]'s own dedup so the two stay consistent.
List<Food> _mergeSearchResults(List<Food> core, List<Food> branded) {
  if (branded.isEmpty) return core;
  final seen = <String>{
    for (final f in core) '${f.brand ?? ''}|${f.name.toLowerCase()}',
  };
  final out = List<Food>.of(core);
  for (final f in branded) {
    if (seen.add('${f.brand ?? ''}|${f.name.toLowerCase()}')) out.add(f);
  }
  return out;
}

class _SearchResults extends ConsumerWidget {
  final MealTimeSlot slot;
  final DateTime date;
  final ScrollController scroll;
  final bool selectMode;
  const _SearchResults({
    required this.slot,
    required this.date,
    required this.scroll,
    this.selectMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(foodSearchResultsProvider);
    final branded = ref.watch(brandedSearchResultsProvider).valueOrNull ?? const <Food>[];
    final c = context.c;
    return results.when(
      data: (core) {
        final foods = _mergeSearchResults(core, branded);
        if (foods.isEmpty) {
          return _EmptyState(icon: LucideIcons.searchX, text: 'No matches found');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenH + 4, 4, AppSpace.screenH, 8),
              child: Text(
                '${foods.length} result${foods.length == 1 ? '' : 's'}',
                style: AppType.overline.copyWith(color: c.textDim),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 0, AppSpace.screenH, 24),
                itemCount: foods.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _RichFoodTile(
                    food: foods[i], slot: slot, date: date, selectMode: selectMode),
              ),
            ),
          ],
        );
      },
      loading: () => const _ShimmerList(),
      error: (e, _) => _EmptyState(icon: LucideIcons.wifiOff, text: 'Search failed'),
    );
  }
}

// ── Browse view (Track with Images · My Meals · Frequently Tracked) ──

class _BrowseView extends ConsumerWidget {
  final MealTimeSlot slot;
  final DateTime date;
  final ScrollController scroll;
  final bool selectMode;
  const _BrowseView({
    required this.slot,
    required this.date,
    required this.scroll,
    this.selectMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentFoodsProvider);
    final favorites = ref.watch(favoriteFoodsProvider);
    final recipes = ref.watch(userRecipesProvider);
    final bundles = ref.watch(savedMealBundlesProvider);

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      children: [
        const SizedBox(height: 6),

        // My Meals — multi-item bundles don't map to a single link item, so
        // they're hidden when picking a food for a task.
        if (!selectMode) ...[
          _SectionHeader(
            title: 'My Meals',
            actionLabel: 'View all',
            onAction: () => _openSavedMeals(context),
          ),
          bundles.when(
            data: (list) => list.isEmpty
                ? _Hint(text: 'Save a slot as a meal to reuse it in one tap.')
                : Column(
                    children: [
                      for (final b in list.take(4)) ...[
                        _MyMealTile(
                          bundle: b,
                          onTap: () => _logBundle(context, ref, b),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
            loading: () => const _ShimmerList(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
        ],

        // Frequently Tracked Foods
        _SectionHeader(title: 'Frequently Tracked Foods'),
        recents.when(
          data: (r) => r.isEmpty
              ? _Hint(text: 'Foods you log will appear here.')
              : Column(
                  children: [
                    for (final f in r) ...[
                      _RichFoodTile(
                          food: f, slot: slot, date: date, selectMode: selectMode),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
          loading: () => const _ShimmerList(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 18),

        // Create dish
        if (!selectMode)
          _CreateDishButton(
            onSaved: () => ref.invalidate(userRecipesProvider),
          ),

        // My Recipes
        recipes.when(
          data: (r) => r.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'My Recipes'),
                    for (final f in r) ...[
                      _RichFoodTile(
                          food: f, slot: slot, date: date, selectMode: selectMode),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        // Favorites
        favorites.when(
          data: (r) => r.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'Favorites'),
                    for (final f in r) ...[
                      _RichFoodTile(
                          food: f, slot: slot, date: date, selectMode: selectMode),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openSavedMeals(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SavedMealsSheet(slot: slot, date: date),
    );
  }

  Future<void> _logBundle(
      BuildContext context, WidgetRef ref, MealBundle bundle) async {
    final repo = ref.read(mealBundleRepositoryProvider);
    await repo.logBundle(bundle: bundle, slot: slot, date: date);
    ref.invalidate(diaryEntriesProvider);
    if (!context.mounted) return;
    LogConfirmationToast.show(context, bundle.totalNutrients,
        slotLabel: slot.label);
    Navigator.of(context).pop();
  }
}

// ── Section header with optional "View all" action ───────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: t.bodyStrong)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: t.meta.copyWith(
                    color: c.accent, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Press-scale tactility ────────────────────────────────────────────

/// Quick scale-down on press so a button has physical "give".
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const _PressScale({required this.child, required this.onTap, this.scale = 0.96});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;
  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── Barcode scan button (square, height-matched to the search field) ──

class _ScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _PressScale(
      onTap: onTap,
      scale: 0.92,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(LucideIcons.scanLine, size: 22, color: c.onAccent),
        ),
      ),
    );
  }
}

// ── "Create dish" CTA — a substantial, on-brand action card ───────────

class _CreateDishButton extends StatelessWidget {
  final VoidCallback onSaved;
  const _CreateDishButton({required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _PressScale(
      scale: 0.98,
      onTap: () async {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const RecipeBuilderScreen()),
        );
        if (saved == true) onSaved();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(LucideIcons.chefHat, size: 20, color: c.onAccent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a dish',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: c.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Combine foods into a reusable recipe',
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
            const SizedBox(width: 10),
            // Decorative accent "+" — the whole row is the tap target.
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.accent, width: 1.4),
              ),
              child: Icon(LucideIcons.plus, size: 16, color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ── My Meals (saved bundle) tile ─────────────────────────────────────

class _MyMealTile extends StatelessWidget {
  final MealBundle bundle;
  final VoidCallback onTap;
  const _MyMealTile({required this.bundle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final ingredients =
        bundle.items.map((i) => i.foodName).join(', ');
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bundle.name,
                      style: t.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (ingredients.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      ingredients,
                      style: t.meta.copyWith(color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${bundle.totalKcal.round()} kcal',
                style: AppType.numMd.copyWith(color: c.textSecondary, fontSize: 13)),
            const SizedBox(width: 10),
            _QuickAddButton(onTap: onTap),
          ],
        ),
      ),
    );
  }
}

// ── Outline "+" quick-add button (matches HealthifyMe) ───────────────

class _QuickAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: c.accent, width: 1.4)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(LucideIcons.plus, size: 16, color: c.accent),
        ),
      ),
    );
  }
}

// ── Rich food tile with macro chips ─────────────────────────────────

class _RichFoodTile extends ConsumerWidget {
  final Food food;
  final MealTimeSlot slot;
  final DateTime date;
  final bool selectMode;
  const _RichFoodTile({
    required this.food,
    required this.slot,
    required this.date,
    this.selectMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final p = food.per;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () async {
          if (selectMode) {
            final selection = await Navigator.of(context).push<FoodSelection>(
              MaterialPageRoute(
                builder: (_) => FoodDetailScreen(
                    food: food, initialSlot: slot, date: date, selectMode: true),
              ),
            );
            if (selection != null && context.mounted) {
              Navigator.of(context).pop(selection);
            }
            return;
          }
          final logged = await Navigator.of(context).push<MealEntry>(
            MaterialPageRoute(
              builder: (_) => FoodDetailScreen(food: food, initialSlot: slot, date: date),
            ),
          );
          if (logged != null && context.mounted) {
            Navigator.of(context).pop(logged);
          }
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Source icon
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _sourceColor(c).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Icon(
                  _sourceIcon(),
                  size: 16,
                  color: _sourceColor(c),
                ),
              ),
              const SizedBox(width: 12),
              // Name + brand + macro chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: t.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _OriginBadge(
                          label: _sourceLabel(),
                          color: _sourceColor(c),
                        ),
                        const SizedBox(width: 6),
                        if (food.brand != null && food.brand!.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              food.brand!,
                              style: t.meta.copyWith(color: c.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text('·', style: t.meta.copyWith(color: c.textDim)),
                          ),
                        ],
                        Text(
                          '${food.servingQty.round()} ${food.servingUnit}',
                          style: t.meta.copyWith(color: c.textDim),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Macro pills row
                    Row(
                      children: [
                        _MacroPill(label: 'P', value: p.proteinG, color: c.athletic),
                        const SizedBox(width: 6),
                        _MacroPill(label: 'C', value: p.carbsG, color: c.amber),
                        const SizedBox(width: 6),
                        _MacroPill(label: 'F', value: p.fatG, color: c.mind),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Calories + quick-add (logs one default serving)
              Text('${p.kcal.round()} kcal',
                  style: AppType.numMd
                      .copyWith(color: c.textSecondary, fontSize: 13)),
              // In select mode the row tap opens the portion picker, so the
              // one-tap quick-add (which logs immediately) is hidden.
              if (!selectMode) ...[
                const SizedBox(width: 10),
                _QuickAddButton(onTap: () => _quickAdd(context, ref)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final repo = ref.read(foodRepositoryProvider);
    final entry = await repo.logFood(
      food: food,
      qty: food.servingQty,
      slot: slot,
      date: date,
    );
    if (context.mounted) Navigator.of(context).pop(entry);
  }

  IconData _sourceIcon() => switch (food.source) {
        'curated' => LucideIcons.chefHat,
        'ifct' || 'local' => LucideIcons.utensils,
        'usda' => LucideIcons.leaf,
        'off' => LucideIcons.scanLine,
        'recipe' => LucideIcons.chefHat,
        _ => LucideIcons.user,
      };

  Color _sourceColor(AppPalette c) => switch (food.source) {
        'curated' => c.amber,
        'ifct' || 'local' => c.accent,
        'usda' => c.positive,
        'off' => c.athletic,
        'recipe' => c.mind,
        _ => c.body,
      };

  String _sourceLabel() => switch (food.source) {
        'curated' => 'DISH',
        'ifct' || 'local' => 'IFCT',
        'usda' => 'USDA',
        'off' => 'OFF',
        'recipe' => 'MINE',
        _ => 'CUSTOM',
      };
}

/// Small badge that indicates where the food's nutrition data came from.
class _OriginBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _OriginBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Macro pill ──────────────────────────────────────────────────────

class _MacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$label ${value.round()}g',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Shimmer loading ─────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH, vertical: 8),
      child: Column(
        children: List.generate(4, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12, width: 140,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10, width: 80,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10, width: 110,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        )),
      ),
    );
  }
}

// ── Empty + hint states ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, size: 24, color: c.textDim),
          ),
          const SizedBox(height: 12),
          Text(text, style: t.body.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Text(text, style: t.meta.copyWith(color: c.textMuted)),
    );
  }
}
