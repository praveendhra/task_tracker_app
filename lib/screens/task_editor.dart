import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../models/quick_add.dart';
import '../models/task.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens the create/edit form. Full screen on phones, a dialog on wide
/// screens. Returns the saved task, or null if cancelled.
Future<Task?> showTaskEditor(BuildContext context, Task task) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (wide) {
    return showDialog<Task>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 820),
          child: TaskEditor(task: task),
        ),
      ),
    );
  }
  return Navigator.of(context).push<Task>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TaskEditor(task: task),
  ));
}

class _StepDraft {
  _StepDraft(this.step)
      : controller = TextEditingController(text: step.title),
        note = TextEditingController(text: step.note),
        showNote = step.note.isNotEmpty,
        due = step.dueDate;
  final TaskStep step;
  DateTime? due;
  final TextEditingController controller;
  final TextEditingController note;
  final FocusNode noteFocus = FocusNode();
  bool showNote;

  void dispose() {
    controller.dispose();
    note.dispose();
    noteFocus.dispose();
  }
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.task});
  final Task task;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _tagInput = TextEditingController();
  final _newStep = TextEditingController();
  final _newStepFocus = FocusNode();
  late Priority _priority;
  DateTime? _due;
  late List<String> _tags;
  late List<_StepDraft> _steps;
  bool _dirty = false;

  bool get _isNew => AppScope.read(context).taskById(widget.task.id) == null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t.title)..addListener(_touch);
    _description = TextEditingController(text: t.description)..addListener(_touch);
    _priority = t.priority;
    _due = t.dueDate;
    _tags = [...t.tags];
    _steps = [for (final s in t.steps) _StepDraft(s)];
  }

  void _touch() => _dirty = true;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tagInput.dispose();
    _newStep.dispose();
    _newStepFocus.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    final text = _newStep.text.trim();
    if (text.isEmpty) return;
    final parsed = parseStepText(text);
    setState(() {
      _steps.add(_StepDraft(
          TaskStep(id: newId(), title: parsed.title, dueDate: parsed.dueDate)));
      _dirty = true;
    });
    _newStep.clear();
    _newStepFocus.requestFocus();
  }

  void _moveStep(int from, int to) {
    if (to < 0 || to >= _steps.length) return;
    setState(() {
      _steps.insert(to, _steps.removeAt(from));
      _dirty = true;
    });
  }

  Future<void> _pickStepDate(_StepDraft d) async {
    final today = TaskDates.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.due ?? _due ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 5),
      helpText: 'Step due date',
    );
    if (picked != null) {
      setState(() {
        d.due = picked;
        _dirty = true;
      });
    }
  }

  void _toggleNote(_StepDraft d) {
    setState(() => d.showNote = !d.showNote);
    if (d.showNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) => d.noteFocus.requestFocus());
    }
  }

  void _addTag(String raw) {
    final tag = raw.trim().replaceAll('#', '').replaceAll(RegExp(r'\s+'), '-').toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagInput.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
      _dirty = true;
    });
    _tagInput.clear();
  }

  Future<void> _pickDate() async {
    final today = TaskDates.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) {
      setState(() {
        _due = picked;
        _dirty = true;
      });
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Give the task a name')));
      return;
    }
    // Pending text in the "add step" box counts as a step.
    if (_newStep.text.trim().isNotEmpty) _addStep();

    final app = AppScope.read(context);
    final base = app.taskById(widget.task.id) ?? widget.task;
    final steps = [
      for (final d in _steps)
        if (d.controller.text.trim().isNotEmpty)
          d.step.copyWith(
              title: d.controller.text.trim(),
              note: d.note.text.trim(),
              dueDate: d.due,
              clearDueDate: d.due == null),
    ];
    var next = base.copyWith(
      title: title,
      description: _description.text.trim(),
      priority: _priority,
      dueDate: _due,
      clearDueDate: _due == null,
      tags: _tags,
      steps: steps,
      clearCurrentStep:
          base.currentStepId != null && !steps.any((s) => s.id == base.currentStepId),
    );
    if (steps.isNotEmpty) {
      // Keep the task status in line with its steps after edits.
      final allDone = steps.every((s) => s.isDone);
      if (allDone && !next.isDone) next = next.withStatus(TaskStatus.done);
      if (!allDone && next.isDone) next = next.withStatus(TaskStatus.inProgress);
    }
    app.save(next);
    Navigator.of(context).pop(next);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text("Your edits to this task won't be saved."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok ?? false;
  }

  Widget _stepRow(BuildContext context, int i) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = _steps[i];
    final hasNote = d.note.text.trim().isNotEmpty;
    return Padding(
      key: ValueKey(d.step.id),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerTheme.color!),
        ),
        padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ReorderableDragStartListener(
              index: i,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Tooltip(
                  message: 'Drag to reorder',
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                    child: Icon(Icons.drag_indicator_rounded, color: scheme.muted),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text('${i + 1}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.muted)),
            ),
            Expanded(
              child: TextField(
                controller: d.controller,
                onChanged: (_) => _dirty = true,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Step',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
            IconButton(
              tooltip: d.showNote ? 'Hide note' : (hasNote ? 'Show note' : 'Add note'),
              visualDensity: VisualDensity.compact,
              onPressed: () => _toggleNote(d),
              icon: Icon(
                hasNote ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
                color: hasNote || d.showNote ? scheme.primary : scheme.muted,
              ),
            ),
            IconButton(
              tooltip: d.due == null ? 'Set a due date' : 'Change due date',
              visualDensity: VisualDensity.compact,
              onPressed: () => _pickStepDate(d),
              icon: Icon(
                d.due == null ? Icons.event_outlined : Icons.event_rounded,
                color: d.due == null ? scheme.muted : scheme.primary,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert_rounded, color: scheme.muted),
              onSelected: (v) {
                switch (v) {
                  case 'up':
                    _moveStep(i, i - 1);
                  case 'down':
                    _moveStep(i, i + 1);
                  case 'top':
                    _moveStep(i, 0);
                  case 'clear-date':
                    setState(() {
                      d.due = null;
                      _dirty = true;
                    });
                  case 'remove':
                    setState(() {
                      _steps.removeAt(i).dispose();
                      _dirty = true;
                    });
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'up',
                    enabled: i > 0,
                    child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.arrow_upward_rounded),
                        title: Text('Move up'))),
                PopupMenuItem(
                    value: 'down',
                    enabled: i < _steps.length - 1,
                    child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.arrow_downward_rounded),
                        title: Text('Move down'))),
                PopupMenuItem(
                    value: 'top',
                    enabled: i > 0,
                    child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.vertical_align_top_rounded),
                        title: Text('Move to top'))),
                if (d.due != null)
                  const PopupMenuItem(
                      value: 'clear-date',
                      child: ListTile(
                          dense: true,
                          leading: Icon(Icons.event_busy_outlined),
                          title: Text('Remove due date'))),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline_rounded, color: scheme.danger),
                        title: Text('Remove step', style: TextStyle(color: scheme.danger)))),
              ],
            ),
          ]),
          if (d.due != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 0, 12, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StepDueChip(
                  due: d.due!,
                  onTap: () => _pickStepDate(d),
                  onClear: () => setState(() {
                    d.due = null;
                    _dirty = true;
                  }),
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: d.showNote
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 12, 8),
                    child: TextField(
                      controller: d.note,
                      focusNode: d.noteFocus,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: (_) => setState(() => _dirty = true),
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Note: blockers, links, who you are waiting on…',
                        fillColor: scheme.subtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = TaskDates.today();

    Widget dueChip(String label, DateTime? date) {
      final selected = date == null
          ? false
          : _due != null && TaskDates.dateOnly(_due!) == date;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() {
          _due = selected ? null : date;
          _dirty = true;
        }),
      );
    }

    final presetDates = {
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 7)),
    };
    final customDue =
        _due != null && !presetDates.contains(TaskDates.dateOnly(_due!));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
      },
      child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_isNew ? 'New task' : 'Edit task'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            TextField(
              controller: _title,
              autofocus: _isNew,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.titleLarge,
              decoration: const InputDecoration(
                hintText: 'Task name',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            TextField(
              controller: _description,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add details',
                hintStyle: TextStyle(color: scheme.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Due'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              dueChip('Today', today),
              dueChip('Tomorrow', today.add(const Duration(days: 1))),
              dueChip('Next week', today.add(const Duration(days: 7))),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(customDue ? formatDue(_due!) : 'Pick date'),
                onPressed: _pickDate,
                backgroundColor: customDue ? scheme.secondaryContainer : null,
              ),
              if (_due != null)
                ActionChip(
                  avatar: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('No date'),
                  onPressed: () => setState(() {
                    _due = null;
                    _dirty = true;
                  }),
                ),
            ]),
            const SizedBox(height: 24),
            const SectionLabel('Priority'),
            SegmentedButton<Priority>(
              showSelectedIcon: false,
              segments: [
                for (final p in Priority.values)
                  ButtonSegment(
                    value: p,
                    label: Text(switch (p) {
                      Priority.none => 'None',
                      Priority.medium => 'Med',
                      _ => p.label,
                    }),
                    icon: p == Priority.none
                        ? null
                        : Icon(Icons.flag_rounded, color: scheme.priorityColor(p), size: 16),
                  ),
              ],
              selected: {_priority},
              onSelectionChanged: (v) => setState(() {
                _priority = v.first;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Tags'),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final t in _tags)
                InputChip(
                  label: Text('#$t'),
                  onDeleted: () => setState(() {
                    _tags.remove(t);
                    _dirty = true;
                  }),
                ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _tagInput,
                  decoration: const InputDecoration(
                    hintText: 'Add tag',
                    isDense: true,
                    prefixIcon: Icon(Icons.tag_rounded, size: 18),
                  ),
                  onChanged: (v) {
                    if (v.endsWith(',') || v.endsWith(' ')) {
                      _addTag(v.substring(0, v.length - 1));
                    }
                  },
                  onSubmitted: _addTag,
                ),
              ),
              for (final s in AppScope.of(context).allTags.where((t) => !_tags.contains(t)).take(6))
                ActionChip(
                  label: Text('#$s', style: TextStyle(color: scheme.muted)),
                  onPressed: () => _addTag(s),
                ),
            ]),
            const SizedBox(height: 28),
            SectionLabel('Steps',
                trailing: _steps.length < 2
                    ? null
                    : Text('Drag ⠿ or use ⋮ to reorder',
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.muted))),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _steps.length,
              onReorderItem: (from, to) => _moveStep(from, to),
              proxyDecorator: (child, _, __) => Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
              itemBuilder: (context, i) => _stepRow(context, i),
            ),
            TextField(
              controller: _newStep,
              focusNode: _newStepFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addStep(),
              decoration: InputDecoration(
                hintText: _steps.isEmpty ? 'Add the first step' : 'Add another step',
                prefixIcon: Icon(Icons.add_rounded, color: scheme.primary),
                suffixIcon: IconButton(
                  tooltip: 'Add step',
                  icon: const Icon(Icons.keyboard_return_rounded),
                  onPressed: _addStep,
                ),
              ),
            ),
            if (_steps.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text('Press Enter to add each step. Add a note, a due date (or type one, like "fri") and reorder right here.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted)),
              ),
          ],
        ),
      ),
    ),
    );
  }
}


class _StepDueChip extends StatelessWidget {
  const _StepDueChip({required this.due, required this.onTap, required this.onClear});
  final DateTime due;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = TaskDates.today();
    final color = due.isBefore(today)
        ? scheme.danger
        : TaskDates.dateOnly(due) == today
            ? scheme.warning
            : scheme.primary;
    return InputChip(
      avatar: Icon(Icons.event_rounded, size: 16, color: color),
      label: Text('Due ${formatDue(due)}'),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      onDeleted: onClear,
      deleteButtonTooltipMessage: 'Remove due date',
    );
  }
}
