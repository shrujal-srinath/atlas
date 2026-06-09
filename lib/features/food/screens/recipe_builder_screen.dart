import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/food.dart';
import '../domain/recipe.dart';
import '../providers/food_providers.dart';
import '../providers/recipe_providers.dart';

/// Screen for creating / editing a multi-ingredient recipe.
///
/// Flow: name + servings → search & add ingredients → adjust qty each →
/// auto-computed per-serving macros → save.
class RecipeBuilderScreen extends ConsumerStatefulWidget {
  /// Pass an existing recipe's Food row + ingredients to edit.
  final Food? existingFood;
  final List<RecipeIngredient>? existingIngredients;

  const RecipeBuilderScreen({
    super.key,
    this.existingFood,
    this.existingIngredients,
  });

  @override
  ConsumerState<RecipeBuilderScreen> createState() =>
      _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends ConsumerState<RecipeBuilderScreen> {
  late final TextEditingController _nameCtrl;
  int _servings = 1;
  final List<RecipeIngredient> _ingredients = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.existingFood?.name ?? '',
    );
    if (widget.existingIngredients != null) {
      _ingredients.addAll(widget.existingIngredients!);
    }
    if (widget.existingFood != null) {
      // Reverse-engineer servings from stored serving_qty vs total grams.
      final totalG = widget.existingIngredients
              ?.fold<double>(0, (a, i) => a + i.qty) ??
          0;
      final perG = widget.existingFood!.servingQty;
      if (perG > 0 && totalG > 0) {
        _servings = (totalG / perG).round().clamp(1, 99);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Recipe get _recipe => Recipe(
        id: widget.existingFood?.id,
        name: _nameCtrl.text.trim(),
        servings: _servings,
        ingredients: _ingredients,
      );

  Nutrients get _perServing => _recipe.perServing;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _ingredients.isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(recipeRepositoryProvider);
      await repo.saveRecipe(_recipe);
      ref.invalidate(userRecipesProvider);
      ref.invalidate(foodSearchResultsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
      setState(() => _saving = false);
    }
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  void _updateQty(int index, double newQty) {
    if (newQty <= 0) return;
    setState(() {
      _ingredients[index] = _ingredients[index].copyWith(qty: newQty);
    });
  }

  Future<void> _addIngredient() async {
    final food = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _IngredientSearchSheet(),
    );
    if (food == null || !mounted) return;
    setState(() {
      _ingredients.add(RecipeIngredient(
        food: food,
        qty: food.servingQty,
        unit: food.servingUnit,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final n = _perServing;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        title: Text(
          widget.existingFood != null ? 'Edit Recipe' : 'Create Recipe',
          style: t.h2,
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Save',
                    style: TextStyle(
                      color: _canSave ? c.accent : c.textDim,
                      fontWeight: FontWeight.w600,
                    )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.screenH, 8, AppSpace.screenH, 100),
        children: [
          // Name field
          TextField(
            controller: _nameCtrl,
            style: t.body,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Recipe name',
              prefixIcon:
                  Icon(LucideIcons.chefHat, size: 18, color: c.textMuted),
            ),
          ),
          const SizedBox(height: 16),

          // Servings stepper
          Row(
            children: [
              Text('Servings', style: t.bodyStrong),
              const Spacer(),
              _StepperButton(
                icon: LucideIcons.minus,
                onTap: _servings > 1
                    ? () => setState(() => _servings--)
                    : null,
                c: c,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$_servings',
                    style: AppType.numLg.copyWith(color: c.textPrimary)),
              ),
              _StepperButton(
                icon: LucideIcons.plus,
                onTap: _servings < 99
                    ? () => setState(() => _servings++)
                    : null,
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Per-serving nutrition preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PER SERVING',
                    style: AppType.overline.copyWith(color: c.textMuted)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MacroChip('Kcal', n.kcal, c.textPrimary, c),
                    _MacroChip('Protein', n.proteinG, c.accent, c),
                    _MacroChip('Carbs', n.carbsG, c.amber, c),
                    _MacroChip('Fat', n.fatG, c.negative, c),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ingredients header
          Row(
            children: [
              Text('INGREDIENTS',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              Text('${_ingredients.length} items',
                  style: t.meta.copyWith(color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 8),

          // Ingredient list
          if (_ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Tap + to add ingredients',
                    style: t.body.copyWith(color: c.textMuted)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _ingredients.length; i++) ...[
                    _IngredientRow(
                      ingredient: _ingredients[i],
                      onQtyChanged: (q) => _updateQty(i, q),
                      onRemove: () => _removeIngredient(i),
                    ),
                    if (i < _ingredients.length - 1)
                      Divider(height: 1, color: c.border),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Add ingredient button
          OutlinedButton.icon(
            onPressed: _addIngredient,
            icon: Icon(LucideIcons.plus, size: 16, color: c.accent),
            label: Text('Add ingredient',
                style: t.body.copyWith(color: c.accent)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ingredient row ──────────────────────────────────────────────

class _IngredientRow extends StatefulWidget {
  final RecipeIngredient ingredient;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onRemove;
  const _IngredientRow({
    required this.ingredient,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: _fmtQty(widget.ingredient.qty),
    );
  }

  @override
  void didUpdateWidget(_IngredientRow old) {
    super.didUpdateWidget(old);
    if (old.ingredient.qty != widget.ingredient.qty) {
      _qtyCtrl.text = _fmtQty(widget.ingredient.qty);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final ing = widget.ingredient;
    final kcal = ing.nutrients.kcal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ing.food.name,
                    style: t.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${kcal.round()} kcal',
                    style: t.meta.copyWith(color: c.textMuted)),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppType.numMd.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null && n > 0) widget.onQtyChanged(n);
              },
            ),
          ),
          const SizedBox(width: 4),
          Text(ing.unit, style: t.meta.copyWith(color: c.textMuted)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onRemove,
            child: Icon(LucideIcons.x, size: 16, color: c.textDim),
          ),
        ],
      ),
    );
  }
}

// ── Stepper button ──────────────────────────────────────────────

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final AppPalette c;
  const _StepperButton({required this.icon, this.onTap, required this.c});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon,
              size: 16,
              color: onTap != null ? c.textPrimary : c.textDim),
        ),
      );
}

// ── Macro chip ──────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final AppPalette c;
  const _MacroChip(this.label, this.value, this.color, this.c);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value >= 10 ? value.round().toString() : value.toStringAsFixed(1),
            style: AppType.numLg.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: AppType.meta.copyWith(color: c.textMuted)),
        ],
      );
}

// ── Ingredient search sheet ─────────────────────────────────────

class _IngredientSearchSheet extends ConsumerStatefulWidget {
  const _IngredientSearchSheet();

