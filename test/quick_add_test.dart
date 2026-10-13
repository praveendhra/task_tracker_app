import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker_app/models/quick_add.dart';
import 'package:task_tracker_app/models/task.dart';

void main() {
  // Tuesday 13 Oct 2026.
  final now = DateTime(2026, 10, 13, 9, 30);
  QuickAddResult p(String s, {Set<String> ignore = const {}}) =>
      parseQuickAdd(s, now: now, ignore: ignore);

  test('plain title', () {
    final r = p('Buy coffee beans');
    expect(r.title, 'Buy coffee beans');
    expect(r.hasExtras, isFalse);
  });

  test('tags, priority and weekday together', () {
    final r = p('Rotate SQL creds fri #work #Security !high');
    expect(r.title, 'Rotate SQL creds');
    expect(r.tags, ['work', 'security']);
    expect(r.priority, Priority.high);
    expect(r.dueDate, DateTime(2026, 10, 16));
  });

  test('relative dates', () {
    expect(p('x today').dueDate, DateTime(2026, 10, 13));
    expect(p('x tomorrow').dueDate, DateTime(2026, 10, 14));
    expect(p('x tmr').dueDate, DateTime(2026, 10, 14));
    expect(p('x in 3 days').dueDate, DateTime(2026, 10, 16));
    expect(p('x in 2 weeks').dueDate, DateTime(2026, 10, 27));
    expect(p('x next week').dueDate, DateTime(2026, 10, 20));
  });

  test('weekdays: bare means the coming one, today counts', () {
    expect(p('x tue').dueDate, DateTime(2026, 10, 13));
    expect(p('x wed').dueDate, DateTime(2026, 10, 14));
    expect(p('x mon').dueDate, DateTime(2026, 10, 19));
    expect(p('x next fri').dueDate, DateTime(2026, 10, 23));
    expect(p('x next fri').title, 'x');
  });

  test('calendar dates roll into next year once passed', () {
    expect(p('x oct 21').dueDate, DateTime(2026, 10, 21));
    expect(p('x 21 oct').dueDate, DateTime(2026, 10, 21));
    expect(p('x 3/4').dueDate, DateTime(2027, 3, 4));
    expect(p('x jan 5th').dueDate, DateTime(2027, 1, 5));
    expect(p('x feb 31').dueDate, isNull);
  });

  test('priority spellings', () {
    expect(p('a !h').priority, Priority.high);
    expect(p('a !med').priority, Priority.medium);
    expect(p('a !low').priority, Priority.low);
    expect(p('a !!!').priority, Priority.high);
    expect(p('a !!').priority, Priority.medium);
    expect(p('a p3').priority, Priority.low);
    expect(p('Wow!').priority, Priority.none);
  });

  test('"due"/"by" before a date is dropped from the title', () {
    expect(p('Submit report by fri').title, 'Submit report');
    expect(p('Pay rent due oct 21').title, 'Pay rent');
  });

  test('ignored tokens stay in the title', () {
    final r = p('Sat exam prep', ignore: {'sat'});
    expect(r.dueDate, isNull);
    expect(r.title, 'Sat exam prep');
  });

  test('matches cover the recognised text', () {
    const s = 'Ship it tomorrow #release';
    final r = p(s);
    final texts = r.matches.map((m) => s.substring(m.start, m.end)).toList();
    expect(texts, containsAll(['tomorrow', '#release']));
  });

  test('step text: only the date is pulled out', () {
    final r = parseStepText('Draft runbook #ops fri', now: now);
    expect(r.title, 'Draft runbook #ops');
    expect(r.dueDate, DateTime(2026, 10, 16));
    final plain = parseStepText('Call the vendor', now: now);
    expect(plain.title, 'Call the vendor');
    expect(plain.dueDate, isNull);
    expect(parseStepText('tomorrow', now: now).title, 'tomorrow');
  });
}
