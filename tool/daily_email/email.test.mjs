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

test('steps due today or overdue get their own list', () => {
  const tasks = normaliseTasks([
    { title: 'Migration', status: 2, priority: 3, currentStepId: 'b',
      steps: [
        { id: 'a', title: 'Done step', status: 3, dueDate: '2026-10-01' },
        { id: 'b', title: 'Late step', status: 2, dueDate: '2026-10-11' },
        { id: 'c', title: 'Today step', status: 1, dueDate: '2026-10-13' },
        { id: 'd', title: 'Later step', status: 1, dueDate: '2026-10-20' },
      ] },
    { title: 'Finished task', status: 3, steps: [{ id: 'x', title: 'Old', status: 1, dueDate: '2026-10-01' }] },
  ], tz);
  const d = buildDigest(tasks, '2026-10-13');
  assert.deepEqual(d.stepsDue.map((s) => s.title), ['Late step', 'Today step']);
  assert.equal(d.stepsDue[0].task, 'Migration');
  assert.equal(d.stepsOverdueCount, 1);
  assert.equal(d.high[0].currentStepDue, '2026-10-11');
  assert.match(subjectFor(d), /2 steps due/);
});
