import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/user_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showSettings(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: const SettingsScreen(),
        ),
      ),
    );
  }
  return Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
}

String formatHour(int h) {
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:00 $suffix';
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = app.settings;
    final user = app.user;

    final zones = <String>{
      if (s.timezone.isNotEmpty) s.timezone,
      if (app.detectedTimezone != null) app.detectedTimezone!,
      ...commonTimezones,
    }.toList();

    void update(UserSettings next) => app.saveSettings(next);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionLabel('Daily email'),
          Card(
            child: Column(children: [
              SwitchListTile(
                value: s.dailyEmail,
                onChanged: (v) => update(s.copyWith(
                  dailyEmail: v,
                  timezone: s.timezone.isEmpty ? (app.detectedTimezone ?? 'UTC') : null,
                )),
                secondary: Icon(Icons.mark_email_unread_outlined, color: scheme.primary),
                title: const Text('Morning summary'),
                subtitle: Text(
                  'Every day at ${formatHour(s.emailHour)}: high priority, overdue, '
                  'due today and in-progress tasks${user != null ? ', sent to ${user.email}' : ''}.',
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                enabled: s.dailyEmail,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Send at'),
                trailing: DropdownButton<int>(
                  value: s.emailHour,
                  underline: const SizedBox.shrink(),
                  onChanged: s.dailyEmail
                      ? (h) => update(s.copyWith(emailHour: h))
                      : null,
                  items: [
                    for (var h = 0; h < 24; h++)
                      DropdownMenuItem(value: h, child: Text(formatHour(h))),
                  ],
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                enabled: s.dailyEmail,
                leading: const Icon(Icons.public_rounded),
                title: const Text('Time zone'),
                subtitle: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: s.timezone.isEmpty
                          ? 'Not set'
                          : s.timezone.replaceAll('_', ' ')),
                  if (app.detectedTimezone != null &&
                      s.timezone.isNotEmpty &&
                      app.detectedTimezone != s.timezone)
                    TextSpan(
                      text: '\nThis device is in ${app.detectedTimezone!.replaceAll('_', ' ')}',
                      style: TextStyle(color: scheme.warning),
                    ),
                ])),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final tz = await _pickTimezone(context, zones, s.timezone);
                  if (tz != null) update(s.copyWith(timezone: tz));
                },
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              "No email is sent on a day when you have nothing open. "
              "It can arrive up to about 20 minutes after the hour.",
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System')),
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark')),
                ],
                selected: {app.themeMode},
                onSelectionChanged: (v) => app.setThemeMode(v.first),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _pickTimezone(BuildContext context, List<String> zones, String current) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TimezonePicker(zones: zones, current: current),
  );
}

class _TimezonePicker extends StatefulWidget {
  const _TimezonePicker({required this.zones, required this.current});
  final List<String> zones;
  final String current;

  @override
  State<_TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends State<_TimezonePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _q.toLowerCase().replaceAll(' ', '_');
    final list = widget.zones.where((z) => z.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Search city or region',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final z = list[i];
              final selected = z == widget.current;
              return ListTile(
                title: Text(z.split('/').last.replaceAll('_', ' ')),
                subtitle: Text(z.replaceAll('_', ' '),
                    style: TextStyle(color: scheme.muted)),
                trailing: selected ? Icon(Icons.check_rounded, color: scheme.primary) : null,
                selected: selected,
                onTap: () => Navigator.pop(context, z),
              );
            },
          ),
        ),
      ]),
    );
  }
}
