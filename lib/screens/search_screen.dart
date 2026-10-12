import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/task.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onOpen});
  final ValueChanged<Task> onOpen;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final results = app.search(_q.text);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search tasks, steps, notes, #tags',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_q.clear),
                    ),
            ),
          ),
        ),
      ),
      body: _q.text.trim().isEmpty
          ? const EmptyState(
              icon: Icons.manage_search_rounded,
              title: 'Find anything',
              message: 'Search covers titles, descriptions, every step and its notes, and tags — archived tasks included.',
            )
          : results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Nothing matches "${_q.text.trim()}".',
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      itemCount: results.length + 1,
                      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 4 : 10),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Text(
                            '${results.length} result${results.length == 1 ? '' : 's'}',
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.muted),
                          );
                        }
                        final t = results[i - 1];
                        return Stack(children: [
                          TaskCard(
                            task: t,
                            onTap: () => widget.onOpen(t),
                            onToggle: () => app.cycleStatus(t),
                          ),
                          if (t.archived)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: Pill(
                                label: 'Archived',
                                color: scheme.muted,
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                        ]);
                      },
                    ),
                  ),
                ),
    );
  }
}