  @override
  ConsumerState<_IngredientSearchSheet> createState() =>
      _IngredientSearchSheetState();
}

class _IngredientSearchSheetState
    extends ConsumerState<_IngredientSearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 14, AppSpace.screenH, 10),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: t.body,
                decoration: InputDecoration(
                  hintText: 'Search ingredient…',
                  prefixIcon:
                      Icon(LucideIcons.search, size: 18, color: c.textMuted),
                ),
                onChanged: (v) {
                  ref.read(foodSearchQueryProvider.notifier).state = v;
                  setState(() => _query = v.trim());
                },
              ),
            ),
            Expanded(
              child: _query.length < 2
                  ? Center(
                      child: Text('Type to search',
                          style: t.body.copyWith(color: c.textMuted)),
                    )
                  : _IngredientResults(scroll: scroll),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientResults extends ConsumerWidget {
  final ScrollController scroll;
  const _IngredientResults({required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final results = ref.watch(foodSearchResultsProvider);

    return results.when(
      loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) =>
          Center(child: Text('Search failed', style: t.body)),
      data: (foods) => foods.isEmpty
          ? Center(
              child: Text('No results',
                  style: t.body.copyWith(color: c.textMuted)))
          : ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.screenH, vertical: 4),
              itemCount: foods.length,
              itemBuilder: (_, i) {
                final f = foods[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  onTap: () => Navigator.of(context).pop(f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name,
                                  style: t.bodyStrong,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (f.brand != null && f.brand!.isNotEmpty)
                                Text(f.brand!,
                                    style:
                                        t.meta.copyWith(color: c.textMuted)),
                            ],
                          ),
                        ),
                        Text('${f.per.kcal.round()}',
                            style: AppType.numMd
                                .copyWith(color: c.textPrimary)),
                        const SizedBox(width: 2),
                        Text('kcal',
                            style: t.meta.copyWith(color: c.textMuted)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
