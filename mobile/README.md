# LearnLite Flutter client

LearnLite is an offline-first Flutter app. Firebase Authentication handles
email/password identity; SQLite is the local source of truth for learner
profiles, vocabulary, lessons, quizzes, results, progress, history, and saved
resources. Learning data remains local to SQLite; the AI Tutor uses only the
existing LearnLite API and does not synchronize learning records.

## Run

```powershell
flutter pub get
flutter run
```

The Android application ID is `com.example.learnlite`. The Android Firebase
configuration at `android/app/google-services.json` belongs to project
`learnlite-f1dd5` and registers that exact package. The Google Services Gradle
plugin supplies its options to the Android Firebase SDK. When no Dart-defined
options are provided, Android initializes Firebase from that native
configuration. The app rejects a different Firebase project ID.

Email/Password must be enabled in Firebase Console > Authentication >
Sign-in method. For other platforms, provide Firebase client options at build
time:

```powershell
flutter run `
  --dart-define=FIREBASE_API_KEY=your-public-api-key `
  --dart-define=FIREBASE_APP_ID=your-app-id `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id `
  --dart-define=FIREBASE_PROJECT_ID=learnlite-f1dd5 `
  --dart-define=LEARNLITE_API_BASE_URL=https://your-learnlite-api.example
```

For web, also supply `FIREBASE_AUTH_DOMAIN`. Do not substitute values from
another Firebase app or project. The local `firebase.json` is not proof that
Email/Password is enabled remotely; check the Firebase Console. This app does
not deploy or modify Firebase resources.

## AI Tutor

The Tutor sends chat messages to the existing LearnLite API at `POST /ai/chat`
using the signed-in, verified learner's Firebase ID token. That API retains its
current Ollama configuration and model; the Flutter app does not call another
AI provider or substitute generated sample answers.

Set `LEARNLITE_API_BASE_URL` to the reachable base URL of the existing API. For
an Android emulator connecting to an API on the development host, use
`http://10.0.2.2:8000`. Debug Android builds allow cleartext HTTP for local
development; release builds require HTTPS. A physical phone needs a reachable
API URL (prefer HTTPS). If the URL is unset, the API is unreachable, or Ollama
is unavailable, the Tutor reports the issue and offline lessons, vocabulary,
quizzes, and progress continue to work.

## Authentication and offline use

Registration and login use Firebase's Flutter email/password SDK directly.
Firebase retains its normal platform authentication state. Learner profiles
are keyed by Firebase UID in SQLite, so an offline launch for a previously
signed-in account uses that account's local profile. A new login or
registration still needs a Firebase connection; offline Firebase sign-in is
not promised. Email verification and password reset also require a connection.

Users may choose **Continue with downloaded lessons** without signing in.
Guest learning records stay on the device under a separate local guest profile
and are not synchronized or merged into a Firebase account. A registration
username is only checked against profiles on this device; the Firebase email
is the sign-in identity.

## Local data and offline behavior

SQLite is stored in the platform application database as `learnlite.db` and
uses versioned, non-destructive schema migrations. On first startup, the app
imports the bundled vocabulary JSON, and imports existing saved packs,
profiles, and progress from the previous SharedPreferences cache without
deleting the original values. Existing workbook JSON and source workbooks are
preserved.

Schema version 3 adds a per-learner `last_login` timestamp and indexes for
learner-scoped quiz results, learning history, and dictionary searches.
Upgrading from version 2 backfills `last_login` from the existing profile
timestamps and retains the learner records and learning history. Firebase UID
is the primary key in the local `learners` table; repeated sign-ins repair a
missing profile without replacing an existing learner's name, username,
learning preference, or progress. Signing out clears Firebase's locally
persisted auth state but leaves every learner profile and learning record on
the device.

Bundled vocabulary is searchable offline. A bundled LearnLite app-use guide
provides initial lessons and quizzes without adding or certifying Subanen
vocabulary or claiming the guide is an official language/culture curriculum.
Modules, lesson content, quiz
questions/answers, quiz attempts, completion state, XP, and learning history
are stored locally and remain available after restart. Content that has not
been bundled or saved on the device is not fabricated. Downloaded resource
blobs and packs are stored in SQLite. There is no Firestore or backend sync
queue; local learning continues to work without Firebase.

The three `assets/vocabulary/*.json` files preserve 169 LearnLite vocabulary
rows, 68 “Still needed” rows, and 82 starter-list entries. Pending-review and
untranslated statuses remain intact. The app does not invent translations or
claim the local workbook entries are verified dictionary translations.

Learning content, profile data, vocabulary progress, quiz attempts, and
rewards remain SQLite-backed. Only Tutor chat requests use the existing API;
the existing top-level `backend/` implementation and Ollama configuration are
not modified.

## Tests and build

Run from this directory:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
