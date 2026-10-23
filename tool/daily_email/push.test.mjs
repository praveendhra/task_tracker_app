import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pushPrefs, pushSlot, reminderFor } from './push.mjs';
import { buildDigest, normaliseTasks } from './email.mjs';

const tz = 'America/New_York';
// 2026-10-23 is EDT (UTC-4): 14:00 UTC = 10 AM local.
const at = (h) => new Date(Date.UTC(2026, 9, 23, h + 4, 0, 30));
const on = (extra = {}) => pushPrefs({ pushReminders: true, pushTokens: ['t1'], ...extra });

test('defaults: hourly from 9 AM to 9 PM', () => {
  const p = on();
  assert.equal(pushSlot(p, at(8), tz), null);
  assert.equal(pushSlot(p, at(9), tz), '2026-10-23T09');
  assert.equal(pushSlot(p, at(14), tz), '2026-10-23T14');
  assert.equal(pushSlot(p, at(21), tz), '2026-10-23T21');
  assert.equal(pushSlot(p, at(22), tz), null);
});

test('off, or no devices, never sends', () => {
  assert.equal(pushSlot(pushPrefs({ pushReminders: false, pushTokens: ['t'] }), at(10), tz), null);
  assert.equal(pushSlot(pushPrefs({ pushReminders: true }), at(10), tz), null);
});

test('every N hours counts from the start hour', () => {
  const p = on({ pushEvery: 3, pushFrom: 8, pushTo: 20 });
  const hours = [...Array(24).keys()].filter((h) => pushSlot(p, at(h), tz));
  assert.deepEqual(hours, [8, 11, 14, 17, 20]);
});

test('window can wrap past midnight', () => {
  const p = on({ pushFrom: 22, pushTo: 1 });
  const hours = [...Array(24).keys()].filter((h) => pushSlot(p, at(h), tz));
  assert.deepEqual(hours, [0, 1, 22, 23]);
});

test('at most once per hour', () => {
  assert.equal(pushSlot(on(), at(10), tz, '2026-10-23T10'), null);
  assert.equal(pushSlot(on(), at(11), tz, '2026-10-23T10'), '2026-10-23T11');
});

test('reminder text leads with what is urgent and the next step', () => {
  const today = '2026-10-23';
  const tasks = normaliseTasks([
    { title: 'Prepare quarterly report', status: 2, priority: 2, dueDate: new Date('2026-10-23T15:00:00Z'),
      currentStepId: 'b', steps: [{ id: 'a', title: 'Pull numbers', status: 3 }, { id: 'b', title: 'Draft slides', status: 1 }] },
    { title: 'Groceries', status: 1, priority: 1, steps: [] },
  ], tz);
  const r = reminderFor(buildDigest(tasks, today));
  assert.equal(r.title, '1 due today');
  assert.equal(r.body, 'Next: Draft slides (Prepare quarterly report) · 2 tasks open');
});

test('plain count when nothing is urgent; nothing when all done', () => {
  const tasks = normaliseTasks([{ title: 'Read a book', status: 1, steps: [] }], tz);
  assert.deepEqual(reminderFor(buildDigest(tasks, '2026-10-23')), { title: '1 task open', body: 'Next: Read a book' });
  const done = normaliseTasks([{ title: 'x', status: 3, steps: [] }], tz);
  assert.equal(reminderFor(buildDigest(done, '2026-10-23')), null);
});
