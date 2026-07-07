import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../domain/todo_item.dart';
import '../providers/todo_providers.dart';

/// A date-scoped to-do list for day-to-day things ("Buy groceries"). Pick a
/// date for the whole list; add tasks with an optional time; check, edit,
/// reorder, delete. Stored locally.
class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  String? _pendingTime; // time to attach to the next added task

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  DateTime get _date => ref.read(selectedTodoDateProvider);
  void _bump() => ref.read(todoRevisionProvider.notifier).state++;

  Future<void> _add() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    await ref.read(todoRepositoryProvider).add(_date, text, time: _pendingTime);
    _addCtrl.clear();
    setState(() => _pendingTime = null);
    _bump();
    HapticFeedback.lightImpact();
    _addFocus.requestFocus();
  }

  Future<void> _pickPendingTime() async {
    final picked = await _pickTime(context, _pendingTime);
    if (picked != null) setState(() => _pendingTime = picked);
  }

  void _shiftDate(int days) {
    HapticFeedback.selectionClick();
    ref.read(selectedTodoDateProvider.notifier).state =
        _date.add(Duration(days: days));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ref.read(selectedTodoDateProvider.notifier).state =
          DateTime(picked.year, picked.month, picked.day);
    }
  }

  Future<void> _editTodo(TodoItem item) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.c.background,
      builder: (_) => _EditSheet(item: item),
    );
    if (result == null) return;
    final repo = ref.read(todoRepositoryProvider);
    if (result.delete) {
      await repo.delete(_date, item.id);
    } else {
      await repo.update(
          _date,
          item.copyWith(
              text: result.text,
              time: result.time,
              clearTime: result.time == null));
    }
    _bump();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = ref.watch(todosForDateProvider);
    final date = ref.watch(selectedTodoDateProvider);
    final doneCount = items.where((t) => t.done).length;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(),
        title: Text('To-do', style: context.t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _DateHeader(
              date: date,
              done: doneCount,
              total: items.length,
              onPrev: () => _shiftDate(-1),
              onNext: () => _shiftDate(1),
              onPick: _pickDate,
            ),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(onTap: () => _addFocus.requestFocus())
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.screenH, 8, AppSpace.screenH, 12),
                      itemCount: items.length,
                      onReorder: (oldI, newI) {
                        final list = [...items];
                        if (newI > oldI) newI -= 1;
                        final moved = list.removeAt(oldI);
                        list.insert(newI, moved);
                        ref.read(todoRepositoryProvider).reorder(_date, list);
                        _bump();
                      },
                      proxyDecorator: (child, _, _) =>
                          Material(color: Colors.transparent, child: child),
                      itemBuilder: (ctx, i) {
                        final t = items[i];
                        return Padding(
                          key: ValueKey(t.id),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TodoRow(
                            item: t,
                            index: i,
                            onToggle: () {
                              ref
                                  .read(todoRepositoryProvider)
                                  .toggle(_date, t.id);
                              _bump();
                              HapticFeedback.selectionClick();
                            },
                            onTap: () => _editTodo(t),
                          ),
                        );
                      },
                    ),
            ),
            _AddBar(
              controller: _addCtrl,
              focusNode: _addFocus,
              pendingTime: _pendingTime,
              onPickTime: _pickPendingTime,
              onClearTime: () => setState(() => _pendingTime = null),
              onSubmit: _add,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date header ────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final int done;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  const _DateHeader({
    required this.date,
    required this.done,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.screenH, 8, AppSpace.screenH, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          _NavBtn(icon: LucideIcons.chevronLeft, onTap: onPrev),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text(_relativeLabel(date),
                      style: t.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text(
                    total == 0
                        ? _fullDate(date)
                        : '$done of $total done · ${_fullDate(date)}',
                    style: t.meta.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
          _NavBtn(icon: LucideIcons.chevronRight, onTap: onNext),
        ],
      ),
    );
  }

  static String _relativeLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    return switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => _weekday(d.weekday),
    };
  }

  static String _fullDate(DateTime d) =>
      '${_weekday(d.weekday)}, ${_month(d.month)} ${d.day}';
  static String _weekday(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][(w - 1).clamp(0, 6)];
  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][(m - 1).clamp(0, 11)];
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, size: 22, color: c.textSecondary),
      ),
    );
  }
}

