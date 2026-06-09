import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';

// ── Serving presets ─────────────────────────────────────────────

class ServingPreset {
  final String label;
  final double grams;
  const ServingPreset(this.label, this.grams);

  @override
  bool operator ==(Object other) =>
      other is ServingPreset && other.label == label && other.grams == grams;
  @override
  int get hashCode => Object.hash(label, grams);
}

const _presets = <ServingPreset>[
  ServingPreset('g',      1),
  ServingPreset('Bowl',   200),
  ServingPreset('Katori', 150),
  ServingPreset('Cup',    240),
  ServingPreset('Plate',  300),
  ServingPreset('Piece',  50),
  ServingPreset('Slice',  30),
  ServingPreset('Roti',   40),
  ServingPreset('Scoop',  30),
  ServingPreset('Tbsp',   15),
  ServingPreset('Tsp',    5),
  ServingPreset('Glass',  250),
  ServingPreset('ml',     1),
];

// Quick multiplier presets (shown as tappable chips)
const _quickAmounts = [0.5, 1.0, 1.5, 2.0, 3.0];

// ── Screen ──────────────────────────────────────────────────────

class FoodDetailScreen extends ConsumerStatefulWidget {
  final Food food;
  final MealTimeSlot initialSlot;
  final DateTime date;
  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.initialSlot,
    required this.date,
  });

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  late MealTimeSlot _slot;
  late ServingPreset _preset;
  double _servings = 1.0;
  bool _saving = false;
  bool _favorited = false;

  @override
  void initState() {
    super.initState();
    _slot = widget.initialSlot;
    _favorited = widget.food.isFavorite;
    _preset = _presets.first; // grams
    _servings = widget.food.servingQty; // e.g., 100
  }

  double get _totalGrams => _servings * _preset.grams;

  double get _factor {
    if (widget.food.servingQty == 0) return 0;
    return _totalGrams / widget.food.servingQty;
  }

  Nutrients get _scaled => widget.food.per.scale(_factor);

  // Slider range depends on preset
  double get _sliderMin => _preset.grams == 1 ? 10 : 0.5;
  double get _sliderMax => _preset.grams == 1 ? 500 : 10;
  int get _sliderDivisions {
    if (_preset.grams == 1) return 49; // 10g steps
    return 19; // 0.5 steps
  }

  void _setServings(double v) {
    setState(() {
      if (_preset.grams == 1) {
        _servings = (v / 10).round() * 10.0; // snap to 10g
      } else {
        _servings = (v * 2).round() / 2; // snap to 0.5
      }
    });
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

                  // ── Hero calorie + macro card
                  _CalorieMacroCard(n: n),
                  const SizedBox(height: 24),

                  // ── Serving size presets
                  _SectionLabel(text: 'SERVING SIZE'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = _presets[i];
                        final active = p == _preset;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _preset = p;
                              _servings = p.grams == 1
                                  ? widget.food.servingQty
                                  : 1;
                            });
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: active ? c.accent : c.surface,
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              border: Border.all(
                                color: active ? c.accent : c.border,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              p.label,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: active ? c.onAccent : c.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Quantity: quick presets + slider
                  _SectionLabel(text: 'QUANTITY'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        // Current amount display
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: Text(
                            _preset.grams == 1
                                ? '${_servings.round()} g'
                                : '${_fmtServings(_servings)} ${_preset.label}',
                            key: ValueKey('${_servings}_${_preset.label}'),
                            style: AppType.numLg.copyWith(
                              color: c.textPrimary,
                              fontSize: 28,
                            ),
                          ),
                        ),
                        if (_preset.grams > 1) ...[
                          const SizedBox(height: 2),
                          Text(
                            '= ${_totalGrams.round()} g',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 12,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Quick amount chips
                        if (_preset.grams > 1)
                          Row(
                            children: [
                              for (final amt in _quickAmounts)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        right: amt == _quickAmounts.last ? 0 : 6),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _servings = amt);
                                        HapticFeedback.selectionClick();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 120),
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: _servings == amt
                                              ? c.accent.withValues(alpha: 0.12)
                                              : c.surfaceElevated,
                                          borderRadius:
                                              BorderRadius.circular(AppRadii.chip),
                                          border: Border.all(
                                            color: _servings == amt
                                                ? c.accent
                                                : c.border,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _fmtServings(amt),
                                          style: TextStyle(
                                            fontFamily: 'SpaceGrotesk',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _servings == amt
                                                ? c.accent
                                                : c.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (_preset.grams > 1) const SizedBox(height: 12),

                        // Slider
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: c.accent,
                            inactiveTrackColor: c.surfaceElevated,
                            thumbColor: c.accent,
                            overlayColor: c.accent.withValues(alpha: 0.12),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _servings.clamp(_sliderMin, _sliderMax),
                            min: _sliderMin,
                            max: _sliderMax,
                            divisions: _sliderDivisions,
                            onChanged: (v) {
                              _setServings(v);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ),
                        // Min/max labels
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _preset.grams == 1
                                    ? '${_sliderMin.round()}g'
                                    : _fmtServings(_sliderMin),
                                style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 10,
                                    color: c.textDim),
                              ),
                              Text(
                                _preset.grams == 1
                                    ? '${_sliderMax.round()}g'
                                    : _fmtServings(_sliderMax),
                                style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 10,
                                    color: c.textDim),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Meal slot picker
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

                  // ── Full nutrition
                  _SectionLabel(text: 'NUTRITION (logged amount)'),
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
                    onPressed: _totalGrams <= 0 || _saving ? null : _log,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Add ${n.kcal.round()} kcal to ${_slot.label}',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
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

  String _fmtServings(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

// ── Calorie + macro hero card ──────────────────────────────────

class _CalorieMacroCard extends StatelessWidget {
  final Nutrients n;
  const _CalorieMacroCard({required this.n});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          // Big calorie number
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              n.kcal.round().toString(),
              key: ValueKey(n.kcal.round()),
              style: AppType.display.copyWith(
                  color: c.textPrimary, fontSize: 44, letterSpacing: -1.5),
            ),
          ),
          Text('kcal', style: TextStyle(
            fontFamily: 'Inter', fontSize: 13, color: c.textMuted,
          )),
          const SizedBox(height: 18),
          // Macro bars
          Row(
            children: [
              Expanded(child: _MacroBar(
                label: 'Protein', value: n.proteinG, color: c.athletic)),
              const SizedBox(width: 12),
              Expanded(child: _MacroBar(
                label: 'Carbs', value: n.carbsG, color: c.amber)),
              const SizedBox(width: 12),
              Expanded(child: _MacroBar(
                label: 'Fat', value: n.fatG, color: c.mind)),
              const SizedBox(width: 12),
              Expanded(child: _MacroBar(
                label: 'Fiber', value: n.fiberG, color: c.positive)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(value < 10 ? 1 : 0)}g',
          style: AppType.numMd.copyWith(color: color, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
          fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500,
          color: c.textMuted,
        )),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              value: (value / 50).clamp(0.0, 1.0),
              backgroundColor: c.surfaceElevated,
              color: color,
            ),
          ),
        ),
      ],
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

