import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';

// ── Fallback measures ───────────────────────────────────────────────
// Used when a food has no catalog-supplied measures (custom foods, OFF).
// Catalog foods carry their own food-specific list (e.g. 1 katori ≈ 150 g).
const _kDefaultMeasures = <FoodMeasure>[
  FoodMeasure('g', 1),
  FoodMeasure('Bowl', 200),
  FoodMeasure('Katori', 150),
  FoodMeasure('Cup', 240),
  FoodMeasure('Plate', 300),
  FoodMeasure('Piece', 50),
  FoodMeasure('Slice', 30),
  FoodMeasure('Roti', 40),
  FoodMeasure('Tbsp', 15),
  FoodMeasure('Tsp', 5),
  FoodMeasure('Glass', 250),
];

// ── Screen ──────────────────────────────────────────────────────────

/// A configured portion picked in [FoodDetailScreen]'s select mode — returned
/// to a caller (e.g. the task food-link editor) instead of being logged.
class FoodSelection {
  final Food food;
  final double qty;       // human quantity, e.g. 1
  final String unit;      // measure label, e.g. "Katori"
  final Nutrients totals; // scaled for [qty] [unit]
  const FoodSelection({
    required this.food,
    required this.qty,
    required this.unit,
    required this.totals,
  });
}

class FoodDetailScreen extends ConsumerStatefulWidget {
  final Food food;
  final MealTimeSlot initialSlot;
  final DateTime date;

  /// When true, the screen returns a [FoodSelection] (portion picker only) on
  /// confirm instead of logging to the diary. Used by the task food-link editor.
  final bool selectMode;

  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.initialSlot,
    required this.date,
    this.selectMode = false,
  });

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  late MealTimeSlot _slot;
  late FoodMeasure _measure;
  double _quantity = 1.0;
  bool _saving = false;
  bool _favorited = false;

  List<FoodMeasure> get _measures =>
      widget.food.measures.isNotEmpty ? widget.food.measures : _kDefaultMeasures;

  @override
  void initState() {
    super.initState();
    _slot = widget.initialSlot;
    _favorited = widget.food.isFavorite;
    final ms = _measures;
    // Default to a realistic household portion ("1 katori") when one exists,
    // otherwise one serving's weight in grams.
    _measure = ms.firstWhere((m) => m.grams > 1, orElse: () => ms.first);
    _quantity = _measure.grams > 1 ? 1.0 : widget.food.servingQty;
  }

  double get _totalGrams => _quantity * _measure.grams;

  double get _factor =>
      widget.food.servingQty == 0 ? 0 : _totalGrams / widget.food.servingQty;

  Nutrients get _scaled => widget.food.per.scale(_factor);

  Future<void> _openServingPicker() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => _ServingPickerSheet(
        food: widget.food,
        measures: _measures,
        initialQty: _quantity,
        initialMeasure: _measure,
        // Live: every wheel tick updates the macro card behind the sheet.
        onChanged: (q, m) => setState(() {
          _quantity = q;
          _measure = m;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final f = widget.food;
    final n = _scaled;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Food'),
        actions: [
          if (!widget.selectMode)
            IconButton(
              icon: Icon(
                _favorited ? Icons.favorite_rounded : LucideIcons.heart,
                size: 20,
                color: _favorited ? c.negative : c.textMuted,
              ),
              onPressed: _toggleFav,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 4, AppSpace.screenH, 24),
                children: [
                  // ── Food name & brand
                  Text(f.name, style: t.h1),
                  const SizedBox(height: 4),
                  Text(
                    f.brand == null || f.brand!.isEmpty
                        ? 'per ${f.servingQty.round()} ${f.servingUnit}'
                        : '${f.brand!}  ·  per ${f.servingQty.round()} ${f.servingUnit}',
                    style: t.body.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 20),

                  // ── Serving (tap → unified quantity + measure wheel picker)
                  _ServingSummaryCard(
                    quantity: _quantity,
                    measure: _measure,
                    netWtG: _totalGrams,
                    onTap: _openServingPicker,
                  ),
                  const SizedBox(height: 24),

                  // ── Macronutrients Breakdown
                  _SectionLabel(text: 'MACRONUTRIENTS BREAKDOWN'),
                  const SizedBox(height: 10),
                  _MacroBreakdownCard(n: n, netWtG: _totalGrams),
                  const SizedBox(height: 22),

                  // ── Meal slot picker (the link editor owns the slot, so
                  //    select mode hides it).
                  if (!widget.selectMode) ...[
                    _SectionLabel(text: 'MEAL'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in kDiarySlotOrder)
                          _SlotChip(
                            label: s.label,
                            active: s == _slot,
                            onTap: () => setState(() => _slot = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                  ],

                  // ── Micronutrients Breakdown
                  _SectionLabel(text: 'MICRONUTRIENTS BREAKDOWN'),
                  const SizedBox(height: 8),
                  _FullNutrition(n: n),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Sticky bottom button
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 10, AppSpace.screenH, 16),
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _totalGrams <= 0 || _saving
                        ? null
                        : (widget.selectMode ? _select : _log),
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.selectMode
                                ? 'Add to task · ${n.kcal.round()} kcal'
                                : 'Add ${n.kcal.round()} kcal to ${_slot.label}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _log() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(foodRepositoryProvider);
      final entry = await repo.logFood(
        food: widget.food,
        qty: _totalGrams,
        slot: _slot,
        date: widget.date,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(entry);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnack(context, e);
    }
  }

  /// Select mode: return the configured portion to the caller without logging.
  void _select() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      FoodSelection(
        food: widget.food,
        qty: _quantity,
        unit: _measure.label,
        totals: _scaled,
      ),
    );
  }

  Future<void> _toggleFav() async {
    if (widget.food.source == 'off' && widget.food.id.startsWith('off:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log this food first, then favorite it')),
      );
      return;
    }
    setState(() => _favorited = !_favorited);
    try {
      final repo = ref.read(foodRepositoryProvider);
      await repo.toggleFavorite(widget.food.id, _favorited);
    } catch (_) {
      setState(() => _favorited = !_favorited);
    }
  }
}

