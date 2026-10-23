// Push reminder logic, kept free of Firebase so it can be unit tested.
import { localDate, localHour } from './email.mjs';

export const DEFAULT_PUSH = { every: 1, from: 9, to: 21 };

/** Reads the reminder settings from a user document, with safe defaults. */
export function pushPrefs(p = {}) {
  const int = (v, d, lo, hi) => (Number.isInteger(v) ? Math.min(hi, Math.max(lo, v)) : d);
  return {
    enabled: p.pushReminders === true,
    every: int(p.pushEvery, DEFAULT_PUSH.every, 1, 12),
    from: int(p.pushFrom, DEFAULT_PUSH.from, 0, 23),
    to: int(p.pushTo, DEFAULT_PUSH.to, 0, 23),
    tokens: Array.isArray(p.pushTokens) ? p.pushTokens.filter((t) => typeof t === 'string' && t) : [],
  };
}

/**
 * Whether a reminder is due this hour. Reminders go out on the hours from
 * `from` to `to` (inclusive, local time), every `every` hours, at most once per
 * hour. A window that wraps midnight (e.g. 22 to 2) is supported.
 * Returns the slot key ("YYYY-MM-DDTHH") when due, otherwise null.
 */
export function pushSlot(prefs, now, timeZone, lastPush) {
  if (!prefs.enabled || prefs.tokens.length === 0) return null;
  const h = localHour(now, timeZone);
  const span = (prefs.to - prefs.from + 24) % 24;
  const offset = (h - prefs.from + 24) % 24;
  if (offset > span) return null;
  if (offset % prefs.every !== 0) return null;
  const slot = `${localDate(now, timeZone)}T${String(h).padStart(2, '0')}`;
  return slot === lastPush ? null : slot;
}

const plural = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`;

/** Builds the notification for a digest (see buildDigest), or null if nothing is open. */
export function reminderFor(d) {
  if (!d || d.openCount === 0) return null;
  const bits = [];
  if (d.overdueCount) bits.push(`${d.overdueCount} overdue`);
  if (d.dueTodayCount) bits.push(`${d.dueTodayCount} due today`);
  if (d.highCount) bits.push(`${d.highCount} high priority`);
  const title = bits.length ? bits.join(' · ') : `${plural(d.openCount, 'task')} open`;

  const next = [...d.high, ...d.overdue, ...d.dueToday, ...d.inProgress, ...d.upcoming, ...d.other][0];
  let body;
  if (d.stepsDue.length) {
    const st = d.stepsDue[0];
    body = `Next: ${st.title} (${st.task})`;
  } else if (next) {
    body = next.currentStep ? `Next: ${next.currentStep} (${next.title})` : `Next: ${next.title}`;
  } else {
    body = 'Tap to see your tasks.';
  }
  if (bits.length && d.openCount > 1) body += ` · ${plural(d.openCount, 'task')} open`;
  return { title, body: body.length > 180 ? `${body.slice(0, 177)}…` : body };
}

/** FCM error codes that mean the token will never work again. */
export const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);
