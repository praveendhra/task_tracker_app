// Hourly job: sends push reminders ("2 due today · Next: …") to users who
// turned them on, within their chosen hours. Run by .github/workflows/daily-email.yml
// right after the email step.
//
// Env:
//   FIREBASE_SERVICE_ACCOUNT  service-account JSON
//   APP_URL                   opened when the notification is clicked on the web
//   FORCE_PUSH                optional: send to this account now, ignoring the schedule
//   DRY_RUN                   "true" to log without sending or recording
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { buildDigest, localDate, normaliseTasks } from './email.mjs';
import { DEAD_TOKEN_CODES, pushPrefs, pushSlot, reminderFor } from './push.mjs';

const { FIREBASE_SERVICE_ACCOUNT, APP_URL = 'https://task.praveendhra.com', FORCE_PUSH = '', DRY_RUN = '' } = process.env;
const dryRun = DRY_RUN === 'true';

if (!FIREBASE_SERVICE_ACCOUNT) {
  console.log('::warning::FIREBASE_SERVICE_ACCOUNT is not set, so no reminders were sent.');
  process.exit(0);
}

initializeApp({ credential: cert(JSON.parse(FIREBASE_SERVICE_ACCOUNT)) });
const db = getFirestore();
const now = new Date();

async function main() {
  let forcedUid = null;
  if (FORCE_PUSH) {
    forcedUid = (await getAuth().getUserByEmail(FORCE_PUSH.trim())).uid;
    console.log(`Forcing a reminder for ${FORCE_PUSH}`);
  }
  const users = forcedUid
    ? [await db.collection('users').doc(forcedUid).get()]
    : (await db.collection('users').where('pushReminders', '==', true).get()).docs;

  let sent = 0, skipped = 0, failed = 0;
  for (const doc of users) {
    const uid = doc.id;
    const data = doc.data() || {};
    const prefs = pushPrefs(data);
    const tz = data.timezone || 'UTC';
    try {
      const forced = uid === forcedUid;
      const slot = forced
        ? `${localDate(now, tz)}Tforced`
        : pushSlot(prefs, now, tz, data.lastPush);
      if (!slot || prefs.tokens.length === 0) { skipped++; continue; }

      const snap = await db.collection('users').doc(uid).collection('tasks').get();
      const digest = buildDigest(normaliseTasks(snap.docs.map((d) => d.data()), tz), localDate(now, tz));
      const note = reminderFor(digest);
      if (!note) { skipped++; continue; }

      if (dryRun) {
        console.log(`[dry run] ${uid} (${prefs.tokens.length} device(s)): ${note.title} — ${note.body}`);
        sent++;
        continue;
      }

      const res = await getMessaging().sendEachForMulticast({
        tokens: prefs.tokens,
        notification: note,
        data: { route: 'tasks' },
        // Each reminder replaces the previous one instead of stacking up.
        android: { collapseKey: 'reminder', notification: { tag: 'reminder', color: '#4F46E5' } },
        apns: {
          headers: { 'apns-collapse-id': 'reminder' },
          payload: { aps: { sound: 'default', 'thread-id': 'reminders' } },
        },
        webpush: {
          fcmOptions: { link: APP_URL },
          notification: { tag: 'reminder', renotify: true, icon: `${APP_URL}/icons/Icon-192.png` },
        },
      });

      const dead = [];
      res.responses.forEach((r, i) => {
        if (!r.success && DEAD_TOKEN_CODES.has(r.error?.code)) dead.push(prefs.tokens[i]);
      });
      const update = { lastPush: slot };
      if (dead.length) update.pushTokens = FieldValue.arrayRemove(...dead);
      await doc.ref.set(update, { merge: true });

      console.log(`${uid}: ${res.successCount}/${prefs.tokens.length} delivered${dead.length ? `, removed ${dead.length} stale token(s)` : ''}`);
      if (res.successCount > 0) sent++; else failed++;
    } catch (e) {
      failed++;
      console.log(`::warning::${uid}: ${e.message}`);
    }
  }
  console.log(`Reminders: ${sent} sent, ${skipped} not due, ${failed} failed`);
}

await main();
