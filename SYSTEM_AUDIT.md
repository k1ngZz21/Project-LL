# LearnLite System Audit

- **Audit date:** 2026-11-19
- **Baseline commit:** `7bd8f35` on `learnlite-roadmap`
- **Method:** the findings were checked against the source code. Diagnostics were `flutter analyze`, `flutter test` (temp copy), git inspection and a local Ollama check.

## 1. System overview

| Area | Finding |
|---|---|
| Flutter app | `mobile/`, Flutter 3.47.1, about 17k lines of Dart in 46 files. Packages: firebase_core/auth, sqflite, http, audioplayers, pdf/printing, file_picker, shared_preferences, uuid. |
| Firebase | Project `learnlite-f1dd5`, Android package `com.example.learnlite`, real `android/app/google-services.json`. Auth only; no Firestore and no sync. |
| SQLite | `learnlite.db`, schema v3, 16 tables. Migrations are non-destructive. Learner data is keyed by Firebase UID, with a separate `offline-guest` profile. Code: `mobile/lib/core/learning_database.dart`. |
| Ollama | Installed on the development PC. Models: `qwen2.5:3b` (configured), `qwen2.5-coder:7b`, `llama3.2`. Server reachable on `localhost:11434`. |
| Backend | `backend/learnlite_api/main.py` (FastAPI, about 1,670 lines, its own SQLite). The app uses only `POST /ai/chat`. It has never been run in this workspace (no `backend/data/`). |
| Vocabulary assets | 3 JSON files generated from the workbooks: 169 vocabulary rows (all "Pending review"), 68 still-needed rows and 82 starter-list rows. |
| Diagnostics | `flutter analyze`: no issues. `flutter test`: 60/60 pass in a temp copy. In the workspace it fails because OneDrive locks `build\unit_test_assets`. |

## 2. Implemented features (verified in source)

- **Auth:** register, email login, logout, password reset, email verification gate, change password and session restore. Unit-tested, **not tested live**.
- **Guest mode:** "Continue with downloaded lessons", with a separate local guest profile.
- **SQLite:** per-UID profile, XP and level, streak, lesson start/complete, quiz attempts and review, learning history, recent searches, vocabulary learned/bookmarked. One-time import of SharedPreferences data.
- **Vocabulary:** 319 bundled entries; debounced search; source and topic filters; practice and quiz with saved attempts.
- **Lessons:** one bundled "Offline Study Guide" module; previous/next, resume, audio playback and a quiz with review.
- **Rewards:** daily quest, weekly chest, badges and on-device PDF certificates.
- **Other screens:** Dashboard, Progress, Profile/avatar (nickname only) and Settings.
- **Admin area:** module, dictionary and resource editing, gated by a Firebase custom claim. Edits are local to the device.
- **AI Tutor screen:** calls `LEARNLITE_API_BASE_URL/ai/chat` with a Firebase ID token and shows clear errors.

## 3. Problems

Each problem is labelled with the phase that will address it.

### Critical
| ID | Problem | Evidence | Phase |
|---|---|---|---|
| C1 | The Tutor can't work end to end. `/ai/chat` requires a learner row in the backend database, which the app never creates. The backend also needs `FIREBASE_ENABLED=true` and Admin credentials. | `backend/learnlite_api/main.py:1376`, where `learner_exists` returns 404 | 5 |
| C2 | Live Firebase auth has never been verified (the earlier Phase 4 blockers). | `mobile/phase4-output/phase4-completion-report.md` | 2 |
| C3 | The vocabulary search ANR hasn't been re-verified. All matching cards are built at once in a non-lazy `ListView`. | `mobile/lib/features/content/local_vocabulary_screen.dart:217` | 1 |
| C4 | Tests and clean builds fail in the workspace because of the OneDrive lock. | `flutter test` cannot delete `build\unit_test_assets` | 0 |

### Functional
| ID | Problem | Evidence | Phase |
|---|---|---|---|
| F1 | The quiz result shows "100 / 1". The score is a percentage but is displayed as score/total. | `mobile/lib/features/modules/lesson_screen.dart:685`, `learning_database.dart:1150` | 1 |
| F2 | The Dictionary is always empty, because it searches verified entries only and none are verified. | `learning_database.dart:1410` | 1 (D5) |
| F3 | Streaks, quests and chests use UTC days, so the day rolls over at 08:00 in the Philippines. | `auth_gateway.dart` `fetchRewards` / `_currentStreak` | 1 |
| F4 | "Offline downloads" only copies modules that are already local. There is no remote source for PDFs or audio. | `auth_gateway.dart` `downloadContentPack` | 4 |
| F5 | Admin edits never reach other learners. | Admin gateway methods write to local SQLite only | Documented limitation |

