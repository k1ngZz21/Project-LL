# LearnLite Phase Progress

Status values are COMPLETED, PARTIALLY COMPLETED, IN PROGRESS, BLOCKED and NOT STARTED.
A phase is COMPLETED only after its verification has passed. The plan is in [MASTER_ROADMAP.md](MASTER_ROADMAP.md).

| Phase | Title | Status | Last updated |
|---|---|---|---|
| 0 | Baseline and decisions | COMPLETED | 2026-11-19 |
| 1 | Fix existing defects | PARTIALLY COMPLETED | 2026-11-19 |
| 2 | Live Firebase authentication verification | IN PROGRESS (owner checks pending) | 2026-11-19 |
| 3 | SQLite hardening | COMPLETED (commit `4e7454f`) | 2026-11-20 |
| 4 | Complete the offline learning modules | PARTIALLY COMPLETED (audio/PDF need source files) | 2026-11-20 |
| 5 | AI Tutor integration | COMPLETED (release build verified over LAN HTTP on the emulator; physical-phone run still to do) | 2026-11-20 |
| 6 | Firebase cloud sync | DEFERRED (D2) | 2026-11-19 |
| 7 | Security and error handling | PARTIALLY COMPLETED (only the API-key restriction, an owner Console task, is open) | 2026-11-20 |
| 8 | UI/UX polish and physical device testing | PARTIALLY COMPLETED (physical-phone pass) | 2026-11-20 |
| 9 | Release build and documentation | PARTIALLY COMPLETED (owner keystore, app ID, screenshots) | 2026-11-20 |

The earlier plan (`mobile/.cursor/rules/Phase.md.txt`) had a Phase 4, "Offline Learning Modules". It is
**PARTIALLY COMPLETED** (D7): offline lessons, quizzes and persistence were verified for the guest profile,
but live auth and the vocabulary search ANR remain open. Those items are carried into Phases 1 and 2.

---

## Phase 0: Baseline and decisions

| Task | Status | Evidence |
|---|---|---|
| 0.1 Record decisions D1–D7 | COMPLETED | MASTER_ROADMAP.md |
| 0.2 Baseline commit on `learnlite-roadmap` | COMPLETED | Commit `7bd8f35` (19 files); `main` untouched |
| 0.3 Add `mobile/tool/verify.ps1` | COMPLETED | Run on 2026-11-19: pub get, analyze and test all PASSED |
| 0.4 Create roadmap documents | COMPLETED | MASTER_ROADMAP, SYSTEM_AUDIT, PHASE_PROGRESS, IMPLEMENTATION_NOTES |
| 0.5 Verify (analyze, tests, git status) | COMPLETED | Analyze: no issues. Tests: 60/60 passed. Git: only Phase 0 files changed |

The script's `-Build` option was later verified in Phase 1.

---

## Phase 1: Fix existing defects

Status: **PARTIALLY COMPLETED.** One device check is still open (see the table below).

