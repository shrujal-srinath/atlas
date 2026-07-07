import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../data/notes_repository.dart';
import '../domain/folder_style.dart';
import '../domain/note.dart';
import '../domain/note_folder.dart';
import '../domain/note_item.dart';
import '../providers/notes_providers.dart';
import '../widgets/folder_sheets.dart';
import '../widgets/note_reminder_sheet.dart';
import '../widgets/reminder_format.dart';

/// Editor for a single note. Freeform notes get a title + body; checklists get
/// a title + a reorderable, tickable item list. Both share a meta bar for
/// filing into a folder and attaching a reminder, plus pin/delete in the bar.
/// Title/body/items auto-save (debounced); metadata saves immediately.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String noteId;
  final Note? initial;
  const NoteEditorScreen({super.key, required this.noteId, this.initial});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();

  Timer? _metaDebounce;
  bool _metaDirty = false;
  bool _hydrated = false;

  // Local metadata mirror (so the UI updates without a refetch).
  NoteKind _kind = NoteKind.note;
  String? _folderId;
  bool _pinned = false;
  DateTime? _reminderAt;
  ReminderRule? _reminderRule;

  // Checklist state.
  final List<NoteItem> _items = [];
  final Map<String, TextEditingController> _itemCtrls = {};
  final Map<String, Timer> _itemDebounce = {};
  final Map<String, String> _pendingItemText = {};
  bool _itemsLoaded = false;

  NotesRepository get _repo => ref.read(notesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _hydrate(widget.initial!);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final note = await _repo.getById(widget.noteId);
      if (!mounted || note == null) return;
      setState(() => _hydrate(note));
    } catch (_) {
      // Offline / not found — leave a blank note editor; saves still write by id.
    }
  }

  void _hydrate(Note note) {
    if (_hydrated) return;
    _hydrated = true;
    _title.text = note.title;
    _body.text = note.body;
    _kind = note.kind;
    _folderId = note.folderId;
    _pinned = note.pinned;
    _reminderAt = note.reminderAt;
    _reminderRule = note.reminderRule;
    if (_kind == NoteKind.checklist) _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _repo.items(widget.noteId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        for (final it in items) {
          _itemCtrls[it.id] = TextEditingController(text: it.text);
        }
        _itemsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _itemsLoaded = true);
    }
  }

  // ── Title / body autosave ──────────────────────────────────────────

  void _queueMetaSave() {
    _metaDirty = true;
    _metaDebounce?.cancel();
    _metaDebounce = Timer(const Duration(milliseconds: 600), _flushMeta);
  }

  Future<void> _flushMeta() async {
    if (!_metaDirty) return;
    _metaDirty = false;
    try {
      await _repo.save(widget.noteId,
          title: _title.text.trim(), body: _body.text);
    } catch (_) {
      // OfflineWriter already queued it.
    }
  }

  // ── Checklist item ops ──────────────────────────────────────────────

  Future<void> _addItem(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final item =
          await _repo.addItem(widget.noteId, text: trimmed, position: _items.length);
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _itemCtrls[item.id] = TextEditingController(text: trimmed);
      });
      // Only clear on success — otherwise the input looks like it worked
      // while the typed item silently never made it into the list.
      _addCtrl.clear();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
    _addFocus.requestFocus();
  }

  Future<void> _toggleItem(NoteItem it) async {
    HapticFeedback.selectionClick();
    final idx = _items.indexWhere((e) => e.id == it.id);
    if (idx < 0) return;
    final next = !it.done;
    setState(() => _items[idx] = _items[idx].copyWith(done: next));
    try {
      await _repo.updateItem(it.id, done: next);
    } catch (_) {}
  }

  void _onItemChanged(String id, String text) {
    _pendingItemText[id] = text;
    _itemDebounce[id]?.cancel();
    _itemDebounce[id] = Timer(const Duration(milliseconds: 600), () {
      _flushItem(id);
    });
  }

  Future<void> _flushItem(String id) async {
    final text = _pendingItemText.remove(id);
    if (text == null) return;
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0) _items[idx] = _items[idx].copyWith(text: text);
    try {
      await _repo.updateItem(id, text: text.trim());
    } catch (_) {}
  }

  Future<void> _flushAllItems() async {
    for (final tmr in _itemDebounce.values) {
      tmr.cancel();
    }
    final ids = _pendingItemText.keys.toList();
    for (final id in ids) {
      await _flushItem(id);
    }
  }

  Future<void> _deleteItem(NoteItem it) async {
    setState(() {
      _items.removeWhere((e) => e.id == it.id);
      _itemCtrls.remove(it.id)?.dispose();
      _itemDebounce.remove(it.id)?.cancel();
      _pendingItemText.remove(it.id);
    });
    try {
      await _repo.deleteItem(it.id);
    } catch (_) {}
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
    });
    _repo.reorderItems(_items);
  }

  // ── Metadata ops (save immediately) ─────────────────────────────────

  Future<void> _editFolder() async {
    final pick =
        await showFolderPickerSheet(context, ref, currentFolderId: _folderId);
    if (pick == null) return;
    setState(() => _folderId = pick.folderId);
    try {
      await _repo.setFolder(widget.noteId, pick.folderId);
    } catch (_) {}
    ref.invalidate(notesListProvider);
  }

  Future<void> _editReminder() async {
    final choice = await showNoteReminderSheet(
      context,
      initialAt: _reminderAt,
      initialRule: _reminderRule,
    );
    if (choice == null) return;
    setState(() {
      if (choice.cleared) {
        _reminderAt = null;
        _reminderRule = null;
      } else {
        _reminderAt = choice.at;
        _reminderRule = choice.rule;
      }
    });
    try {
      await _repo.setReminder(widget.noteId,
          at: _reminderAt, rule: _reminderRule);
    } catch (_) {}
    // Refetch drives the note-reminder runner to (re)schedule the OS alarm.
    ref.invalidate(notesListProvider);
  }

  Future<void> _togglePin() async {
    HapticFeedback.selectionClick();
    setState(() => _pinned = !_pinned);
    try {
      await _repo.setPinned(widget.noteId, _pinned);
    } catch (_) {}
    ref.invalidate(notesListProvider);
  }

  // ── Leaving / deleting ──────────────────────────────────────────────

  bool get _isEffectivelyEmpty {
    if (_title.text.trim().isNotEmpty) return false;
    if (_reminderRule != null || _pinned || _folderId != null) return false;
    if (_kind == NoteKind.checklist) {
      return _items.isEmpty && _addCtrl.text.trim().isEmpty;
    }
    return _body.text.trim().isEmpty;
  }

  Future<void> _leave() async {
    // Capture a half-typed trailing checklist item before anything else.
    if (_kind == NoteKind.checklist && _addCtrl.text.trim().isNotEmpty) {
      await _addItem(_addCtrl.text);
    }
    await _flushMeta();
    await _flushAllItems();

    if (_isEffectivelyEmpty) {
      try {
        await _repo.delete(widget.noteId);
      } catch (_) {}
    }
    ref.invalidate(notesListProvider);
    if (mounted) popOrGo(context, '/me/notes');
  }

  Future<void> _deleteAndLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This can’t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: context.c.negative)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final tmr in _itemDebounce.values) {
      tmr.cancel();
    }
    _metaDebounce?.cancel();
    try {
      await _repo.delete(widget.noteId);
    } catch (_) {}
    ref.invalidate(notesListProvider);
    if (mounted) popOrGo(context, '/me/notes');
  }

  @override
  void dispose() {
    _metaDebounce?.cancel();
    for (final tmr in _itemDebounce.values) {
      tmr.cancel();
    }
    for (final ctrl in _itemCtrls.values) {
      ctrl.dispose();
    }
    _title.dispose();
    _body.dispose();
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];
    final isChecklist = _kind == NoteKind.checklist;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: _leave,
          ),
          title: Text(isChecklist ? 'Checklist' : 'Note', style: context.t.h2),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _pinned ? LucideIcons.pinOff : LucideIcons.pin,
                color: _pinned ? c.accent : null,
              ),
              tooltip: _pinned ? 'Unpin' : 'Pin',
              onPressed: _togglePin,
            ),
            IconButton(
              icon: Icon(LucideIcons.trash2, color: c.negative),
              tooltip: 'Delete',
              onPressed: _deleteAndLeave,
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 6,
                    AppSpace.screenH, 0),
                child: TextField(
                  controller: _title,
                  onChanged: (_) => _queueMetaSave(),
                  textCapitalization: TextCapitalization.sentences,
                  style: context.t.h1.copyWith(fontSize: 22),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle:
                        AppType.h1.copyWith(fontSize: 22, color: c.textDim),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              _MetaBar(
                folder: _folderById(folders, _folderId),
                reminderLabel: _reminderRule == null
                    ? null
                    : formatReminder(
                        context,
                        _stubNote(),
                      ),
                reminderPassed: _reminderRule == ReminderRule.once &&
                    _reminderAt != null &&
                    _reminderAt!.isBefore(DateTime.now()),
                onFolder: _editFolder,
                onReminder: _editReminder,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: isChecklist
                    ? _checklistBody(c)
                    : _noteBody(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds a throwaway Note carrying just the reminder fields so the shared
  // [formatReminder] helper can render the meta bar label.
  Note _stubNote() => Note(
        id: widget.noteId,
        userId: '',
        title: '',
        body: '',
        folderId: _folderId,
        kind: _kind,
        pinned: _pinned,
        reminderAt: _reminderAt,
        reminderRule: _reminderRule,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  NoteFolder? _folderById(List<NoteFolder> folders, String? id) {
    if (id == null) return null;
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  Widget _noteBody(AppPalette c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screenH, 4, AppSpace.screenH, 16),
      child: TextField(
        controller: _body,
        onChanged: (_) => _queueMetaSave(),
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        textCapitalization: TextCapitalization.sentences,
        style: context.t.body,
        decoration: InputDecoration(
          hintText: 'Start writing…',
          hintStyle: AppType.body.copyWith(color: c.textDim),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _checklistBody(AppPalette c) {
    if (!_itemsLoaded && _items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
      );
    }
    final doneCount = _items.where((e) => e.done).length;
    return Column(
      children: [
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 2,
                AppSpace.screenH, 6),
            child: Row(
              children: [
                Text('$doneCount of ${_items.length} done',
                    style: context.t.meta.copyWith(color: c.textMuted)),
                const Spacer(),
                if (doneCount > 0)
                  TextButton(
                    onPressed: _clearCompleted,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Clear done',
                        style: context.t.meta.copyWith(color: c.accent)),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _items.isEmpty
              ? _emptyChecklist(c)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.screenH, 0, AppSpace.screenH, 8),
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorder: _reorder,
                  itemBuilder: (ctx, i) {
                    final it = _items[i];
                    return _ChecklistRow(
                      key: ValueKey(it.id),
                      index: i,
                      item: it,
                      controller: _itemCtrls[it.id]!,
                      onToggle: () => _toggleItem(it),
                      onChanged: (v) => _onItemChanged(it.id, v),
                      onDelete: () => _deleteItem(it),
                    );
                  },
                ),
        ),
        _AddItemField(
          controller: _addCtrl,
          focusNode: _addFocus,
          onSubmit: () => _addItem(_addCtrl.text),
        ),
      ],
    );
  }

  Widget _emptyChecklist(AppPalette c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.listChecks, size: 34, color: c.textDim),
            const SizedBox(height: 12),
            Text('Add your first item below',
                style: context.t.body.copyWith(color: c.textMuted)),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCompleted() async {
    final done = _items.where((e) => e.done).toList();
    if (done.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      for (final it in done) {
        _items.removeWhere((e) => e.id == it.id);
        _itemCtrls.remove(it.id)?.dispose();
        _itemDebounce.remove(it.id)?.cancel();
        _pendingItemText.remove(it.id);
      }
    });
    for (final it in done) {
      try {
        await _repo.deleteItem(it.id);
      } catch (_) {}
    }
  }
}

// ── Meta bar ───────────────────────────────────────────────────────────

class _MetaBar extends StatelessWidget {
  final NoteFolder? folder;
  final String? reminderLabel;
  final bool reminderPassed;
  final VoidCallback onFolder;
  final VoidCallback onReminder;
  const _MetaBar({
    required this.folder,
    required this.reminderLabel,
    required this.reminderPassed,
    required this.onFolder,
    required this.onReminder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final folderColor =
        folder == null ? c.textMuted : FolderStyle.color(context, folder!.color);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.screenH, 8, AppSpace.screenH, 4),
      child: Row(
        children: [
          Expanded(
            child: _MetaButton(
              icon: folder == null
                  ? LucideIcons.folderPlus
                  : FolderStyle.icon(folder!.icon),
              iconColor: folderColor,
              label: folder?.displayName ?? 'Folder',
              muted: folder == null,
              onTap: onFolder,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetaButton(
              icon: LucideIcons.bell,
              iconColor: reminderLabel == null
                  ? c.textMuted
                  : (reminderPassed ? c.textMuted : c.accent),
              label: reminderLabel ?? 'Remind me',
              muted: reminderLabel == null,
              onTap: onReminder,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool muted;
  final VoidCallback onTap;
  const _MetaButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.muted,
    required this.onTap,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    color: muted ? c.textMuted : c.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Checklist rows ──────────────────────────────────────────────────────

class _ChecklistRow extends StatelessWidget {
  final int index;
  final NoteItem item;
  final TextEditingController controller;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;
  const _ChecklistRow({
    super.key,
    required this.index,
    required this.item,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = item.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                size: 21,
                color: done ? c.positive : c.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textCapitalization: TextCapitalization.sentences,
              style: context.t.body.copyWith(
                color: done ? c.textMuted : c.textPrimary,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: c.textMuted,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Item',
                hintStyle: AppType.body.copyWith(color: c.textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(LucideIcons.x, size: 15, color: c.textDim),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(LucideIcons.gripVertical, size: 16, color: c.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddItemField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  const _AddItemField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        8,
        AppSpace.screenH,
        MediaQuery.of(context).viewPadding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.plus, size: 18, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: context.t.body,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Add an item',
                hintStyle: AppType.body.copyWith(color: c.textDim),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
