import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/atlas_controls.dart';
import '../auth/providers/auth_provider.dart';
import '../home/providers/home_providers.dart';
import '../home/scoring/focus.dart';
import '../home/scoring/section_def.dart';

/// The "Focus" editor — choose how your daily score is weighted across the
/// three sections. Persona › phase preset, your own custom weights, or Off —
/// all resolve to ONE weighting the score reads. Also renames the sections.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FocusScreen()),
      );

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late FocusConfig _cfg;
  late final Map<HabitSection, TextEditingController> _labelCtrls;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _labelCtrls = {
      for (final s in HabitSection.values) s: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _labelCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _load() {
    if (_loaded) return;
    _loaded = true;
    _cfg = ref.read(focusConfigProvider);
    for (final s in HabitSection.values) {
      final custom = _cfg.labels[s];
      if (custom != null) _labelCtrls[s]!.text = custom;
    }
  }

  Map<HabitSection, double> get _weights => resolveFocusWeights(_cfg);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Gather renames (blank → default, i.e. not stored).
      final labels = <HabitSection, String>{};
      for (final s in HabitSection.values) {
        final v = _labelCtrls[s]!.text.trim();
        if (v.isNotEmpty && v != defaultSectionLabel(s)) labels[s] = v;
      }
      final cfg = _cfg.copyWith(labels: labels);

      await ref.read(userActionsProvider.notifier).update({
        // The focus blob is the single source the score resolves from.
        'section_weights': cfg.toJson(),
        // Keep the legacy display label in sync so anything showing the phase
        // name stays correct.
        'current_phase': cfg.mode == FocusMode.phase
            ? (phaseByKey(cfg.personaKey, cfg.phaseKey)?.label ?? cfg.summary)
            : cfg.summary,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Focus updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnack(context, e);
    }
  }

  Future<void> _editCustom(SectionDef? existing) async {
    final result = await showModalBottomSheet<SectionDef>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.c.background,
      builder: (_) => _CustomSectionSheet(
        existing: existing,
        order: existing?.order ?? _cfg.customSections.length,
      ),
    );
    if (result == null) return;
    setState(() {
      final list = [..._cfg.customSections];
      final i = list.indexWhere((s) => s.id == result.id);
      if (i >= 0) {
        list[i] = result;
      } else {
        list.add(result);
      }
      _cfg = _cfg.copyWith(customSections: list);
    });
  }

  Future<void> _deleteCustom(SectionDef s) async {
    final c = context.c;
    final parentName = HabitSectionParse.fromDb(s.parent).defaultLabel;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete “${s.name}”?', style: ctx.t.h2),
        content: Text(
          'Any habits in this section keep counting toward $parentName for '
          'scoring. You can move them to another section anytime.',
          style: ctx.t.body.copyWith(color: c.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: ctx.t.bodyStrong.copyWith(color: c.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Delete', style: ctx.t.bodyStrong.copyWith(color: c.accent))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _cfg = _cfg.copyWith(
          customSections:
              _cfg.customSections.where((x) => x.id != s.id).toList()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    _load();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Focus'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Live preview — always shows the resulting split.
            _PreviewBar(cfg: _cfg, weights: _weights),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 14, AppSpace.screenH, 24),
                children: [
                  _SectionLabel('How should we weight your score?'),
                  const SizedBox(height: 10),
                  _ModeRow(
                    mode: _cfg.mode,
                    onChanged: (m) => setState(() => _cfg = _cfg.copyWith(mode: m)),
                  ),
                  const SizedBox(height: 18),
                  if (_cfg.mode == FocusMode.phase) ..._phaseBody(c),
                  if (_cfg.mode == FocusMode.custom) ..._customBody(c),
                  if (_cfg.mode == FocusMode.off) _offBody(c),
                  const SizedBox(height: 24),
                  _SectionLabel('Rename your sections'),
                  const SizedBox(height: 4),
                  Text(
                    'Make the three areas yours — names show everywhere.',
                    style: context.t.meta.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 12),
                  for (final s in HabitSection.values) ...[
                    _RenameField(
                      controller: _labelCtrls[s]!,
                      hint: defaultSectionLabel(s),
                      dot: s.color(c),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 24),
                  _SectionLabel('Custom sections'),
                  const SizedBox(height: 4),
                  Text(
                    'Add your own areas (Career, Recovery…). Each rolls up to a '
                    'core section for scoring.',
                    style: context.t.meta.copyWith(color: c.textMuted, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  for (final s in _cfg.customSections) ...[
                    _CustomSectionCard(
                      section: s,
                      onTap: () => _editCustom(s),
                      onDelete: () => _deleteCustom(s),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _AddSectionRow(onTap: () => _editCustom(null)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 10, AppSpace.screenH, 16),
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: AtlasButton(
                  label: 'Save focus',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _phaseBody(AppPalette c) {
    final persona = personaByKey(_cfg.personaKey) ?? kPersonas.last;
    return [
      _SectionLabel('Who are you right now?'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in kPersonas)
            _Chip(
              label: p.label,
              active: p.key == _cfg.personaKey,
              onTap: () => setState(() {
                // Switch persona → default to its first phase.
                _cfg = _cfg.copyWith(
                    personaKey: p.key, phaseKey: p.phases.first.key);
              }),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(persona.blurb,
          style: context.t.meta.copyWith(color: c.textMuted)),
      const SizedBox(height: 16),
      _SectionLabel('Phase'),
      const SizedBox(height: 10),
      for (final ph in persona.phases) ...[
        _PhaseCard(
          phase: ph,
          labelFor: _cfg.labelFor,
          selected: ph.key == _cfg.phaseKey,
          onTap: () => setState(() => _cfg = _cfg.copyWith(phaseKey: ph.key)),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _customBody(AppPalette c) {
    return [
      _SectionLabel('Set your own emphasis'),
      const SizedBox(height: 6),
      Text('Slide to weight each area; we balance them to 100%.',
          style: context.t.meta.copyWith(color: c.textMuted)),
      const SizedBox(height: 14),
      _WeightSlider(
        label: _cfg.labelFor(HabitSection.athletic),
        color: HabitSection.athletic.color(c),
        value: _cfg.customAthletic,
        pct: _weights[HabitSection.athletic] ?? 0,
        onChanged: (v) =>
            setState(() => _cfg = _cfg.copyWith(customAthletic: v)),
      ),
      const SizedBox(height: 14),
      _WeightSlider(
        label: _cfg.labelFor(HabitSection.mind),
        color: HabitSection.mind.color(c),
        value: _cfg.customMind,
        pct: _weights[HabitSection.mind] ?? 0,
        onChanged: (v) => setState(() => _cfg = _cfg.copyWith(customMind: v)),
      ),
      const SizedBox(height: 14),
      _WeightSlider(
        label: _cfg.labelFor(HabitSection.body),
        color: HabitSection.body.color(c),
        value: _cfg.customBody,
        pct: _weights[HabitSection.body] ?? 0,
        onChanged: (v) => setState(() => _cfg = _cfg.copyWith(customBody: v)),
      ),
    ];
  }

  Widget _offBody(AppPalette c) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.scale, size: 18, color: c.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Every section counts the same. Your score is a simple average — '
              'no area is emphasised.',
              style: t.body.copyWith(color: c.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── pieces ────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.t.label.copyWith(
          color: context.c.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      );
}

/// Stacked horizontal bar of the resolved A/M/B split, with a legend.
class _PreviewBar extends StatelessWidget {
  final FocusConfig cfg;
  final Map<HabitSection, double> weights;
  const _PreviewBar({required this.cfg, required this.weights});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screenH, 12, AppSpace.screenH, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('YOUR SCORE WEIGHTING', style: _miniLabel(context)),
              const Spacer(),
              Text(cfg.summary,
                  style: t.meta.copyWith(
                      color: c.accent, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                for (final s in HabitSection.values)
                  Expanded(
                    flex: ((weights[s] ?? 0) * 1000).round().clamp(1, 1000),
                    child: Container(height: 12, color: s.color(c)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in HabitSection.values) ...[
                _LegendDot(color: s.color(c)),
                const SizedBox(width: 5),
                Text(
                  '${cfg.labelFor(s)} ${((weights[s] ?? 0) * 100).round()}%',
                  style: t.meta.copyWith(
                      color: c.textSecondary, fontWeight: FontWeight.w600),
                ),
                if (s != HabitSection.body) const SizedBox(width: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

TextStyle _miniLabel(BuildContext context) => AppType.overline
    .copyWith(color: context.c.textMuted, letterSpacing: 1.2);

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _ModeRow extends StatelessWidget {
  final FocusMode mode;
  final ValueChanged<FocusMode> onChanged;
  const _ModeRow({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in FocusMode.values) ...[
          Expanded(
            child: _ModeChip(
              label: switch (m) {
                FocusMode.phase => 'Phase',
                FocusMode.custom => 'Custom',
                FocusMode.off => 'Off',
              },
              icon: switch (m) {
                FocusMode.phase => LucideIcons.target,
                FocusMode.custom => LucideIcons.slidersHorizontal,
                FocusMode.off => LucideIcons.scale,
              },
              active: m == mode,
              onTap: () => onChanged(m),
            ),
          ),
          if (m != FocusMode.off) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.96,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: active ? c.accent : c.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? c.onAccent : c.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? c.onAccent : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persona pill — solid accent when active (house rule 1).
class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.96,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: active ? c.accent : c.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? c.onAccent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Phase option — surface + accent border + check when selected (rule 1's
/// alternate for text-heavy rows), with a mini weight mix.
class _PhaseCard extends StatelessWidget {
  final FocusPhase phase;
  final String Function(HabitSection) labelFor;
  final bool selected;
  final VoidCallback onTap;
  const _PhaseCard({
    required this.phase,
    required this.labelFor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final mix = {
      HabitSection.athletic: phase.athletic,
      HabitSection.mind: phase.mind,
      HabitSection.body: phase.body,
    };
    return PressScale(
      scale: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.fromLTRB(15, 13, 13, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(phase.label,
                      style: t.bodyStrong.copyWith(color: c.textPrimary)),
                ),
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  size: 18,
                  color: selected ? c.accent : c.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(phase.blurb, style: t.meta.copyWith(color: c.textMuted)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final s in HabitSection.values) ...[
                  _LegendDot(color: s.color(c)),
                  const SizedBox(width: 4),
                  Text('${mix[s]}',
                      style: t.meta.copyWith(
                          color: c.textSecondary, fontWeight: FontWeight.w700)),
                  if (s != HabitSection.body) const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  final String label;
  final Color color;
  final int value;
  final double pct;
  final ValueChanged<int> onChanged;
  const _WeightSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.pct,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: color),
            const SizedBox(width: 8),
            Text(label,
                style: t.bodyStrong.copyWith(color: c.textPrimary)),
            const Spacer(),
            Text('${(pct * 100).round()}%',
                style: t.bodyStrong.copyWith(color: c.textSecondary)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: color,
            inactiveTrackColor: c.border,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value.toDouble().clamp(0, 100),
            max: 100,
            divisions: 20,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v.round());
            },
          ),
        ),
      ],
    );
  }
}

class _RenameField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color dot;
  const _RenameField({
    required this.controller,
    required this.hint,
    required this.dot,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Row(
      children: [
        _LegendDot(color: dot),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            style: t.body.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: t.body.copyWith(color: c.textDim, fontWeight: FontWeight.w400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: c.borderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: c.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: c.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Custom section management ──────────────────────────────────────────

class _CustomSectionCard extends StatelessWidget {
  final SectionDef section;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CustomSectionCard({
    required this.section,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final parentName = HabitSectionParse.fromDb(section.parent).defaultLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: sectionColorForKey(c, section.colorKey),
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.name, style: t.bodyStrong),
                  const SizedBox(height: 1),
                  Text('Counts toward $parentName',
                      style: t.meta.copyWith(color: c.textMuted)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.pencil, size: 16, color: c.textSecondary),
            onPressed: onTap,
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 16, color: c.textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddSectionRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSectionRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return PressScale(
      scale: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, size: 17, color: c.accent),
            const SizedBox(width: 8),
            Text('Add custom section',
                style: t.bodyStrong.copyWith(color: c.accent)),
          ],
        ),
      ),
    );
  }
}

/// Create / edit a custom section: name, colour, and the core section it rolls
/// up to for scoring.
class _CustomSectionSheet extends StatefulWidget {
  final SectionDef? existing;
  final int order;
  const _CustomSectionSheet({required this.existing, required this.order});
  @override
  State<_CustomSectionSheet> createState() => _CustomSectionSheetState();
}

class _CustomSectionSheetState extends State<_CustomSectionSheet> {
  late final TextEditingController _name;
  late String _colorKey;
  late String _parent;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _colorKey = widget.existing?.colorKey ?? kCustomSectionColorKeys.first;
    _parent = widget.existing?.parent ?? kMindId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final id = widget.existing?.id ??
        'cs_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
      context,
      SectionDef(
        id: id,
        name: name,
        colorKey: _colorKey,
        order: widget.order,
        builtIn: false,
        parent: _parent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.screenH, 14, AppSpace.screenH,
          18 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.existing == null ? 'New section' : 'Edit section',
              style: t.h2),
          const SizedBox(height: 16),
          _miniLabel(context, 'Name'),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            autofocus: true,
            style: t.body.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. Career',
              hintStyle: t.body.copyWith(color: c.textDim, fontWeight: FontWeight.w400),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: c.borderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: c.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: c.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _miniLabel(context, 'Colour'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final key in kCustomSectionColorKeys)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _colorKey = key);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: sectionColorForKey(c, key),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorKey == key ? c.textPrimary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _miniLabel(context, 'Counts toward'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final s in HabitSection.values) ...[
                Expanded(
                  child: _ParentChip(
                    label: s.label,
                    active: _parent == s.id,
                    onTap: () => setState(() => _parent = s.id),
                  ),
                ),
                if (s != HabitSection.body) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 20),
          AtlasButton(label: 'Done', onPressed: _done),
        ],
      ),
    );
  }

  Widget _miniLabel(BuildContext context, String s) => Text(s,
      style: context.t.label.copyWith(
          color: context.c.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1));
}

class _ParentChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ParentChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      scale: 0.96,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
              color: active ? c.accent : c.border, width: active ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? c.onAccent : c.textSecondary,
            )),
      ),
    );
  }
}
