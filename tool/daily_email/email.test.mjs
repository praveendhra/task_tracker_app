import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildDigest, localDate, localHour, normaliseTasks, subjectFor } from './email.mjs';

const tz = 'America/New_York';
// 2026-10-13 13:30 UTC = 09:30 in New York.
const now = new Date(Date.UTC(2026, 9, 13, 13, 30));
const at = (y, m, d) => new Date(Date.UTC(y, m - 1, d, 4)); // midnight New York (EDT)

test('local date and hour follow the time zone', () => {
  assert.equal(localDate(now, tz), '2026-10-13');
  assert.equal(localHour(now, tz), 9);
  assert.equal(localHour(now, 'Asia/Kolkata'), 19);
  assert.equal(localDate(new Date(Date.UTC(2026, 9, 13, 2)), tz), '2026-10-12');
});

test('high priority comes first and each task appears once', () => {
  const tasks = normaliseTasks([
    { title: 'High and overdue', status: 1, priority: 3, dueDate: at(2026, 10, 10) },
    { title: 'Overdue', status: 1, priority: 1, dueDate: at(2026, 10, 12) },
    { title: 'Today', status: 1, dueDate: at(2026, 10, 13) },
    { title: 'Working on it', status: 2, steps: [{ id: 'a', title: 'Step A', status: 3 }, { id: 'b', title: 'Step B', status: 1 }] },
    { title: 'Next week', status: 1, dueDate: at(2026, 10, 18) },
    { title: 'Done', status: 3, priority: 3, completedAt: at(2026, 10, 12) },
    { title: 'Archived high', status: 1, priority: 3, archived: true },
  ], tz);
  const d = buildDigest(tasks, '2026-10-13');
  assert.deepEqual(d.high.map((t) => t.title), ['High and overdue']);
  assert.deepEqual(d.overdue.map((t) => t.title), ['Overdue']);
  assert.deepEqual(d.dueToday.map((t) => t.title), ['Today']);
  assert.deepEqual(d.inProgress.map((t) => t.title), ['Working on it']);
  assert.equal(d.inProgress[0].currentStep, 'Step B');
  assert.deepEqual(d.upcoming.map((t) => t.title), ['Next week']);
  assert.equal(d.overdueCount, 2);
  assert.equal(d.doneYesterday, 1);
  assert.equal(d.openCount, 5);
  assert.equal(subjectFor(d), 'Your day: 1 high priority, 2 overdue, 1 due today');
});

test('nothing urgent still gives a sensible subject', () => {
  const d = buildDigest(normaliseTasks([{ title: 'Someday', status: 1 }], tz), '2026-10-13');
  assert.equal(subjectFor(d), 'Your day: 1 open task');
});
