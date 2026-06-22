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

/// Edit a logged diary entry: adjust the portion and/or move it to another
/// meal slot. Macros recompute live from the stored per-quantity snapshot.
/// Returns `true` from the sheet when something changed (so the caller can
/// invalidate the diary).
class EditEntrySheet extends ConsumerStatefulWidget {
  final MealEntry entry;
  const EditEntrySheet({super.key, required this.entry});

  @override
  ConsumerState<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<EditEntrySheet> {
  late double _qty;
  late MealTimeSlot _slot;
  late final TextEditingController _qtyCtrl;
  bool _busy = false;

  double get _step =>
      (widget.entry.unit == 'g' || widget.entry.unit == 'ml') ? 10 : 1;

  @override
  void initState() {
    super.initState();
    _qty = widget.entry.qty;
    _slot = widget.entry.slot;
    _qtyCtrl = TextEditingController(text: _fmt(_qty));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Nutrients get _scaled {
    final base = widget.entry.qty == 0 ? 1.0 : _qty / widget.entry.qty;
    return widget.entry.totals.scale(base);
  }

  void _bump(double delta) {
    final next = (_qty + delta).clamp(0.0, 100000.0);
    setState(() {
      _qty = next;
      _qtyCtrl.text = _fmt(next);
      _qtyCtrl.selection =
          TextSelection.collapsed(offset: _qtyCtrl.text.length);
    });
    HapticFeedback.selectionClick();
  }

  void _onTyped(String v) {
    final parsed = double.tryParse(v);
    if (parsed != null) setState(() => _qty = parsed);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final n = _scaled;
    final changed = _qty != widget.entry.qty || _slot != widget.entry.slot;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.screenH,
        right: AppSpace.screenH,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.entry.name,
                style: t.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('Edit portion', style: t.body.copyWith(color: c.textMuted)),
            const SizedBox(height: 18),

            // ── Quantity stepper ──
            Text('QUANTITY', style: AppType.overline.copyWith(color: c.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                _StepBtn(icon: LucideIcons.minus, onTap: () => _bump(-_step)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: AppType.numLg.copyWith(color: c.textPrimary, fontSize: 26),
                    decoration: InputDecoration(
                      suffixText: ' ${widget.entry.unit}',
                      suffixStyle: t.meta.copyWith(color: c.textMuted),
                    ),
                    onChanged: _onTyped,
                  ),
                ),
                const SizedBox(width: 10),
                _StepBtn(icon: LucideIcons.plus, onTap: () => _bump(_step)),
              ],
            ),
            const SizedBox(height: 18),

            // ── Live macro preview ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: c.border, width: 0.5),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${n.kcal.round()}',
                          style: AppType.numLg
                              .copyWith(color: c.textPrimary, fontSize: 30)),
                      Text('kcal', style: t.meta.copyWith(color: c.textMuted)),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Macro(label: 'P', g: n.proteinG, tint: c.athletic),
                        _Macro(label: 'C', g: n.carbsG, tint: c.amber),
                        _Macro(label: 'F', g: n.fatG, tint: c.mind),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Meal slot ──
            Text('MEAL', style: AppType.overline.copyWith(color: c.textMuted)),
            const SizedBox(height: 8),
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

            // ── Actions ──
            Row(
              children: [
                _DeleteBtn(onTap: _busy ? null : _delete),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: (!changed || _qty <= 0 || _busy) ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save changes',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(foodRepositoryProvider).updateEntry(
            entry: widget.entry,
            newQty: _qty,
            newSlot: _slot,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ref.read(foodRepositoryProvider).deleteEntry(widget.entry.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, e);
    }
  }

  static String _fmt(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: 18, color: c.textSecondary),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final double g;
  final Color tint;
  const _Macro({required this.label, required this.g, required this.tint});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text('${g.round()}g',
            style: AppType.numMd.copyWith(color: c.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tint)),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SlotChip(
      {required this.label, required this.active, required this.onTap});
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
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? c.accent : c.textSecondary)),
      ),
    );
  }
}

class _DeleteBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _DeleteBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: c.negative.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.negative.withValues(alpha: 0.35)),
        ),
        child: Icon(LucideIcons.trash2, size: 18, color: c.negative),
      ),
    );
  }
}
