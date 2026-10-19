# Publishing to Google Play and the App Store

| | Android | iOS |
|---|---|---|
| App ID | `com.pravii_corp.task_tracker` | `com.pravii.taskTrackerApp` |
| Store name | Task Tracker: Step by Step | Task Tracker: Step by Step |
| Workflow | Actions → **Android release** | Actions → **iOS release** |
| Goes to | Play internal test track | TestFlight |

Build numbers are `100 + workflow run number`, so every run uploads a new build.

---

## Android (Google Play)

### 1. Create a new upload key (once)

The old key's password was committed to the repo, so make a fresh one. On your Mac:

```bash
keytool -genkey -v -keystore ~/task-tracker-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
base64 -i ~/task-tracker-upload.jks | pbcopy     # copies the key as text
```

Keep the `.jks` file and its password somewhere safe (a password manager), never in the repo.

### 2. GitHub secrets

Repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the base64 text you copied |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password (same as keystore password unless you chose another) |

### 3. Create the app in Play Console

1. Play Console → **Create app** → name *Task Tracker: Step by Step*, App, Free.
2. Run **Actions → Android release** once. Download the `app-release-aab` artifact from the run.
3. Play Console → Testing → **Internal testing** → Create release → upload that `.aab` (the first upload must be manual). Accept **Play App Signing**.
4. Fill in **Main store listing** and every item under **App content** from [`listing.md`](listing.md).

### 4. Let GitHub upload future builds (optional)

1. Google Cloud console (project `task-tracker-9c52d` is fine) → IAM → Service accounts → Create → then **Keys → Add key → JSON**.
2. Play Console → **Users and permissions** → Invite new user → the service account's email → App permissions: this app → *Release apps to testing tracks* (and *Release to production* if you want).
3. Add the JSON file's contents as secret `PLAY_SERVICE_ACCOUNT_JSON`.

From then on, each run of **Android release** uploads straight to the chosen track.

### 5. Google sign-in on Android

Play re-signs the app, so Firebase needs Play's fingerprints:
Play Console → Test and release → **App integrity** → App signing → copy **SHA-1** and **SHA-256** → Firebase console → Project settings → Android app `com.pravii_corp.task_tracker` → **Add fingerprint** (both). Also add your upload key's SHA-1 (`keytool -list -v -keystore ~/task-tracker-upload.jks -alias upload`).

### 6. Testing requirement for new personal accounts

Personal developer accounts created after Nov 2023 must run a **closed test with at least 12 testers for 14 days in a row** before production access. Testing → Closed testing → create a track, add 12+ Google accounts (an email list or a Google Group), promote the internal build there, and ask testers to opt in and keep it installed. After 14 days, apply for production in the Dashboard.

---

## iOS (App Store)

### 1. App Store Connect API key

App Store Connect → Users and Access → **Integrations → App Store Connect API** → Team keys → generate a key with role **App Manager**. Download the `.p8` (only once).

### 2. Certificate key

On your Mac:

```bash
ssh-keygen -t rsa -b 2048 -m PEM -f ~/ios_cert_key -q -N ""
```

This private key is used to create and reuse the distribution certificate from CI.

### 3. GitHub secrets

| Secret | Value |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID shown above the keys list |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | the key's Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | full contents of the `.p8` file |
| `IOS_CERTIFICATE_PRIVATE_KEY` | full contents of `~/ios_cert_key` |

### 4. App ID and app record

1. developer.apple.com → Certificates, IDs & Profiles → Identifiers → `com.pravii.taskTrackerApp` (create it if missing) → enable **Sign In with Apple** → Save.
2. App Store Connect → Apps → **+ New App** → iOS, name *Task Tracker: Step by Step*, language English, bundle ID `com.pravii.taskTrackerApp`, SKU `task-tracker`.

### 5. Turn on Apple sign-in in Firebase

Firebase console → Authentication → Sign-in method → **Apple** → Enable → Save (no Services ID is needed for the native iOS flow).

### 6. Build and submit

1. Run **Actions → iOS release**. The build appears in App Store Connect → TestFlight after processing (10–30 min).
2. Fill in the version page, App Privacy and App Review Information from [`listing.md`](listing.md); upload the iPhone screenshots.
3. Pick the build and **Submit for Review**.

---

## Reviewer account

Both stores need a working login. Sign up in the app with an email and password made just for reviewers, add a few tasks with steps, and give those details in the review forms.