class _FullNutrition extends StatelessWidget {
  final Nutrients n;
  const _FullNutrition({required this.n});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = <(String, double, String)>[
      ('Fiber',         n.fiberG,        'g'),
      ('Sugar',         n.sugarG,        'g'),
      ('Saturated fat', n.satFatG,       'g'),
      ('Trans fat',     n.transFatG,     'g'),
      ('Cholesterol',   n.cholesterolMg, 'mg'),
      ('Sodium',        n.sodiumMg,      'mg'),
      ('Potassium',     n.potassiumMg,   'mg'),
      ('Calcium',       n.calciumMg,     'mg'),
      ('Iron',          n.ironMg,        'mg'),
      ('Magnesium',     n.magnesiumMg,   'mg'),
      ('Zinc',          n.zincMg,        'mg'),
      ('Vit A',         n.vitAUg,        'µg'),
      ('Vit C',         n.vitCMg,        'mg'),
      ('Vit D',         n.vitDUg,        'µg'),
      ('Vit E',         n.vitEMg,        'mg'),
      ('Vit K',         n.vitKUg,        'µg'),
      ('B6',            n.b6Mg,          'mg'),
      ('B12',           n.b12Ug,         'µg'),
      ('Folate',        n.folateUg,      'µg'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.body)),
          Text(
            blank ? '—' : '${value.toStringAsFixed(value < 10 ? 1 : 0)} $unit',
            style: AppType.numMd.copyWith(color: blank ? c.textDim : c.textPrimary),
          ),
        ],
      ),
    );
  }
}
