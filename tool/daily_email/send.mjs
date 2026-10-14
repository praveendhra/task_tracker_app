// Hourly job: sends each opted-in user their morning summary once a day at
// their chosen local hour. Run by .github/workflows/daily-email.yml.
//
// Env:
//   FIREBASE_SERVICE_ACCOUNT  service-account JSON (Firebase console > Project settings > Service accounts)
//   RESEND_API_KEY            Resend API key
//   MAIL_FROM                 e.g. "Task Tracker <tasks@mail.praveendhra.com>"
//   APP_URL                   link in the email (default https://task.praveendhra.com)
//   FORCE_EMAIL               optional: send to this account now, ignoring hour and "already sent"
//   DRY_RUN                   "true" to log what would be sent without sending or recording
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { buildDigest, localDate, localHour, normaliseTasks, renderHtml, renderText, subjectFor } from './email.mjs';

const {
  FIREBASE_SERVICE_ACCOUNT, RESEND_API_KEY, MAIL_FROM,
  APP_URL = 'https://task.praveendhra.com', FORCE_EMAIL = '', DRY_RUN = '',
} = process.env;
const dryRun = DRY_RUN === 'true';

if (!FIREBASE_SERVICE_ACCOUNT) {
  console.log('::warning::FIREBASE_SERVICE_ACCOUNT is not set, so no emails were sent. See README.');
  process.exit(0);
}
if (!dryRun && (!RESEND_API_KEY || !MAIL_FROM)) {
  console.log('::warning::RESEND_API_KEY or MAIL_FROM is not set, so no emails were sent. See README.');
  process.exit(0);
}

initializeApp({ credential: cert(JSON.parse(FIREBASE_SERVICE_ACCOUNT)) });
const db = getFirestore();
const auth = getAuth();
const now = new Date();

async function sendEmail({ to, subject, html, text, idempotencyKey }) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': idempotencyKey,
    },
    body: JSON.stringify({ from: MAIL_FROM, to: [to], subject, html, text }),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${await res.text()}`);
}

async function main() {
  let forcedUid = null;
  if (FORCE_EMAIL) {
    forcedUid = (await auth.getUserByEmail(FORCE_EMAIL.trim())).uid;
    console.log(`Forcing a send for ${FORCE_EMAIL}`);
  }

  const users = forcedUid
    ? [await db.collection('users').doc(forcedUid).get()]
    : (await db.collection('users').where('dailyEmail', '==', true).get()).docs;

  let sent = 0, skipped = 0, failed = 0;
  for (const doc of users) {
    const uid = doc.id;
    const prefs = doc.data() || {};
    const tz = prefs.timezone || 'UTC';
    const hour = Number.isInteger(prefs.emailHour) ? prefs.emailHour : 9;
    try {
      const today = localDate(now, tz);
      const h = localHour(now, tz);
      const forced = uid === forcedUid;
      // Any run from the chosen hour until midnight sends, once. If GitHub
      // skips the on-time runs, the email still arrives, just later.
      const due = forced || (h >= hour && prefs.lastDailyEmail !== today);
      if (!due) { skipped++; continue; }

      const snap = await db.collection('users').doc(uid).collection('tasks').get();
      const tasks = normaliseTasks(snap.docs.map((d) => d.data()), tz);
      const digest = buildDigest(tasks, today);

      if (digest.openCount === 0 && !forced) {
        console.log(`${uid}: nothing open, no email today`);
        if (!dryRun) await doc.ref.set({ lastDailyEmail: today }, { merge: true });
        skipped++;
        continue;
      }

      const user = await auth.getUser(uid);
      if (!user.email) { console.log(`${uid}: no email address`); skipped++; continue; }
      const name = (user.displayName || '').trim().split(/\s+/)[0] || '';
      const subject = subjectFor(digest);
      const opts = { name, appUrl: APP_URL };

      if (dryRun) {
        console.log(`[dry run] ${user.email} (${tz} ${today} ${h}:00): ${subject}`);
        console.log(renderText(digest, opts));
      } else {
        await sendEmail({
          to: user.email,
          subject,
          html: renderHtml(digest, opts),
          text: renderText(digest, opts),
          idempotencyKey: `daily-${uid}-${today}${forced ? `-forced-${now.getTime()}` : ''}`,
        });
        await doc.ref.set(
          { lastDailyEmail: today, lastDailyEmailAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
        console.log(`Sent to ${user.email}: ${subject}`);
      }
      sent++;
    } catch (e) {
      failed++;
      console.log(`::error::${uid}: ${e.message}`);
    }
  }
  console.log(`Done: ${sent} sent, ${skipped} skipped, ${failed} failed (of ${users.length} opted in)`);
  if (failed) process.exitCode = 1;
}

await main();
