import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';

/// The app icon, cropped to the mark (assets/icon/mark.png).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/icon/mark.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Task Tracker',
      );
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatDue(DateTime d) {
  final today = TaskDates.today();
  final diff = TaskDates.dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return _weekdays[d.weekday - 1];
  final sameYear = d.year == today.year;
  return '${_months[d.month - 1]} ${d.day}${sameYear ? '' : ', ${d.year}'}';
}

String formatAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDue(d);
}

/// Round checkbox that cycles through a status.
class StatusCheck extends StatelessWidget {
  const StatusCheck({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 24,
    this.tooltip,
  });

  final TaskStatus status;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.statusColor(status);
    final Widget inner = switch (status) {
      TaskStatus.done => Icon(Icons.check_rounded,
          size: size * 0.7, color: scheme.surface),
      TaskStatus.inProgress => Container(
          width: size * 0.42,
          height: size * 0.42,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      TaskStatus.notStarted => const SizedBox.shrink(),
    };
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status == TaskStatus.done ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
      child: inner,
    );
    return Tooltip(
      message: tooltip ?? status.label,
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: Padding(padding: const EdgeInsets.all(6), child: box),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = scheme.statusColor(status);
    return Pill(
      label: status.label,
      color: c,
      icon: switch (status) {
        TaskStatus.notStarted => Icons.radio_button_unchecked_rounded,
        TaskStatus.inProgress => Icons.timelapse_rounded,
        TaskStatus.done => Icons.check_circle_rounded,
      },
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: color, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(label, style: style),
      ]),
    );
  }
}

class DuePill extends StatelessWidget {
  const DuePill(this.task, {super.key});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = task.dueDate;
    if (due == null) return const SizedBox.shrink();
    final color = task.isOverdue
        ? scheme.danger
        : task.isDueSoon
            ? scheme.warning
            : scheme.muted;
    return Pill(
      label: formatDue(due),
      color: color,
      icon: task.isOverdue ? Icons.error_outline_rounded : Icons.event_rounded,
    );
  }
}

class PriorityFlag extends StatelessWidget {
  const PriorityFlag(this.priority, {super.key, this.showLabel = false});
  final Priority priority;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (priority == Priority.none && !showLabel) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme.priorityColor(priority);
    if (showLabel) {
      return Pill(label: priority.label, color: c, icon: Icons.flag_rounded);
    }
    return Tooltip(
      message: '${priority.label} priority',
      child: Icon(Icons.flag_rounded, size: 16, color: c),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 6});
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color ?? (value >= 1 ? scheme.success : scheme.primary),
          backgroundColor: scheme.subtle,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 34, color: scheme.primary),
          ),
          const SizedBox(height: 18),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.muted)),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

/// One task in a list.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    this.selected = false,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = task.currentStep;
    final done = task.isDone;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : theme.dividerTheme.color!,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusCheck(
              status: task.status,
              onTap: onToggle,
              tooltip: done ? 'Reopen' : 'Mark done',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        task.title.isEmpty ? 'Untitled task' : task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? scheme.muted : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (task.priority != Priority.none) ...[
                      const SizedBox(width: 8),
                      PriorityFlag(task.priority),
                    ],
                  ]),
                  if (current != null && !done) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.subdirectory_arrow_right_rounded,
                          size: 14, color: scheme.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          current.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.muted),
                        ),
                      ),
                    ]),
                  ] else if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
                    ),
                  ],
                  if (task.steps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: ProgressBar(value: task.progress, height: 5)),
                      const SizedBox(width: 10),
                      Text('${task.doneSteps}/${task.steps.length}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.muted)),
                    ]),
                  ],
                  if (task.dueDate != null || task.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (task.dueDate != null && !done) DuePill(task),
                      for (final tag in task.tags.take(3))
                        Pill(label: '#$tag', color: scheme.primary),
                    ]),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(children: [
        Text(text.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.muted,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
