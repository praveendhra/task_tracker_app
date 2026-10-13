import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../config.dart';
import '../models/task.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/quick_add_sheet.dart';
import 'archive_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'task_detail_screen.dart';
import 'task_editor.dart';

const _wideBreakpoint = 900.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TaskFilter _filter = TaskFilter.active;
  String? _tag;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    final screen = demoParams['screen'];
    if (screen != null) {
      Future<void>.delayed(
          const Duration(milliseconds: 600), () => _openDemoScreen(screen));
    }
  }

  void _openDemoScreen(String screen) {
    if (!mounted) return;
    final app = AppScope.read(context);
    final task = app.taskById(demoParams['task'] ?? 'migrate');
    switch (screen) {
      case 'detail' when task != null:
        _open(task);
      case 'editor' when task != null:
        showTaskEditor(context, task);
      case 'new':
        _newTask();
      case 'quick':
        showQuickAdd(context, initialText: demoParams['q'] ?? '');
      case 'shortcuts':
        showShortcutsHelp(context);
      case 'settings':
        showSettings(context);
      case 'archive':
        _openArchive();
      case 'search':
        _openSearch();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final imported = app.lastImportCount;
    if (imported != null) {
      app.clearImportNotice();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Moved $imported task${imported == 1 ? '' : 's'} over from the old app.'),
        ));
      });
    }
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  /// Quick add: one line with dates, #tags, !priority.
  Future<void> _quickAdd() async {
    final created = await showQuickAdd(context);
    if (created != null && mounted) _afterCreate(created);
  }

  /// The default: full editor with steps, notes, everything.
  Future<void> _newTask() async {
    final created = await showTaskEditor(context, Task.blank());
    if (created != null && mounted) _afterCreate(created);
  }

  void _afterCreate(Task t) {
    if (_wide) {
      setState(() => _selectedId = t.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added "${t.title}"'),
        action: SnackBarAction(label: 'Open', onPressed: () => _open(t)),
      ));
    }
  }

  // ---- keyboard ------------------------------------------------------------

  final Map<String, GlobalKey> _itemKeys = {};
  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  List<Task> get _visible =>
      AppScope.read(context).filtered(_filter, tag: _tag);

  Task? get _selected {
    final id = _selectedId;
    return id == null ? null : AppScope.read(context).taskById(id);
  }

  void _moveSelection(int delta) {
    final list = _visible;
    if (list.isEmpty) return;
    final i = list.indexWhere((t) => t.id == _selectedId);
    final next = i < 0
        ? (delta > 0 ? 0 : list.length - 1)
        : (i + delta).clamp(0, list.length - 1);
    final id = list[next].id;
    setState(() => _selectedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _itemKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignmentPolicy: delta > 0
                ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
            duration: const Duration(milliseconds: 120));
      }
    });
  }

  void _setFilter(TaskFilter f) => setState(() {
        _filter = f;
        _tag = null;
      });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Never steal keys from a text field (e.g. "Add a step" in the detail pane).
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return KeyEventResult.ignored;
    }
    // Only act when this screen is on top (no dialog, sheet or pushed page).
    if (ModalRoute.of(context)?.isCurrent != true) return KeyEventResult.ignored;

    final keys = HardwareKeyboard.instance;
    final mod = keys.isControlPressed || keys.isMetaPressed;
    final key = event.logicalKey;
    final app = AppScope.read(context);
    final sel = _selected;

    if (mod && key == LogicalKeyboardKey.keyK) {
      _openSearch();
      return KeyEventResult.handled;
    }
    if (mod || keys.isAltPressed) return KeyEventResult.ignored;

    final digit = key.keyId - LogicalKeyboardKey.digit1.keyId;

    if (event.character == '?') {
      showShortcutsHelp(context);
    } else if (key == LogicalKeyboardKey.keyN) {
      _newTask();
    } else if (key == LogicalKeyboardKey.keyQ) {
      _quickAdd();
    } else if (key == LogicalKeyboardKey.slash) {
      _openSearch();
    } else if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
    } else if (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
    } else if (key == LogicalKeyboardKey.escape) {
      if (_selectedId == null) return KeyEventResult.ignored;
      setState(() => _selectedId = null);
    } else if (digit >= 0 && digit < TaskFilter.values.length) {
      _setFilter(TaskFilter.values[digit]);
    } else if (sel == null) {
      return KeyEventResult.ignored;
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.keyO) {
      if (!_wide) _open(sel);
    } else if (key == LogicalKeyboardKey.keyX || key == LogicalKeyboardKey.space) {
      _toggleDone(sel);
    } else if (key == LogicalKeyboardKey.keyE) {
      showTaskEditor(context, sel);
    } else if (key == LogicalKeyboardKey.keyA) {
      _archive(sel);
    } else if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      confirmDelete(context, sel).then((ok) {
        if (ok) {
          setState(() => _selectedId = null);
          app.delete(sel.id);
        }
      });
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---- actions shared by swipe and keyboard ---------------------------------

  void _toggleDone(Task t) {
    final app = AppScope.read(context);
    final before = t;
    app.cycleStatus(t);
    final nowDone = !before.isDone;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(nowDone ? 'Marked done' : 'Reopened'),
        action: SnackBarAction(label: 'Undo', onPressed: () => app.save(before)),
      ));
  }

  void _archive(Task t) {
    final app = AppScope.read(context);
    app.setArchived(t, true);
    if (_selectedId == t.id) setState(() => _selectedId = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Archived'),
        action: SnackBarAction(label: 'Undo', onPressed: () => app.setArchived(t, false)),
      ));
  }

  void _open(Task t) {
    if (_wide) {
      setState(() => _selectedId = t.id);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: t.id)));
    }
  }

  void _openSearch() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SearchScreen(onOpen: (t) {
            Navigator.of(context).pop();
            _open(t);
          })));

  void _openArchive() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ArchiveScreen()));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tasks = app.filtered(_filter, tag: _tag);

    final list = _TaskList(
      tasks: tasks,
      loaded: app.tasksLoaded,
      filter: _filter,
      tag: _tag,
      selectedId: _selectedId,
      onOpen: (t) {
        if (!_wide) setState(() => _selectedId = null);
        _open(t);
      },
      onNew: _newTask,
      onToggleDone: _toggleDone,
      onArchiveTask: _archive,
      keyFor: _keyFor,
      onFilter: (f) => setState(() => _filter = f),
      onTag: (t) => setState(() => _tag = t),
      onSearch: _openSearch,
      onArchive: _openArchive,
      showHeader: !_wide,
    );

    if (!_wide) {
      return Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: SafeArea(bottom: false, child: list),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'quick-add',
                tooltip: 'Quick add: type one line',
                onPressed: _quickAdd,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                child: const Icon(Icons.text_fields_rounded),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'new-task',
                tooltip: 'New task with steps',
                onPressed: _newTask,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New task'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _selectedId == null ? null : app.taskById(_selectedId!);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
      body: SafeArea(
        child: Row(children: [
          SizedBox(
            width: 260,
            child: _Sidebar(
              filter: _filter,
              tag: _tag,
              onFilter: (f) => setState(() {
                _filter = f;
                _tag = null;
              }),
              onTag: (t) => setState(() => _tag = t),
              onNew: _newTask,
              onQuickAdd: _quickAdd,
              onSearch: _openSearch,
              onArchive: _openArchive,
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(width: 460, child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? const EmptyState(
                    icon: Icons.touch_app_outlined,
                    title: 'Pick a task',
                    message: 'Select a task to see its steps, notes and progress here.',
                  )
                : TaskDetailView(
                    key: ValueKey(selected.id),
                    taskId: selected.id,
                    embedded: true,
                    onDeleted: () => setState(() => _selectedId = null),
                  ),
          ),
        ]),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.loaded,
    required this.filter,
    required this.tag,
    required this.selectedId,
    required this.onOpen,
    required this.onNew,
    required this.onToggleDone,
    required this.onArchiveTask,
    required this.keyFor,
    required this.onFilter,
    required this.onTag,
    required this.onSearch,
    required this.onArchive,
    required this.showHeader,
  });

  final List<Task> tasks;
  final bool loaded;
  final TaskFilter filter;
  final String? tag;
  final String? selectedId;
  final ValueChanged<Task> onOpen;
  final VoidCallback onNew;
  final ValueChanged<Task> onToggleDone;
  final ValueChanged<Task> onArchiveTask;
  final GlobalKey Function(String id) keyFor;
  final ValueChanged<TaskFilter> onFilter;
  final ValueChanged<String?> onTag;
  final VoidCallback onSearch;
  final VoidCallback onArchive;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const pad = EdgeInsets.symmetric(horizontal: 20);

    return CustomScrollView(slivers: [
      if (showHeader) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          sliver: SliverToBoxAdapter(child: _Greeting(onArchive: onArchive)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(child: _StatsRow(onFilter: onFilter)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(child: _SearchField(onTap: onSearch)),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 14),
          sliver: SliverToBoxAdapter(
            child: _FilterChips(
                filter: filter, tag: tag, onFilter: onFilter, onTag: onTag),
          ),
        ),
      ] else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 12, 4),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(
                child: Text(tag != null ? '#$tag' : _filterTitle(filter),
                    style: theme.textTheme.headlineSmall),
              ),
              const _SortMenu(),
            ]),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
        sliver: SliverToBoxAdapter(
          child: Row(children: [
            Text(
              '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.muted),
            ),
            const Spacer(),
            if (showHeader) const _SortMenu(),
          ]),
        ),
      ),
      if (!loaded)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (app.syncError != null && tasks.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load your tasks",
            message: '${app.syncError}',
          ),
        )
      else if (tasks.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyFor(filter, onNew),
        )
      else
        SliverPadding(
          padding: pad.copyWith(bottom: 120),
          sliver: SliverList.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = tasks[i];
              return _SwipeableTask(
                key: ValueKey(t.id),
                task: t,
                onDone: () => onToggleDone(t),
                onArchive: () => onArchiveTask(t),
                child: TaskCard(
                  key: keyFor(t.id),
                  task: t,
                  selected: t.id == selectedId,
                  onTap: () => onOpen(t),
                  onToggle: () => onToggleDone(t),
                ),
              );
            },
          ),
        ),
    ]);
  }

  static Widget _emptyFor(TaskFilter f, VoidCallback onNew) => switch (f) {
        TaskFilter.done => const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Nothing finished yet',
            message: 'Completed tasks show up here.',
          ),
        TaskFilter.today => const EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'Nothing due today',
            message: 'Enjoy it, or pull something forward.',
          ),
        TaskFilter.upcoming => const EmptyState(
            icon: Icons.event_outlined,
            title: 'No upcoming deadlines',
            message: 'Tasks with a future due date land here.',
          ),
        _ => EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'All clear',
            message: 'Create a task and break it into steps to get going.',
            action: FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New task'),
            ),
          ),
      };
}

