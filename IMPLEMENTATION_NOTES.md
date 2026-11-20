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
