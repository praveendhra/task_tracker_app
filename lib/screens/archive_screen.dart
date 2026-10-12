import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'task_detail_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tasks = app.archivedTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: tasks.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Archive is empty',
              message: 'Archive finished or parked tasks to keep your list focused. They stay searchable.',
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = tasks[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        title: Text(t.title.isEmpty ? 'Untitled task' : t.title,
                            style: theme.textTheme.titleSmall),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${t.status.label} · archived ${formatAgo(t.updatedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
                          ),
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TaskDetailScreen(taskId: t.id))),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Restore',
                            icon: const Icon(Icons.unarchive_outlined),
                            onPressed: () {
                              app.setArchived(t, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Task restored')));
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline_rounded, color: scheme.danger),
                            onPressed: () async {
                              if (await confirmDelete(context, t)) {
                                await app.delete(t.id);
                              }
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
