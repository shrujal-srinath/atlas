import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/models/models.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';

/// Quick-add: log raw kcal + optional macros when you can't search a food.
class QuickAddSheet extends ConsumerStatefulWidget {
  final DateTime date;
  const QuickAddSheet({super.key, required this.date});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _name = TextEditingController(text: 'Quick add');
  MealTimeSlot _slot = MealTimeSlot.snack;
  bool _saving = false;

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _name.dispose();
    super.dispose();
  }

  // Floored at zero so a stray "-" typed into Protein/Carbs/Fat can't save a
  // negative macro (only kcal was gated before; the other three weren't).
  double _val(TextEditingController c) {
    final v = double.tryParse(c.text) ?? 0.0;
    return v < 0 ? 0.0 : v;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.screenH,
        right: AppSpace.screenH,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Quick add', style: t.h2),
            const SizedBox(height: 4),
            Text('Log calories without searching a food',
                style: t.body.copyWith(color: c.textMuted)),
            const SizedBox(height: 18),

            // Name
            TextField(
              controller: _name,
              style: t.body,
              decoration: const InputDecoration(hintText: 'Label (optional)'),
            ),
            const SizedBox(height: 12),

            // Kcal — big
            TextField(
              controller: _kcal,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: AppType.numLg.copyWith(color: c.textPrimary, fontSize: 28),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'kcal',
                suffixStyle: t.meta.copyWith(color: c.textMuted),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // P / C / F row
            Row(
              children: [
                Expanded(
                  child: _MiniField(controller: _protein, hint: 'Protein', unit: 'g'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniField(controller: _carbs, hint: 'Carbs', unit: 'g'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniField(controller: _fat, hint: 'Fat', unit: 'g'),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Meal slot
            Text('MEAL', style: AppType.overline.copyWith(color: c.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in kDiarySlotOrder)
                  _Chip(
                    label: s.label,
                    active: s == _slot,
                    onTap: () => setState(() => _slot = s),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _val(_kcal) <= 0 || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Add ${_val(_kcal).round()} kcal',
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(foodRepositoryProvider);
      final entry = await repo.quickAdd(
        kcal: _val(_kcal),
        proteinG: _val(_protein),
        carbsG: _val(_carbs),
        fatG: _val(_fat),
        slot: _slot,
        date: widget.date,
        name: _name.text.trim().isEmpty ? 'Quick add' : _name.text.trim(),
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
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String hint, unit;
  const _MiniField({required this.controller, required this.hint, required this.unit});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.c;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: t.body,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: unit,
        suffixStyle: t.meta.copyWith(color: c.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? c.accentSoft : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: active ? c.accent : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? c.textPrimary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
