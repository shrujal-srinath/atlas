import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';
import '../providers/recipe_providers.dart';
import 'barcode_scanner_screen.dart';
import 'food_detail_screen.dart';
import 'recipe_builder_screen.dart';

/// Full-screen modal that powers "Add food".
///
/// Three tabs — Recents · Search results · Favorites. Search is debounced
/// in the provider (200 ms of stability) and merges local custom foods +
/// Open Food Facts hits.
class FoodSearchSheet extends ConsumerStatefulWidget {
  final MealTimeSlot slot;
  final DateTime date;
  const FoodSearchSheet({super.key, required this.slot, required this.date});

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
                      'Add to ${widget.slot.label}',
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
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
              child: Row(
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
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: IconButton(
                      icon: Icon(LucideIcons.scanLine, size: 20, color: c.accent),
                      tooltip: 'Scan barcode',
                      onPressed: () async {
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _hasQuery
                  ? _SearchResults(slot: widget.slot, date: widget.date, scroll: scroll)
                  : _BrowseView(
                      slot: widget.slot,
                      date: widget.date,
                      scroll: scroll,
                      onQuickSearch: (q) {
                        _controller.text = q;
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Popular food quick-search chips ─────────────────────────────────

const _popularFoods = [
  'Rice', 'Chicken', 'Egg', 'Banana', 'Roti', 'Dal',
  'Milk', 'Oats', 'Paneer', 'Curd', 'Apple', 'Bread',
];

// ── Search results ──────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  final MealTimeSlot slot;
  final DateTime date;
  final ScrollController scroll;
  const _SearchResults({required this.slot, required this.date, required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(foodSearchResultsProvider);
    final c = context.c;
    return results.when(
      data: (foods) {
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
                itemBuilder: (_, i) => _RichFoodTile(food: foods[i], slot: slot, date: date),
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

// ── Browse view (recents + favorites + popular) ─────────────────────

class _BrowseView extends ConsumerWidget {
  final MealTimeSlot slot;
  final DateTime date;
  final ScrollController scroll;
  final ValueChanged<String> onQuickSearch;
  const _BrowseView({
    required this.slot,
    required this.date,
    required this.scroll,
    required this.onQuickSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentFoodsProvider);
    final favorites = ref.watch(favoriteFoodsProvider);
    final recipes = ref.watch(userRecipesProvider);
    final c = context.c;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      children: [
        // Popular foods — quick search chips
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Text('QUICK ADD', style: AppType.overline.copyWith(color: c.textMuted)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in _popularFoods)
              _QuickChip(label: name, onTap: () => onQuickSearch(name)),
          ],
        ),
        const SizedBox(height: 8),

        // Create dish button
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: OutlinedButton.icon(
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const RecipeBuilderScreen()),
              );
              if (saved == true) ref.invalidate(userRecipesProvider);
            },
            icon: Icon(LucideIcons.chefHat, size: 16, color: c.accent),
            label: Text('Create dish', style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.accent,
            )),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // My Recipes
        recipes.when(
          data: (r) => r.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
                      child: Text('MY RECIPES', style: AppType.overline.copyWith(color: c.textMuted)),
                    ),
                    for (final f in r) ...[
                      _RichFoodTile(food: f, slot: slot, date: date),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        // Recent
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
          child: Text('RECENT', style: AppType.overline.copyWith(color: c.textMuted)),
        ),
        recents.when(
          data: (r) => r.isEmpty
              ? _Hint(text: 'Foods you log will appear here.')
              : Column(
                  children: [
                    for (final f in r) ...[
                      _RichFoodTile(food: f, slot: slot, date: date),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
          loading: () => const _ShimmerList(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        // Favorites
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
          child: Text('FAVORITES', style: AppType.overline.copyWith(color: c.textMuted)),
        ),
        favorites.when(
          data: (r) => r.isEmpty
              ? _Hint(text: 'Star a food on its detail screen to favorite it.')
              : Column(
                  children: [
                    for (final f in r) ...[
                      _RichFoodTile(food: f, slot: slot, date: date),
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
}

// ── Rich food tile with macro chips ─────────────────────────────────

class _RichFoodTile extends ConsumerWidget {
  final Food food;
  final MealTimeSlot slot;
  final DateTime date;
  const _RichFoodTile({required this.food, required this.slot, required this.date});

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
                        _MacroPill(label: 'P', value: p.proteinG, color: c.accent),
                        const SizedBox(width: 6),
                        _MacroPill(label: 'C', value: p.carbsG, color: c.athletic),
                        const SizedBox(width: 6),
                        _MacroPill(label: 'F', value: p.fatG, color: c.mind),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Calorie badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${p.kcal.round()}',
                      style: AppType.numMd.copyWith(color: c.accent, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: c.accent.withValues(alpha: 0.7),
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

  IconData _sourceIcon() => switch (food.source) {
        'local' => LucideIcons.utensils,
        'off' => LucideIcons.scanLine,
        'recipe' => LucideIcons.chefHat,
        _ => LucideIcons.user,
      };

  Color _sourceColor(AppPalette c) => switch (food.source) {
        'local' => c.accent,
        'off' => c.athletic,
        'recipe' => c.mind,
        _ => c.body,
      };

  String _sourceLabel() => switch (food.source) {
        'local' => 'IFCT',
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

// ── Quick search chip ───────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: c.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
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