String _filterTitle(TaskFilter f) => switch (f) {
      TaskFilter.active => 'Active',
      TaskFilter.today => 'Due today',
      TaskFilter.upcoming => 'Upcoming',
      TaskFilter.done => 'Done',
      TaskFilter.all => 'All tasks',
    };

IconData _filterIcon(TaskFilter f) => switch (f) {
      TaskFilter.active => Icons.inbox_rounded,
      TaskFilter.today => Icons.wb_sunny_outlined,
      TaskFilter.upcoming => Icons.event_outlined,
      TaskFilter.done => Icons.task_alt_rounded,
      TaskFilter.all => Icons.list_alt_rounded,
    };

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onArchive});
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final h = DateTime.now().hour;
    final hello = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$hello,',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.muted, fontWeight: FontWeight.w500)),
          Text(app.user?.firstName ?? '',
              style: theme.textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
      AccountButton(onArchive: onArchive),
    ]);
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.onFilter});
  final ValueChanged<TaskFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final live = app.liveTasks;
    final overdue = live.where((t) => t.isOverdue || t.hasOverdueStep).length;
    final inProgress = live.where((t) => t.status == TaskStatus.inProgress).length;
    return Row(children: [
      Expanded(
        child: _StatTile(
          value: '${app.count(TaskFilter.today)}',
          label: overdue > 0 ? '$overdue overdue' : 'Due today',
          icon: Icons.wb_sunny_outlined,
          color: overdue > 0 ? scheme.danger : scheme.warning,
          onTap: () => onFilter(TaskFilter.today),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          value: '$inProgress',
          label: 'In progress',
          icon: Icons.timelapse_rounded,
          color: scheme.info,
          onTap: () => onFilter(TaskFilter.active),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          value: '${app.completedThisWeek}',
          label: 'Done in 7 days',
          icon: Icons.task_alt_rounded,
          color: scheme.success,
          onTap: () => onFilter(TaskFilter.done),
        ),
      ),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(height: 1)),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.muted)),
          ]),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.subtle,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Icon(Icons.search_rounded, color: scheme.muted, size: 20),
            const SizedBox(width: 10),
            Text('Search tasks, steps, notes…',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.muted)),
          ]),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.tag,
    required this.onFilter,
    required this.onTag,
  });

  final TaskFilter filter;
  final String? tag;
  final ValueChanged<TaskFilter> onFilter;
  final ValueChanged<String?> onTag;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tags = app.allTags;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final f in TaskFilter.values) ...[
            ChoiceChip(
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_filterTitle(f)),
                const SizedBox(width: 6),
                Text('${app.count(f)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: filter == f
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.muted)),
              ]),
              selected: filter == f,
              showCheckmark: false,
              onSelected: (_) => onFilter(f),
            ),
            const SizedBox(width: 8),
          ],
          if (tags.isNotEmpty) const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          for (final t in tags) ...[
            FilterChip(
              label: Text('#$t'),
              selected: tag == t,
              showCheckmark: false,
              onSelected: (on) => onTag(on ? t : null),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    String label(TaskSort s) => switch (s) {
          TaskSort.smart => 'Smart',
          TaskSort.dueDate => 'Due date',
          TaskSort.priority => 'Priority',
          TaskSort.recent => 'Recently updated',
        };
    return PopupMenuButton<TaskSort>(
      tooltip: 'Sort',
      initialValue: app.sort,
      onSelected: app.setSort,
      itemBuilder: (_) => [
        for (final s in TaskSort.values)
          CheckedPopupMenuItem(value: s, checked: app.sort == s, child: Text(label(s))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_vert_rounded, size: 18, color: Theme.of(context).colorScheme.muted),
          const SizedBox(width: 4),
          Text(label(app.sort), style: Theme.of(context).textTheme.labelMedium),
        ]),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.filter,
    required this.tag,
    required this.onFilter,
    required this.onTag,
    required this.onNew,
    required this.onQuickAdd,
    required this.onSearch,
    required this.onArchive,
  });

  final TaskFilter filter;
  final String? tag;
  final ValueChanged<TaskFilter> onFilter;
  final ValueChanged<String?> onTag;
  final VoidCallback onNew;
  final VoidCallback onQuickAdd;
  final VoidCallback onSearch;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget item(IconData icon, String label, bool selected, VoidCallback onTap,
            {String? trailing, Color? iconColor}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Material(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Icon(icon,
                      size: 19,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : (iconColor ?? scheme.muted)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? scheme.onPrimaryContainer : null)),
                  ),
                  if (trailing != null)
                    Text(trailing,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: selected ? scheme.onPrimaryContainer : scheme.muted)),
                ]),
              ),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 0, 22),
          child: Row(children: [
            const AppLogo(size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text('Task Tracker', style: theme.textTheme.titleMedium)),
            AccountButton(onArchive: onArchive, compact: true),
          ]),
        ),
        Row(children: [
          Expanded(
            child: Tooltip(
              message: 'New task with steps (N)',
              child: FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New task'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Quick add: type one line (Q)',
            onPressed: onQuickAdd,
            icon: const Icon(Icons.text_fields_rounded),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded, size: 20),
          label: const Text('Search'),
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
        ),
        const SizedBox(height: 24),
        const SectionLabel('Views'),
        for (final f in TaskFilter.values)
          item(_filterIcon(f), _filterTitle(f), filter == f && tag == null,
              () => onFilter(f),
              trailing: '${app.count(f)}'),
        if (app.allTags.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Tags'),
          for (final t in app.allTags)
            item(Icons.tag_rounded, t, tag == t, () => onTag(tag == t ? null : t),
                trailing: '${app.liveTasks.where((x) => x.tags.contains(t)).length}'),
        ],
        const SizedBox(height: 20),
        item(Icons.inventory_2_outlined, 'Archive', false, onArchive,
            trailing: '${app.archivedTasks.length}'),
        const SizedBox(height: 24),
        _WeekCard(),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => showShortcutsHelp(context),
            icon: const Icon(Icons.keyboard_outlined, size: 18),
            label: const Text('Keyboard shortcuts  ?'),
            style: TextButton.styleFrom(foregroundColor: scheme.muted),
          ),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = app.count(TaskFilter.active);
    final done = app.completedThisWeek;
    final total = active + done;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This week', style: theme.textTheme.labelMedium?.copyWith(color: scheme.muted)),
          const SizedBox(height: 6),
          Text('$done done · $active open', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          ProgressBar(value: total == 0 ? 0 : done / total),
        ]),
      ),
    );
  }
}

