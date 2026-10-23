# Task Tracker

Break work into steps and see exactly where everything stands. Flutter app for web, Android and iOS, live at **https://task.praveendhra.com**.

- Tasks with ordered steps, a "current step", notes per step and a progress bar
- Due dates (overdue tasks float to the top), priorities and tags
- Views for Active, Due today, Upcoming, Done and All, plus per-tag filtering and four sort orders
- Full-text search across titles, descriptions, steps, notes and tags (archived tasks included)
- Archive with restore, undo on archive, confirm on delete
- Light, dark or system theme; responsive three-pane layout on desktop
- Live sync across devices and offline support (Firestore cache)

## Architecture

| Piece | What |
|---|---|
| UI | Flutter (Material 3), `lib/screens`, `lib/widgets` |
| State | `AppController` (`lib/app_controller.dart`), a `ChangeNotifier` exposed through `AppScope` |
| Auth | Firebase Authentication: email and password, Google, Apple (iOS) |
| Database | Cloud Firestore, one document per task |
| Hosting | GitHub Pages from [`task_tracker_live`](https://github.com/praveendhra/task_tracker_live) |

### Data model

```
users/{uid}                     legacyImportedAt, legacyTaskCount
users/{uid}/tasks/{taskId}      title, description, status (1 not started, 2 in progress, 3 done),
                                priority (0-3), dueDate, tags[], steps[{id, title, note, status}],
                                currentStepId, archived, createdAt, updatedAt, completedAt
```

Steps are embedded in the task document so a task and its steps always change together. Security rules (`firestore.rules`) only let a signed-in user read or write their own documents and validate the shape of every task write.

### Moving from the old database

Version 1 kept every task for a user in a single JSON string at `users/{uid}/data` in the Realtime Database, so every edit rewrote the whole list and two devices could overwrite each other. On first sign-in, v2 copies that list into Firestore (`FirestoreTaskRepository.prepare`), marks the account as imported, and shows how many tasks moved. The Realtime Database data is left untouched.

## Daily email

Users can turn on a morning summary under **Settings & daily email** (account menu). It lists high-priority tasks first, then overdue, due today, in progress and the coming week, and is sent at the chosen hour in the user's time zone (detected from the browser). No email goes out on a day with nothing open.

`tool/daily_email/send.mjs` does the work: it reads opted-in users from Firestore with the Admin SDK, sends through [Resend](https://resend.com), and records `lastDailyEmail` so each user gets one email a day. Every open task appears in the email; anything that isn't high priority, overdue, due soon or in progress is listed under *Other open tasks*.

It runs in `.github/workflows/daily-email.yml`, which is started at the top of every hour by a Cloudflare Worker (`cloudflare/email-trigger`). GitHub's own cron is best-effort and often skips runs, while Cloudflare's cron fires on time and a dispatched workflow starts within seconds. In zones with a half-hour offset (India +5:30, Nepal +5:45) the email arrives 30–45 minutes after the chosen hour; switch the cron to `*/15 * * * *` to make it exact everywhere. An hourly GitHub schedule stays as a backup; if runs are missed the email still goes out on the first run after the chosen hour, before midnight.

### Cloudflare trigger setup

1. GitHub → Settings → Developer settings → Fine-grained tokens → Generate. Repository access: only `praveendhra/task_tracker_app`. Permissions: **Actions: Read and write**. Copy the token.
2. Cloudflare dashboard → Workers & Pages → Create → Worker. Name it `task-tracker-email-trigger`, deploy, then **Edit code**, paste `cloudflare/email-trigger/src/index.js`, and deploy again.
3. The Worker's **Settings → Variables and Secrets**: add a **Secret** named `GITHUB_TOKEN` with the token.
4. **Settings → Trigger events → Add → Cron trigger**: `0 * * * *` (every hour).

(Or from this folder: `npx wrangler deploy` and `npx wrangler secret put GITHUB_TOKEN`.) The Worker's Logs tab shows each run; GitHub → Actions → Daily email shows the runs it started.

Repository secrets it needs (Settings → Secrets and variables → Actions):

| Secret | Where to get it |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | Firebase console → Project settings → Service accounts → Generate new private key. Paste the whole JSON file. |
| `RESEND_API_KEY` | resend.com → API Keys → Create (Sending access). |

The sender defaults to `Task Tracker <tasks@mail.praveendhra.com>` (the domain is already verified in Resend). Override it with an Actions **variable** named `MAIL_FROM`.

To test: Actions → Daily email → Run workflow, put your email in *force_email* (and tick *dry_run* to only log it). Preview the template locally with `cd tool/daily_email && npm i && node preview.mjs`.

GitHub pauses scheduled workflows in repos with no activity for 60 days; any push re-enables it.

## Task reminders (iPhone)

On iPhone, Settings > **Reminders** turns on notifications that say what's due and the next step ("1 due today · Next: Draft slides (Quarterly report)"). Tapping one opens the app. Users pick how often (every 1-6 hours) and the hours they may arrive (default every hour, 9 AM to 9 PM).

They're **local notifications**: the app plans them on the phone from the tasks it already has (`lib/models/reminders.dart`) and schedules up to 60 ahead with `flutter_local_notifications`, re-planning a couple of seconds after any task or setting changes. No server, push key or device token is involved, and nothing leaves the phone. Each slot's text is worked out for that day, so a task due today reads as overdue tomorrow. Changes made on another device show up the next time the iPhone app syncs. The section is hidden on the web and Android.

## Mobile apps

Android (`com.pravii_corp.task_tracker`) and iOS (`com.pravii.taskTrackerApp`) build from the same code. CI builds both on every pull request; **Android release** and **iOS release** workflows sign and upload to the Play internal track and TestFlight. Setup steps: [`store/RELEASE.md`](store/RELEASE.md). Listing text, privacy answers and screenshots: [`store/listing.md`](store/listing.md). The privacy policy and account-deletion pages are `web/privacy.html` and `web/delete-account.html`.

## Develop

```bash
flutter pub get
flutter run -d chrome                              # real Firebase project
flutter run -d chrome --dart-define=DEMO=true      # in-memory sample data, no sign-in
flutter analyze && flutter test
```

Demo builds accept URL parameters for jumping to a view: `?screen=detail|editor|new|archive|search|auth`, `&task=<id>`, `&theme=light|dark`. CI uses these to screenshot every pull request.

## Firebase setup

Firestore must be enabled on project `task-tracker-9c52d` and the rules deployed:

```bash
npm i -g firebase-tools
firebase login
firebase deploy --only firestore
```

(Or paste `firestore.rules` into Firebase console, Firestore, Rules, and publish.)

## Deploy

`.github/workflows/ci.yml` analyzes, tests and builds on every pull request, and screenshots the demo build. On every push to `main` it builds and pushes `build/web` to `task_tracker_live`, which serves `task.praveendhra.com` through GitHub Pages.

The deploy step needs a repository secret named `LIVE_REPO_TOKEN`: a fine-grained personal access token with **Contents: Read and write** on `praveendhra/task_tracker_live` only. Until it exists, the deploy step is skipped with a notice.
