# Store listing: Task Tracker: Step by Step

Copy these into Google Play Console (Main store listing) and App Store Connect (App Information / version page).

## Names

| Field | Value |
|---|---|
| App name (Play, 30 max) | Task Tracker: Step by Step |
| App name (App Store, 30 max) | Task Tracker: Step by Step |
| Subtitle (App Store, 30 max) | Break work into clear steps |
| Category | Productivity |
| Price | Free, no in-app purchases, no ads |
| Contact email | tasks@mail.praveendhra.com |
| Website / marketing URL | https://task.praveendhra.com |
| Privacy policy URL | https://task.praveendhra.com/privacy.html |
| Account deletion URL (Play) | https://task.praveendhra.com/delete-account.html |
| Support URL (App Store) | https://task.praveendhra.com/delete-account.html (or the website) |

## Short description (Play, 80 max)

Plan tasks as steps, track the current one, and get a daily summary by email.

## Promotional text (App Store, 170 max)

Turn any task into clear steps, see exactly where you are, and start each morning with a summary of what's due and what matters most.

## Keywords (App Store, 100 max)

todo,to-do,checklist,steps,planner,projects,habits,reminder,productivity,organizer,goals,daily

## Full description (both stores)

Task Tracker helps you finish things by breaking them into steps and always showing the next one.

STEP BY STEP
• Add a task with as many steps as you need, each with its own note and due date
• Mark the current step and see progress at a glance
• Reorder steps while you plan, not only after

STAY ON TOP OF DATES
• Due dates and priorities on every task, with overdue items floated to the top
• Views for Active, Due today, Upcoming and Done
• Tags and four sort orders to slice your list your way

FAST
• Quick add: type "Call plumber fri #home !high" and the date, tag and priority are filled in for you
• Swipe to complete or archive
• Full-text search across titles, steps, notes and tags

DAILY SUMMARY
• Optional morning email at the hour you choose, in your time zone
• High-priority work first, then overdue, due today, steps due and in progress

EVERYWHERE
• Syncs instantly between your phone and the web app at task.praveendhra.com
• Works offline and catches up when you're back online
• Light and dark themes

PRIVATE
• No ads, no tracking, no data sold
• Delete your account and all data from Settings at any time

## Screenshots

CI renders them from the demo build on every pull request into the `ci-screenshots` branch, folder `store/`:

- App Store, iPhone 6.9"/6.7": `iphone-1-home.png` … `iphone-6-settings.png` (1290 × 2796)
- Google Play phone: `android-1-home.png` … (1080 × 2160)
- Google Play feature graphic: `feature-graphic.png` (1024 × 500)
- Icons: `store/assets/play-icon-512.png`, `store/assets/app-store-icon-1024.png`

## Google Play: Data safety answers

- Does your app collect or share any of the required user data types? **Yes**
- Is all user data encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes** (in app and the deletion URL)
- Data collected (none is shared with third parties; none is optional except where noted):
  - Personal info → **Email address**: collected, purpose *App functionality, Account management*
  - Personal info → **Name**: collected (only with Google/Apple sign-in), *Account management*
  - App activity → **Other user-generated content** (tasks, steps, notes): collected, *App functionality*
- Not collected: location, contacts, photos, device or other IDs, financial info, health, messages, analytics, crash logs.

Other Play App content forms:
- Ads: **No ads**
- App access: **All functionality requires sign-in** → give a reviewer login (create a test account with email and password, e.g. `review@…`, add a couple of tasks)
- Content rating questionnaire: Category *Utility, Productivity*; answer **No** to every content question → rated Everyone / 3+
- Target audience: **18 and over** (simplest; avoids Families policy)
- News app: No · Government app: No · Financial features: None · Health: None

## App Store: App Privacy answers

- Data used to track you: **None**
- Data linked to you:
  - Contact Info → **Email Address** — App Functionality
  - Contact Info → **Name** — App Functionality
  - User Content → **Other User Content** — App Functionality
- Data not linked to you: none
- Age rating: answer **None** to everything → 4+
- Export compliance: already declared in Info.plist (`ITSAppUsesNonExemptEncryption = false`)
- Sign-in required → App Review Information: give the same reviewer email and password
- Review notes: "Sign in with the demo account above, or use Sign in with Apple. Account deletion is in Settings → Delete account."