/// Avatar with the account menu: theme, archive, sign out.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.onArchive, this.compact = false});
  final VoidCallback onArchive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final user = app.user;
    final initial = (user?.firstName.isNotEmpty ?? false)
        ? user!.firstName[0].toUpperCase()
        : '?';
    return MenuAnchor(
      alignmentOffset: const Offset(-180, 4),
      menuChildren: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.displayName ?? user.firstName,
                  style: Theme.of(context).textTheme.titleSmall),
              Text(user.email,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.muted)),
            ]),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => _rename(context),
          child: const Text('Change name'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.inventory_2_outlined),
          onPressed: onArchive,
          child: const Text('Archive'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.settings_outlined),
          onPressed: () => showSettings(context),
          child: const Text('Settings & daily email'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.keyboard_outlined),
          onPressed: () => showShortcutsHelp(context),
          child: const Text('Keyboard shortcuts'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.palette_outlined),
          menuChildren: [
            for (final m in ThemeMode.values)
              MenuItemButton(
                leadingIcon: Icon(app.themeMode == m
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                onPressed: () => app.setThemeMode(m),
                child: Text(switch (m) {
                  ThemeMode.system => 'Match system',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                }),
              ),
          ],
          child: const Text('Theme'),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout_rounded),
          onPressed: app.auth.signOut,
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        tooltip: 'Account',
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: CircleAvatar(
          radius: compact ? 15 : 20,
          backgroundColor: scheme.primaryContainer,
          child: Text(initial,
              style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 13 : 16)),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final app = AppScope.read(context);
    final c = TextEditingController(text: app.user?.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await app.auth.updateDisplayName(name);
    }
  }
}

