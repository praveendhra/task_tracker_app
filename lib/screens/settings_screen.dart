import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../data/repository.dart';
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
              "It usually arrives within a few minutes of the hour.",
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
            ),
          ),
          const SizedBox(height: 28),
          if (app.push.supported) ...[
            const SectionLabel('Reminders'),
            const _PushRemindersCard(),
            const SizedBox(height: 28),
          ],
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
          const SizedBox(height: 28),
          const SectionLabel('Account'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Signed in'),
                subtitle: Text(user?.email ?? ''),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                subtitle: const Text('task.praveendhra.com/privacy.html'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(Uri.parse('https://task.praveendhra.com/privacy.html'),
                    mode: LaunchMode.externalApplication),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: scheme.danger),
                title: Text('Delete account', style: TextStyle(color: scheme.danger)),
                subtitle: const Text('Permanently remove your account and all tasks'),
                onTap: () => confirmDeleteAccount(context),
              ),
            ]),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

Future<void> confirmDeleteAccount(BuildContext context) async {
  final app = AppScope.read(context);
  final scheme = Theme.of(context).colorScheme;
  final needsPassword = app.auth.primaryProvider == 'password';
  final password = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account, every task and step, '
            'and your settings. It cannot be undone.',
          ),
          const SizedBox(height: 16),
          if (needsPassword)
            TextField(
              controller: password,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password to confirm'),
            )
          else
            const Text("You'll be asked to sign in again to confirm it's you."),
        ],
      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete forever'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await app.deleteAccount(password: needsPassword ? password.text : null);
    nav.popUntil((r) => r.isFirst);
    messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
  } on AuthFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not delete the account: $e')));
  }
}

/// Push reminder settings: on/off, how often, and the hours they may arrive.
class _PushRemindersCard extends StatefulWidget {
  const _PushRemindersCard();

  @override
  State<_PushRemindersCard> createState() => _PushRemindersCardState();
}

class _PushRemindersCardState extends State<_PushRemindersCard> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (on) {
        final error = await app.enablePushReminders();
        if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
      } else {
        await app.disablePushReminders();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not update reminders: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = app.settings;
    final supported = app.push.supported;
    final on = s.pushReminders;
    void update(UserSettings next) => app.saveSettings(next);

    String every(int n) => n == 1 ? 'Every hour' : 'Every $n hours';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Column(children: [
          SwitchListTile(
            value: on && supported,
            onChanged: supported && !_busy ? _toggle : null,
            secondary: _busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.notifications_active_outlined, color: scheme.primary),
            title: const Text('Push reminders'),
            subtitle: Text(supported
                ? '${every(s.pushEvery)} from ${formatHour(s.pushFrom)} to ${formatHour(s.pushTo)}: '
                    "what's due and the next step. Tap one to open your tasks."
                : 'Not available on this device or browser yet.'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            enabled: on && supported,
            leading: const Icon(Icons.repeat_rounded),
            title: const Text('How often'),
            trailing: DropdownButton<int>(
              value: s.pushEvery,
              underline: const SizedBox.shrink(),
              onChanged: on && supported ? (v) => update(s.copyWith(pushEvery: v)) : null,
              items: [
                for (final n in const [1, 2, 3, 4, 6])
                  DropdownMenuItem(value: n, child: Text(every(n))),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            enabled: on && supported,
            leading: const Icon(Icons.wb_twilight_rounded),
            title: const Text('From'),
            trailing: DropdownButton<int>(
              value: s.pushFrom,
              underline: const SizedBox.shrink(),
              onChanged: on && supported ? (v) => update(s.copyWith(pushFrom: v)) : null,
              items: [
                for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(formatHour(h))),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            enabled: on && supported,
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Until'),
            trailing: DropdownButton<int>(
              value: s.pushTo,
              underline: const SizedBox.shrink(),
              onChanged: on && supported ? (v) => update(s.copyWith(pushTo: v)) : null,
              items: [
                for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(formatHour(h))),
              ],
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: Text(
          'Uses the time zone above. Nothing is sent when you have no open tasks, '
          'and each reminder replaces the last one.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
        ),
      ),
    ]);
  }
}
