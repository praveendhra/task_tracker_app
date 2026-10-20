import 'task.dart';

/// What quick add understood from a line like
/// `Call the plumber fri #home !high`.
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.dueDate,
    this.tags = const [],
    this.priority = Priority.none,
    this.matches = const [],
  });

  final String title;
  final DateTime? dueDate;
  final List<String> tags;
  final Priority priority;

  /// Character ranges of the recognised tokens, for highlighting.
  final List<QuickAddMatch> matches;

  bool get hasExtras =>
      dueDate != null || tags.isNotEmpty || priority != Priority.none;
}

enum QuickAddKind { date, tag, priority }

class QuickAddMatch {
  const QuickAddMatch(this.start, this.end, this.kind, this.text);
  final int start;
  final int end;
  final QuickAddKind kind;

  /// The matched text, lower-cased. Pass it in `ignore` to keep it in the title.
  final String text;
}

const _weekdays = {
  'mon': 1, 'monday': 1,
  'tue': 2, 'tues': 2, 'tuesday': 2,
  'wed': 3, 'weds': 3, 'wednesday': 3,
  'thu': 4, 'thur': 4, 'thurs': 4, 'thursday': 4,
  'fri': 5, 'friday': 5,
  'sat': 6, 'saturday': 6,
  'sun': 7, 'sunday': 7,
};

const _months = {
  'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
  'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
  'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
  'oct': 10, 'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
};

/// Parses quick-add text. Recognises:
/// - tags: `#work`
/// - priority: `!high` `!med` `!low` (also `!h` `!m` `!l`, `!!!` `!!` `!`, `p1` `p2` `p3`)
/// - dates: `today`, `tomorrow`/`tmr`, `mon`..`sun`, `next fri`, `next week`,
///   `in 3 days`, `in 2 weeks`, `oct 21`, `21 oct`, `10/21`
/// Anything else is the title. Only the last date and priority found win.
/// Tokens listed in [ignore] (lower-cased match text) are left in the title,
/// so "Call Tom" or "Sat exam" can stay as typed.
QuickAddResult parseQuickAdd(String input,
    {DateTime? now, Set<String> ignore = const {}}) {
  final today = TaskDates.dateOnly(now ?? DateTime.now());
  final matches = <QuickAddMatch>[];
  final tags = <String>[];
  DateTime? due;
  var priority = Priority.none;

  bool overlaps(int s, int e) => matches.any((m) => s < m.end && e > m.start);
  bool ignored(Match m) =>
      ignore.contains(input.substring(m.start, m.end).toLowerCase());
  void claim(Match m, QuickAddKind kind) => matches.add(QuickAddMatch(
      m.start, m.end, kind, input.substring(m.start, m.end).toLowerCase()));

  // Tags.
  for (final m in RegExp(r'(?<=^|\s)#([\w-]+)').allMatches(input)) {
    if (ignored(m)) continue;
    final tag = m.group(1)!.toLowerCase();
    if (!tags.contains(tag)) tags.add(tag);
    claim(m, QuickAddKind.tag);
  }

  // Priority.
  final pri = RegExp(
      r'(?<=^|\s)(?:!(high|hi|h|medium|med|m|low|lo|l)|(!{1,3})|p([1-3]))(?=$|\s)',
      caseSensitive: false);
  for (final m in pri.allMatches(input)) {
    if (ignored(m)) continue;
    final word = m.group(1)?.toLowerCase();
    final bangs = m.group(2);
    final p = m.group(3);
    priority = switch ((word, bangs, p)) {
      (String w, _, _) when w.startsWith('h') => Priority.high,
      (String w, _, _) when w.startsWith('m') => Priority.medium,
      (String _, _, _) => Priority.low,
      (_, String b, _) => b.length == 3
          ? Priority.high
          : b.length == 2
              ? Priority.medium
              : Priority.low,
      (_, _, String n) => n == '1'
          ? Priority.high
          : n == '2'
              ? Priority.medium
              : Priority.low,
      _ => priority,
    };
    claim(m, QuickAddKind.priority);
  }

  // Dates, most specific patterns first so "next fri" beats "fri".
  final dayNames = _weekdays.keys.join('|');
  final monthNames = _months.keys.join('|');
  final datePatterns = <RegExp, DateTime? Function(Match)>{
    RegExp(r'\bin (\d{1,3}) (day|days|week|weeks|month|months)\b',
        caseSensitive: false): (m) {
      final n = int.parse(m.group(1)!);
      final unit = m.group(2)!.toLowerCase();
      if (unit.startsWith('day')) return today.add(Duration(days: n));
      if (unit.startsWith('week')) return today.add(Duration(days: 7 * n));
      return DateTime(today.year, today.month + n, today.day);
    },
    RegExp(r'\bnext week\b', caseSensitive: false): (_) =>
        today.add(const Duration(days: 7)),
    RegExp('\\bnext ($dayNames)\\b', caseSensitive: false): (m) {
      final wd = _weekdays[m.group(1)!.toLowerCase()]!;
      var d = _nextWeekday(today, wd, allowToday: false);
      // "next fri" means the one after this coming one, unless that is
      // already a week or more away.
      if (d.difference(today).inDays < 7) d = d.add(const Duration(days: 7));
      return d;
    },
    RegExp('\\b($monthNames)\\.? (\\d{1,2})(?:st|nd|rd|th)?\\b',
        caseSensitive: false): (m) =>
        _monthDay(today, _months[m.group(1)!.toLowerCase()]!, int.parse(m.group(2)!)),
    RegExp('\\b(\\d{1,2})(?:st|nd|rd|th)? ($monthNames)\\b',
        caseSensitive: false): (m) =>
        _monthDay(today, _months[m.group(2)!.toLowerCase()]!, int.parse(m.group(1)!)),
    RegExp(r'(?<=^|\s)(\d{1,2})/(\d{1,2})(?=$|\s)'): (m) =>
        _monthDay(today, int.parse(m.group(1)!), int.parse(m.group(2)!)),
    RegExp(r'\b(today|tod|tonight)\b', caseSensitive: false): (_) => today,
    RegExp(r'\b(tomorrow|tmr|tmrw)\b', caseSensitive: false): (_) =>
        today.add(const Duration(days: 1)),
    RegExp('\\b($dayNames)\\b', caseSensitive: false): (m) =>
        _nextWeekday(today, _weekdays[m.group(1)!.toLowerCase()]!, allowToday: true),
  };

  for (final entry in datePatterns.entries) {
    for (final m in entry.key.allMatches(input)) {
      if (overlaps(m.start, m.end) || ignored(m)) continue;
      final d = entry.value(m);
      if (d == null) continue;
      due = d;
      claim(m, QuickAddKind.date);
    }
  }

  // Title: input with matched tokens removed, whitespace tidied.
  matches.sort((a, b) => a.start.compareTo(b.start));
  final buf = StringBuffer();
  var pos = 0;
  for (final m in matches) {
    if (m.start > pos) buf.write(input.substring(pos, m.start));
    pos = m.end;
  }
  if (pos < input.length) buf.write(input.substring(pos));
  final title = buf
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+([,.;:])'), r'$1')
      .trim()
      .replaceAll(RegExp(r'^(on|by|due)\s+|\s+(on|by|due)$', caseSensitive: false), '');

  return QuickAddResult(
    title: title,
    dueDate: due,
    tags: tags,
    priority: priority,
    matches: matches,
  );
}

