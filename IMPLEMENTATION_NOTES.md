# LearnLite Implementation Notes

These are practical notes for building, testing and running LearnLite. They are updated as phases progress.

## Verification workflow

OneDrive locks files under `mobile/build/`, so `flutter test` and `flutter clean`
fail inside the workspace with "Flutter failed to delete a directory at
build\unit_test_assets". Run the checks with the script, which copies the
sources to `%TEMP%\learnlite_verify` and never writes into the project:

```powershell
# from the repository root
powershell -NoProfile -ExecutionPolicy Bypass -File mobile\tool\verify.ps1          # pub get, analyze, test
powershell -NoProfile -ExecutionPolicy Bypass -File mobile\tool\verify.ps1 -Build   # also builds a debug APK
```

The script exits non-zero if any step fails and prints a summary at the end.
A debug APK built with `-Build` is written to
`%TEMP%\learnlite_verify\build\app\outputs\flutter-apk\app-debug.apk`.

`flutter analyze` also works directly in `mobile/`.

A permanent fix is to move the project out of a OneDrive-synced folder. That is the owner's choice.

## Environment (2026-11-19)

| Item | Value |
|---|---|
| Flutter | 3.47.1 (stable) |
| Ollama | Installed. `qwen2.5:3b` is the configured Tutor model and must not be changed. |
| Python | 3.14.7 (used only to run the existing backend bridge, D1) |
| Firebase project | `learnlite-f1dd5`; Android package `com.example.learnlite` |

## Architecture constraints

- SQLite is the only learning data store. Firebase is used for authentication only (D2).
- The backend is used only for `POST /ai/chat` (D1). Don't add features to it.
- Never invent Subanen translations, pronunciation or difficulty levels (D4, D5).
- The Tutor is local-network AI: phone → PC bridge → Ollama (D6). Every other feature must work offline.

## Known limitations

- The admin edits a single device's database. Edits are not distributed to other learners.
- Web builds are not supported (no sqflite support, and the auth gateway is disabled on web).
- All workbook vocabulary is unverified ("Pending review").

## Change log

| Date | Phase | Change |
|---|---|---|
| 2026-11-19 | 0 | Baseline commit `7bd8f35`. Added `mobile/tool/verify.ps1` and the four roadmap documents. |
| 2026-11-19 | 1 | Lazy vocabulary list; quiz headline uses correct/total; dictionary searches all entries with Pending review badges (D5); rewards use local calendar days (`lib/core/local_day.dart`, injectable `LearningDatabase.clock`); fixed `setState` returning a Future in 7 places. 67 tests. |

| 2026-11-19 | 3 | Startup step timing; vocabulary import skipped unless the bundled-data fingerprint changes, and existing rows updated instead of skipped; retry after a failed database open; `addHistory` requires an owner; `integrityProblems()`; v1-to-v3 and double-reopen tests; `saveVocabulary` keeps an entry's identity on edit (F9). 76 tests. Emulator: data kept on `install -r`; steady startup setup 2.9–4.2 s (debug). |

| 2026-11-20 | 8 | Design system and redesign of all learner screens, Back fixes, Settings sign-out fix, launcher icon and "LearnLite" label (commits `29be31f`, `152602d`). 78 tests. |
| 2026-11-20 | 4 | Workbook modules (`lib/core/workbook_modules.dart`): 5 modules / 19 lessons with word cards and generated quizzes; identification mode and module filter in practice. 85 tests. |
| 2026-11-20 | 5 | Bridge: `/ai/chat` accepts any verified Firebase user; revocation check only with a service-account file; optional vocabulary `context`. App: `relevantVocabulary()` sends matching workbook entries and lists them under the reply. Backend tests in `backend/tests`. |
| 2026-11-20 | 7 | `userMessage()` replaces raw error text; UI dumps untracked; `.gitignore` covers dumps, `backend/.venv`, `backend/data`. |
| 2026-11-20 | 9 | Release signing from `android/key.properties`; README rewritten. |
| 2026-11-20 | 4–9 | Committed as `5bab2fc`. |
| 2026-11-20 | 2, 4, 7, 9 | `f21e62c`: Auth-emulator hook and device account test (7/7), offline sign-in fix (F15), word-list PDF, release signing outside the repo, OWNER_ACTIONS.md. `bfd7b8c`: guest progress (F16), greeting (F17), quiz scroll (F18), text (F19). 100 unit/widget tests. |
| 2026-11-20 | 5, 7 | `d6e87fe`: LAN-HTTP opt-in for release builds (F13); admin-created entries listed and deactivated entries hidden (F11). 92 tests. Release APK smoke-tested on the emulator; database unchanged across release ↔ debug installs. |

## Device integration tests

- `mobile/integration_test/auth_flow_test.dart` drives the real Firebase Auth plugin and SQLite on a device against the **Firebase Auth emulator**:
  ```powershell
  firebase emulators:start --only auth --project demo-learnlite          # repo root; config in firebase.json
  # in %TEMP%\learnlite_verify (after verify.ps1 copied the sources):
  flutter test integration_test/auth_flow_test.dart -d emulator-5554 --dart-define=LEARNLITE_AUTH_EMULATOR=10.0.2.2:9099
  ```
