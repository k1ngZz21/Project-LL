# LearnLite Master Roadmap

This is the central plan for finishing LearnLite. Phase status is tracked in
[PHASE_PROGRESS.md](PHASE_PROGRESS.md), the findings behind each phase are in
[SYSTEM_AUDIT.md](SYSTEM_AUDIT.md), and build/test procedures are in
[IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md).

- **Roadmap approved:** 2026-11-19
- **Working branch:** `learnlite-roadmap` (merges to `main` only with approval)

## Approved stack

| Layer | Technology | Role |
|---|---|---|
| App | Flutter (`mobile/`) | All UI and application logic |
| Identity | Firebase Authentication (`learnlite-f1dd5`) | Email/password accounts only |
| Data | SQLite (`learnlite.db`, sqflite) | Primary and only learning data store |
| AI | Ollama, `qwen2.5:3b` | Local AI Tutor model, configuration unchanged |
| AI bridge | Existing `backend/learnlite_api` (FastAPI) | Used **only** as the Ollama bridge for `POST /ai/chat` |

No new languages, frameworks or databases may be added without approval.

## Approval workflow

1. Each phase gets a detailed plan, which must be approved before any file changes.
2. The approved tasks are implemented and verified (`mobile/tool/verify.ps1`, plus device checks where required).
3. Results and remaining issues are reported.
4. The next phase starts only after explicit approval. Approving the roadmap is not approval of any phase's changes.
5. Work outside the approved scope stops until it is approved.

Status values: COMPLETED, PARTIALLY COMPLETED, IN PROGRESS, BLOCKED, NOT STARTED.
Nothing unverified may be marked COMPLETED.

## Recorded decisions (2026-11-19)

| # | Topic | Decision |
|---|---|---|
| D1 | AI bridge | Keep the existing Python backend as the Ollama bridge only. Apply the minimal fix so `/ai/chat` accepts any verified Firebase user without a backend learner row. The Ollama model and URL stay unchanged. No other backend features are used. |
| D2 | Firebase scope | Firebase is used for authentication only. No Firestore and no cloud sync. Phase 6 is deferred. |
| D3 | Vocabulary storage | The bundled workbook JSON stays the source asset and is seeded into SQLite. This overrides the "no vocabulary tables" line in `mobile/.cursor/rules/learnlite.mdc` §9A. |
| D4 | Vocabulary categories | Keep the Module/Topic categories from the workbooks. Common/Intermediate/Difficult levels are not available in the source data and will not be invented. |
| D5 | Dictionary | Search all workbook entries, with a clear "Pending review" label on every unverified entry. Nothing is presented as a verified translation. |
| D6 | "Offline" AI | The Tutor is documented as **local-network AI**: the phone talks to a PC running Ollama and the bridge. It is not on-device AI. Lessons, vocabulary, quizzes and progress remain fully offline. |
| D7 | Earlier Phase 4 | The previous plan's Phase 4 is recorded as PARTIALLY COMPLETED because live auth checks and the search ANR are unresolved. |

## Phase order and dependencies

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 ─┐
                       └──────────────→ Phase 5 ─┼→ Phase 7 → Phase 8 → Phase 9
                       └─(deferred)───→ Phase 6 ─┘