DateTime _nextWeekday(DateTime today, int weekday, {required bool allowToday}) {
  var diff = (weekday - today.weekday) % 7;
  if (diff == 0 && !allowToday) diff = 7;
  return today.add(Duration(days: diff));
}

/// Month/day in the current year, or next year if it has already passed.
DateTime? _monthDay(DateTime today, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  var d = DateTime(today.year, month, day);
  if (d.month != month) return null; // e.g. Feb 31
  if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
  return d;
}

/// For step text: pulls out just a date ("Draft runbook fri" → "Draft runbook",
/// Friday). Tags and priorities stay as typed, since steps don't have them.
({String title, DateTime? dueDate}) parseStepText(String input, {DateTime? now}) {
  final r = parseQuickAdd(input, now: now);
  final dates = r.matches.where((m) => m.kind == QuickAddKind.date).toList();
  if (r.dueDate == null || dates.isEmpty) return (title: input.trim(), dueDate: null);
  final buf = StringBuffer();
  var pos = 0;
  for (final m in dates) {
    buf.write(input.substring(pos, m.start));
    pos = m.end;
  }
  buf.write(input.substring(pos));
  final title = buf
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+(on|by|due)$', caseSensitive: false), '')
      .trim();
  // A step that is nothing but a date keeps its text.
  if (title.isEmpty) return (title: input.trim(), dueDate: null);
  return (title: title, dueDate: r.dueDate);
}
