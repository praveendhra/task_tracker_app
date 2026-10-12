import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/task.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'task_editor.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: TaskDetailView(
            taskId: taskId,
            onDeleted: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
}

/// Task details with its step timeline. Used full-screen on phones and as the
/// right-hand pane on wide screens.
class TaskDetailView extends StatelessWidget {
  const TaskDetailView({
    super.key,
    required this.taskId,
    this.embedded = false,
    this.onDeleted,
  });

  final String taskId;
  final bool embedded;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final task = app.taskById(taskId);
    if (task == null) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Task not found',
        message: 'It may have been deleted on another device.',
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(children: [
      _TopBar(task: task, embedded: embedded, onDeleted: onDeleted),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
          children: [
            if (task.archived)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Pill(
                    label: 'Archived',
                    color: scheme.muted,
                    icon: Icons.inventory_2_outlined),
              ),
            Text(task.title.isEmpty ? 'Untitled task' : task.title,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _StatusMenu(task: task),
              if (task.priority != Priority.none)
                PriorityFlag(task.priority, showLabel: true),
              if (task.dueDate != null) DuePill(task),
              for (final t in task.tags) Pill(label: '#$t', color: scheme.primary),
            ]),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(task.description,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
            ],
            const SizedBox(height: 28),
            _ProgressCard(task: task),
            const SizedBox(height: 28),
            SectionLabel(
              'Steps',
              trailing: task.steps.isEmpty
                  ? null
                  : Text('${task.doneSteps} of ${task.steps.length} done',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.muted)),
            ),
            if (task.steps.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                    'Break this into steps to track exactly where it stands.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.muted)),
              ),
            for (var i = 0; i < task.steps.length; i++)
              _StepTile(
                task: task,
                step: task.steps[i],
                isCurrent: task.currentStep?.id == task.steps[i].id && !task.isDone,
                isLast: i == task.steps.length - 1,
              ),
            const SizedBox(height: 8),
            _AddStepField(task: task),
            const SizedBox(height: 28),
            Text(
              'Created ${formatAgo(task.createdAt)} · Updated ${formatAgo(task.updatedAt)}'
              '${task.completedAt != null ? ' · Completed ${formatAgo(task.completedAt!)}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.task, required this.embedded, this.onDeleted});
  final Task task;
  final bool embedded;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        if (!embedded) const BackButton(),
        const Spacer(),
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => showTaskEditor(context, task),
        ),
        IconButton(
          tooltip: task.archived ? 'Restore' : 'Archive',
          icon: Icon(task.archived
              ? Icons.unarchive_outlined
              : Icons.inventory_2_outlined),
          onPressed: () {
            app.setArchived(task, !task.archived);
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(SnackBar(
              content: Text(task.archived ? 'Task restored' : 'Task archived'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => app.setArchived(task, task.archived),
              ),
            ));
          },
        ),
        IconButton(
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline_rounded, color: scheme.danger),
          onPressed: () async {
            final ok = await confirmDelete(context, task);
            if (ok) {
              onDeleted?.call();
              await app.delete(task.id);
            }
          },
        ),
      ]),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, Task task) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this task?'),
      content: Text(
          '"${task.title.isEmpty ? 'Untitled task' : task.title}" and its '
          '${task.steps.length} step${task.steps.length == 1 ? '' : 's'} will be '
          'gone for good. Archive it instead if you might need it later.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PopupMenuButton<TaskStatus>(
      tooltip: 'Change status',
      onSelected: (s) {
        if (task.steps.isEmpty) {
          app.save(task.withStatus(s));
        } else if (s == TaskStatus.done || (task.isDone && s != TaskStatus.done)) {
          app.cycleStatus(task);
        } else {
          app.save(task.withStatus(s));
        }
      },
      itemBuilder: (_) => [
        for (final s in TaskStatus.values)
          PopupMenuItem(value: s, child: StatusPill(s)),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        StatusPill(task.status),
        Icon(Icons.expand_more_rounded,
            size: 16, color: Theme.of(context).colorScheme.muted),
      ]),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pct = (task.progress * 100).round();
    final current = task.currentStep;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: task.progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: task.isDone ? scheme.success : scheme.primary,
                  backgroundColor: scheme.subtle,
                ),
              ),
              ),
              Text('$pct%', style: theme.textTheme.labelLarge),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                task.isDone
                    ? 'All done'
                    : current != null
                        ? 'Now on'
                        : task.steps.isEmpty
                            ? 'No steps yet'
                            : 'Up next',
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.muted),
              ),
              const SizedBox(height: 2),
              Text(
                task.isDone
                    ? (task.completedAt != null
                        ? 'Finished ${formatAgo(task.completedAt!)}'
                        : 'Finished')
                    : current?.title ?? 'Add the first step below',
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.task,
    required this.step,
    required this.isCurrent,
    required this.isLast,
  });

  final Task task;
  final TaskStep step;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lineColor = step.isDone ? scheme.success : theme.dividerTheme.color!;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Column(children: [
            StatusCheck(
              status: step.status,
              size: 22,
              tooltip: step.isDone ? 'Mark not done' : 'Mark done',
              onTap: () => app.toggleStep(task, step),
            ),
            if (!isLast)
              Expanded(
                child: Container(width: 2, color: lineColor.withValues(alpha: 0.6)),
              ),
          ]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: isCurrent
                  ? scheme.primaryContainer.withValues(alpha: 0.45)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showStepSheet(context, task, step),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          step.title.isEmpty ? 'Untitled step' : step.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration: step.isDone ? TextDecoration.lineThrough : null,
                            color: step.isDone ? scheme.muted : null,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Pill(label: 'Current', color: scheme.primary),
                    ]),
                    if (step.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(step.note,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.muted, height: 1.4)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<void> _showStepSheet(BuildContext context, Task task, TaskStep step) {
  final app = AppScope.read(context);
  final title = TextEditingController(text: step.title);
  final note = TextEditingController(text: step.note);
  var status = step.status;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final theme = Theme.of(context);
        void commit() {
          final latest = app.taskById(task.id);
          if (latest == null) return;
          final next = latest.withStep(step.copyWith(
              title: title.text.trim(), note: note.text.trim(), status: status));
          app.save(next);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Step', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'What needs doing'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Blockers, links, who you are waiting on…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<TaskStatus>(
                segments: [
                  for (final s in TaskStatus.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {status},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setSheet(() => status = v.first),
              ),
              const SizedBox(height: 20),
              Row(children: [
                TextButton.icon(
                  onPressed: () {
                    final latest = app.taskById(task.id);
                    if (latest == null) return;
                    final steps = latest.steps.where((s) => s.id != step.id).toList();
                    app.save(latest.copyWith(
                      steps: steps,
                      clearCurrentStep: latest.currentStepId == step.id,
                    ));
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.danger),
                  label: Text('Remove', style: TextStyle(color: theme.colorScheme.danger)),
                ),
                const Spacer(),
                if (!step.isDone)
                  TextButton(
                    onPressed: () {
                      commit();
                      final latest = app.taskById(task.id);
                      if (latest != null) {
                        app.setCurrentStep(latest,
                            latest.steps.firstWhere((s) => s.id == step.id,
                                orElse: () => step));
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Make current'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    commit();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ]),
            ],
          ),
        );
      },
    ),
  );
}

class _AddStepField extends StatefulWidget {
  const _AddStepField({required this.task});
  final Task task;

  @override
  State<_AddStepField> createState() => _AddStepFieldState();
}

class _AddStepFieldState extends State<_AddStepField> {
  final _c = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    final app = AppScope.read(context);
    final latest = app.taskById(widget.task.id) ?? widget.task;
    final step = TaskStep(id: newId(), title: text);
    var next = latest.copyWith(steps: [...latest.steps, step]);
    // A finished task with a new open step is no longer finished.
    if (next.isDone) next = next.withStatus(TaskStatus.inProgress);
    app.save(next);
    _c.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      SizedBox(
        width: 40,
        child: Icon(Icons.add_rounded, color: scheme.primary),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: TextField(
          controller: _c,
          focusNode: _focus,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            hintText: 'Add a step',
            isDense: true,
            suffixIcon: IconButton(
              tooltip: 'Add step',
              icon: const Icon(Icons.keyboard_return_rounded),
              onPressed: _add,
            ),
          ),
        ),
      ),
    ]);
  }
}