- **Never run it on `Flutter_Emulator`** (it holds the owner's account and progress). Use `LL_Phone_API36` / `LL_Tablet_API36`.
- The emulator stores accounts under `demo-learnlite`; the test reads verification links from there (`LEARNLITE_AUTH_EMULATOR_PROJECT` overrides).
- `LEARNLITE_AUTH_EMULATOR` only works in debug/profile builds.

## Release signing

- `mobile/tool/create_release_keystore.ps1` creates `%USERPROFILE%\.learnlite-signing\learnlite-upload.jks` and `key.properties` (random password, current-user ACL). It refuses to overwrite an existing key.
- Gradle looks for `key.properties` in `LEARNLITE_KEY_PROPERTIES`, then that folder, then `android/key.properties`; without one it signs with the debug key and warns on release tasks.
- A release-signed APK cannot replace a debug-signed install (signature mismatch). Don't install release builds on `Flutter_Emulator` unless losing its local data is acceptable.

## Avatars

- `lib/core/avatar_design.dart` holds the choices and the `sbn1:` string stored in `learners.avatar_id` (outfit colour also in `outfit_color` as hex). `tryParse` returns null for anything else, so old or empty values show the generic icon. **Add a new prefix (e.g. `sbn2:`) if the meaning of existing fields ever changes.**
- `lib/widgets/subanen_avatar.dart` draws it with `CustomPainter` in a 0–1 unit space; `LearnerAvatar(avatarId: …)` uses it everywhere.
- Builder controls: `lib/features/profile/avatar_builder.dart`, used by `AvatarCreationScreen` (onboarding and "Customize avatar" on Profile). Guests have no Profile tab, so avatars are for accounts.
- To preview many designs without a device, render `SubanenAvatar` widgets in a test and save `RenderRepaintBoundary.toImage()` (see `docs/screenshots/16-avatar-gallery.png`).

## Word-list PDF

- `lib/core/vocabulary_pdf.dart` builds the PDF from the SQLite vocabulary catalog; it is stored as content pack `vocabulary-pdf` (bytes in `content_packs.media_json`) and opened with `printing`. Regenerate it after vocabulary changes by removing and downloading it again.

## Workbook modules

- `buildWorkbookModules()` turns rows of `LearnLite-Subanen-Vocabulary.xlsx` with a numbered module ("1 · Basic Greetings") and a topic into one module per number and one lesson per topic. It never adds Subanen text.
- `seedWorkbookModulesIfChanged()` stores `g<generator version>:<vocabulary fingerprint>` in `app_metadata.workbook_modules_fingerprint_v1`. When it changes, each module is rewritten **in place** (same ID, found through `bundled_module:workbook-module-N`), so progress keyed by module ID and lesson index survives. **Bump `workbookModulesGeneratorVersion`** when lesson or quiz generation changes.
- Lesson word cards are found at display time with `isWorkbookLessonEntry()` (module name + topic), so no schema change was needed. Renaming a topic in the workbook moves its progress to the lesson at the same index.

## Tutor bridge

- Run it as described in the README. In this workspace a venv lives at `%LOCALAPPDATA%\learnlite_backend_venv` and runtime data at `%LOCALAPPDATA%\learnlite_backend_data` (outside OneDrive).
- `POST /ai/chat` body: `messages` (1–10, user/assistant) and optional `context` (≤ 12 objects with `english`, `subanen`, `status`, each ≤ 200 characters).
- Debug builds allow `http://`; release builds require `https://` (`OllamaTutorGateway.configurationMessage`) unless built with `--dart-define=LEARNLITE_ALLOW_LAN_HTTP=true`, which also allows `http://` to a private IPv4 literal (`isPrivateNetworkAddress`). Host names are never allowed over HTTP in release.
- Emulator → PC: `http://10.0.2.2:8000`. The bridge logs these requests as coming from `127.0.0.1`.
- On this 7.6 GB PC, close Gradle daemons (`gradlew --stop`) and other heavy apps before running the emulator and Ollama together (F14).
- Root works on this emulator image (`adb root`), so ANR traces can be read from `/data/anr/`. In Git Bash set `MSYS_NO_PATHCONV=1` first, or device paths get rewritten.

## Vocabulary import

- `LocalVocabularyRepository.fingerprint()` hashes the three bundled JSON files plus `importerVersion`. **Bump `importerVersion`** whenever the column-to-field mapping changes, so every device re-imports.
- `seedVocabularyIfChanged` compares the fingerprint with `app_metadata.vocabulary_seed_fingerprint_v1` and imports only when they differ.
- An import overwrites workbook text fields of rows matched by `source_key`, but never `is_verified`, `is_active`, `pronunciation`, `audio_url`, or a verified entry's review status. The workbooks stay the source of truth.

## Coding notes

- Don't write `setState(() => _future = ...)`. The assignment's value (a Future) is returned to `setState`, which asserts in debug builds. Use a block body.
- Rewards and streak logic must use the helpers in `lib/core/local_day.dart` and `LearningDatabase.clock`, never `DateTime.now().toUtc()` day strings.
- Quiz `score` in local results is a **percentage**. Use `correctAnswers`/`totalQuestions` for counts.

## Device testing

- Emulator: `Flutter_Emulator` (start with `%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe -avd Flutter_Emulator`). adb is at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` and is not on PATH.
- The emulator holds a signed-in real Firebase account. Avoid actions that change its progress unless the owner approves.