### Requirement gaps
| ID | Gap | Phase |
|---|---|---|
| G1 | No Common/Intermediate/Difficult data in the workbooks. Topic categories are kept (D4). | Documented |
| G2 | There is only one lesson module, an app-use guide, and no Subanen lessons. | 4 |
| G3 | No pronunciation audio files are bundled. | 4 |
| G4 | Flashcard and identification modes are incomplete or unverified. | 4 |
| G5 | The Tutor doesn't use the local vocabulary (rule §9F). | 5 |
| G6 | The Tutor needs a PC running Ollama and the bridge on the network (D6). | 5, documented |

### Security and release
| ID | Problem | Phase |
|---|---|---|
| S1 | The release build is signed with the debug key; the package ID is `com.example.*`; the label is lowercase. | 9 |
| S2 | Root `window_dump*.xml` UI dumps and a `.docx` are committed. No email addresses were found in the dumps. | 7 |
| S3 | `google-services.json` is committed, which is normal for Firebase, but the API key should be restricted in the Console. | 7 |
| S4 | Web is unsupported (`UnavailableAuthGateway`, and sqflite has no web support), but the README implies web works. | 9 (docs) |
| S5 | Stale build folders exist, and 32 packages have newer, constraint-incompatible versions. | 7, 9 |

### Found during Phase 1
| ID | Problem | Status |
|---|---|---|
| F6 | `setState(() => _future = ...)` returns a Future to `setState`, which asserts in debug builds and breaks the vocabulary learned/saved toggle and several Retry buttons. | Fixed in Phase 1 (7 places) |

### Found during Phase 3
| ID | Problem | Status |
|---|---|---|
| F7 | All bundled vocabulary was re-imported on every launch (about 830 ms on desktop), and corrected workbook rows never updated existing devices. | Fixed in Phase 3 |
| F8 | A failed database open was cached forever, so the app could not recover without a restart. | Fixed in Phase 3 |
| F9 | `saveVocabulary` rewrote an edited workbook entry's `source_key` to `admin:<id>`, so the entry vanished from the offline vocabulary list and a duplicate of the original returned on the next import. | Fixed in Phase 3, with a regression test. A device already affected before the fix (no admin edits found on emulator-5554) would keep its earlier duplicate until cleaned up. |
| F10 | Opening the database takes about 2–3 s at startup on the emulator (debug build), now the slowest startup step. | Open (to investigate in Phase 4 with the launch screen and profile measurements) |
| F11 | Entries an admin creates (rather than edits) never appear in the offline vocabulary list, only in Dictionary search, because the list includes workbook rows only. | Open (existing behaviour; to decide in Phase 5) |

C3, F1, F2 and F3 were addressed in Phase 1. See PHASE_PROGRESS.md for verification status.

### Status update (2026-11-20, Phases 4, 5, 7 and 9)
| ID | Status |
|---|---|
| C1 | **Fixed and verified end to end.** `/ai/chat` no longer needs a backend learner row (D1). Without a service-account file the bridge verifies tokens with Google's public keys (signature, project, issuer, expiry, verified email); with one, Firebase Admin also checks revocation. Found and fixed during testing: the Admin SDK rejected every token without credentials. 9 backend tests pass, including a live `qwen2.5:3b` reply. **Emulator:** signed in as account A, the Tutor answered "How do I say good morning?" with the workbook form labelled pending review, and listed the shared workbook entries. |
| C2 | Open: owner checks for Phase 2. |
| C4 | Worked around with `verify.ps1`. |
| G2, G4 | **Fixed (Phase 4).** 5 workbook modules, 19 lessons, generated quizzes, flashcards, identification mode and module filter. |
| G3, F4 | Open: no audio or PDF source files exist. Word cards state that no audio is recorded. |
| G5 | **Fixed (Phase 5).** The app sends matching workbook entries, labelled unverified, with each Tutor question and lists them under the reply. |
| S1 | Label and icon fixed. Release signing now reads the owner's `key.properties` (falls back to the debug key for test builds). Package ID unchanged (needs a Firebase app registration). |
| S2 | UI dumps removed from tracking and git-ignored (they held a partial username, no passwords). They remain in older commits. The `.docx` was left in place as a project document. |
| S3 | Open: restrict the API key in the Google Cloud Console (owner). |
| S4 | **Fixed.** The new README states Android only. |
| S5 | Firebase packages have minor updates and no security advisories; not upgraded before the demo. Stale build folders were not deleted. |
| F10 | Measured, not changed: debug launches spend 1.5–5 s opening the database on the emulator; most of the debug start-up time is Dart JIT, which release builds remove. |
| F11 | Open (unchanged). |
| F12 (new) | **Fixed.** Raw error text (exceptions, SQL, paths) was shown to learners on five screens and four admin screens. Replaced by `userMessage()`, which keeps LearnLite's own messages and logs the rest. |
| F13 (new) | Release builds accept only an `https://` Tutor address, so a plain-HTTP classroom setup works with debug builds only. Decision needed: HTTPS on the classroom PC, or allow the classroom address over HTTP. |

## 4. Documentation conflicts and their resolution

All seven conflicts were resolved on 2026-11-19. See decisions D1–D7 in
[MASTER_ROADMAP.md](MASTER_ROADMAP.md#recorded-decisions-2026-11-19).
