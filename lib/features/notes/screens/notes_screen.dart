import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../../../shared/widgets/atlas_empty.dart';
import '../domain/folder_style.dart';
import '../domain/note.dart';
import '../domain/note_folder.dart';
import '../providers/notes_providers.dart';
import '../widgets/folder_sheets.dart';
import '../widgets/reminder_format.dart';

/// Notes home — search, folder filters, a pinned section, and cards that show
/// checklist progress + reminder/folder chips. Reached from the Me hub.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _create(NoteKind kind) async {
    HapticFeedback.selectionClick();
    // File a new note straight into the active folder (when one's selected).
    final folder = ref.read(activeFolderProvider);
    final folderId =
        (folder == null || folder == kUnfiledFolderId) ? null : folder;
    try {
      final note =
          await ref.read(notesRepositoryProvider).create(kind: kind, folderId: folderId);
      ref.invalidate(notesListProvider);
      if (mounted) context.push('/me/notes/${note.id}', extra: note);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create — try again.")),
        );
      }
    }
  }

  Future<void> _newMenu() async {
    HapticFeedback.selectionClick();
    final kind = await showModalBottomSheet<NoteKind>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewNoteSheet(),
    );
    if (kind != null) await _create(kind);
  }

  Future<void> _manageFolder(NoteFolder f) async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderActionsSheet(folder: f),
    );
    if (action == 'edit' && mounted) {
      final fields = await showFolderEditSheet(context, existing: f);
      if (fields == null) return;
      await ref.read(noteFoldersRepositoryProvider).update(
            f.id,
            name: fields.name,
            icon: fields.icon,
            color: fields.color,
          );
      ref.invalidate(noteFoldersProvider);
    } else if (action == 'delete') {
      await ref.read(noteFoldersRepositoryProvider).delete(f.id);
      if (ref.read(activeFolderProvider) == f.id) {
        ref.read(activeFolderProvider.notifier).state = null;
      }
      ref.invalidate(noteFoldersProvider);
      ref.invalidate(notesListProvider); // notes lose their folder badge
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final visible = ref.watch(visibleNotesProvider);
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];
    final active = ref.watch(activeFolderProvider);
    final query = ref.watch(notesSearchProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(fallback: '/me'),
        title: Text('Notes', style: context.t.h2),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'New',
            onPressed: _newMenu,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SearchField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(notesSearchProvider.notifier).state = v,
            ),
            _FolderBar(
              folders: folders,
              active: active,
              onSelect: (id) =>
                  ref.read(activeFolderProvider.notifier).state = id,
              onLongPressFolder: _manageFolder,
              onAddFolder: () async {
                final fields = await showFolderEditSheet(context);
                if (fields == null) return;
                await ref.read(noteFoldersRepositoryProvider).create(
                      name: fields.name,
                      icon: fields.icon,
                      color: fields.color,
                      position: folders.length,
                    );
                ref.invalidate(noteFoldersProvider);
              },
            ),
            Expanded(
              child: visible.when(
                loading: () => Center(
                  child:
                      CircularProgressIndicator(color: c.accent, strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Text(friendlyError(e),
                      style: TextStyle(color: c.negative, fontSize: 13)),
                ),
                data: (notes) => _list(notes, query, folders),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Note> notes, String query, List<NoteFolder> folders) {
    if (notes.isEmpty) {
      if (query.trim().isNotEmpty) {
        return AtlasEmpty.noResults(
          title: 'No matches',
          body: 'Nothing here matches "$query".',
        );
      }
      final filtered = ref.read(activeFolderProvider) != null;
      if (filtered) {
        return AtlasEmpty.noData(
          icon: LucideIcons.folderOpen,
          title: 'Empty folder',
          body: 'Notes you file here will show up in this view.',
          actionLabel: 'New note',
          onAction: _newMenu,
        );
      }
      return AtlasEmpty.firstRun(
        icon: LucideIcons.stickyNote,
        title: 'No notes yet',
        body: 'Capture a thought, build a checklist, or set a reminder.',
        actionLabel: 'New note',
        onAction: _newMenu,
      );
    }

    final folderById = {for (final f in folders) f.id: f};
    final pinned = notes.where((n) => n.pinned).toList();
    final rest = notes.where((n) => !n.pinned).toList();
    final showInFolder = ref.read(activeFolderProvider) == null;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.screenH, 4, AppSpace.screenH, 118),
      children: [
        if (pinned.isNotEmpty) ...[
          _SectionLabel(icon: LucideIcons.pin, label: 'Pinned'),
          for (final n in pinned)
            _noteCard(n, folderById, showFolder: showInFolder),
          if (rest.isNotEmpty)
            _SectionLabel(icon: LucideIcons.stickyNote, label: 'Notes'),
        ],
        for (final n in rest)
          _noteCard(n, folderById, showFolder: showInFolder),
      ],
    );
  }

  Widget _noteCard(
    Note n,
    Map<String, NoteFolder> folderById, {
    required bool showFolder,
  }) {
    final folder = n.folderId == null ? null : folderById[n.folderId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _NoteCard(
        note: n,
        folder: showFolder ? folder : null,
        onTap: () => context.push('/me/notes/${n.id}', extra: n),
        onDelete: () async {
          await ref.read(notesRepositoryProvider).delete(n.id);
          ref.invalidate(notesListProvider);
        },
      ),
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 6, AppSpace.screenH, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.t.body,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search notes',
          prefixIcon: Icon(LucideIcons.search, size: 18, color: c.textMuted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(LucideIcons.x, size: 16, color: c.textMuted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: c.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            borderSide: BorderSide(color: c.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            borderSide: BorderSide(color: c.border, width: 0.5),
          ),
        ),
      ),
    );
  }
}

