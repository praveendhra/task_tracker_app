import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../models/quick_add.dart';
import '../models/task.dart';
import '../screens/task_editor.dart';
import '../theme.dart';
import 'common.dart';

/// Opens quick add: a single line that understands dates, #tags and !priority.
/// A bottom sheet on phones, a command-palette style dialog on wide screens.
/// Returns the created task, if any.
Future<Task?> showQuickAdd(BuildContext context, {String initialText = ''}) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (wide) {
    return showDialog<Task>(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Align(
        alignment: const Alignment(0, -0.55),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: QuickAddPanel(initialText: initialText),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: QuickAddPanel(initialText: initialText),
    ),
  );
}

/// Colours recognised tokens inside the text field as you type.
class _HighlightController extends TextEditingController {
  _HighlightController({super.text});

  List<QuickAddMatch> matches = const [];
  ColorScheme? scheme;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final s = scheme;
    if (s == null || matches.isEmpty || value.composing.isValid) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in matches) {
      if (m.end > text.length) break;
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      final color = switch (m.kind) {
        QuickAddKind.date => s.warning,
        QuickAddKind.tag => s.primary,
        QuickAddKind.priority => s.danger,
      };
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ));
      pos = m.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return TextSpan(style: style, children: spans);
  }
}

class QuickAddPanel extends StatefulWidget {
  const QuickAddPanel({super.key, this.initialText = ''});
  final String initialText;

  @override
  State<QuickAddPanel> createState() => _QuickAddPanelState();
}

class _QuickAddPanelState extends State<QuickAddPanel> {
  late final _HighlightController _c = _HighlightController(text: widget.initialText);
  final Set<String> _ignore = {};
  late QuickAddResult _result = parseQuickAdd(widget.initialText);

  @override
  void initState() {
    super.initState();
    _c.addListener(_reparse);
    _c.matches = _result.matches;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _reparse() {
    final r = parseQuickAdd(_c.text, ignore: _ignore);
    _c.matches = r.matches;
    setState(() => _result = r);
  }

  Task _buildTask() {
    final r = _result;
    return Task.blank().copyWith(
      title: r.title,
      dueDate: r.dueDate,
      tags: r.tags,
      priority: r.priority,
    );
  }

  void _add() {
    if (_result.title.isEmpty) return;
    final task = _buildTask();
    AppScope.read(context).save(task);
    Navigator.of(context).pop(task);
  }

  Future<void> _details() async {
    final nav = Navigator.of(context);
    final task = _buildTask();
    nav.pop();
    // Opened from the root so it survives this sheet closing.
    await showTaskEditor(nav.context, task);
  }

  void _drop(QuickAddMatch m) {
    _ignore.add(m.text);
    _reparse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    _c.scheme = scheme;
    final r = _result;

    Widget chip(QuickAddMatch? m, IconData icon, String label, Color color) => InputChip(
          avatar: Icon(icon, size: 16, color: color),
          label: Text(label),
          labelStyle: theme.textTheme.labelMedium?.copyWith(color: color),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          backgroundColor: color.withValues(alpha: 0.08),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          deleteButtonTooltipMessage: 'Keep as text',
          onDeleted: m == null ? null : () => _drop(m),
        );

    QuickAddMatch? lastOf(QuickAddKind k) {
      final list = r.matches.where((m) => m.kind == k).toList();
      return list.isEmpty ? null : list.last;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _add,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _add,
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): _details,
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _c,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'e.g. Rotate SQL creds fri #work !high',
                prefixIcon: Icon(Icons.add_task_rounded, color: scheme.primary),
                suffixIcon: IconButton(
                  tooltip: 'Add (Enter)',
                  onPressed: r.title.isEmpty ? null : _add,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: r.title.isEmpty ? null : scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.topLeft,
              child: r.hasExtras
                  ? Wrap(spacing: 8, runSpacing: 8, children: [
                      if (r.dueDate != null)
                        chip(lastOf(QuickAddKind.date), Icons.event_rounded,
                            formatDue(r.dueDate!), scheme.warning),
                      if (r.priority != Priority.none)
                        chip(lastOf(QuickAddKind.priority), Icons.flag_rounded,
                            r.priority.label, scheme.priorityColor(r.priority)),
                      for (final m in r.matches.where((m) => m.kind == QuickAddKind.tag))
                        chip(m, Icons.tag_rounded, m.text.substring(1), scheme.primary),
                    ])
                  : Text(
                      'Type a date (fri, tomorrow, oct 21, in 3 days), #tag or !high/!med/!low.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
                    ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              TextButton.icon(
                onPressed: _details,
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: const Text('Add steps & details'),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 700)
                Text('Enter to add · Shift+Enter for details',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.muted)),
            ]),
          ],
        ),
      ),
    );
  }
}
