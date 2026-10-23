import 'user_settings.dart';

/// A daily reminder at [hour]:00 local time.
class DailyReminder {
  const DailyReminder(this.hour, this.title, this.body);
  final int hour;
  final String title;
  final String body;

  @override
  String toString() => '$hour:00 $title — $body';
}

const _nudges = [
  "Take a minute to see what's next.",
  'A quick look keeps things moving.',
  "What's the next step?",
  'Tick something off.',
];

/// The hours (local, 0-23) reminders repeat at every day: from `pushFrom` to
/// `pushTo` inclusive, every `pushEvery` hours. A window may wrap midnight.
List<int> reminderHours(UserSettings s) {
  if (!s.pushReminders) return const [];
  final span = (s.pushTo - s.pushFrom + 24) % 24;
  return [
    for (var o = 0; o <= span; o += s.pushEvery) (s.pushFrom + o) % 24,
  ];
}

/// A simple nudge to open the app; no task details, so it's never out of date.
List<DailyReminder> dailyReminders(UserSettings s) => [
      for (final (i, h) in reminderHours(s).indexed)
        DailyReminder(h, 'Time to check your tasks', _nudges[i % _nudges.length]),
    ];
