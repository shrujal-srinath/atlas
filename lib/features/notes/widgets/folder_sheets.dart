import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/folder_style.dart';
import '../domain/note_folder.dart';
import '../providers/notes_providers.dart';

/// Wraps a picked folder id so a `null` selection ("No folder") is
/// distinguishable from a cancelled sheet (which returns null).
class FolderPick {
  final String? folderId;
  const FolderPick(this.folderId);
}

/// Lets the user file a note: pick an existing folder, clear it, or create a
/// new one inline. Returns null if dismissed without choosing.
Future<FolderPick?> showFolderPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  String? currentFolderId,
}) {
  return showModalBottomSheet<FolderPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FolderPickerSheet(currentFolderId: currentFolderId),
  );
}

class _FolderPickerSheet extends ConsumerWidget {
  final String? currentFolderId;
  const _FolderPickerSheet({this.currentFolderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];

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
          const SizedBox(height: 16),
          Text('Move to folder', style: t.h2),
          const SizedBox(height: 16),
          _Option(
            icon: LucideIcons.inbox,
            iconColor: c.textMuted,
            label: 'No folder',
            selected: currentFolderId == null,
            onTap: () => Navigator.of(context).pop(const FolderPick(null)),
          ),
          for (final f in folders) ...[
            const SizedBox(height: 8),
            _Option(
              icon: FolderStyle.icon(f.icon),
              iconColor: FolderStyle.color(context, f.color),
              label: f.displayName,
              selected: currentFolderId == f.id,
              onTap: () => Navigator.of(context).pop(FolderPick(f.id)),
            ),
          ],
          const SizedBox(height: 8),
          _Option(
            icon: LucideIcons.plus,
            iconColor: c.accent,
            label: 'New folder…',
            selected: false,
            onTap: () async {
              final fields = await showFolderEditSheet(context);
              if (fields == null) return;
              final repo = ref.read(noteFoldersRepositoryProvider);
              final created = await repo.create(
                name: fields.name,
                icon: fields.icon,
                color: fields.color,
                position: folders.length,
              );
              ref.invalidate(noteFoldersProvider);
              if (context.mounted) {
                Navigator.of(context).pop(FolderPick(created.id));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Option({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: t.bodyStrong.copyWith(color: c.textPrimary)),
              ),
              if (selected) Icon(LucideIcons.check, size: 18, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Folder create/edit ───────────────────────────────────────────────

typedef FolderFields = ({String name, String icon, String color});

/// Create or edit a folder's name, icon and colour. Returns null if cancelled
/// or if the name is left blank.
Future<FolderFields?> showFolderEditSheet(
  BuildContext context, {
  NoteFolder? existing,
}) {
  return showModalBottomSheet<FolderFields>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FolderEditSheet(existing: existing),
  );
}

class _FolderEditSheet extends StatefulWidget {
  final NoteFolder? existing;
  const _FolderEditSheet({this.existing});

  @override
  State<_FolderEditSheet> createState() => _FolderEditSheetState();
}

class _FolderEditSheetState extends State<_FolderEditSheet> {
  late final TextEditingController _name;
  late String _icon;
  late String _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _icon = widget.existing?.icon ?? FolderStyle.iconKeys.first;
    _color = widget.existing?.color ?? FolderStyle.colorKeys.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.of(context).pop((name: name, icon: _icon, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            const SizedBox(height: 16),
            Text(widget.existing == null ? 'New folder' : 'Edit folder',
                style: t.h2),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              style: context.t.body,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Folder name',
                filled: true,
                fillColor: c.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('ICON', style: t.overline.copyWith(color: c.textMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final key in FolderStyle.iconKeys)
                  _Swatch(
                    selected: _icon == key,
                    color: FolderStyle.color(context, _color),
                    onTap: () => setState(() => _icon = key),
                    child: Icon(
                      FolderStyle.icon(key),
                      size: 18,
                      color: _icon == key
                          ? FolderStyle.color(context, _color)
                          : c.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('COLOUR', style: t.overline.copyWith(color: c.textMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final key in FolderStyle.colorKeys)
                  _Swatch(
                    selected: _color == key,
                    color: FolderStyle.color(context, key),
                    onTap: () => setState(() => _color = key),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: FolderStyle.color(context, key),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.existing == null ? 'Create folder' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final bool selected;
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  const _Swatch({
    required this.selected,
    required this.color,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(
            color: selected ? color : c.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