// ── Folder filter bar ─────────────────────────────────────────────────

class _FolderBar extends StatelessWidget {
  final List<NoteFolder> folders;
  final String? active;
  final ValueChanged<String?> onSelect;
  final ValueChanged<NoteFolder> onLongPressFolder;
  final VoidCallback onAddFolder;
  const _FolderBar({
    required this.folders,
    required this.active,
    required this.onSelect,
    required this.onLongPressFolder,
    required this.onAddFolder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
        children: [
          _FolderChip(
            label: 'All',
            icon: LucideIcons.layers,
            color: c.accent,
            selected: active == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          for (final f in folders) ...[
            _FolderChip(
              label: f.displayName,
              icon: FolderStyle.icon(f.icon),
              color: FolderStyle.color(context, f.color),
              selected: active == f.id,
              onTap: () => onSelect(f.id),
              onLongPress: () => onLongPressFolder(f),
            ),
            const SizedBox(width: 8),
          ],
          _FolderChip(
            label: 'Unfiled',
            icon: LucideIcons.inbox,
            color: c.textMuted,
            selected: active == kUnfiledFolderId,
            onTap: () => onSelect(kUnfiledFolderId),
          ),
          const SizedBox(width: 8),
          _AddFolderChip(onTap: onAddFolder),
        ],
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _FolderChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : c.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? color : c.border,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: selected ? color : c.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: t.label.copyWith(
                  color: selected ? c.textPrimary : c.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFolderChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFolderChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Icon(LucideIcons.plus, size: 15, color: c.textMuted),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
      child: Row(
        children: [
          Icon(icon, size: 13, color: c.textMuted),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: t.overline.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final Note note;
  final NoteFolder? folder;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _NoteCard({
    required this.note,
    required this.folder,
    required this.onTap,
    required this.onDelete,
  });

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      final m = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour < 12 ? 'am' : 'pm';
      final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
      return '$h12:$m $ampm';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final accentColor =
        folder != null ? FolderStyle.color(context, folder!.color) : c.accent;
    final preview = note.body.trim();

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: c.negative.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Icon(LucideIcons.trash2, color: c.negative, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Icon(
                    note.isChecklist
                        ? LucideIcons.listChecks
                        : LucideIcons.fileText,
                    size: 17,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(color: c.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_fmtDate(note.updatedAt),
                              style: t.meta.copyWith(color: c.textMuted)),
                        ],
                      ),
                      if (note.isChecklist && note.itemTotal > 0) ...[
                        const SizedBox(height: 8),
                        _Progress(
                          done: note.itemDone,
                          total: note.itemTotal,
                          color: accentColor,
                        ),
                      ] else if (!note.isChecklist && preview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.body
                              .copyWith(color: c.textSecondary, fontSize: 13),
                        ),
                      ],
                      if (note.hasReminder || folder != null) ...[
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (note.hasReminder)
                              _MetaChip(
                                icon: LucideIcons.bell,
                                label: formatReminder(context, note),
                                color: note.reminderPassed
                                    ? c.textMuted
                                    : c.accent,
                              ),
                            if (folder != null)
                              _MetaChip(
                                icon: FolderStyle.icon(folder!.icon),
                                label: folder!.displayName,
                                color: FolderStyle.color(context, folder!.color),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final int done;
  final int total;
  final Color color;
  const _Progress({required this.done, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final frac = total == 0 ? 0.0 : done / total;
    final complete = done == total;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              backgroundColor: c.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(
                complete ? c.positive : color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$done/$total',
            style: t.meta.copyWith(
              color: complete ? c.positive : c.textMuted,
            )),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: t.meta.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── New-note + folder-actions sheets ──────────────────────────────────

class _NewNoteSheet extends StatelessWidget {
  const _NewNoteSheet();

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
          Text('Create', style: t.h2),
          const SizedBox(height: 14),
          _CreateRow(
            icon: LucideIcons.fileText,
            title: 'Note',
            sub: 'Freeform text for memory keeping',
            onTap: () => Navigator.of(context).pop(NoteKind.note),
          ),
          const SizedBox(height: 10),
          _CreateRow(
            icon: LucideIcons.listChecks,
            title: 'Checklist',
            sub: 'A list of items you can tick off',
            onTap: () => Navigator.of(context).pop(NoteKind.checklist),
          ),
        ],
      ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _CreateRow({
    required this.icon,
    required this.title,
    required this.sub,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.accent),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.bodyStrong.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(sub, style: t.meta.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderActionsSheet extends StatelessWidget {
  final NoteFolder folder;
  const _FolderActionsSheet({required this.folder});

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
          Row(
            children: [
              Icon(FolderStyle.icon(folder.icon),
                  size: 18, color: FolderStyle.color(context, folder.color)),
              const SizedBox(width: 8),
              Expanded(child: Text(folder.displayName, style: t.h2)),
            ],
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.pencil, size: 18, color: c.textSecondary),
            title: Text('Edit folder', style: t.body),
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.trash2, size: 18, color: c.negative),
            title: Text('Delete folder',
                style: t.body.copyWith(color: c.negative)),
            subtitle: Text('Notes inside move to Unfiled',
                style: t.meta.copyWith(color: c.textMuted)),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
  }
}
