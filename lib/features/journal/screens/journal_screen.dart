import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../domain/journal_entry.dart';
import '../providers/journal_providers.dart';

/// Full daily journal + wellness editor for the selected date.
///
/// Auto-saves on field change after a 600ms debounce. All five wellness
/// dimensions (mood, energy, soreness, sleep hours, sleep quality) plus
/// morning intent + night review live on a single scrollable surface.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late final TextEditingController _intent;
  late final TextEditingController _review;
  late final TextEditingController _sleep;

  Timer? _debounce;
  JournalEntry? _current;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _intent = TextEditingController();
    _review = TextEditingController();
    _sleep = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _intent.dispose();
    _review.dispose();
    _sleep.dispose();
    super.dispose();
  }

  void _hydrate(JournalEntry entry) {
    if (_hydrated) return;
    _hydrated = true;
    _current = entry;
    _intent.text = entry.morningIntent ?? '';
    _review.text = entry.nightReview ?? '';
    _sleep.text = entry.sleepHours?.toString() ?? '';
  }

  void _queueSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  Future<void> _flush() async {
    final entry = _current;
    if (entry == null) return;
    final intent = _intent.text.trim();
    final review = _review.text.trim();
    final sleep = double.tryParse(_sleep.text.trim());
    final updated = entry.copyWith(
      morningIntent: intent.isEmpty ? null : intent,
      nightReview: review.isEmpty ? null : review,
      sleepHours: sleep,
    );
    final repo = ref.read(journalRepositoryProvider);
    final persisted = await repo.upsert(updated);
    _current = persisted;
    ref.invalidate(journalForSelectedDateProvider);
  }

  Future<void> _setRating(String field, int value) async {
    HapticFeedback.selectionClick();
    var entry = _current;
    if (entry == null) return;
    switch (field) {
      case 'mood':
        entry = entry.copyWith(mood: value);
        break;
      case 'energy':
        entry = entry.copyWith(energy: value);
        break;
      case 'soreness':
        entry = entry.copyWith(soreness: value);
        break;
      case 'sleep_quality':
        entry = entry.copyWith(sleepQuality: value);
        break;
    }
    setState(() => _current = entry);
    final repo = ref.read(journalRepositoryProvider);
    final persisted = await repo.upsert(entry);
    _current = persisted;
    ref.invalidate(journalForSelectedDateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final date = ref.watch(selectedDateProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final entryAsync = ref.watch(journalForSelectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text(
          'Journal · ${DateFormat('EEE d MMM').format(date)}',
          style: context.t.h2.copyWith(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () async {
            await _flush();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
      body: entryAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: TextStyle(color: c.negative, fontSize: 13)),
        ),
        data: (existing) {
          final base = existing ??
              (user == null
                  ? null
                  : JournalEntry.empty(user.id, date));
          if (base == null) {
            return Center(
                child: Text('Sign in to journal',
                    style: AppType.body.copyWith(color: c.textMuted)));
          }
          _hydrate(base);
          final current = _current ?? base;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 12, AppSpace.screenH, 80),
            children: [
              _SectionLabel(text: 'Morning intent'),
              const SizedBox(height: 8),
              _Field(
                controller: _intent,
                hint: 'One line. What matters today?',
                onChanged: (_) => _queueSave(),
                icon: LucideIcons.target,
              ),
              const SizedBox(height: 20),

              _SectionLabel(text: 'Wellness'),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.smile,
                label: 'Mood',
                value: current.mood,
                onSelect: (v) => _setRating('mood', v),
              ),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.zap,
                label: 'Energy',
                value: current.energy,
                onSelect: (v) => _setRating('energy', v),
              ),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.activity,
                label: 'Soreness',
                value: current.soreness,
                onSelect: (v) => _setRating('soreness', v),
                lowLabel: 'fresh',
                highLabel: 'wrecked',
              ),
              const SizedBox(height: 20),

              _SectionLabel(text: 'Sleep'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _sleep,
                      hint: 'Hours',
                      onChanged: (_) => _queueSave(),
                      icon: LucideIcons.moon,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _RatingRow(
                icon: LucideIcons.bedDouble,
                label: 'Quality',
                value: current.sleepQuality,
                onSelect: (v) => _setRating('sleep_quality', v),
              ),
              const SizedBox(height: 20),

              _SectionLabel(text: 'Night review'),
              const SizedBox(height: 8),
              _Field(
                controller: _review,
                hint: 'What went well · what to fix tomorrow',
                onChanged: (_) => _queueSave(),
                icon: LucideIcons.bookOpen,
                maxLines: 4,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(),
          style: AppType.overline.copyWith(color: context.c.textMuted));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboard;

  const _Field({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.icon,
    this.maxLines = 1,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(icon, size: 14, color: c.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: maxLines,
              keyboardType: keyboard,
              onChanged: onChanged,
              style: context.t.body,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.body.copyWith(color: c.textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final ValueChanged<int> onSelect;
  final String? lowLabel;
  final String? highLabel;

  const _RatingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSelect,
    this.lowLabel,
    this.highLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(width: 10),
          Text(label,
              style: AppType.bodyStrong.copyWith(
                  color: c.textPrimary, fontSize: 13)),
          const Spacer(),
          for (int i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: value == i ? c.accent : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(
                      color: value == i ? c.accent : c.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$i',
                    style: AppType.numMd.copyWith(
                      color: value == i ? c.onAccent : c.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