/// Swipe right to complete (or reopen), swipe left to archive.
/// The card snaps back for "done" so it can stay in views that show done tasks;
/// archive lets it slide away.
class _SwipeableTask extends StatelessWidget {
  const _SwipeableTask({
    super.key,
    required this.task,
    required this.onDone,
    required this.onArchive,
    required this.child,
  });

  final Task task;
  final VoidCallback onDone;
  final VoidCallback onArchive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    Widget bg(Alignment align, Color color, IconData icon, String label) => Container(
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.white)),
            ],
          ),
        );

    return Dismissible(
      key: ValueKey('swipe-${task.id}'),
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: bg(
        Alignment.centerLeft,
        task.isDone ? scheme.info : scheme.success,
        task.isDone ? Icons.replay_rounded : Icons.check_rounded,
        task.isDone ? 'Reopen' : 'Done',
      ),
      secondaryBackground: bg(
        Alignment.centerRight,
        scheme.onSurfaceVariant,
        Icons.inventory_2_outlined,
        'Archive',
      ),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        if (dir == DismissDirection.startToEnd) {
          onDone();
          return false; // snap back; the list updates itself
        }
        return true;
      },
      onDismissed: (_) => onArchive(),
      child: child,
    );
  }
}

const _shortcuts = <(String, String)>[
  ('N', 'New task (with steps)'),
  ('Q', 'Quick add (one line)'),
  ('/  or  Ctrl/⌘ + K', 'Search'),
  ('J / K  or  ↓ / ↑', 'Move through tasks'),
  ('Enter', 'Open selected task'),
  ('X  or  Space', 'Mark selected done / reopen'),
  ('E', 'Edit selected'),
  ('A', 'Archive selected'),
  ('Delete', 'Delete selected'),
  ('1 – 5', 'Active · Today · Upcoming · Done · All'),
  ('Esc', 'Clear selection'),
  ('Ctrl/⌘ + Enter', 'Save in the editor'),
  ('?', 'Show this list'),
];

Future<void> showShortcutsHelp(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (keys, action) in _shortcuts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(action, style: theme.textTheme.bodyMedium)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.subtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerTheme.color!),
                    ),
                    child: Text(keys,
                        style: theme.textTheme.labelMedium),
                  ),
                ]),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}
