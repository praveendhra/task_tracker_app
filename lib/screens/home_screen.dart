import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../config.dart';
import '../models/task.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'archive_screen.dart';
import 'search_screen.dart';
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

  Future<void> _newTask() async {
    final created = await showTaskEditor(context, Task.blank());
    if (created != null && _wide) setState(() => _selectedId = created.id);
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
      selectedId: _wide ? _selectedId : null,
      onOpen: _open,
      onNew: _newTask,
      onFilter: (f) => setState(() => _filter = f),
      onTag: (t) => setState(() => _tag = t),
      onSearch: _openSearch,
      onArchive: _openArchive,
      showHeader: !_wide,
    );

    if (!_wide) {
      return Scaffold(
        body: SafeArea(bottom: false, child: list),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newTask,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New task'),
        ),
      );
    }

    final selected = _selectedId == null ? null : app.taskById(_selectedId!);
    return Scaffold(
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
              return TaskCard(
                key: ValueKey(t.id),
                task: t,
                selected: t.id == selectedId,
                onTap: () => onOpen(t),
                onToggle: () => app.cycleStatus(t),
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
    final overdue = live.where((t) => t.isOverdue).length;
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
          label: 'Done this week',
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
              label: Text('${_filterTitle(f)}  ${app.count(f)}'),
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
    required this.onSearch,
    required this.onArchive,
  });

  final TaskFilter filter;
  final String? tag;
  final ValueChanged<TaskFilter> onFilter;
  final ValueChanged<String?> onTag;
  final VoidCallback onNew;
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
        FilledButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New task'),
        ),
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
