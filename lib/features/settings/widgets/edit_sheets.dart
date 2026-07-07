import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// A bottom sheet that asks for a string. Returns null if cancelled.
Future<String?> showTextEditSheet(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  TextInputType keyboardType = TextInputType.text,
  String? suffix,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TextEditSheet(
      title: title,
      initial: initial,
      hint: hint,
      keyboardType: keyboardType,
      suffix: suffix,
    ),
  );
}

class _TextEditSheet extends StatefulWidget {
  final String title;
  final String initial;
  final String? hint;
  final TextInputType keyboardType;
  final String? suffix;
  const _TextEditSheet({
    required this.title,
    required this.initial,
    required this.keyboardType,
    this.hint,
    this.suffix,
  });

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpace.screenH,
          14,
          AppSpace.screenH,
          MediaQuery.of(context).viewPadding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 14),
            Text(widget.title, style: t.h2),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: widget.keyboardType,
              style: t.body,
              decoration: InputDecoration(
                hintText: widget.hint,
                suffixText: widget.suffix,
              ),
              onSubmitted: (_) => Navigator.pop(context, _ctrl.text.trim()),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, _ctrl.text.trim());
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single-select bottom sheet. Returns the picked key or null.
Future<String?> showSelectSheet(
  BuildContext context, {
  required String title,
  required Map<String, String> options, // key → label
  String? initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SelectSheet(
      title: title,
      options: options,
      initial: initial,
    ),
  );
}

class _SelectSheet extends StatelessWidget {
  final String title;
  final Map<String, String> options;
  final String? initial;
  const _SelectSheet({
    required this.title,
    required this.options,
    this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        14,
        AppSpace.screenH,
        MediaQuery.of(context).viewPadding.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 14),
          Text(title, style: t.h2),
          const SizedBox(height: 10),
          for (final entry in options.entries)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, entry.key);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: entry.key == initial
                      ? c.accentSoft
                      : c.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(
                    color: entry.key == initial ? c.accent : c.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.value,
                        style: t.bodyStrong.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (entry.key == initial)
                      Icon(Icons.check, size: 18, color: c.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