String _fmtQty(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  // up to 2 decimals, trimmed (0.75, 1.5)
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

// ── Serving summary card (tap to open the wheel picker) ───────────────
//
// A single self-describing tile: the current portion stated in plain
// language ("1 Katori"), its net weight, and a clear affordance to change
// it. Tapping opens the unified quantity + measure picker.

class _ServingSummaryCard extends StatelessWidget {
  final double quantity;
  final FoodMeasure measure;
  final double netWtG;
  final VoidCallback onTap;
  const _ServingSummaryCard({
    required this.quantity,
    required this.measure,
    required this.netWtG,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SERVING',
                        style: AppType.overline.copyWith(color: c.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_fmtQty(quantity),
                            style: AppType.numLg
                                .copyWith(color: c.textPrimary, fontSize: 28)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            measure.label,
                            style: t.bodyStrong.copyWith(color: c.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('≈ ${netWtG.round()} g total',
                        style: t.meta.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Edit affordance — pill that reads as the tap target.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.pencil, size: 13, color: c.accent),
                    const SizedBox(width: 6),
                    Text('Edit',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        )),
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

// ── Unified Quantity + Measure picker sheet ───────────────────────────
//
// Two linked wheels in one sheet. Spinning either updates a live calorie +
// macro readout in the sheet AND (via onChanged) the breakdown card on the
// screen behind it, so the numbers move the instant you scroll. The quantity
// wheel adapts to the measure: gram counts for g/ml, fractional servings for
// household units (¼, ½, ¾, 1, 1¼ …).

class _ServingPickerSheet extends StatefulWidget {
  final Food food;
  final List<FoodMeasure> measures;
  final double initialQty;
  final FoodMeasure initialMeasure;
  final void Function(double qty, FoodMeasure measure) onChanged;
  const _ServingPickerSheet({
    required this.food,
    required this.measures,
    required this.initialQty,
    required this.initialMeasure,
    required this.onChanged,
  });

  @override
  State<_ServingPickerSheet> createState() => _ServingPickerSheetState();
}

class _ServingPickerSheetState extends State<_ServingPickerSheet> {
  static const _counts = <double>[
    0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
    3.5, 4, 4.5, 5, 6, 7, 8, 9, 10,
  ];

  late double _qty;
  late FoodMeasure _measure;
  late List<double> _qtyOpts;
  late FixedExtentScrollController _qtyCtrl;
  late FixedExtentScrollController _measureCtrl;

  @override
  void initState() {
    super.initState();
    _measure = widget.initialMeasure;
    _qty = widget.initialQty;
    _qtyOpts = _optionsFor(_measure);
    _qtyCtrl = FixedExtentScrollController(
        initialItem: _nearestIndex(_qtyOpts, _qty));
    final mi = widget.measures.indexWhere((m) => m.label == _measure.label);
    _measureCtrl =
        FixedExtentScrollController(initialItem: mi < 0 ? 0 : mi);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _measureCtrl.dispose();
    super.dispose();
  }

  bool _isGram(FoodMeasure m) => m.grams <= 1.0;

  List<double> _optionsFor(FoodMeasure m) {
    if (!_isGram(m)) return _counts;
    // grams / ml: fine near the bottom, coarser as it grows.
    final out = <double>[];
    for (var g = 5; g <= 200; g += 5) {
      out.add(g.toDouble());
    }
    for (var g = 210; g <= 500; g += 10) {
      out.add(g.toDouble());
    }
    for (var g = 525; g <= 1000; g += 25) {
      out.add(g.toDouble());
    }
    return out;
  }

  int _nearestIndex(List<double> opts, double v) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < opts.length; i++) {
      final d = (opts[i] - v).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _emit() => widget.onChanged(_qty, _measure);

  void _onQty(int i) {
    HapticFeedback.selectionClick();
    setState(() => _qty = _qtyOpts[i]);
    _emit();
  }

  void _onMeasure(int i) {
    HapticFeedback.selectionClick();
    final m = widget.measures[i];
    final opts = _optionsFor(m);
    // Sensible default amount when switching unit types.
    final newQty = _isGram(m) ? widget.food.servingQty : 1.0;
    setState(() {
      _measure = m;
      _qtyOpts = opts;
      _qty = newQty;
    });
    _qtyCtrl.jumpToItem(_nearestIndex(opts, newQty));
    _emit();
  }

  double get _totalGrams => _qty * _measure.grams;
  Nutrients get _scaled => widget.food.per.scale(
      widget.food.servingQty == 0 ? 0 : _totalGrams / widget.food.servingQty);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final n = _scaled;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Live readout (kcal + macros) — updates as you spin
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 16, AppSpace.screenH, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Text(
                            '${n.kcal.round()} kcal',
                            key: ValueKey(n.kcal.round()),
                            style: AppType.numLg
                                .copyWith(color: c.textPrimary, fontSize: 26),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text('${_totalGrams.round()} g total',
                            style: t.meta.copyWith(color: c.textMuted)),
                      ],
                    ),
                  ),
                  _MiniMacro(label: 'P', value: n.proteinG, color: c.athletic),
                  const SizedBox(width: 8),
                  _MiniMacro(label: 'C', value: n.carbsG, color: c.amber),
                  const SizedBox(width: 8),
                  _MiniMacro(label: 'F', value: n.fatG, color: c.mind),
                ],
              ),
            ),
            // ── Column captions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
              child: Row(
                children: [
                  Expanded(
                    child: Text('QUANTITY',
                        textAlign: TextAlign.center,
                        style: AppType.overline.copyWith(color: c.textMuted)),
                  ),
                  Expanded(
                    child: Text('MEASURE',
                        textAlign: TextAlign.center,
                        style: AppType.overline.copyWith(color: c.textMuted)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ── The two wheels
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      controller: _qtyCtrl,
                      onSelected: _onQty,
                      items: [
                        for (final q in _qtyOpts)
                          _isGram(_measure) ? q.round().toString() : _fmtQty(q),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      controller: _measureCtrl,
                      onSelected: _onMeasure,
                      items: [for (final m in widget.measures) m.label],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 4, AppSpace.screenH, 14),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single brand-styled wheel column.
class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelected;
  final List<String> items;
  const _Wheel({
    required this.controller,
    required this.onSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      magnification: 1.06,
      squeeze: 1.15,
      useMagnifier: true,
      onSelectedItemChanged: onSelected,
      selectionOverlay: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      children: [
        for (final s in items)
          Center(
            child: Text(
              s,
              style: AppType.numMd.copyWith(color: c.textPrimary, fontSize: 17),
            ),
          ),
      ],
    );
  }
}

class _MiniMacro extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniMacro(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Column(
        children: [
          Text('$label ${value.round()}g',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ── Macronutrients Breakdown card (Calories + net wt + P/F/C/Fiber) ──

class _MacroBreakdownCard extends StatelessWidget {
  final Nutrients n;
  final double netWtG;
  const _MacroBreakdownCard({required this.n, required this.netWtG});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calories',
                        style: t.meta.copyWith(color: c.textMuted)),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        '${n.kcal.round()} kcal',
                        key: ValueKey(n.kcal.round()),
                        style: AppType.numLg
                            .copyWith(color: c.textPrimary, fontSize: 30),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text('Net wt: ${netWtG.round()} g',
                    style: t.meta.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: c.border),
          _MacroLine(label: 'Protein', value: n.proteinG, tint: c.athletic),
          Divider(height: 1, color: c.border),
          _MacroLine(label: 'Fat', value: n.fatG, tint: c.mind),
          Divider(height: 1, color: c.border),
          _MacroLine(label: 'Carbs', value: n.carbsG, tint: c.amber),
          Divider(height: 1, color: c.border),
          _MacroLine(label: 'Fiber', value: n.fiberG, tint: c.positive),
        ],
      ),
    );
  }
}

class _MacroLine extends StatelessWidget {
  final String label;
  final double value;
  final Color tint;
  const _MacroLine(
      {required this.label, required this.value, required this.tint});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: t.body)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              '${value.toStringAsFixed(value < 10 ? 1 : 0)} g',
              key: ValueKey('$label${value.toStringAsFixed(1)}'),
              style: AppType.numMd.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.overline.copyWith(color: context.c.textMuted));
}

class _SlotChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SlotChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: active ? c.accent : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? c.onAccent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Micronutrients Breakdown — grouped (minerals / vitamins), real data ──

class _FullNutrition extends StatelessWidget {
  final Nutrients n;
  const _FullNutrition({required this.n});

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<(String, double, String)>)>[
      ('Other macros', [
        ('Sugar',         n.sugarG,        'g'),
        ('Saturated fat', n.satFatG,       'g'),
        ('Trans fat',     n.transFatG,     'g'),
        ('Cholesterol',   n.cholesterolMg, 'mg'),
      ]),
      ('Minerals', [
        ('Sodium',        n.sodiumMg,      'mg'),
        ('Potassium',     n.potassiumMg,   'mg'),
        ('Calcium',       n.calciumMg,     'mg'),
        ('Iron',          n.ironMg,        'mg'),
        ('Magnesium',     n.magnesiumMg,   'mg'),
        ('Zinc',          n.zincMg,        'mg'),
      ]),
      ('Vitamins', [
        ('Vitamin A', n.vitAUg,  'µg'),
        ('Vitamin C', n.vitCMg,  'mg'),
        ('Vitamin D', n.vitDUg,  'µg'),
        ('Vitamin E', n.vitEMg,  'mg'),
        ('Vitamin K', n.vitKUg,  'µg'),
        ('Vitamin B6', n.b6Mg,   'mg'),
        ('Vitamin B12', n.b12Ug, 'µg'),
        ('Folate',    n.folateUg,'µg'),
      ]),
    ];
    return Column(
      children: [
        for (final (header, rows) in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8, left: 2),
            child: Text(header,
                style: context.t.meta.copyWith(color: context.c.textMuted)),
          ),
          _NutCard(rows: rows),
        ],
      ],
    );
  }
}

class _NutCard extends StatelessWidget {
  final List<(String, double, String)> rows;
  const _NutCard({required this.rows});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _NutRow(label: rows[i].$1, value: rows[i].$2, unit: rows[i].$3),
            if (i < rows.length - 1) Divider(height: 1, color: c.border),
          ],
        ],
      ),
    );
  }
}

class _NutRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  const _NutRow({required this.label, required this.value, required this.unit});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final blank = value <= 0.0001;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.body)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              blank ? '—' : '${value.toStringAsFixed(value < 10 ? 1 : 0)} $unit',
              key: ValueKey('$label${value.toStringAsFixed(1)}'),
              style: AppType.numMd
                  .copyWith(color: blank ? c.textDim : c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