| Task | Status | Evidence |
|---|---|---|
| 1.1 Vocabulary search freeze (C3) | COMPLETED | Lazy `ListView.builder` and cached search text. Tests: `local_vocabulary_screen_test.dart`. **Emulator:** typed "g" then "gempya" on the 315-entry list; results filtered with no ANR in logcat. |
| 1.2 Quiz score "100 / 1" (F1) | PARTIALLY COMPLETED | The headline now shows correct/total plus a percentage. Widget test updated to the real local value (`score: 100`) and asserts "1 / 1" and "100%". **Not yet checked on the emulator** (it would alter a real account's progress); this moves to Phase 2 with a test account. |
| 1.3 Dictionary shows pending entries (D5) | COMPLETED | Searches all active entries, verified first, with a "Pending review"/"Verified" badge. Tests: DB ranking test, `dictionary_screen_test.dart`. **Emulator:** "gempya" returned 3 entries, each badged "Pending review". |
| 1.4 Local-day streaks, quests and chests (F3) | COMPLETED | `lib/core/local_day.dart` and an injectable clock. Tests: daily bonus across local midnight, streak/quest on local days. **Emulator:** the dashboard calendar shows Thursday 19 as today (UTC+8). |
| Added (approved): setState returning a Future | COMPLETED | Found by a new test. Fixed in 7 places (vocabulary screen, admin reports, dashboard ×2, progress ×2, rewards, settings). **Emulator:** the learned toggle worked on and off with no Flutter errors. |
| 1.5 Verify | COMPLETED | `verify.ps1 -Build`: analyze clean, **67/67 tests**, debug APK built and installed on `emulator-5554`. |

**Side effect (expected):** daily/weekly bonus keys are now local dates. On the switch-over day a learner may receive one extra +5 XP daily bonus. No data was removed.

---

## Phase 2: Live Firebase authentication verification

Status: **IN PROGRESS.** The remaining checks need the owner at the emulator.

| Check | Status | Evidence |
|---|---|---|
| 1. Login survives a restart | COMPLETED | Force-stop and relaunch on emulator-5554 opened Home signed in as account A. |
| 7. Offline relaunch | COMPLETED | Airplane mode plus Wi-Fi and data off (network unreachable, DNS failing). The app relaunched signed in; Lessons, module, Quiz practice, Dictionary and the vocabulary list opened with no errors; the Tutor showed its "not configured" message as expected. Network restored afterwards. |
| 2. Logout keeps local data | NOT STARTED | Needs the owner to sign back in as A |
| 3. Wrong-password message | NOT STARTED | — |
| 4. Register account B | NOT STARTED | Needs the owner's email inbox |
| 5. Quiz on a device (also closes Phase 1, task 1.2) | NOT STARTED | Needs account B |
| 6. A/B progress kept separate | PARTIALLY COMPLETED | Guest vs account A separation verified on the device database (debug build installed, D-10 approved). The A vs B check still needs account B. |
| 8. Account B in the Firebase Console | NOT STARTED | Owner checks the Console |

---

## Phase 3: SQLite hardening

Status: **COMPLETED.** Committed as `4e7454f` and pushed to `origin/learnlite-roadmap` on 2026-11-20. All Phase 3 tasks are implemented and verified on desktop tests and on emulator-5554.

| Task | Status | Evidence |
|---|---|---|
| 3.1 Startup timing | COMPLETED | Per-step timings from the debug build on emulator-5554 (runs 3–6, after the one-time import): open database 1,897–3,192 ms · vocabulary seed check 198–287 ms · legacy cache check 6–10 ms · bundled module 22–34 ms · Firebase init 618–653 ms · **total 2.9–4.2 s**. One-time import launch (run 2): seed 2,046 ms, total 5,844 ms. Time to first frame (`am start -W`): 10.8–12.0 s in debug mode. Debug builds are slower than release; profile numbers come in Phase 11. **Remaining bottleneck: opening the database (about 2–3 s).** |
| 3.2 Vocabulary import fingerprint and update | COMPLETED | Imports only when the fingerprint of the bundled files plus the importer version changes. Existing rows are updated by `source_key`; `is_verified`, `is_active`, `pronunciation`, `audio_url` and a verified entry's review status are preserved. Measured on desktop with real data: first import 830 ms, unchanged launch 20 ms (315 rows). |
| 3.3 Retry after a failed open | COMPLETED | A failed open is no longer cached. Test: first open fails, second succeeds. |
| 3.4 History always has an owner | COMPLETED | `addHistory` requires a non-empty `uid` (all callers already passed one). No table rebuild. |
| 3.5 Integrity check | COMPLETED | `integrityProblems()` runs SQLite's integrity and foreign-key checks and finds ownerless history and search rows. Tests: clean database passes; an orphan row is reported. |
| 3.6 Migration and persistence tests | COMPLETED | v1 to v3 upgrade keeps learner and XP and fills in `last_login`; progress survives two close-and-reopen cycles. |
| 3.8 Admin-edit fix (F9, approved) | COMPLETED | `saveVocabulary` updates in place and never changes `source_key`, `source_file` or `source_row`. Regression test: an edited workbook entry stays in the offline list, keeps its identity, and is not duplicated by the next import; verified, active, review status, pronunciation and audio are preserved; workbook text stays the source of truth. |
| 3.7 Verify | COMPLETED | `verify.ps1 -Build`: analyze clean, **76/76 tests** (75 plus the regression test), debug APK built. Pre-install check: same package `com.example.learnlite` 1.0.0, same signing certificate (SHA-256 `2fab0f91…264a`), target emulator-5554 only. Installed with `adb install -r` (data kept). On-device database before and after: identical learner records (guest XP 27, 2 quiz results, 2 completions, 5 history; account A XP 0); 315 vocabulary rows, **0 duplicate keys** after the first real import; fingerprint stored; 0 ownerless rows; integrity ok. Still signed in as account A after the update. |

---

## Phase 4: Complete the offline learning modules

Status: **PARTIALLY COMPLETED.** Tasks 4.1–4.3 and 4.5 are implemented and verified. Task 4.4 (audio and PDF) is blocked: no source files exist.

| Task | Status | Evidence |
|---|---|---|
| 4.1 Lessons from the workbook | COMPLETED | `lib/core/workbook_modules.dart` turns `LearnLite-Subanen-Vocabulary.xlsx` into **5 modules and 19 lessons** (one per workbook topic). Each lesson shows its rows as word cards: Subanen form, English, Cebuano/Bisaya, dialect, other forms and notes as recorded, review status, source row. The only added text is fixed factual wording; no Subanen content is invented. The starter list (82) and still-needed list (68) stay in the dictionary and practice. |
| 4.2 Quizzes from the same data | COMPLETED | Up to 5 questions per lesson, spread over the lesson's rows. The answer is the row's Subanen form; distractors are Subanen forms from the same module; each explanation cites the workbook row. Deterministic. Test: every answer and choice exists in the workbook module, no duplicate choices. |
| 4.3 Identification mode and module filter | COMPLETED | Quiz tab: "English → Subanen" / "Subanen → English" and a Module filter (category list follows the module). Widget test for identification mode. |
| 4.4 Audio and PDF | NOT STARTED | No source audio or PDF files exist. Every word card states "No recorded audio in the workbook"; nothing is presented as available. |
| 4.5 Data safety | COMPLETED | No schema change. Modules install once and are rewritten **in place** (same module ID) only when the workbook or generator version changes, so completions, quiz results and resume positions are kept. Test: an updated workbook keeps module IDs and a learner's completed lesson. **Emulator:** after the generator update (v1 → v2), still 6 modules (no duplicates), new descriptions shown, and the guest's "Numbers 1–10" still showed **Resume**. Seeding errors are caught so the app always opens. |
| 4.6 Verify | COMPLETED | `verify.ps1 -Build`: analyze clean, **85/85 tests** (78 + 6 module tests + 1 practice test), debug APK built, installed with `adb install -r` (data kept). **Airplane mode on emulator-5554** (airplane on, Wi-Fi and data off, ping unreachable): workbook modules listed, the "Numbers 1–10" lesson showed its word cards, its 5-question quiz opened, Back returned to the lesson, and the Quiz tab's module filter and identification mode worked. Network restored afterwards. |

**Startup cost (debug, emulator):** first install of the modules 8.8 s once; regeneration after a change 3.3 s once; normal launches 21 ms for the check.

**Not done on JanJan's account:** testing used the offline guest profile only; no quiz was submitted.

---

## Phase 5: AI Tutor integration

Status: **COMPLETED** for the emulator. Committed in `5bab2fc` and `d6e87fe`.

| Task | Status | Evidence |
|---|---|---|
| 5.1 `/ai/chat` without a backend learner row (C1, D1) | COMPLETED | Backend tests (9/9 on 2026-11-20), including token checks without a service-account file. |
| 5.2 Run instructions | COMPLETED | README "Set up the AI Tutor". |
| 5.3 `LEARNLITE_API_BASE_URL` for emulator and phone | COMPLETED | Emulator: `http://10.0.2.2:8000`. Phone: the PC's LAN address, see F13 below. |
| 5.4 Local vocabulary context (G5) | COMPLETED | `relevantVocabulary()`; tests in `vocabulary_context_test.dart`. |
| 5.5 Live reply and error paths | COMPLETED | Live `qwen2.5:3b` reply (backend test and emulator); stopped Ollama and timeout give clear 503 messages (backend tests). |
| F13 Release builds and plain-HTTP classroom PCs | COMPLETED | HTTPS stays the default. Opt-in `--dart-define=LEARNLITE_ALLOW_LAN_HTTP=true` allows `http://` only to a private IPv4 address (10/8, 172.16/12, 192.168/16). 3 new tests. **Emulator, release build:** "good morning" answered by `qwen2.5:3b` with "gempya seselem" (Pending review) and the shared workbook entries listed. |

**Observation (2026-11-20):** during the release test the emulator showed "LearnLite isn't responding" and later "System UI isn't responding". The ANR trace shows the main thread waiting inside Android's own `SurfaceControl` call, all LearnLite threads at 0% CPU, `system_server` at 143%, and the host PC at 81% CPU with 0.5–0.7 GB of 7.6 GB RAM free (emulator, Ollama model, Gradle, editor and browser at once). This is host resource exhaustion, not an app defect, but it should be rechecked on the physical phone with the Tutor PC separate (F14).

---

## Phase 7: Security and error handling

Status: **PARTIALLY COMPLETED.** Every item is done or justified except the API-key restriction, which only the owner can do in the Google Cloud Console.

| Check | Result |
|---|---|
| Restrict the Firebase API key (S3) | **OPEN (owner).** Console → APIs & Services → Credentials → restrict the Android key to package `com.example.learnlite` + the signing SHA-1, and to the Identity Toolkit / Token Service APIs. |
| No cleartext HTTP in release | PASSED. Release builds require HTTPS; plain HTTP only with the explicit LAN opt-in and only to private IPv4 addresses (F13). |
| Admin claim | PASSED. `verifyAdministrator()` checks the Firebase custom claim (`admin`, `role`, or `roles`) and is called by every admin read and write (11 methods). Claims can only be set with the Admin SDK. Edits stay local to the device (F5). |
| Committed UI dumps (S2) | PASSED. Untracked and git-ignored. They remain in older commits (partial username, no passwords); rewriting history was not done. |
| Secrets in git history | PASSED. `git log --all -p` scanned for private keys, service-account files, keystores, `.env`, tokens and passwords. Only the Firebase Android API key in `google-services.json` (public by design, see S3) and documentation placeholders were found. |
| Package review (S5) | JUSTIFIED. Minor updates for firebase_core/firebase_auth and a major one for file_picker (`flutter pub outdated`, 2026-11-20); no advisories were recorded in the earlier review (S5). Not upgraded before the demo to avoid regressions. |
| Raw error text (F12) | PASSED. `userMessage()` on all learner and admin screens. |

---

## Phase 9: Release build and documentation

| Task | Status | Evidence |
|---|---|---|
| 9.1 Real application ID | BLOCKED (owner) | Needs a new Firebase Android app registration and `google-services.json`. |
| 9.2 Release signing | PARTIALLY COMPLETED | Gradle reads `android/key.properties`; without it the debug key is used. The owner must create and keep the keystore. |
| 9.3 Release APK smoke test | COMPLETED (emulator) | `flutter build apk --release` (57 MB). Installed with `adb install -r` over the debug build (same certificate `2fab0f91…264a`): opened signed in as account A; Home, Lessons (modules listed), Quiz and Progress correct; Tutor answered over LAN HTTP. Reinstalling the debug build afterwards: on-device database **identical** to the snapshot taken before (integrity ok, 2 learners, XP 27/27, 315 vocabulary rows, 0 duplicate keys, same counts in every table). |
| 9.4 README and docs | COMPLETED | README rewritten; this file, SYSTEM_AUDIT and IMPLEMENTATION_NOTES updated. |
| 9.5 Screenshots | NOT STARTED | Emulator screenshots were taken for testing only (temp folder); curated screenshots need a stable device. |
| 9.6 Stale build folders | COMPLETED (2026-11-20, owner request) | Deleted untracked/ignored items only: `mobile/build`, `build_new`, `build_phase1`, `build_phase4`, the two old APKs in `mobile/phase4-output` (the report was kept), `mobile/.dart_tool` (regenerated by `flutter pub get`), `mobile/android/.gradle`, empty `.idea` and `SYSTEM NOTES`, `.firebase` cache, the root `window_dump*.xml`, `.github/modernize` (VS Code Java-upgrade extension logs) and `__pycache__`. About 5 GB freed. `verify.ps1` passed afterwards; git status unchanged. |

**APK for the owner:** `release/LearnLite-1.0.0-release-tutor-10.0.10.5.apk` (git-ignored, SHA-256 `5070f473…03aa36`). Release mode, **signed with the debug key (testing only)**, Tutor address `http://10.0.10.5:8000` (this PC's Wi-Fi address on 2026-11-20, assigned by DHCP so it may change) with the LAN opt-in. The phone needs inbound TCP 8000 allowed in Windows Firewall and the bridge running.

---

## Phase 8: UI/UX polish and physical device testing

Status: **PARTIALLY COMPLETED.** Done early as the demo sprint and redesign (commit `29be31f`) and the launcher icon (`152602d`).

| Item | Status | Evidence |
|---|---|---|
| Screen states and navigation review | COMPLETED | Redesign of every learner screen; Back fixes (tabs, quiz results); Settings sign-out fix. Emulator walkthroughs recorded in the session reports. |
| App label and icon | COMPLETED | "LearnLite" with the LearnLite logo, including an adaptive icon. Verified in the emulator app drawer. |
| Physical phone | PARTIALLY COMPLETED | Debug APK installed and opened on a TECNO Spark Go 2 (Android 15). The full online/offline pass on the phone is still to do. |

---

**G1:** guest progress stays separate from accounts (current behaviour, unchanged). Verified on the device database: the guest's records and account A's are stored under separate learner IDs with no crossover.

**Phase 2 evidence collected early:** after reinstalling the APK, the emulator reopened already signed in to an existing Firebase account. This shows the session persists, but it does not replace the planned Phase 2 checks.

**Not covered by Phase 0:** no app behavior was changed, so no device testing applies.