```

- Phase 5 needs Phase 2, because the Tutor requires a verified Firebase ID token. It can run alongside Phase 4.
- Phase 6 is deferred by D2.
- Phase 9 needs Phase 8's physical-device pass.

## Phases

### Phase 0: Baseline and decisions
- **Objective:** a safe, reproducible starting point.
- **Tasks:**
  1. Record decisions D1–D7.
  2. Commit the pre-roadmap work as a baseline.
  3. Add `mobile/tool/verify.ps1`, which runs tests in a temp copy to avoid the OneDrive lock.
  4. Create the four roadmap documents.
- **Complete when:** decisions are recorded, the baseline is committed, and verify.ps1 shows a clean analyze and passing tests.

### Phase 1: Fix existing defects
- **Objective:** fix the known bugs before adding features.
- **Tasks:**
  1. Build the vocabulary list lazily to fix the search ANR.
  2. Fix the quiz score display ("100 / 1").
  3. Apply D5 to the Dictionary.
  4. Use the device's local day for streaks, quests and chests.
  5. Add a regression test for each fix.
- **Files:** `local_vocabulary_screen.dart`, `lesson_screen.dart`, `dictionary_screen.dart`, `auth_gateway.dart`, `learning_database.dart`, tests.
- **Complete when:** every fix has a test, verify.ps1 passes, and emulator search has no ANR.

### Phase 2: Live Firebase authentication verification
- **Objective:** close the earlier Phase 4 auth blockers with real accounts.
- **Tasks:** with two user-authorized test accounts, test register, login, wrong password, logout, restart persistence, offline relaunch and account switching (progress isolation). Confirm the accounts appear in the Firebase Console.
- **Complete when:** every item has been verified on the emulator. Only defects found here are fixed.

### Phase 3: SQLite hardening
- **Objective:** reliable local data.
- **Tasks:** test the v1→v3 migration on a real old database, check foreign keys and orphans, decide guest-data handling after sign-in, enforce a non-null `learning_history.uid`, and guard concurrent opens.
- **Complete when:** migration and persistence tests pass and data survives restarts on a device.

### Phase 4: Complete the offline learning modules
- **Objective:** real educational content.
- **Tasks:**
  1. Build Subanen language and culture lessons from the workbook data, without inventing any.
  2. Add flashcard and identification practice modes.
  3. Add offline pronunciation audio and dictionary PDF resources, if source files are provided.
  4. Show a clear message when audio is unavailable.
- **Complete when:** every advertised module works in airplane mode on the emulator.

### Phase 5: AI Tutor integration (D1, D6)
- **Objective:** the Tutor answers using the existing `qwen2.5:3b` setup.
- **Tasks:**
  1. Make the minimal `/ai/chat` learner-row fix.
  2. Document how to run the backend with Firebase Admin credentials.
  3. Configure `LEARNLITE_API_BASE_URL` for the emulator and the phone.
  4. Give the Tutor relevant local vocabulary, labelled as pending review.
  5. Test live replies, a stopped Ollama and a timeout.
- **Complete when:** a live reply is verified on the emulator, the error paths are verified, offline learning still works while the Tutor is down, and the Ollama configuration is unchanged.

### Phase 6: Firebase cloud sync (DEFERRED by D2)
This phase is reconsidered only if the decision changes.

### Phase 7: Security and error handling
- **Objective:** apply the `SECURITY.MD` checks that fit this stack.
- **Tasks:** restrict the API key, confirm release builds have no cleartext HTTP, check the admin claim, remove the committed UI dumps (with approval), scan git history for secrets, review packages, and remove raw error text shown to users.
- **Complete when:** a checklist report shows each item passed or justified.

### Phase 8: UI/UX polish and physical device testing
- **Tasks:** review every screen's loading, empty and error states and navigation; fix the app label and icon; run a full online and offline pass on a physical Android phone.
- **Complete when:** there are no major navigation bugs, no data loss, and the app works on a real phone.

### Phase 9: Release build and documentation
- **Tasks:**
  1. Set the real application ID (needs a Firebase app registration, with approval).
  2. Set up a release signing key that the owner keeps.
  3. Build the release APK, install it and smoke-test it.
  4. Rewrite the root README and document Firebase, the SQLite schema and the Tutor setup.
  5. Take screenshots.
  6. Clean up stale build folders (with approval).
- **Complete when:** the signed release APK installs and works and the documentation is complete.

## Final completion criteria

1. `flutter analyze` is clean and all tests pass through verify.ps1.
2. Live registration, login, logout, persistence and two-account isolation are verified.
3. Lessons, vocabulary, quizzes, progress and rewards work in airplane mode on a physical phone, and data survives a restart.
4. The Tutor answers with the existing Ollama model and shows clear errors when the model is unavailable.
5. There are no open critical or functional defects from SYSTEM_AUDIT.md.
6. The Phase 7 security checklist is complete.
7. A signed release APK installs and runs.
8. Documentation matches the app, and remaining limitations (local-network Tutor, unverified vocabulary) are stated openly.