// ── Todo row ───────────────────────────────────────────────────────────

class _TodoRow extends StatelessWidget {
  final TodoItem item;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  const _TodoRow({
    required this.item,
    required this.index,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final done = item.done;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 48,
              height: 52,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done ? c.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: done ? c.accent : c.borderStrong, width: 2),
                  ),
                  child: done
                      ? Icon(LucideIcons.check, size: 14, color: c.onAccent)
                      : null,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  item.text,
                  style: t.body.copyWith(
                    color: done ? c.textMuted : c.textPrimary,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: c.textMuted,
                  ),
                ),
              ),
            ),
          ),
          if (item.time != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.clock, size: 11, color: c.accent),
                  const SizedBox(width: 4),
                  Text(item.time!,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.accent)),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          ReorderableDragStartListener(
            index: index,
            child: const SizedBox(
              width: 40,
              height: 52,
              child: Center(child: _GripIcon()),
            ),
          ),
        ],
      ),
    );
  }
}

class _GripIcon extends StatelessWidget {
  const _GripIcon();
  @override
  Widget build(BuildContext context) =>
      Icon(LucideIcons.gripVertical, size: 16, color: context.c.textDim);
}

// ── Add bar ────────────────────────────────────────────────────────────

class _AddBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? pendingTime;
  final VoidCallback onPickTime;
  final VoidCallback onClearTime;
  final VoidCallback onSubmit;
  const _AddBar({
    required this.controller,
    required this.focusNode,
    required this.pendingTime,
    required this.onPickTime,
    required this.onClearTime,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpace.screenH, 10, AppSpace.screenH,
          10 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadii.button),
                border: Border.all(color: c.borderStrong),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onSubmit(),
                      style: t.body.copyWith(
                          color: c.textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Add a task…',
                        hintStyle: t.body.copyWith(color: c.textDim),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (pendingTime != null)
                    GestureDetector(
                      onTap: onClearTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(pendingTime!,
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: c.accent)),
                            const SizedBox(width: 4),
                            Icon(LucideIcons.x, size: 12, color: c.accent),
                          ],
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon:
                          Icon(LucideIcons.clock, size: 18, color: c.textMuted),
                      onPressed: onPickTime,
                      tooltip: 'Set time',
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSubmit,
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              child: Icon(LucideIcons.plus, size: 22, color: c.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(LucideIcons.listChecks, size: 28, color: c.accent),
              ),
              const SizedBox(height: 18),
              Text('Nothing here yet',
                  style: t.h2, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                  'Add your first task for the day — groceries, calls, errands.',
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: c.textMuted, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit sheet ─────────────────────────────────────────────────────────

class _EditResult {
  final String text;
  final String? time;
  final bool delete;
  const _EditResult({required this.text, this.time, this.delete = false});
}

class _EditSheet extends StatefulWidget {
  final TodoItem item;
  const _EditSheet({required this.item});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _text;
  String? _time;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.item.text);
    _time = widget.item.time;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
                    color: c.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text('Edit task', style: t.h2),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            autofocus: true,
            style: t.body
                .copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Task',
              filled: true,
              fillColor: c.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final p = await _pickTime(context, _time);
                    if (p != null) setState(() => _time = p);
                  },
                  child: Container(
                    height: 50,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.clock, size: 16, color: c.textSecondary),
                      const SizedBox(width: 10),
                      Text(_time ?? 'No time',
                          style: t.body.copyWith(
                              color: _time != null ? c.textPrimary : c.textDim,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              if (_time != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _time = null),
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child:
                        Icon(LucideIcons.x, size: 17, color: c.textSecondary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(
                    context, const _EditResult(text: '', delete: true)),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(LucideIcons.trash2, size: 19, color: c.negative),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final txt = _text.text.trim();
                    if (txt.isEmpty) return;
                    Navigator.pop(context, _EditResult(text: txt, time: _time));
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    child: Text('Save',
                        style: t.bodyStrong.copyWith(color: c.onAccent)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared time picker ─────────────────────────────────────────────────

Future<String?> _pickTime(BuildContext context, String? current) async {
  final parts = (current ?? '09:00').split(':');
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
  );
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
}
