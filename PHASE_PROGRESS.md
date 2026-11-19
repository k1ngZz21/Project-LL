# LearnLite Phase Progress

Status values are COMPLETED, PARTIALLY COMPLETED, IN PROGRESS, BLOCKED and NOT STARTED.
A phase is COMPLETED only after its verification has passed. The plan is in [MASTER_ROADMAP.md](MASTER_ROADMAP.md).

| Phase | Title | Status | Last updated |
|---|---|---|---|
| 0 | Baseline and decisions | COMPLETED | 2026-11-19 |
| 1 | Fix existing defects | PARTIALLY COMPLETED | 2026-11-19 |
| 2 | Live Firebase authentication verification | NOT STARTED | — |
| 3 | SQLite hardening | NOT STARTED | — |
| 4 | Complete the offline learning modules | NOT STARTED | — |
| 5 | AI Tutor integration | NOT STARTED | — |
| 6 | Firebase cloud sync | DEFERRED (D2) | 2026-11-19 |
| 7 | Security and error handling | NOT STARTED | — |
| 8 | UI/UX polish and physical device testing | NOT STARTED | — |
| 9 | Release build and documentation | NOT STARTED | — |

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

**Phase 2 evidence collected early:** after reinstalling the APK, the emulator reopened already signed in to an existing Firebase account. This shows the session persists, but it does not replace the planned Phase 2 checks.

**Not covered by Phase 0:** no app behavior was changed, so no device testing applies.
