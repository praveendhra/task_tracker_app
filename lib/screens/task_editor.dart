import 'package:flutter/material.dart';

import '../app_controller.dart';
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
  _StepDraft(this.step) : controller = TextEditingController(text: step.title);
  final TaskStep step;
  final TextEditingController controller;
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
      s.controller.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    final text = _newStep.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _steps.add(_StepDraft(TaskStep(id: newId(), title: text)));
      _dirty = true;
    });
    _newStep.clear();
    _newStepFocus.requestFocus();
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
          d.step.copyWith(title: d.controller.text.trim()),
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

    return PopScope(
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
                    label: Text(p == Priority.none ? 'None' : p.label),
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
                trailing: _steps.isEmpty
                    ? null
                    : Text('Drag to reorder',
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.muted))),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _steps.length,
              onReorderItem: (from, to) => setState(() {
                _steps.insert(to, _steps.removeAt(from));
                _dirty = true;
              }),
              itemBuilder: (context, i) {
                final d = _steps[i];
                return Padding(
                  key: ValueKey(d.step.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator_rounded, color: scheme.muted),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: d.controller,
                        onChanged: (_) => _dirty = true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: Text('${i + 1}',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: scheme.muted)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove step',
                      icon: Icon(Icons.remove_circle_outline_rounded, color: scheme.muted),
                      onPressed: () => setState(() {
                        _steps.removeAt(i).controller.dispose();
                        _dirty = true;
                      }),
                    ),
                  ]),
                );
              },
            ),
            Row(children: [
              const SizedBox(width: 40),
              Expanded(
                child: TextField(
                  controller: _newStep,
                  focusNode: _newStepFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addStep(),
                  decoration: InputDecoration(
                    hintText: _steps.isEmpty ? 'First step' : 'Next step',
                    isDense: true,
                    prefixIcon: Icon(Icons.add_rounded, color: scheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ]),
          ],
        ),
      ),
    );
  }
}
