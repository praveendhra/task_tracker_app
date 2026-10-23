import 'task.dart';
import 'user_settings.dart';

/// A reminder the phone should show at [when].
class PlannedReminder {
  const PlannedReminder(this.when, this.title, this.body);
  final DateTime when;
  final String title;
  final String body;

  @override
  String toString() => '$when $title — $body';
}

/// The reminder slots from now on (local wall-clock hours from
/// `pushFrom` to `pushTo` inclusive, every `pushEvery` hours), each with text
/// worked out from [tasks] as they'll stand that day. iOS keeps at most 64
/// pending notifications, so [max] stays below that; the app re-plans whenever
/// tasks change or it's opened.
List<PlannedReminder> planReminders(
  List<Task> tasks,
  UserSettings s,
  DateTime now, {
  int max = 60,
  int days = 7,
}) {
  if (!s.pushReminders) return const [];
  final span = (s.pushTo - s.pushFrom + 24) % 24;
  final out = <PlannedReminder>[];
  var t = DateTime(now.year, now.month, now.day, now.hour + 1);
  final end = now.add(Duration(days: days));
  while (out.length < max && t.isBefore(end)) {
    final offset = (t.hour - s.pushFrom + 24) % 24;
    if (offset <= span && offset % s.pushEvery == 0) {
      final text = reminderText(tasks, DateTime(t.year, t.month, t.day));
      if (text != null) out.add(PlannedReminder(t, text.$1, text.$2));
    }
    t = DateTime(t.year, t.month, t.day, t.hour + 1); // wall clock, DST-safe
  }
  return out;
}

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// (title, body) for a reminder on [day], or null when nothing is open.
/// e.g. ("1 due today · 2 high priority", "Next: Draft slides (Quarterly report) · 4 tasks open").
(String, String)? reminderText(List<Task> tasks, DateTime day) {
  final open = tasks.where((t) => !t.archived && !t.isDone).toList();
  if (open.isEmpty) return null;
  day = _d(day);

  bool overdue(Task t) => t.dueDate != null && _d(t.dueDate!).isBefore(day);
  bool dueToday(Task t) => t.dueDate != null && _d(t.dueDate!) == day;
  final overdueN = open.where(overdue).length;
  final todayN = open.where(dueToday).length;
  final highN = open.where((t) => t.priority == Priority.high).length;

  final bits = [
    if (overdueN > 0) '$overdueN overdue',
    if (todayN > 0) '$todayN due today',
    if (highN > 0) '$highN high priority',
  ];
  final title = bits.isEmpty ? '${_plural(open.length, 'task')} open' : bits.join(' · ');

  // Steps due by this day come first; otherwise the most pressing task.
  final stepsDue = [
    for (final t in open)
      for (final st in t.steps)
        if (!st.isDone && st.dueDate != null && !_d(st.dueDate!).isAfter(day)) (st, t),
  ]..sort((a, b) {
      final c = a.$1.dueDate!.compareTo(b.$1.dueDate!);
      return c != 0 ? c : b.$2.priority.code.compareTo(a.$2.priority.code);
    });

  int rank(Task t) {
    if (t.priority == Priority.high) return 0;
    if (overdue(t)) return 1;
    if (dueToday(t)) return 2;
    if (t.status == TaskStatus.inProgress) return 3;
    if (t.dueDate != null && _d(t.dueDate!).difference(day).inDays <= 7) return 4;
    return 5;
  }

  final sorted = [...open]..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final p = b.priority.code.compareTo(a.priority.code);
      if (p != 0) return p;
      return (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999));
    });

  String body;
  if (stepsDue.isNotEmpty) {
    body = 'Next: ${stepsDue.first.$1.title.trim()} (${stepsDue.first.$2.title.trim()})';
  } else {
    final next = sorted.first;
    final step = next.currentStep;
    body = step != null && !step.isDone
        ? 'Next: ${step.title.trim()} (${next.title.trim()})'
        : 'Next: ${next.title.trim()}';
  }
  if (bits.isNotEmpty && open.length > 1) body += ' · ${_plural(open.length, 'task')} open';
  if (body.length > 180) body = '${body.substring(0, 177)}…';
  return (title, body);
}
