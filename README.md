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
| Auth | Firebase Authentication, email and password |
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
